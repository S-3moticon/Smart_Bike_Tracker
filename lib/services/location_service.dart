import 'dart:async';
import 'dart:developer' as developer;
import 'package:geolocator/geolocator.dart';
import '../models/location_data.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();
  
  StreamSubscription<Position>? _positionSubscription;
  final _locationController = StreamController<LocationData>.broadcast();
  
  Stream<LocationData> get locationStream => _locationController.stream;
  
  Future<bool> checkLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        developer.log('Location services are disabled', name: 'Location');
        return false;
      }
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          developer.log('Location permissions are denied', name: 'Location');
          return false;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        developer.log('Location permissions are permanently denied', name: 'Location');
        return false;
      }
      
      return true;
    } catch (e) {
      developer.log('Error checking location permission: $e', name: 'Location', error: e);
      return false;
    }
  }
  
  Future<void> startLocationTracking() async {
    try {
      final hasPermission = await checkLocationPermission();
      if (!hasPermission) {
        developer.log('Cannot start tracking without location permission', name: 'Location');
        return;
      }
      
      // Stop any existing subscription
      await stopLocationTracking();
      
      developer.log('Starting location tracking', name: 'Location');
      
      // Configure location settings
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      );
      
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) {
        final locationData = LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: position.timestamp,
        );
        
        _locationController.add(locationData);
        developer.log('Location update: ${locationData.formattedCoordinates}', name: 'Location');
      }, onError: (error) {
        developer.log('Location error: $error', name: 'Location', error: error);
      });
    } catch (e) {
      developer.log('Error starting location tracking: $e', name: 'Location', error: e);
    }
  }
  
  Future<void> stopLocationTracking() async {
    developer.log('Stopping location tracking', name: 'Location');
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }
  
  Future<LocationData?> getCurrentLocation() async {
    try {
      final hasPermission = await checkLocationPermission();
      if (!hasPermission) return null;
      
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
      );
      
      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      
      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: position.timestamp,
      );
    } catch (e) {
      developer.log('Error getting current location: $e', name: 'Location', error: e);
      return null;
    }
  }
  
  void dispose() {
    _positionSubscription?.cancel();
    _locationController.close();
  }
}