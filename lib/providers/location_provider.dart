import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:permission_handler/permission_handler.dart';
import '../services/location_service.dart';
import '../models/location_data.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  
  LocationData? _currentLocation;
  LocationSource _currentSource = LocationSource.unknown;
  PermissionStatus _permissionStatus = PermissionStatus.denied;
  bool _isTracking = false;
  bool _locationServiceEnabled = false;
  String? _address;
  
  StreamSubscription? _locationSubscription;
  StreamSubscription? _permissionSubscription;
  
  LocationData? get currentLocation => _currentLocation;
  LocationSource get currentSource => _currentSource;
  PermissionStatus get permissionStatus => _permissionStatus;
  bool get isTracking => _isTracking;
  bool get locationServiceEnabled => _locationServiceEnabled;
  String? get address => _address;
  bool get hasValidLocation => _currentLocation != null && _currentLocation!.isValid;
  
  LocationProvider() {
    _initialize();
  }
  
  Future<void> _initialize() async {
    await checkPermissions();
    await checkLocationService();
    await startTracking();
    
    _locationSubscription = _locationService.locationStream.listen((location) {
      _currentLocation = location;
      _currentSource = location.source;
      notifyListeners();
      
      developer.log(
        'Location updated: ${location.formattedCoordinates} from ${location.source.name}',
        name: 'LocationProvider',
      );
    });
    
    _permissionSubscription = _locationService.permissionStatus.listen((status) {
      _permissionStatus = status;
      notifyListeners();
    });
  }
  
  Future<void> checkPermissions() async {
    _permissionStatus = await _locationService.checkAndRequestPermissions();
    notifyListeners();
  }
  
  Future<void> checkLocationService() async {
    _locationServiceEnabled = await _locationService.checkLocationServiceEnabled();
    notifyListeners();
  }
  
  Future<void> requestPermissions() async {
    _permissionStatus = await _locationService.checkAndRequestPermissions();
    
    if (_permissionStatus.isGranted) {
      await startTracking();
    }
    
    notifyListeners();
  }
  
  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
  }
  
  Future<void> openAppSettings() async {
    await _locationService.openAppSettings();
  }
  
  Future<void> startTracking() async {
    if (_isTracking) return;
    
    try {
      await _locationService.initialize();
      _isTracking = true;
      
      final location = _locationService.lastLocation;
      if (location != null) {
        _currentLocation = location;
        _currentSource = location.source;
      }
      
      notifyListeners();
    } catch (e) {
      developer.log('Error starting tracking: $e', name: 'LocationProvider');
      _isTracking = false;
      notifyListeners();
    }
  }
  
  Future<void> stopTracking() async {
    _isTracking = false;
    notifyListeners();
  }
  
  Future<void> refreshLocation() async {
    final location = await _locationService.getCurrentLocation();
    if (location != null) {
      _currentLocation = location;
      _currentSource = location.source;
      notifyListeners();
    }
  }
  
  void setAddress(String? address) {
    _address = address;
    notifyListeners();
  }
  
  String get locationStatusText {
    if (!_locationServiceEnabled) {
      return 'Location service is disabled';
    }
    
    if (_permissionStatus.isDenied) {
      return 'Location permission denied';
    }
    
    if (_permissionStatus.isPermanentlyDenied) {
      return 'Location permission permanently denied';
    }
    
    if (_currentLocation == null) {
      return 'Waiting for location...';
    }
    
    return 'Location available (${_currentSource.name})';
  }
  
  @override
  void dispose() {
    _locationSubscription?.cancel();
    _permissionSubscription?.cancel();
    _locationService.dispose();
    super.dispose();
  }
}