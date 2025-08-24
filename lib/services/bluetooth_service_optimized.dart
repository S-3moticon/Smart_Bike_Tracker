import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;

import '../models/bike_device.dart';
import '../constants/ble_protocol.dart';
import '../constants/app_constants.dart';

/// Optimized Bluetooth Service with cleaner architecture
class BikeBluetoothServiceOptimized {
  static final _instance = BikeBluetoothServiceOptimized._internal();
  factory BikeBluetoothServiceOptimized() => _instance;
  BikeBluetoothServiceOptimized._internal();
  
  // Stream controllers
  final _scanResults = StreamController<List<BikeDevice>>.broadcast();
  final _connectionState = StreamController<BluetoothConnectionState>.broadcast();
  final _deviceStatus = StreamController<Map<String, dynamic>>.broadcast();
  final _gpsHistory = StreamController<List<Map<String, dynamic>>>.broadcast();
  
  // Public streams
  Stream<List<BikeDevice>> get scanResults => _scanResults.stream;
  Stream<BluetoothConnectionState> get connectionState => _connectionState.stream;
  Stream<Map<String, dynamic>> get deviceStatus => _deviceStatus.stream;
  Stream<List<Map<String, dynamic>>> get gpsHistory => _gpsHistory.stream;
  Stream<BluetoothAdapterState> get bluetoothState => FlutterBluePlus.adapterState;
  
  // State
  BluetoothDevice? _connectedDevice;
  final List<BikeDevice> _discoveredDevices = [];
  final Map<String, StreamSubscription> _subscriptions = {};
  
  // BLE Characteristics
  BluetoothCharacteristic? _configChar;
  BluetoothCharacteristic? _commandChar;
  
  // Initialize service
  void initialize() {
    _setupBluetoothStateMonitoring();
  }
  
