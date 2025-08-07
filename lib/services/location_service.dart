import 'dart:async';
import 'dart:developer' as developer;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/location_data.dart';
import '../services/bluetooth_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();
  
  final _locationController = StreamController<LocationData>.broadcast();
  final _permissionStatusController = StreamController<PermissionStatus>.broadcast();
  
  Stream<LocationData> get locationStream => _locationController.stream;
  Stream<PermissionStatus> get permissionStatus => _permissionStatusController.stream;
  
  final BikeBluetoothService _bluetoothService = BikeBluetoothService();
  
  StreamSubscription<Position>? _phoneGpsSubscription;
  StreamSubscription<LocationData>? _bleLocationSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  
  LocationData? _lastLocation;
  LocationSource _currentSource = LocationSource.unknown;
  bool _isBluetoothConnected = false;
  bool _locationPermissionGranted = false;
  
  LocationData? get lastLocation => _lastLocation;
  LocationSource get currentSource => _currentSource;
  bool get isTrackingActive => _phoneGpsSubscription != null || _bleLocationSubscription != null;
  
  Future<void> initialize() async {
    developer.log('Initializing LocationService', name: 'Location');
    
    await checkAndRequestPermissions();
    
    _connectionSubscription = _bluetoothService.connectionState.listen((state) {
      _handleConnectionStateChange(state);
    });
    
    await _startLocationTracking();
  }
  
  Future<PermissionStatus> checkAndRequestPermissions() async {
    try {
      var status = await Permission.locationWhenInUse.status;
      
      if (status.isDenied || status.isRestricted) {
        status = await Permission.locationWhenInUse.request();
      }
      
      if (status.isPermanentlyDenied) {
        developer.log('Location permission permanently denied', name: 'Location');
        _permissionStatusController.add(status);
        return status;
      }
      
      _locationPermissionGranted = status.isGranted;
      _permissionStatusController.add(status);
      
      if (status.isGranted) {
        developer.log('Location permission granted', name: 'Location');
        
        if (await Permission.locationAlways.status.then((s) => s.isDenied)) {
          final alwaysStatus = await Permission.locationAlways.request();
          developer.log('Background location permission: ${alwaysStatus.name}', name: 'Location');
        }
      }
      
      return status;
    } catch (e) {
      developer.log('Error requesting location permission: $e', name: 'Location', error: e);
      return PermissionStatus.denied;
    }
  }
  
  Future<bool> checkLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      developer.log('Error checking location service: $e', name: 'Location', error: e);
      return false;
    }
  }
  
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }
  
  Future<void> openAppSettings() async {
    await openAppSettings();
  }
  
  void _handleConnectionStateChange(BluetoothConnectionState state) {
    final wasConnected = _isBluetoothConnected;
    _isBluetoothConnected = state == BluetoothConnectionState.connected;
    
    developer.log('Bluetooth connection state changed: ${state.name}, switching GPS source', name: 'Location');
    
    if (wasConnected != _isBluetoothConnected) {
      _switchLocationSource();
    }
  }
  
  Future<void> _switchLocationSource() async {
    await _stopCurrentTracking();
    await _startLocationTracking();
  }
  
  Future<void> _startLocationTracking() async {
    if (_isBluetoothConnected) {
      await _startPhoneGpsTracking();
    } else {
      await _startBleLocationTracking();
    }
  }
  
  Future<void> _startPhoneGpsTracking() async {
    if (!_locationPermissionGranted) {
      developer.log('Cannot start phone GPS: permission not granted', name: 'Location');
      _currentSource = LocationSource.unknown;
      return;
    }
    
    try {
      developer.log('Starting phone GPS tracking', name: 'Location');
      _currentSource = LocationSource.phone;
      
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
      
      _phoneGpsSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          final locationData = LocationData(
            latitude: position.latitude,
            longitude: position.longitude,
            timestamp: position.timestamp,
            speed: position.speed * 3.6,
            satellites: 0,
            battery: 100,
            source: LocationSource.phone,
          );
          
          _lastLocation = locationData;
          _locationController.add(locationData);
          
          developer.log(
            'Phone GPS update: ${locationData.formattedCoordinates}, speed: ${locationData.formattedSpeed}',
            name: 'Location',
          );
        },
        onError: (error) {
          developer.log('Phone GPS error: $error', name: 'Location', error: error);
        },
      );
      
      final currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      
      final initialLocation = LocationData(
        latitude: currentPosition.latitude,
        longitude: currentPosition.longitude,
        timestamp: currentPosition.timestamp,
        speed: currentPosition.speed * 3.6,
        satellites: 0,
        battery: 100,
        source: LocationSource.phone,
      );
      
      _lastLocation = initialLocation;
      _locationController.add(initialLocation);
      
    } catch (e) {
      developer.log('Error starting phone GPS: $e', name: 'Location', error: e);
      _currentSource = LocationSource.unknown;
    }
  }
  
  Future<void> _startBleLocationTracking() async {
    try {
      developer.log('Starting BLE location tracking (SIM7070G)', name: 'Location');
      _currentSource = LocationSource.sim7070g;
      
      _bleLocationSubscription = _bluetoothService.locationData.listen(
        (LocationData locationData) {
          final updatedLocation = LocationData(
            latitude: locationData.latitude,
            longitude: locationData.longitude,
            timestamp: locationData.timestamp,
            speed: locationData.speed,
            satellites: locationData.satellites,
            battery: locationData.battery,
            source: LocationSource.sim7070g,
          );
          
          _lastLocation = updatedLocation;
          _locationController.add(updatedLocation);
          
          developer.log(
            'SIM7070G GPS update: ${updatedLocation.formattedCoordinates}, satellites: ${updatedLocation.satellites}',
            name: 'Location',
          );
        },
        onError: (error) {
          developer.log('BLE location error: $error', name: 'Location', error: error);
        },
      );
    } catch (e) {
      developer.log('Error starting BLE location tracking: $e', name: 'Location', error: e);
      _currentSource = LocationSource.unknown;
    }
  }
  
  Future<void> _stopCurrentTracking() async {
    developer.log('Stopping current location tracking (source: ${_currentSource.name})', name: 'Location');
    
    await _phoneGpsSubscription?.cancel();
    _phoneGpsSubscription = null;
    
    await _bleLocationSubscription?.cancel();
    _bleLocationSubscription = null;
  }
  
  Future<LocationData?> getCurrentLocation() async {
    if (_isBluetoothConnected && _locationPermissionGranted) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        
        final locationData = LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: position.timestamp,
          speed: position.speed * 3.6,
          satellites: 0,
          battery: 100,
          source: LocationSource.phone,
        );
        
        _lastLocation = locationData;
        _locationController.add(locationData);
        return locationData;
      } catch (e) {
        developer.log('Error getting current location: $e', name: 'Location', error: e);
      }
    }
    
    return _lastLocation;
  }
  
  void dispose() {
    _phoneGpsSubscription?.cancel();
    _bleLocationSubscription?.cancel();
    _connectionSubscription?.cancel();
    _locationController.close();
    _permissionStatusController.close();
  }
}