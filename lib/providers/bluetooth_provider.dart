import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/bluetooth_service.dart';
import '../models/bike_device.dart';
import '../models/device_status.dart';

class BluetoothProvider extends ChangeNotifier {
  final BikeBluetoothService _bleService = BikeBluetoothService();
  
  List<BikeDevice> _devices = [];
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  BikeDevice? _connectedDevice;
  DeviceStatus? _deviceStatus;
  bool _isScanning = false;
  bool _bluetoothAvailable = false;
  
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _statusSubscription;
  
  List<BikeDevice> get devices => _devices;
  BluetoothConnectionState get connectionState => _connectionState;
  BikeDevice? get connectedDevice => _connectedDevice;
  DeviceStatus? get deviceStatus => _deviceStatus;
  bool get isScanning => _isScanning;
  bool get bluetoothAvailable => _bluetoothAvailable;
  bool get isConnected => _connectionState == BluetoothConnectionState.connected;
  
  BluetoothProvider() {
    _initialize();
  }
  
  Future<void> _initialize() async {
    _bluetoothAvailable = await _bleService.checkBluetoothAvailability();
    notifyListeners();
    
    _connectionSubscription = _bleService.connectionState.listen((state) {
      _connectionState = state;
      notifyListeners();
    });
    
    _statusSubscription = _bleService.deviceStatus.listen((status) {
      _deviceStatus = status;
      notifyListeners();
    });
  }
  
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    if (_isScanning) return;
    
    try {
      _isScanning = true;
      _devices.clear();
      notifyListeners();
      
      await _bleService.startScan(timeout: timeout);
      
      _scanSubscription?.cancel();
      _scanSubscription = _bleService.scanResults.listen((devices) {
        _devices = devices;
        notifyListeners();
      });
      
      Future.delayed(timeout, () {
        stopScan();
      });
    } catch (e) {
      developer.log('Error starting scan: $e', name: 'BluetoothProvider');
      _isScanning = false;
      notifyListeners();
    }
  }
  
  Future<void> stopScan() async {
    if (!_isScanning) return;
    
    try {
      await _bleService.stopScan();
      _scanSubscription?.cancel();
      _isScanning = false;
      notifyListeners();
    } catch (e) {
      developer.log('Error stopping scan: $e', name: 'BluetoothProvider');
    }
  }
  
  Future<bool> connectToDevice(BikeDevice device) async {
    try {
      _connectedDevice = device;
      notifyListeners();
      
      final success = await _bleService.connectToDevice(device);
      
      if (!success) {
        _connectedDevice = null;
        notifyListeners();
      }
      
      return success;
    } catch (e) {
      developer.log('Error connecting to device: $e', name: 'BluetoothProvider');
      _connectedDevice = null;
      notifyListeners();
      return false;
    }
  }
  
  Future<void> disconnect() async {
    try {
      await _bleService.disconnect();
      _connectedDevice = null;
      _deviceStatus = null;
      notifyListeners();
    } catch (e) {
      developer.log('Error disconnecting: $e', name: 'BluetoothProvider');
    }
  }
  
  Future<void> requestStatus() async {
    final status = await _bleService.requestStatus();
    if (status != null) {
      _deviceStatus = status;
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }
}