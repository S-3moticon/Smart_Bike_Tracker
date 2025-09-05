import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../models/bike_device.dart';
import '../constants/ble_protocol.dart';
import '../constants/app_constants.dart';

class BikeBluetoothService {
  static final BikeBluetoothService _instance = BikeBluetoothService._internal();
  factory BikeBluetoothService() => _instance;
  BikeBluetoothService._internal();
  
  final _scanResultsController = StreamController<List<BikeDevice>>.broadcast();
  final _connectionStateController = StreamController<BluetoothConnectionState>.broadcast();
  final _bluetoothStateController = StreamController<BluetoothAdapterState>.broadcast();
  
  Stream<List<BikeDevice>> get scanResults => _scanResultsController.stream;
  Stream<BluetoothConnectionState> get connectionState => _connectionStateController.stream;
  Stream<BluetoothAdapterState> get bluetoothState => _bluetoothStateController.stream;
  
  final List<BikeDevice> _discoveredDevices = [];
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  
  Timer? _reconnectionTimer;
  String? _lastConnectedDeviceId;
  bool _isReconnecting = false;
  
  // Status updates stream
  StreamSubscription? _statusSubscription;
  final _deviceStatusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get deviceStatus => _deviceStatusController.stream;
  
  // GPS History updates stream
  StreamSubscription? _historySubscription;
  final _gpsHistoryController = StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get gpsHistoryStream => _gpsHistoryController.stream;
  
  // Bluetooth adapter state monitoring
  StreamSubscription? _adapterStateSubscription;
  
  // Use storage keys from constants
  static const String _prefKeyLastDevice = AppConstants.keyLastDevice;
  static const String _prefKeyLastDeviceName = AppConstants.keyLastDeviceName;
  static const String _prefKeyAutoConnect = AppConstants.keyAutoConnect;
  
