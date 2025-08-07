import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/bike_device.dart';
import '../models/location_data.dart';
import '../models/device_status.dart';
import '../models/tracker_config.dart';
import '../constants/ble_protocol.dart';

class BikeBluetoothService {
  static final BikeBluetoothService _instance = BikeBluetoothService._internal();
  factory BikeBluetoothService() => _instance;
  BikeBluetoothService._internal();
  
  final _scanResultsController = StreamController<List<BikeDevice>>.broadcast();
  final _connectionStateController = StreamController<BluetoothConnectionState>.broadcast();
  final _locationDataController = StreamController<LocationData>.broadcast();
  final _deviceStatusController = StreamController<DeviceStatus>.broadcast();
  
  Stream<List<BikeDevice>> get scanResults => _scanResultsController.stream;
  Stream<BluetoothConnectionState> get connectionState => _connectionStateController.stream;
  Stream<LocationData> get locationData => _locationDataController.stream;
  Stream<DeviceStatus> get deviceStatus => _deviceStatusController.stream;
  
  final List<BikeDevice> _discoveredDevices = [];
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _locationSubscription;
  StreamSubscription? _statusSubscription;
  
  BluetoothCharacteristic? _locationChar;
  BluetoothCharacteristic? _configChar;
  BluetoothCharacteristic? _statusChar;
  
  Timer? _reconnectionTimer;
  String? _lastConnectedDeviceId;
  bool _isReconnecting = false;
  
  Future<bool> checkBluetoothAvailability() async {
    try {
      if (await FlutterBluePlus.isSupported == false) {
        developer.log('Bluetooth not supported on this device', name: 'BLE');
        return false;
      }
      
      final state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
    } catch (e) {
      developer.log('Error checking bluetooth availability: $e', name: 'BLE');
      return false;
    }
  }
  
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      _discoveredDevices.clear();
      _scanResultsController.add([]);
      
