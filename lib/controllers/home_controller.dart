import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;

import '../models/bike_device.dart';
import '../models/location_data.dart';
import '../services/bluetooth_service.dart';
import '../services/location_service.dart';
import '../services/location_storage_service.dart';
import '../utils/ui_helpers.dart';

/// Optimized controller for Home Screen business logic
class HomeController {
  final VoidCallback onStateChanged;
  final BuildContext context;
  
  HomeController({
    required this.onStateChanged,
    required this.context,
  });
  
  // Services
  final _bleService = BikeBluetoothService();
  final _locationService = LocationService();
  final _storageService = LocationStorageService();
  
  // State variables
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  BluetoothAdapterState _bluetoothAdapterState = BluetoothAdapterState.unknown;
  bool _isScanning = false;
  bool _isTrackingLocation = false;
  bool _isLoadingMcuHistory = false;
  
  // Data
  List<BikeDevice> _availableDevices = [];
  List<LocationData> _locationHistory = [];
  List<Map<String, dynamic>> _mcuGpsHistory = [];
  Map<String, dynamic>? _deviceStatus;
  LocationData? _currentLocation;
  LatLng? _selectedMapLocation;
  BikeDevice? _connectedDevice;
  
  // Subscriptions
  final _subscriptions = <StreamSubscription>[];
  Timer? _reconnectionTimer;
  
  // Getters
  BluetoothConnectionState get connectionState => _connectionState;
  Stream<BluetoothAdapterState> get bluetoothState => _bleService.bluetoothState;
  bool get isScanning => _isScanning;
  bool get isTrackingLocation => _isTrackingLocation;
  List<BikeDevice> get availableDevices => _availableDevices;
  List<LocationData> get locationHistory => _locationHistory;
  List<Map<String, dynamic>> get mcuGpsHistory => _mcuGpsHistory;
  Map<String, dynamic>? get deviceStatus => _deviceStatus;
  LocationData? get currentLocation => _currentLocation;
  LatLng? get selectedMapLocation => _selectedMapLocation;
  BikeDevice? get connectedDevice => _connectedDevice;
  
  Future<void> initialize() async {
    await _initializeServices();
    await _loadSavedData();
    _setupListeners();
    await _checkBluetoothAndAutoConnect();
  }
  
  Future<void> _initializeServices() async {
    _bleService.initializeBluetoothMonitoring();
    _bluetoothAdapterState = await _bleService.getCurrentBluetoothState();
  }
  
  Future<void> _loadSavedData() async {
    // Load location history
    _locationHistory = await _storageService.loadLocationHistory();
    
    // Load MCU GPS history backup
    await _loadGpsHistoryBackup();
    
    onStateChanged();
  }
  
  void _setupListeners() {
    // BLE connection state
    _subscriptions.add(
      _bleService.connectionState.listen((state) {
        _connectionState = state;
        _handleConnectionStateChange(state);
        onStateChanged();
      }),
    );
    
    // BLE scan results
    _subscriptions.add(
      _bleService.scanResults.listen((devices) {
        _availableDevices = devices;
        onStateChanged();
      }),
    );
    
    // Device status updates
    _subscriptions.add(
      _bleService.deviceStatus.listen((status) {
        _deviceStatus = status;
        onStateChanged();
      }),
    );
    
    // GPS history updates
    _subscriptions.add(
      _bleService.gpsHistoryStream.listen((history) {
        _mergeGpsHistory(history);
        onStateChanged();
      }),
    );
    
    // Location updates
    _subscriptions.add(
      _locationService.locationStream.listen((location) {
        _currentLocation = location;
        _locationHistory.insert(0, location);
        _storageService.saveLocationHistory(_locationHistory);
        onStateChanged();
      }),
    );
  }
  
  Future<void> _checkBluetoothAndAutoConnect() async {
    if (_bluetoothAdapterState == BluetoothAdapterState.off) {
      // Bluetooth is off, can't auto-connect
      return;
    }
    
    // Try auto-connect if enabled
    final prefs = await SharedPreferences.getInstance();
    final autoConnect = prefs.getBool('auto_connect') ?? true;
    final savedDeviceId = prefs.getString('last_device');
    
    if (autoConnect && savedDeviceId != null) {
      await _attemptAutoConnect(savedDeviceId);
    }
  }
  
  Future<void> _attemptAutoConnect(String deviceId) async {
    try {
      await startScan();
      await Future.delayed(const Duration(seconds: 3));
      
      final device = _availableDevices.firstWhere(
        (d) => d.id == deviceId,
        orElse: () => throw Exception('Device not found'),
      );
      
      await connectToDevice(device);
    } catch (e) {
      dev.log('Auto-connect failed: $e', name: 'HomeController');
    } finally {
      stopScan();
    }
  }
  
  void _handleConnectionStateChange(BluetoothConnectionState state) {
    switch (state) {
      case BluetoothConnectionState.connected:
        _reconnectionTimer?.cancel();
        _syncConfiguration();
        fetchMcuGpsHistory();
        break;
        
      case BluetoothConnectionState.disconnected:
        _connectedDevice = null;
        _deviceStatus = null;
        // Consider auto-reconnect logic here if needed
        break;
        
      default:
        break;
    }
  }
  
  Future<void> startScan() async {
    if (_isScanning) return;
    
    try {
      _isScanning = true;
      onStateChanged();
      await _bleService.startScan();
    } catch (e) {
      UIHelpers.showError(context, 'Failed to start scan: $e');
    }
  }
  
  void stopScan() {
    _isScanning = false;
    _bleService.stopScan();
    onStateChanged();
  }
  