  // Initialize Bluetooth state monitoring
  void initializeBluetoothMonitoring() {
    _adapterStateSubscription?.cancel();
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      developer.log('Bluetooth adapter state changed: $state', name: 'BLE');
      _bluetoothStateController.add(state);
      
      // If Bluetooth is turned off while connected, handle disconnection
      if (state == BluetoothAdapterState.off && _connectedDevice != null) {
        developer.log('Bluetooth turned off, disconnecting...', name: 'BLE');
        _handleDisconnection();
      }
    });
  }
  
  Future<bool> checkBluetoothAvailability() async {
    try {
      if (await FlutterBluePlus.isSupported == false) {
        developer.log('Bluetooth not supported on this device', name: 'BLE');
        return false;
      }
      
      // Check location services first (required for BLE scanning on Android)
      if (Platform.isAndroid) {
        bool locationEnabled = await Geolocator.isLocationServiceEnabled();
        if (!locationEnabled) {
          developer.log('Location services disabled - required for BLE scanning', name: 'BLE');
          return false;
        }
        
        // Request Bluetooth permissions for Android 12+
        final permissions = await _requestBluetoothPermissions();
        if (!permissions) {
          developer.log('Bluetooth permissions not granted', name: 'BLE');
          return false;
        }
      }
      
      final state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
    } catch (e) {
      developer.log('Error checking bluetooth availability: $e', name: 'BLE');
      return false;
    }
  }
  
  Future<bool> _requestBluetoothPermissions() async {
    try {
      // Check Android version
      if (Platform.isAndroid) {
        // For Android 12+ (API 31+), we need BLUETOOTH_SCAN and BLUETOOTH_CONNECT
        Map<Permission, PermissionStatus> statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,  // Still needed for BLE scanning
        ].request();
        
        bool allGranted = true;
        statuses.forEach((permission, status) {
          developer.log('Permission ${permission.toString()}: ${status.toString()}', name: 'BLE');
          if (!status.isGranted) {
            allGranted = false;
          }
        });
        
        return allGranted;
      }
      return true;
    } catch (e) {
      developer.log('Error requesting Bluetooth permissions: $e', name: 'BLE');
      // If permission_handler doesn't recognize the permissions (older Android), continue
      return true;
    }
  }
  
  Future<void> startScan({Duration timeout = const Duration(seconds: AppConstants.bleScanTimeout)}) async {
    try {
      // Check location services before scanning
      if (Platform.isAndroid) {
        bool locationEnabled = await Geolocator.isLocationServiceEnabled();
        if (!locationEnabled) {
          developer.log('Cannot start scan - location services disabled', name: 'BLE');
          throw Exception('Location services must be enabled for Bluetooth scanning');
        }
      }
      
      _discoveredDevices.clear();
      _scanResultsController.add([]);
      
      developer.log('Starting BLE scan...', name: 'BLE');
      
      // Stop any existing scan first
      await FlutterBluePlus.stopScan();
      
      // Start scan without service filter to ensure we see all devices
      // Note: androidUsesFineLocation is set to false for Android 12+ if we don't need location-based filtering
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidScanMode: AndroidScanMode.lowLatency,
        androidUsesFineLocation: false,  // Don't require fine location for Android 12+
      );
      
      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _discoveredDevices.clear();
        
        developer.log('Scan results received: ${results.length} devices', name: 'BLE');
        
        for (var result in results) {
          final device = BikeDevice.fromScanResult(result);
          
          // Enhanced logging for debugging
          developer.log(
            'Device found: name="${device.name}", '
            'id=${device.id}, '
            'rssi=${device.rssi}, '
            'isBikeTracker=${device.isBikeTracker}',
            name: 'BLE',
          );
          
          // Add all devices, even those without names (might be our ESP32)
          final existingIndex = _discoveredDevices.indexWhere(
            (d) => d.id == device.id,
          );
          
          if (existingIndex >= 0) {
            _discoveredDevices[existingIndex] = device;
          } else {
            _discoveredDevices.add(device);
          }
        }
        
        _discoveredDevices.sort((a, b) {
          if (a.isBikeTracker && !b.isBikeTracker) return -1;
          if (!a.isBikeTracker && b.isBikeTracker) return 1;
          return b.rssi.compareTo(a.rssi);
        });
        
        _scanResultsController.add(List.from(_discoveredDevices));
        developer.log('Found ${_discoveredDevices.length} visible devices, ${_discoveredDevices.where((d) => d.isBikeTracker).length} bike trackers', name: 'BLE');
      });
    } catch (e) {
      developer.log('Error starting scan: $e', name: 'BLE', error: e);
      rethrow;
    }
  }
  
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    _scanSubscription = null;
  }
  
  Future<bool> connectToDevice(BikeDevice bikeDevice) async {
    try {
      await stopScan();
      
      _connectedDevice = bikeDevice.device;
      _lastConnectedDeviceId = bikeDevice.id;
      
      await bikeDevice.device.connect(
        autoConnect: false,
        mtu: null,
      );
      
      _connectionSubscription?.cancel();
      _connectionSubscription = bikeDevice.device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        } else if (state == BluetoothConnectionState.connected) {
          _isReconnecting = false;
          _reconnectionTimer?.cancel();
        }
        _connectionStateController.add(state);
      });
      
      // Request larger MTU for DLE support (default is 23, we need 512 for optimal throughput)
      try {
        if (Platform.isAndroid) {
          final mtu = await bikeDevice.device.requestMtu(AppConstants.bleMtuSize);
          developer.log('MTU negotiated: $mtu bytes (DLE enabled for packets up to 251 bytes)', name: 'BLE');
          
          // Log DLE status for debugging
          if (mtu >= 512) {
            developer.log('DLE: Full support confirmed (MTU=$mtu)', name: 'BLE');
          } else if (mtu >= 185) {
            developer.log('DLE: Partial support (MTU=$mtu, falling back to smaller packets)', name: 'BLE');
          } else {
            developer.log('DLE: Not supported (MTU=$mtu, using legacy mode)', name: 'BLE');
          }
        }
      } catch (e) {
        developer.log('MTU negotiation failed: $e (using default MTU)', name: 'BLE');
      }
      
      // Discover services after connection
      await _discoverServices(bikeDevice.device);
      
      // Subscribe to status updates
      await subscribeToStatusUpdates();
      
      // Save device info for auto-connect
      await _saveLastConnectedDevice(bikeDevice.id, bikeDevice.name);
      
      developer.log('Connected to ${bikeDevice.name}', name: 'BLE');
      return true;
    } catch (e) {
      developer.log('Error connecting to device: $e', name: 'BLE', error: e);
      _connectionStateController.add(BluetoothConnectionState.disconnected);
      return false;
    }
  }
  
  Future<void> _discoverServices(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      
      for (var service in services) {
        developer.log('Found service: ${service.uuid}', name: 'BLE');
        
        if (service.uuid.toString().toLowerCase() == BleProtocol.serviceUuid.toLowerCase()) {
          developer.log('Found bike tracker service', name: 'BLE');
          
          for (var char in service.characteristics) {
            developer.log('  Characteristic: ${char.uuid}', name: 'BLE');
          }
        }
      }
    } catch (e) {
      developer.log('Error discovering services: $e', name: 'BLE', error: e);
    }
  }
  
  void _handleDisconnection() {
    developer.log('Device disconnected, attempting reconnection...', name: 'BLE');
    
    if (!_isReconnecting && _lastConnectedDeviceId != null) {
      _isReconnecting = true;
      _startReconnectionTimer();
    }
  }
  
  void _startReconnectionTimer() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer.periodic(const Duration(seconds: AppConstants.bleReconnectionInterval), (timer) async {
      if (!_isReconnecting) {
        timer.cancel();
        return;
      }
      
      developer.log('Attempting reconnection...', name: 'BLE');
      
      await startScan(timeout: const Duration(seconds: 3));
      
      await Future.delayed(const Duration(seconds: 3));
      
      final device = _discoveredDevices.firstWhere(
        (d) => d.id == _lastConnectedDeviceId,
        orElse: () => _discoveredDevices.firstWhere(
          (d) => d.isBikeTracker,
          orElse: () => BikeDevice(
            device: _connectedDevice!,
            name: '',
            id: '',
            rssi: 0,
            lastSeen: DateTime.now(),
          ),
        ),
      );
      
      if (device.name.isNotEmpty) {
        final connected = await connectToDevice(device);
        if (connected) {
          timer.cancel();
          _isReconnecting = false;
        }
      }
    });
  }
  
  Future<bool> clearConfiguration() async {
    try {
      if (_connectedDevice == null) {
        developer.log('No device connected', name: 'BLE-ClearConfig');
        return false;
      }
      
      developer.log('Clearing device configuration...', name: 'BLE-ClearConfig');
      
      // Send empty configuration to clear MCU settings
      return await sendConfiguration(
        phoneNumber: '',  // Empty phone number indicates clear
        updateInterval: 300,  // Reset to default
        alertEnabled: false,  // Disable alerts
      );
    } catch (e) {
      developer.log('Error clearing configuration: $e', name: 'BLE-ClearConfig', error: e);
      return false;
    }
  }
  
  Future<List<Map<String, dynamic>>?> readGPSHistory() async {
    try {
      if (_connectedDevice == null) {
        developer.log('No device connected', name: 'BLE-GPSHistory');
        return null;
      }
      
      developer.log('Reading GPS history from device: ${_connectedDevice!.platformName}', name: 'BLE-GPSHistory');
      
      // Find the bike tracker service - with timeout handling
      List<BluetoothService> services;
      try {
        developer.log('Starting service discovery...', name: 'BLE-GPSHistory');
        services = await _connectedDevice!.discoverServices().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            developer.log('Service discovery timed out', name: 'BLE-GPSHistory');
            throw TimeoutException('Service discovery timed out');
          },
        );
        developer.log('Service discovery completed. Found ${services.length} services', name: 'BLE-GPSHistory');
      } catch (e) {
        developer.log('Error during service discovery: $e', name: 'BLE-GPSHistory');
        return null;
      }
      
      for (BluetoothService service in services) {
        developer.log('Checking service: ${service.uuid}', name: 'BLE-GPSHistory');
        
        // Handle both short UUID (1234) and full UUID formats
        String serviceUuid = service.uuid.toString().toLowerCase();
        String targetUuid = AppConstants.serviceUuid.toLowerCase();
        
        // Check if it's the short form (1234) or full form match
        bool isMatch = serviceUuid == targetUuid || 
                      serviceUuid == '1234' || 
                      serviceUuid == '00001234' ||
                      serviceUuid.contains('1234-0000-1000');
        
        if (isMatch) {
          developer.log('Found bike tracker service with ${service.characteristics.length} characteristics', name: 'BLE-GPSHistory');
          
          // Find history characteristic
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            developer.log('Checking characteristic: ${characteristic.uuid}', name: 'BLE-GPSHistory');
            
            // Handle both short UUID (1239) and full UUID formats for history characteristic
            String charUuid = characteristic.uuid.toString().toLowerCase();
            String targetHistoryUuid = AppConstants.historyCharUuid.toLowerCase();
            
            bool isHistoryChar = charUuid == targetHistoryUuid || 
                                charUuid == '1239' || 
                                charUuid == '00001239' ||
                                charUuid.contains('1239-0000-1000');
            
            if (isHistoryChar) {
              if (!characteristic.properties.read) {
                developer.log('History characteristic does not support read!', name: 'BLE-GPSHistory');
                return null;
              }
              
              try {
                List<int> value = await characteristic.read().timeout(
                  const Duration(seconds: 5),
                  onTimeout: () => throw TimeoutException('Characteristic read timed out'),
                );
                
                if (value.isEmpty) {
                  developer.log('Characteristic returned empty data', name: 'BLE-GPSHistory');
                  return [];
                }
                
                String jsonString = String.fromCharCodes(value);
                developer.log('Received GPS history data: ${value.length} bytes', name: 'BLE-GPSHistory');
                
                final history = _parseGPSHistory(jsonString);
                
                if (history != null) {
                  developer.log('Parsed ${history.length} GPS points from history (DLE enabled)', name: 'BLE-GPSHistory');
                  _gpsHistoryController.add(history);
                }
                return history;
              } catch (e) {
                developer.log('Error reading characteristic: $e', name: 'BLE-GPSHistory');
                return null;
              }
            }
          }
          developer.log('History characteristic not found. Looking for: ${AppConstants.historyCharUuid} or 1239', name: 'BLE-GPSHistory');
          developer.log('Available characteristics in service:', name: 'BLE-GPSHistory');
          for (var char in service.characteristics) {
            developer.log('  - ${char.uuid} (read: ${char.properties.read}, notify: ${char.properties.notify})', name: 'BLE-GPSHistory');
          }
        }
      }
      
      developer.log('Service not found: ${AppConstants.serviceUuid}', name: 'BLE-GPSHistory');
      return null;
    } catch (e) {
      developer.log('Error reading GPS history: $e', name: 'BLE-GPSHistory', error: e);
      return null;
    }
  }
  
  Future<Map<String, dynamic>?> readGPSHistoryPage(int page) async {
    try {
      if (_connectedDevice == null) {
        developer.log('No device connected', name: 'BLE-GPSPage');
        return null;
      }
      
      developer.log('Requesting GPS history page $page', name: 'BLE-GPSPage');
      
      // Find the bike tracker service
      List<BluetoothService> services;
      try {
        services = await _connectedDevice!.discoverServices().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('Service discovery timed out');
          },
        );
      } catch (e) {
        developer.log('Error during service discovery: $e', name: 'BLE-GPSPage');
        return null;
      }
      
      BluetoothCharacteristic? commandChar;
      BluetoothCharacteristic? historyChar;
      
      for (BluetoothService service in services) {
        String serviceUuid = service.uuid.toString().toLowerCase();
        
        bool isMatch = serviceUuid.contains('1234');
        
        if (isMatch) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            String charUuid = characteristic.uuid.toString().toLowerCase();
            
            // Find command characteristic (0x1238)
            if (charUuid.contains('1238')) {
              commandChar = characteristic;
              developer.log('Found command characteristic', name: 'BLE-GPSPage');
            }
            
            // Find history characteristic (0x1239)
            if (charUuid.contains('1239')) {
              historyChar = characteristic;
              developer.log('Found history characteristic', name: 'BLE-GPSPage');
            }
          }
        }
      }
      
      if (commandChar == null || historyChar == null) {
        developer.log('Required characteristics not found', name: 'BLE-GPSPage');
        return null;
      }
      
      // Subscribe to history characteristic notifications first
      if (!historyChar.isNotifying) {
        await historyChar.setNotifyValue(true);
        developer.log('Subscribed to history notifications', name: 'BLE-GPSPage');
      }
      
      // Set up completer to wait for notification response
      final completer = Completer<Map<String, dynamic>?>();
      
      // Listen for the notification response
      final subscription = historyChar.lastValueStream.listen((value) {
        try {
          if (value.isEmpty) {
            developer.log('Received empty notification', name: 'BLE-GPSPage');
            return;
          }
          
          String jsonString = String.fromCharCodes(value);
          developer.log('Received page data via notification: ${value.length} bytes', name: 'BLE-GPSPage');
          
          // Parse and check if this is page data (has "page" field)
          final Map<String, dynamic> data = json.decode(jsonString);
          if (data.containsKey('page') && data['page'] == page) {
            developer.log('Received data for page $page: totalPages=${data['totalPages']}, totalPoints=${data['totalPoints']}', 
                         name: 'BLE-GPSPage');
            if (!completer.isCompleted) {
              completer.complete(data);
            }
          }
        } catch (e) {
          developer.log('Error parsing notification data: $e', name: 'BLE-GPSPage');
        }
      });
      
      // Send page request command
      String command = 'GPS_PAGE:$page';
      await commandChar.write(utf8.encode(command), withoutResponse: false);
      developer.log('Sent command: $command', name: 'BLE-GPSPage');
      
      // Wait for notification with timeout
      try {
        final pageData = await completer.future.timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            developer.log('Timeout waiting for page $page notification', name: 'BLE-GPSPage');
            return null;
          },
        );
        
        subscription.cancel();
        return pageData;
      } catch (e) {
        developer.log('Error getting page data: $e', name: 'BLE-GPSPage');
        subscription.cancel();
        return null;
      }
    } catch (e) {
      developer.log('Error in readGPSHistoryPage: $e', name: 'BLE-GPSPage', error: e);
      return null;
    }
  }
  
  Future<List<Map<String, dynamic>>?> readAllGPSHistory() async {
    try {
      List<Map<String, dynamic>> allPoints = [];
      int page = 0;
      bool hasMorePages = true;
      int totalPages = 0;
      
      developer.log('Starting to read all GPS history pages', name: 'BLE-GPSHistory');
      
      while (hasMorePages) {
        final pageData = await readGPSHistoryPage(page);
        
        if (pageData == null) {
          developer.log('Failed to read page $page', name: 'BLE-GPSHistory');
          hasMorePages = false;
          break;
        }
        
        // Extract metadata
        totalPages = pageData['totalPages'] ?? 0;
        int totalPoints = pageData['totalPoints'] ?? 0;
        
        developer.log('Page $page: totalPages=$totalPages, totalPoints=$totalPoints', 
                     name: 'BLE-GPSHistory');
        
        // Extract history points from this page
        final List<dynamic>? historyList = pageData['history'];
        if (historyList != null && historyList.isNotEmpty) {
          for (var item in historyList) {
            if (item is Map<String, dynamic>) {
              // Debug: log the actual GPS values
              if (page == 0 && allPoints.isEmpty) {
                developer.log('First GPS point from page 0: lat=${item['lat']}, lon=${item['lon']}', 
                             name: 'BLE-GPSHistory');
              }
              allPoints.add(item);
            }
          }
          developer.log('Added ${historyList.length} points from page $page', 
                       name: 'BLE-GPSHistory');
        }
        
        page++;
        hasMorePages = page < totalPages;
        
        // Small delay between page requests to avoid overwhelming MCU
        if (hasMorePages) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      
      developer.log('Retrieved ${allPoints.length} total GPS points across $page pages', 
                   name: 'BLE-GPSHistory');
      
      // Also emit to stream for real-time updates
      if (allPoints.isNotEmpty) {
        _gpsHistoryController.add(allPoints);
      }
      
      return allPoints;
    } catch (e) {
      developer.log('Error reading all GPS history: $e', name: 'BLE-GPSHistory', error: e);
      // Fall back to single page read
      return await readGPSHistory();
    }
  }
  
  Future<bool> clearMCUGPSHistory() async {
    try {
      if (_connectedDevice == null) {
        developer.log('No device connected', name: 'BLE-ClearHistory');
        return false;
      }

      List<BluetoothService> services = await _connectedDevice!.discoverServices();
      
      for (BluetoothService service in services) {
        String serviceUuid = service.uuid.toString().toLowerCase();
        
        // Check if this is the bike tracker service (contains '1234')
        if (serviceUuid.contains('1234')) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            String charUuid = characteristic.uuid.toString().toLowerCase();
            
            // Check if this is the command characteristic (contains '1238')
            if (charUuid.contains('1238')) {
              developer.log('Found command characteristic, sending CLEAR_HISTORY command', name: 'BLE-ClearHistory');
              
              // Send clear history command
              await characteristic.write(utf8.encode('CLEAR_HISTORY'));
              
              // Wait a bit for MCU to process
              await Future.delayed(Duration(milliseconds: 500));
              
              developer.log('GPS history clear command sent successfully', name: 'BLE-ClearHistory');
              return true;
            }
          }
        }
      }
      
      developer.log('Command characteristic not found', name: 'BLE-ClearHistory');
      return false;
    } catch (e) {
      developer.log('Error clearing MCU GPS history: $e', name: 'BLE-ClearHistory', error: e);
      return false;
    }
  }
  
  List<Map<String, dynamic>>? _parseGPSHistory(String jsonString) {
    try {
      if (jsonString.trim().isEmpty) return [];
      
      final dynamic decodedData = json.decode(jsonString);
      if (decodedData is! Map<String, dynamic>) return [];
      
      final Map<String, dynamic> jsonData = decodedData;
      
      // Extract the history array
      if (!jsonData.containsKey('history')) {
        developer.log('No history key found in GPS data. Available keys: ${jsonData.keys}', name: 'BLE-GPSHistory');
        return [];
      }
      
      final dynamic historyData = jsonData['history'];
      developer.log('History data type: ${historyData.runtimeType}', name: 'BLE-GPSHistory');
      
      if (historyData is! List) {
        developer.log('History data is not a List', name: 'BLE-GPSHistory');
        return [];
      }
      
      final List<dynamic> historyArray = historyData;
      developer.log('History array has ${historyArray.length} items', name: 'BLE-GPSHistory');
      
      List<Map<String, dynamic>> history = [];
      
      for (var i = 0; i < historyArray.length; i++) {
        var point = historyArray[i];
        developer.log('Processing point $i: $point', name: 'BLE-GPSHistory');
        
        if (point is Map<String, dynamic>) {
          Map<String, dynamic> gpsPoint = {};
          
          // Extract latitude (numeric value from MCU)
          if (point.containsKey('lat')) {
            final lat = point['lat'];
            developer.log('  lat value: $lat (type: ${lat.runtimeType})', name: 'BLE-GPSHistory');
            if (lat is num) {
              gpsPoint['latitude'] = lat.toDouble();
            } else if (lat is String) {
              gpsPoint['latitude'] = double.tryParse(lat) ?? 0.0;
            }
          }
          
          // Extract longitude (numeric value from MCU)
          if (point.containsKey('lon')) {
            final lon = point['lon'];
            developer.log('  lon value: $lon (type: ${lon.runtimeType})', name: 'BLE-GPSHistory');
            if (lon is num) {
              gpsPoint['longitude'] = lon.toDouble();
            } else if (lon is String) {
              gpsPoint['longitude'] = double.tryParse(lon) ?? 0.0;
            }
          }
          
          // Extract timestamp
          if (point.containsKey('time')) {
            final time = point['time'];
            developer.log('  time value: $time (type: ${time.runtimeType})', name: 'BLE-GPSHistory');
            if (time is num) {
              gpsPoint['timestamp'] = time.toInt();
            } else if (time is String) {
              gpsPoint['timestamp'] = int.tryParse(time) ?? 0;
            }
          }
          
          // Extract speed (km/h)
          if (point.containsKey('speed')) {
            final speed = point['speed'];
            developer.log('  speed value: $speed (type: ${speed.runtimeType})', name: 'BLE-GPSHistory');
            if (speed is num) {
              gpsPoint['speed'] = speed.toDouble();
            } else if (speed is String) {
              gpsPoint['speed'] = double.tryParse(speed) ?? 0.0;
            }
          }
          
          // Extract source (0=Phone, 1=SIM7070G)
          if (point.containsKey('src')) {
            final src = point['src'];
            if (src is num) {
              gpsPoint['source'] = src.toInt();
            }
          }
          
          developer.log('  Parsed point: $gpsPoint', name: 'BLE-GPSHistory');
          
          // Only add valid points with both coordinates
          if (gpsPoint.containsKey('latitude') && 
              gpsPoint.containsKey('longitude') &&
              gpsPoint['latitude'] != 0.0 && 
              gpsPoint['longitude'] != 0.0) {
            history.add(gpsPoint);
            developer.log('  Point added to history', name: 'BLE-GPSHistory');
          } else {
            developer.log('  Point skipped (missing or zero coordinates)', name: 'BLE-GPSHistory');
          }
        }
      }
      
      final count = jsonData['count'] ?? history.length;
      developer.log('Successfully parsed ${history.length} GPS points from history (MCU reports $count total)', name: 'BLE-GPSHistory');
      return history;
    } catch (e, stack) {
      developer.log('Error parsing GPS history: $e', name: 'BLE-GPSHistory', error: e);
      developer.log('Stack trace: $stack', name: 'BLE-GPSHistory');
      developer.log('Raw JSON that failed: $jsonString', name: 'BLE-GPSHistory');
      return null;
    }
  }
  
  Future<bool> sendConfiguration({
    required String phoneNumber,
    required int updateInterval,
    required bool alertEnabled,
    double? motionSensitivity,
  }) async {
    try {
      if (_connectedDevice == null) {
        developer.log('No device connected', name: 'BLE-Config');
        return false;
      }
      
      developer.log('Starting configuration send...', name: 'BLE-Config');
      developer.log('Connected device: ${_connectedDevice!.platformName}', name: 'BLE-Config');
      
      // Discover services if not already done
      final services = await _connectedDevice!.discoverServices();
      developer.log('Discovered ${services.length} services', name: 'BLE-Config');
      
      // Log all services and characteristics for debugging
      for (var service in services) {
        developer.log('Service: ${service.uuid}', name: 'BLE-Config');
        for (var char in service.characteristics) {
          developer.log('  Char: ${char.uuid}, Properties: ${char.properties}', name: 'BLE-Config');
        }
      }
      
      // Find our service
      for (var service in services) {
        final serviceUuid = service.uuid.toString().toLowerCase();
        
        // Handle both short (16-bit) and full (128-bit) UUID formats
        // Short form: "1234" should match full form: "00001234-0000-1000-8000-00805f9b34fb"
        final targetUuid = BleProtocol.serviceUuid.toLowerCase();
        final shortTargetUuid = targetUuid.substring(4, 8); // Extract "1234" from full UUID
        
        developer.log('Checking service: $serviceUuid against $targetUuid (short: $shortTargetUuid)', name: 'BLE-Config');
        
        if (serviceUuid == targetUuid || serviceUuid == shortTargetUuid) {
          developer.log('Found bike tracker service!', name: 'BLE-Config');
          
          // Find config characteristic
          for (var characteristic in service.characteristics) {
            final charUuid = characteristic.uuid.toString().toLowerCase();
            
            // Handle both short and full UUID formats for characteristics
            final targetCharUuid = BleProtocol.configCharUuid.toLowerCase();
            final shortTargetCharUuid = targetCharUuid.substring(4, 8); // Extract "1236" from full UUID
            
            developer.log('Checking char: $charUuid against $targetCharUuid (short: $shortTargetCharUuid)', name: 'BLE-Config');
            
            if (charUuid == targetCharUuid || charUuid == shortTargetCharUuid) {
              developer.log('Found config characteristic!', name: 'BLE-Config');
              
              // Check if we need compact format (if MTU is small)
              bool useCompactFormat = false;
              try {
                final mtu = await _connectedDevice!.mtu.first;
                developer.log('Current MTU: $mtu', name: 'BLE-Config');
                
                // With DLE support, we should have MTU >= 512
                // Only use compact format for very old devices
                if (mtu < 100) {
                  useCompactFormat = true;
                  developer.log('Using compact format due to small MTU (legacy device)', name: 'BLE-Config');
                } else if (mtu >= AppConstants.bleMtuSize) {
                  developer.log('Full DLE support detected, using standard format', name: 'BLE-Config');
                }
              } catch (e) {
                developer.log('Could not get MTU: $e', name: 'BLE-Config');
              }
              
              // Format JSON string (compact if needed)
              String jsonString;
              if (useCompactFormat) {
                // Compact format: remove spaces and use short keys
                final alertStr = alertEnabled ? '1' : '0';
                final sensitivityStr = motionSensitivity != null ? ',"s":${motionSensitivity.toStringAsFixed(1)}' : '';
                jsonString = '{"p":"$phoneNumber","i":$updateInterval,"a":$alertStr$sensitivityStr}';
              } else {
                // Full format
                final alertStr = alertEnabled ? 'true' : 'false';
                final sensitivityStr = motionSensitivity != null ? ',"motion_sensitivity":${motionSensitivity.toStringAsFixed(1)}' : '';
                jsonString = '{"phone_number":"$phoneNumber","update_interval":$updateInterval,"alert_enabled":$alertStr$sensitivityStr}';
              }
              
              developer.log('Sending config JSON: $jsonString', name: 'BLE-Config');
              developer.log('JSON length: ${jsonString.length} bytes', name: 'BLE-Config');
              
              // Write to characteristic
              try {
                await characteristic.write(
                  jsonString.codeUnits,
                  withoutResponse: false,
                );
                developer.log('Configuration sent successfully!', name: 'BLE-Config');
                return true;
              } catch (writeError) {
                developer.log('Write error: $writeError', name: 'BLE-Config', error: writeError);
                // Try with withoutResponse = true
                try {
                  await characteristic.write(
                    jsonString.codeUnits,
                    withoutResponse: true,
                  );
                  developer.log('Configuration sent (without response)!', name: 'BLE-Config');
                  return true;
                } catch (e) {
                  developer.log('Write failed both ways: $e', name: 'BLE-Config');
                  return false;
                }
              }
            }
          }
          developer.log('Config characteristic not found in service', name: 'BLE-Config');
        }
      }
      
      developer.log('Bike tracker service not found', name: 'BLE-Config');
      return false;
    } catch (e) {
      developer.log('Error sending configuration: $e', name: 'BLE-Config', error: e);
      return false;
    }
  }
  
  Future<bool> subscribeToStatusUpdates() async {
    try {
      if (_connectedDevice == null) {
        developer.log('No device connected', name: 'BLE-Status');
        return false;
      }
      
      developer.log('Subscribing to status updates...', name: 'BLE-Status');
      
      // Discover services if not already done
      final services = await _connectedDevice!.discoverServices();
      
      // Find our service
      for (var service in services) {
        final serviceUuid = service.uuid.toString().toLowerCase();
        final targetUuid = BleProtocol.serviceUuid.toLowerCase();
        final shortTargetUuid = targetUuid.substring(4, 8);
        
        if (serviceUuid == targetUuid || serviceUuid == shortTargetUuid) {
          developer.log('Found bike tracker service for status', name: 'BLE-Status');
          
          // Find status characteristic
          for (var characteristic in service.characteristics) {
            final charUuid = characteristic.uuid.toString().toLowerCase();
            final targetCharUuid = BleProtocol.statusCharUuid.toLowerCase();
            final shortTargetCharUuid = targetCharUuid.substring(4, 8);
            
            if (charUuid == targetCharUuid || charUuid == shortTargetCharUuid) {
              developer.log('Found status characteristic!', name: 'BLE-Status');
              
              // Check if it supports notifications
              if (characteristic.properties.notify) {
                // Subscribe to notifications
                await characteristic.setNotifyValue(true);
                
                // Cancel any existing subscription
                await _statusSubscription?.cancel();
                
                // Listen for status updates
                _statusSubscription = characteristic.onValueReceived.listen((value) {
                  final jsonString = String.fromCharCodes(value);
                  
                  try {
                    final statusData = _parseStatusJson(jsonString);
                    // Immediately broadcast the update
                    _deviceStatusController.add(statusData);
                    developer.log('IR Status: user_present=${statusData['user'] ?? statusData['user_present']}', name: 'BLE-Status');
                  } catch (e) {
                    developer.log('Error parsing status: $e', name: 'BLE-Status');
                  }
                });
                
                developer.log('Subscribed to status notifications', name: 'BLE-Status');
                
                // Read current value and broadcast it
                final currentStatus = await readDeviceStatus();
                if (currentStatus != null) {
                  _deviceStatusController.add(currentStatus);
                }
                
                return true;
              } else {
                developer.log('Status characteristic does not support notifications', name: 'BLE-Status');
                // Fall back to periodic reading
                return false;
              }
            }
          }
          developer.log('Status characteristic not found in service', name: 'BLE-Status');
        }
      }
      
      developer.log('Bike tracker service not found for status', name: 'BLE-Status');
      return false;
    } catch (e) {
      developer.log('Error subscribing to status: $e', name: 'BLE-Status', error: e);
      return false;
    }
  }
  
  Future<Map<String, dynamic>?> readDeviceStatus() async {
    try {
      if (_connectedDevice == null) {
        developer.log('No device connected', name: 'BLE-Status');
        return null;
      }
      
      developer.log('Reading device status...', name: 'BLE-Status');
      
      // Discover services if not already done
      final services = await _connectedDevice!.discoverServices();
      
      // Find our service and status characteristic
      for (var service in services) {
        final serviceUuid = service.uuid.toString().toLowerCase();
        final targetUuid = BleProtocol.serviceUuid.toLowerCase();
        final shortTargetUuid = targetUuid.substring(4, 8);
        
        if (serviceUuid == targetUuid || serviceUuid == shortTargetUuid) {
          for (var characteristic in service.characteristics) {
            final charUuid = characteristic.uuid.toString().toLowerCase();
            final targetCharUuid = BleProtocol.statusCharUuid.toLowerCase();
            final shortTargetCharUuid = targetCharUuid.substring(4, 8);
            
            if (charUuid == targetCharUuid || charUuid == shortTargetCharUuid) {
              // Read the characteristic value
              final value = await characteristic.read();
              final jsonString = String.fromCharCodes(value);
              developer.log('Status read: $jsonString', name: 'BLE-Status');
              
              // Parse and return the status
              final statusData = _parseStatusJson(jsonString);
              _deviceStatusController.add(statusData);
              return statusData;
            }
          }
        }
      }
      
      developer.log('Status characteristic not found', name: 'BLE-Status');
      return null;
    } catch (e) {
      developer.log('Error reading status: $e', name: 'BLE-Status', error: e);
      return null;
    }
  }
  
  Map<String, dynamic> _parseStatusJson(String jsonString) {
    // Manual JSON parsing for status data
    Map<String, dynamic> result = {};
    
    // Extract ble_connected (check both "ble_connected" and "ble" keys)
    if (jsonString.contains('"ble_connected":')) {
      result['ble_connected'] = jsonString.contains('"ble_connected":true');
    } else if (jsonString.contains('"ble":')) {
      result['ble_connected'] = jsonString.contains('"ble":true');
    }
    
    // Extract phone_configured
    if (jsonString.contains('"phone_configured":')) {
      result['phone_configured'] = jsonString.contains('"phone_configured":true');
    }
    
    // Extract phone number
    final phoneMatch = RegExp(r'"phone":"([^"]*)"').firstMatch(jsonString);
    if (phoneMatch != null) {
      result['phone'] = phoneMatch.group(1) ?? '';
    }
    
    // Extract interval
    final intervalMatch = RegExp(r'"interval":(\d+)').firstMatch(jsonString);
    if (intervalMatch != null) {
      result['interval'] = int.tryParse(intervalMatch.group(1) ?? '0') ?? 0;
    }
    
    // Extract alerts enabled
    if (jsonString.contains('"alerts":')) {
      result['alerts'] = jsonString.contains('"alerts":true');
    }
    
    // Extract last config time
    final configTimeMatch = RegExp(r'"last_config_time":(\d+)').firstMatch(jsonString);
    if (configTimeMatch != null) {
      result['last_config_time'] = int.tryParse(configTimeMatch.group(1) ?? '0') ?? 0;
    }
    
    // Extract user_present (IR sensor) - check both "user_present" and "user" keys
    if (jsonString.contains('"user_present":')) {
      result['user_present'] = jsonString.contains('"user_present":true');
      result['user'] = result['user_present']; // Add both keys for compatibility
    } else if (jsonString.contains('"user":')) {
      result['user'] = jsonString.contains('"user":true');
      result['user_present'] = result['user']; // Add both keys for compatibility
    }
    
    // Extract device mode (READY, AWAY, DISCONNECTED)
    final modeMatch = RegExp(r'"mode":"([^"]*)"').firstMatch(jsonString);
    if (modeMatch != null) {
      result['mode'] = modeMatch.group(1) ?? 'UNKNOWN';
    }
    
    return result;
  }
  
  Future<void> disconnect() async {
    _reconnectionTimer?.cancel();
    _isReconnecting = false;
    _lastConnectedDeviceId = null;
    
    await _connectionSubscription?.cancel();
    await _statusSubscription?.cancel();  // Cancel status subscription
    
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
    }
    
    _connectionStateController.add(BluetoothConnectionState.disconnected);
  }
  
  // Auto-connect methods
  Future<void> _saveLastConnectedDevice(String deviceId, String deviceName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyLastDevice, deviceId);
      await prefs.setString(_prefKeyLastDeviceName, deviceName);
      await prefs.setBool(_prefKeyAutoConnect, true);
      developer.log('Saved device for auto-connect: $deviceName ($deviceId)', name: 'BLE');
    } catch (e) {
      developer.log('Error saving device preferences: $e', name: 'BLE', error: e);
    }
  }
  
  Future<Map<String, String>?> getLastConnectedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoConnect = prefs.getBool(_prefKeyAutoConnect) ?? true;
      
      if (!autoConnect) return null;
      
      final deviceId = prefs.getString(_prefKeyLastDevice);
      final deviceName = prefs.getString(_prefKeyLastDeviceName);
      
      if (deviceId != null && deviceName != null) {
        developer.log('Found saved device: $deviceName ($deviceId)', name: 'BLE');
        return {'id': deviceId, 'name': deviceName};
      }
    } catch (e) {
      developer.log('Error loading device preferences: $e', name: 'BLE', error: e);
    }
    return null;
  }
  
  Future<void> clearLastConnectedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyLastDevice);
      await prefs.remove(_prefKeyLastDeviceName);
      developer.log('Cleared saved device', name: 'BLE');
    } catch (e) {
      developer.log('Error clearing device preferences: $e', name: 'BLE', error: e);
    }
  }
  
  Future<void> setAutoConnectEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyAutoConnect, enabled);
      developer.log('Auto-connect set to: $enabled', name: 'BLE');
    } catch (e) {
      developer.log('Error setting auto-connect preference: $e', name: 'BLE', error: e);
    }
  }
  
  Future<bool> isAutoConnectEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefKeyAutoConnect) ?? true;
    } catch (e) {
      developer.log('Error getting auto-connect preference: $e', name: 'BLE', error: e);
      return true;
    }
  }
  
  Future<bool> tryAutoConnect() async {
    try {
      // Check location services first
      if (Platform.isAndroid) {
        bool locationEnabled = await Geolocator.isLocationServiceEnabled();
        if (!locationEnabled) {
          developer.log('Cannot auto-connect - location services disabled', name: 'BLE');
          return false;
        }
      }
      
      final lastDevice = await getLastConnectedDevice();
      if (lastDevice == null) {
        developer.log('No saved device for auto-connect', name: 'BLE');
        return false;
      }
      
      developer.log('Attempting auto-connect to ${lastDevice['name']}', name: 'BLE');
      
      // Start scanning
      await startScan(timeout: const Duration(seconds: 5));
      
      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 5));
      
      // Look for the saved device
      final device = _discoveredDevices.firstWhere(
        (d) => d.id == lastDevice['id'],
        orElse: () => BikeDevice(
          device: BluetoothDevice(remoteId: const DeviceIdentifier('')),
          name: '',
          id: '',
          rssi: 0,
          lastSeen: DateTime.now(),
        ),
      );
      
      if (device.name.isNotEmpty) {
        developer.log('Found saved device, connecting...', name: 'BLE');
        return await connectToDevice(device);
      } else {
        developer.log('Saved device not found in scan', name: 'BLE');
        return false;
      }
    } catch (e) {
      developer.log('Error during auto-connect: $e', name: 'BLE', error: e);
      return false;
    }
  }
  
  void dispose() {
    _reconnectionTimer?.cancel();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _statusSubscription?.cancel();
    _historySubscription?.cancel();
    _scanResultsController.close();
    _connectionStateController.close();
    _bluetoothStateController.close();
    _deviceStatusController.close();
    _gpsHistoryController.close();
  }
  
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null;
  
  Future<BluetoothAdapterState> getCurrentBluetoothState() async {
    return await FlutterBluePlus.adapterState.first;
  }
}