      // Scan with service UUID filter as fallback (optional)
      // This helps find devices advertising our specific service
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidScanMode: AndroidScanMode.lowLatency,
        // withServices: [Guid(BleProtocol.serviceUuid)], // Uncomment to filter by service
      );
      
      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _discoveredDevices.clear();
        
        for (var result in results) {
          final device = BikeDevice.fromScanResult(result);
          
          // Log device details for debugging
          developer.log(
            'Scanned device: name="${device.name}", '
            'id=${device.id}, '
            'rssi=${device.rssi}, '
            'isBikeTracker=${device.isBikeTracker}',
            name: 'BLE',
          );
          
          // Add all devices with non-empty names
          if (device.name.isNotEmpty) {
            final existingIndex = _discoveredDevices.indexWhere(
              (d) => d.id == device.id,
            );
            
            if (existingIndex >= 0) {
              _discoveredDevices[existingIndex] = device;
            } else {
              _discoveredDevices.add(device);
            }
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
      
      // Note: Android & iOS don't stream connecting state
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
      
      await _discoverServices(bikeDevice.device);
      
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
        if (service.uuid.toString().toLowerCase() == BleProtocol.serviceUuid.toLowerCase()) {
          developer.log('Found bike tracker service', name: 'BLE');
          
          for (var char in service.characteristics) {
            final charUuid = char.uuid.toString().toLowerCase();
            
            if (charUuid == BleProtocol.locationCharUuid.toLowerCase()) {
              _locationChar = char;
              await _subscribeToLocation(char);
              developer.log('Found location characteristic', name: 'BLE');
            } else if (charUuid == BleProtocol.configCharUuid.toLowerCase()) {
              _configChar = char;
              developer.log('Found config characteristic', name: 'BLE');
            } else if (charUuid == BleProtocol.statusCharUuid.toLowerCase()) {
              _statusChar = char;
              await _subscribeToStatus(char);
              developer.log('Found status characteristic', name: 'BLE');
            } else if (charUuid == BleProtocol.commandCharUuid.toLowerCase()) {
              // Command characteristic found but not used yet
              developer.log('Found command characteristic', name: 'BLE');
            }
          }
          break;
        }
      }
      
      if (_locationChar == null || _configChar == null || _statusChar == null) {
        developer.log('Warning: Some characteristics not found', name: 'BLE');
      }
    } catch (e) {
      developer.log('Error discovering services: $e', name: 'BLE', error: e);
    }
  }
  
  Future<void> _subscribeToLocation(BluetoothCharacteristic char) async {
    try {
      await char.setNotifyValue(true);
      
      _locationSubscription?.cancel();
      _locationSubscription = char.onValueReceived.listen((value) {
        try {
          final jsonString = utf8.decode(value);
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          final location = LocationData.fromJson(json, LocationSource.sim7070g);
          _locationDataController.add(location);
          developer.log('Received location: ${location.formattedCoordinates}', name: 'BLE');
        } catch (e) {
          developer.log('Error parsing location data: $e', name: 'BLE', error: e);
        }
      });
    } catch (e) {
      developer.log('Error subscribing to location: $e', name: 'BLE', error: e);
    }
  }
  
  Future<void> _subscribeToStatus(BluetoothCharacteristic char) async {
    try {
      await char.setNotifyValue(true);
      
      _statusSubscription?.cancel();
      _statusSubscription = char.onValueReceived.listen((value) {
        try {
          final jsonString = utf8.decode(value);
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          final status = DeviceStatus.fromJson(json);
          _deviceStatusController.add(status);
          developer.log('Received status: ${status.mode.value}', name: 'BLE');
        } catch (e) {
          developer.log('Error parsing status data: $e', name: 'BLE', error: e);
        }
      });
    } catch (e) {
      developer.log('Error subscribing to status: $e', name: 'BLE', error: e);
    }
  }
  
  Future<bool> writeConfig(TrackerConfig config) async {
    try {
      if (_configChar == null) {
        developer.log('Config characteristic not available', name: 'BLE');
        return false;
      }
      
      final jsonString = config.toJsonString();
      final bytes = utf8.encode(jsonString);
      
      await _configChar!.write(bytes, withoutResponse: false);
      developer.log('Config written successfully', name: 'BLE');
      return true;
    } catch (e) {
      developer.log('Error writing config: $e', name: 'BLE', error: e);
      return false;
    }
  }
  
  Future<LocationData?> requestLocation() async {
    try {
      if (_locationChar == null) {
        developer.log('Location characteristic not available', name: 'BLE');
        return null;
      }
      
      final value = await _locationChar!.read();
      final jsonString = utf8.decode(value);
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return LocationData.fromJson(json, LocationSource.sim7070g);
    } catch (e) {
      developer.log('Error requesting location: $e', name: 'BLE', error: e);
      return null;
    }
  }
  
  Future<DeviceStatus?> requestStatus() async {
    try {
      if (_statusChar == null) {
        developer.log('Status characteristic not available', name: 'BLE');
        return null;
      }
      
      final value = await _statusChar!.read();
      final jsonString = utf8.decode(value);
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return DeviceStatus.fromJson(json);
    } catch (e) {
      developer.log('Error requesting status: $e', name: 'BLE', error: e);
      return null;
    }
  }
  
  void _handleDisconnection() {
    developer.log('Device disconnected, attempting reconnection...', name: 'BLE');
    
    _locationSubscription?.cancel();
    _statusSubscription?.cancel();
    _locationChar = null;
    _configChar = null;
    _statusChar = null;
    
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
  
  Future<void> disconnect() async {
    _reconnectionTimer?.cancel();
    _isReconnecting = false;
    _lastConnectedDeviceId = null;
    
    await _locationSubscription?.cancel();
    await _statusSubscription?.cancel();
    await _connectionSubscription?.cancel();
    
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
    }
    
    _locationChar = null;
    _configChar = null;
    _statusChar = null;
    
    _connectionStateController.add(BluetoothConnectionState.disconnected);
  }
  
  void dispose() {
    _reconnectionTimer?.cancel();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _locationSubscription?.cancel();
    _statusSubscription?.cancel();
    _scanResultsController.close();
    _connectionStateController.close();
    _locationDataController.close();
    _deviceStatusController.close();
  }
  
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null;
}