  Future<void> connectToDevice(BikeDevice device) async {
    try {
      _connectedDevice = device;
      // Pass the BikeDevice to the service
      await _bleService.connectToDevice(device);
      
      // Save for auto-connect
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_device', device.id);
      await prefs.setString('last_device_name', device.name);
    } catch (e) {
      if (context.mounted) {
        UIHelpers.showError(context, 'Connection failed: $e');
      }
      _connectedDevice = null;
    }
  }
  
  Future<void> disconnect(BuildContext context) async {
    // Check if alerts are configured
    final phoneConfigured = _deviceStatus?['phone_configured'] ?? false;
    final alertsEnabled = _deviceStatus?['alerts'] ?? false;
    
    if (!phoneConfigured || !alertsEnabled) {
      final proceed = await _showDisconnectWarning(
        context,
        phoneConfigured: phoneConfigured,
        alertsEnabled: alertsEnabled,
      );
      if (!proceed) return;
    }
    
    await _bleService.disconnect();
    if (context.mounted) {
      UIHelpers.showInfo(context, 'Disconnected from device');
    }
  }
  
  Future<bool> _showDisconnectWarning(
    BuildContext context, {
    required bool phoneConfigured,
    required bool alertsEnabled,
  }) async {
    // Implementation of warning dialog
    // Returns true to proceed with disconnect, false to cancel
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Warning'),
        content: Text(
          !phoneConfigured 
            ? 'No phone number configured. You won\'t receive alerts.'
            : 'Alerts are disabled. You won\'t receive notifications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect Anyway'),
          ),
        ],
      ),
    ) ?? false;
  }
  
  Future<void> toggleLocationTracking() async {
    if (_isTrackingLocation) {
      await _locationService.stopLocationTracking();
    } else {
      await _locationService.startLocationTracking();
    }
    _isTrackingLocation = !_isTrackingLocation;
    onStateChanged();
  }
  
  void selectMapLocation(LatLng location) {
    _selectedMapLocation = location;
    onStateChanged();
  }
  
  Future<void> fetchMcuGpsHistory() async {
    if (_connectionState != BluetoothConnectionState.connected) return;
    if (_isLoadingMcuHistory) return;
    
    _isLoadingMcuHistory = true;
    try {
      // Request GPS history sync from device
      // This will trigger the gpsHistoryStream listener
      await Future.delayed(const Duration(milliseconds: 500));
      // The actual implementation depends on your BLE service
    } catch (e) {
      dev.log('Failed to fetch GPS history: $e', name: 'HomeController');
    } finally {
      _isLoadingMcuHistory = false;
    }
  }
  
  Future<void> clearPhoneHistory() async {
    await _storageService.clearLocationHistory();
    _locationHistory.clear();
    onStateChanged();
  }
  
  Future<void> clearTrackerHistory() async {
    _mcuGpsHistory.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mcu_gps_history_backup');
    onStateChanged();
  }
  
  Future<void> syncConfiguration() async {
    if (_connectionState != BluetoothConnectionState.connected) return;
    
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('config_phone');
    final interval = prefs.getInt('config_interval') ?? 300;
    final alerts = prefs.getBool('config_alerts') ?? true;
    
    if (phone != null && phone.isNotEmpty) {
      await _bleService.sendConfiguration(
        phoneNumber: phone,
        updateInterval: interval,
        alertEnabled: alerts,
      );
    }
  }
  
  void promptBluetoothEnable(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bluetooth is Off'),
        content: const Text('Please enable Bluetooth to connect to your tracker.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              FlutterBluePlus.turnOn();
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _syncConfiguration() async {
    // Sync saved configuration to connected device
    await syncConfiguration();
  }
  
  void _mergeGpsHistory(List<Map<String, dynamic>> newHistory) {
    // Merge new history with existing, removing duplicates
    final uniquePoints = <int, Map<String, dynamic>>{};
    
    for (var point in _mcuGpsHistory.reversed.toList()) {
      final timestamp = point['time'] ?? point['timestamp'] ?? 0;
      uniquePoints[timestamp] = point;
    }
    
    for (var point in newHistory) {
      final timestamp = point['time'] ?? point['timestamp'] ?? 0;
      uniquePoints[timestamp] = point;
    }
    
    _mcuGpsHistory = uniquePoints.values.toList()
      ..sort((a, b) {
        final timeA = a['time'] ?? a['timestamp'] ?? 0;
        final timeB = b['time'] ?? b['timestamp'] ?? 0;
        return timeB.compareTo(timeA);
      });
    
    _saveGpsHistoryLocally(_mcuGpsHistory.reversed.toList());
  }
  
  Future<void> _saveGpsHistoryLocally(List<Map<String, dynamic>> history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = json.encode(history);
      await prefs.setString('mcu_gps_history_backup', historyJson);
      await prefs.setString('mcu_gps_history_backup_date', DateTime.now().toIso8601String());
    } catch (e) {
      dev.log('Error saving GPS history: $e', name: 'HomeController');
    }
  }
  
  Future<void> _loadGpsHistoryBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('mcu_gps_history_backup');
      
      if (historyJson != null && historyJson.isNotEmpty) {
        final List<dynamic> decodedHistory = json.decode(historyJson);
        _mcuGpsHistory = decodedHistory
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
            .reversed
            .toList();
      }
    } catch (e) {
      dev.log('Error loading GPS history backup: $e', name: 'HomeController');
    }
  }
  
  void dispose() {
    _reconnectionTimer?.cancel();
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _bleService.dispose();
    _locationService.dispose();
  }
}