  void _setupBluetoothStateMonitoring() {
    _subscriptions['adapter']?.cancel();
    _subscriptions['adapter'] = FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.off && _connectedDevice != null) {
        _handleDisconnection();
      }
    });
  }
  
  // Scanning
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      _discoveredDevices.clear();
      _scanResults.add([]);
      
      await FlutterBluePlus.stopScan();
      
      _subscriptions['scan']?.cancel();
      _subscriptions['scan'] = FlutterBluePlus.onScanResults.listen(
        (results) => _processScanResults(results),
        onError: (e) => dev.log('Scan error: $e', name: 'BLE'),
      );
      
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: false,
      );
    } catch (e) {
      dev.log('Failed to start scan: $e', name: 'BLE');
      rethrow;
    }
  }
  
  void stopScan() {
    FlutterBluePlus.stopScan();
    _subscriptions['scan']?.cancel();
  }
  
  void _processScanResults(List<ScanResult> results) {
    _discoveredDevices.clear();
    
    for (var result in results) {
      if (result.device.platformName.startsWith(BleProtocol.deviceNamePrefix)) {
        _discoveredDevices.add(BikeDevice(
          id: result.device.remoteId.toString(),
          name: result.device.platformName,
          rssi: result.rssi,
          device: result.device,
          lastSeen: DateTime.now(),
        ));
      }
    }
    
    _discoveredDevices.sort((a, b) => b.rssi.compareTo(a.rssi));
    _scanResults.add(_discoveredDevices);
  }
  
  // Connection management
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      _connectionState.add(BluetoothConnectionState.disconnected);
      
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );
      
      _connectedDevice = device;
      await _setupDeviceConnection(device);
      
      _connectionState.add(BluetoothConnectionState.connected);
      await _saveDeviceForAutoConnect(device);
      
    } catch (e) {
      dev.log('Connection failed: $e', name: 'BLE');
      _connectionState.add(BluetoothConnectionState.disconnected);
      rethrow;
    }
  }
  
  Future<void> _setupDeviceConnection(BluetoothDevice device) async {
    // Discover services
    final services = await device.discoverServices();
    
    for (var service in services) {
      if (service.uuid.toString() == BleProtocol.serviceUuid) {
        for (var char in service.characteristics) {
          final uuid = char.uuid.toString();
          
          switch (uuid) {
            case BleProtocol.configCharUuid:
              _configChar = char;
              break;
            case BleProtocol.statusCharUuid:
              await _subscribeToStatus(char);
              break;
            case '00001239-0000-1000-8000-00805f9b34fb':  // History UUID
              await _subscribeToHistory(char);
              break;
            case BleProtocol.commandCharUuid:
              _commandChar = char;
              break;
          }
        }
        break;
      }
    }
    
    // Setup connection state monitoring
    _subscriptions['connection']?.cancel();
    _subscriptions['connection'] = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _handleDisconnection();
      }
    });
  }
  
  Future<void> _subscribeToStatus(BluetoothCharacteristic char) async {
    try {
      await char.setNotifyValue(true);
      _subscriptions['status']?.cancel();
      _subscriptions['status'] = char.onValueReceived.listen((value) {
        final status = _parseStatusData(value);
        if (status != null) {
          _deviceStatus.add(status);
        }
      });
      
      // Read initial value
      final value = await char.read();
      final status = _parseStatusData(value);
      if (status != null) {
        _deviceStatus.add(status);
      }
    } catch (e) {
      dev.log('Failed to subscribe to status: $e', name: 'BLE');
    }
  }
  
  Future<void> _subscribeToHistory(BluetoothCharacteristic char) async {
    try {
      await char.setNotifyValue(true);
      _subscriptions['history']?.cancel();
      _subscriptions['history'] = char.onValueReceived.listen((value) {
        final history = _parseHistoryData(value);
        if (history != null) {
          _gpsHistory.add(history);
        }
      });
    } catch (e) {
      dev.log('Failed to subscribe to history: $e', name: 'BLE');
    }
  }
  
  Map<String, dynamic>? _parseStatusData(List<int> value) {
    try {
      final jsonStr = utf8.decode(value);
      return json.decode(jsonStr);
    } catch (e) {
      dev.log('Failed to parse status: $e', name: 'BLE');
      return null;
    }
  }
  
  List<Map<String, dynamic>>? _parseHistoryData(List<int> value) {
    try {
      final jsonStr = utf8.decode(value);
      final data = json.decode(jsonStr);
      
      if (data is Map && data.containsKey('history')) {
        return List<Map<String, dynamic>>.from(data['history']);
      }
      return null;
    } catch (e) {
      dev.log('Failed to parse history: $e', name: 'BLE');
      return null;
    }
  }
  
  Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
    _handleDisconnection();
  }
  
  void _handleDisconnection() {
    _connectedDevice = null;
    _configChar = null;
    _commandChar = null;
    
    for (var key in ['connection', 'status', 'history']) {
      _subscriptions[key]?.cancel();
    }
    
    _connectionState.add(BluetoothConnectionState.disconnected);
  }
  
  // Configuration
  Future<bool> sendConfiguration({
    required String phoneNumber,
    required int updateInterval,
    required bool alertEnabled,
    double? motionSensitivity,
  }) async {
    if (_configChar == null) return false;
    
    try {
      final config = {
        'p': phoneNumber,
        'i': updateInterval,
        'a': alertEnabled ? 1 : 0,
        if (motionSensitivity != null) 's': motionSensitivity,
      };
      
      final jsonStr = json.encode(config);
      final bytes = utf8.encode(jsonStr);
      
      await _configChar!.write(bytes, withoutResponse: false);
      dev.log('Configuration sent: $jsonStr', name: 'BLE');
      return true;
      
    } catch (e) {
      dev.log('Failed to send configuration: $e', name: 'BLE');
      return false;
    }
  }
  
  Future<bool> clearConfiguration() async {
    if (_configChar == null) return false;
    
    try {
      await _configChar!.write(utf8.encode('CLEAR'));
      return true;
    } catch (e) {
      dev.log('Failed to clear configuration: $e', name: 'BLE');
      return false;
    }
  }
  
  // GPS History
  Future<void> requestGpsHistory() async {
    if (_commandChar == null) return;
    
    try {
      await _commandChar!.write(utf8.encode('SYNC'));
      dev.log('GPS history sync requested', name: 'BLE');
    } catch (e) {
      dev.log('Failed to request GPS history: $e', name: 'BLE');
    }
  }
  
  Future<void> requestGpsPage(int page) async {
    if (_commandChar == null) return;
    
    try {
      await _commandChar!.write(utf8.encode('GPS_PAGE:$page'));
      dev.log('GPS page $page requested', name: 'BLE');
    } catch (e) {
      dev.log('Failed to request GPS page: $e', name: 'BLE');
    }
  }
  
  Future<void> clearGpsHistory() async {
    if (_commandChar == null) return;
    
    try {
      await _commandChar!.write(utf8.encode('CLEAR_HISTORY'));
      dev.log('GPS history clear requested', name: 'BLE');
    } catch (e) {
      dev.log('Failed to clear GPS history: $e', name: 'BLE');
    }
  }
  
  // Auto-connect
  Future<void> _saveDeviceForAutoConnect(BluetoothDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyLastDevice, device.remoteId.toString());
    await prefs.setString(AppConstants.keyLastDeviceName, device.platformName);
  }
  
  Future<Map<String, String>?> getSavedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(AppConstants.keyLastDevice);
    final name = prefs.getString(AppConstants.keyLastDeviceName);
    
    if (id != null && name != null) {
      return {'id': id, 'name': name};
    }
    return null;
  }
  
  Future<bool> getAutoConnectEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyAutoConnect) ?? true;
  }
  
  Future<void> setAutoConnectEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyAutoConnect, enabled);
  }
  
  // Bluetooth state
  Future<BluetoothAdapterState> getCurrentBluetoothState() async {
    return await FlutterBluePlus.adapterState.first;
  }
  
  // Cleanup
  void dispose() {
    stopScan();
    _connectedDevice?.disconnect();
    
    for (var sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    
    _scanResults.close();
    _connectionState.close();
    _deviceStatus.close();
    _gpsHistory.close();
  }
}