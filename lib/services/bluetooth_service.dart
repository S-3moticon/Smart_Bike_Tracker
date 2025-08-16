import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bike_device.dart';
import '../constants/ble_protocol.dart';

class BikeBluetoothService {
  static final BikeBluetoothService _instance = BikeBluetoothService._internal();
  factory BikeBluetoothService() => _instance;
  BikeBluetoothService._internal();
  
  final _scanResultsController = StreamController<List<BikeDevice>>.broadcast();
  final _connectionStateController = StreamController<BluetoothConnectionState>.broadcast();
  
  Stream<List<BikeDevice>> get scanResults => _scanResultsController.stream;
  Stream<BluetoothConnectionState> get connectionState => _connectionStateController.stream;
  
  final List<BikeDevice> _discoveredDevices = [];
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  
  Timer? _reconnectionTimer;
  String? _lastConnectedDeviceId;
  bool _isReconnecting = false;
  
  static const String _prefKeyLastDevice = 'last_connected_device_id';
  static const String _prefKeyLastDeviceName = 'last_connected_device_name';
  static const String _prefKeyAutoConnect = 'auto_connect_enabled';
  
  Future<bool> checkBluetoothAvailability() async {
    try {
      if (await FlutterBluePlus.isSupported == false) {
        developer.log('Bluetooth not supported on this device', name: 'BLE');
        return false;
      }
      
      // Request Bluetooth permissions for Android 12+
      if (Platform.isAndroid) {
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
  
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      _discoveredDevices.clear();
      _scanResultsController.add([]);
      
      developer.log('Starting BLE scan...', name: 'BLE');
      
      // Stop any existing scan first
      await FlutterBluePlus.stopScan();
      
      // Start scan without service filter to ensure we see all devices
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidScanMode: AndroidScanMode.lowLatency,
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
      
      // Request larger MTU for config data (default is 23, we need at least 100)
      try {
        if (Platform.isAndroid) {
          final mtu = await bikeDevice.device.requestMtu(185);
          developer.log('MTU negotiated: $mtu bytes', name: 'BLE');
        }
      } catch (e) {
        developer.log('MTU negotiation failed: $e', name: 'BLE');
      }
      
      // Discover services after connection
      await _discoverServices(bikeDevice.device);
      
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
    _reconnectionTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
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
  
  Future<bool> sendConfiguration({
    required String phoneNumber,
    required int updateInterval,
    required bool alertEnabled,
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
                if (mtu < 100) {
                  useCompactFormat = true;
                  developer.log('Using compact format due to small MTU', name: 'BLE-Config');
                }
              } catch (e) {
                developer.log('Could not get MTU: $e', name: 'BLE-Config');
              }
              
              // Format JSON string (compact if needed)
              String jsonString;
              if (useCompactFormat) {
                // Compact format: remove spaces and use short keys
                final alertStr = alertEnabled ? '1' : '0';
                jsonString = '{"p":"$phoneNumber","i":$updateInterval,"a":$alertStr}';
              } else {
                // Full format
                final alertStr = alertEnabled ? 'true' : 'false';
                jsonString = '{"phone_number":"$phoneNumber","update_interval":$updateInterval,"alert_enabled":$alertStr}';
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
  
  Future<void> disconnect() async {
    _reconnectionTimer?.cancel();
    _isReconnecting = false;
    _lastConnectedDeviceId = null;
    
    await _connectionSubscription?.cancel();
    
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
    _scanResultsController.close();
    _connectionStateController.close();
  }
  
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null;
}