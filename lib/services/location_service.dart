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
  Position? _lastKnownPosition;
  DateTime? _lastPositionTime;
  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 5;
  
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
      
      // First, try to get last known position for immediate feedback
      try {
        Position? lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          // Check if position is recent (within 5 minutes)
          final age = DateTime.now().difference(lastPosition.timestamp);
          if (age.inMinutes < 5) {
            developer.log('Using last known position (${age.inSeconds}s old)', name: 'Location');
            _lastKnownPosition = lastPosition;
            _lastPositionTime = lastPosition.timestamp;
            
            final speedKmh = lastPosition.speed * 3.6;
            final locationData = LocationData(
              latitude: lastPosition.latitude,
              longitude: lastPosition.longitude,
              speed: speedKmh,
              accuracy: lastPosition.accuracy,
              timestamp: lastPosition.timestamp,
            );
            _locationController.add(locationData);
          }
        }
      } catch (e) {
        developer.log('Could not get last known position: $e', name: 'Location');
      }
      
      // Configure optimized location settings
      // Use BestForNavigation for faster initial fix, then switch to High accuracy
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation, // Better for quick fix
        distanceFilter: 5, // More frequent updates (5 meters)
        // Removed timeLimit to allow Samsung devices more time to get GPS fix
      );
      
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) {
        // Reset retry count on successful location
        _retryCount = 0;
        _retryTimer?.cancel();
        
        _lastKnownPosition = position;
        _lastPositionTime = position.timestamp;
        
        // Convert speed from m/s to km/h (Geolocator provides speed in m/s)
        final speedKmh = position.speed * 3.6;
        
        final locationData = LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          speed: speedKmh,
          accuracy: position.accuracy,
          timestamp: position.timestamp,
        );
        
        _locationController.add(locationData);
        developer.log('Location update: ${locationData.formattedCoordinates}', name: 'Location');
      }, onError: (error) {
        developer.log('Location error: $error', name: 'Location', error: error);
        
        // On error, try to use last known position if available
        if (_lastKnownPosition != null) {
          final speedKmh = _lastKnownPosition!.speed * 3.6;
          final locationData = LocationData(
            latitude: _lastKnownPosition!.latitude,
            longitude: _lastKnownPosition!.longitude,
            speed: speedKmh,
            accuracy: _lastKnownPosition!.accuracy,
            timestamp: _lastKnownPosition!.timestamp,
          );
          _locationController.add(locationData);
        }
        
        // Auto-retry on timeout or other errors
        _handleLocationError(error);
      });
    } catch (e) {
      developer.log('Error starting location tracking: $e', name: 'Location', error: e);
    }
  }
  
  void _handleLocationError(dynamic error) {
    // Cancel any existing retry timer
    _retryTimer?.cancel();
    
    // Check if we should retry
    if (_retryCount < _maxRetries) {
      _retryCount++;
      final retryDelay = Duration(seconds: 2 * _retryCount); // Exponential backoff
      
      developer.log('Location error occurred, retrying in ${retryDelay.inSeconds}s (attempt $_retryCount/$_maxRetries)', 
                   name: 'Location');
      
      _retryTimer = Timer(retryDelay, () async {
        developer.log('Restarting location tracking after error...', name: 'Location');
        // Cancel existing subscription
        await _positionSubscription?.cancel();
        _positionSubscription = null;
        
        // Restart tracking
        await startLocationTracking();
      });
    } else {
      developer.log('Max retries reached, stopping location tracking', name: 'Location');
      _retryCount = 0; // Reset for next time
    }
  }
  
  Future<void> stopLocationTracking() async {
    developer.log('Stopping location tracking', name: 'Location');
    _retryTimer?.cancel();
    _retryCount = 0;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }
  
  Future<LocationData?> getCurrentLocation() async {
    try {
      final hasPermission = await checkLocationPermission();
      if (!hasPermission) return null;
      
      // First try to get last known position for immediate response
      Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        final age = DateTime.now().difference(lastPosition.timestamp);
        if (age.inMinutes < 2) {
          // If position is less than 2 minutes old, use it immediately
          developer.log('Using recent cached position (${age.inSeconds}s old)', name: 'Location');
          final speedKmh = lastPosition.speed * 3.6;
          return LocationData(
            latitude: lastPosition.latitude,
            longitude: lastPosition.longitude,
            speed: speedKmh,
            accuracy: lastPosition.accuracy,
            timestamp: lastPosition.timestamp,
          );
        }
      }
      
      // Configure for faster fix
      // Low accuracy gets position faster, then we can refine
      const LocationSettings quickSettings = LocationSettings(
        accuracy: LocationAccuracy.low, // Fastest fix
        timeLimit: Duration(seconds: 5), // Quick timeout
      );
      
      const LocationSettings preciseSettings = LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation, // More accurate
        timeLimit: Duration(seconds: 10),
      );
      
      // Try quick fix first
      try {
        final quickPosition = await Geolocator.getCurrentPosition(
          locationSettings: quickSettings,
        );
        
        // Got quick position, update cache
        _lastKnownPosition = quickPosition;
        _lastPositionTime = quickPosition.timestamp;
        
        developer.log('Got quick GPS fix', name: 'Location');
        
        // Return quick position immediately
        final speedKmh = quickPosition.speed * 3.6;
        final quickData = LocationData(
          latitude: quickPosition.latitude,
          longitude: quickPosition.longitude,
          speed: speedKmh,
          accuracy: quickPosition.accuracy,
          timestamp: quickPosition.timestamp,
        );
        
        // Try to get more accurate position in background
        Geolocator.getCurrentPosition(
          locationSettings: preciseSettings,
        ).then((precisePosition) {
          _lastKnownPosition = precisePosition;
          _lastPositionTime = precisePosition.timestamp;
          developer.log('Updated with precise GPS fix', name: 'Location');
        }).catchError((e) {
          // Ignore errors for background precise update
        });
        
        return quickData;
      } catch (e) {
        // Quick fix failed, try precise
        developer.log('Quick fix failed, trying precise: $e', name: 'Location');
        
        final position = await Geolocator.getCurrentPosition(
          locationSettings: preciseSettings,
        );
        
        _lastKnownPosition = position;
        _lastPositionTime = position.timestamp;
        
        final speedKmh = position.speed * 3.6;
        return LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          speed: speedKmh,
          accuracy: position.accuracy,
          timestamp: position.timestamp,
        );
      }
    } catch (e) {
      developer.log('Error getting current location: $e', name: 'Location', error: e);
      
      // Last resort: return cached position if available
      if (_lastKnownPosition != null) {
        developer.log('Returning cached position as fallback', name: 'Location');
        final speedKmh = _lastKnownPosition!.speed * 3.6;
        return LocationData(
          latitude: _lastKnownPosition!.latitude,
          longitude: _lastKnownPosition!.longitude,
          speed: speedKmh,
          accuracy: _lastKnownPosition!.accuracy,
          timestamp: _lastKnownPosition!.timestamp,
        );
      }
      
      return null;
    }
  }
  
  Future<LocationData?> getQuickLocation() async {
    // Optimized method for getting location as fast as possible
    try {
      final hasPermission = await checkLocationPermission();
      if (!hasPermission) return null;
      
      // Check cache first
      if (_lastKnownPosition != null && _lastPositionTime != null) {
        final age = DateTime.now().difference(_lastPositionTime!);
        if (age.inSeconds < 30) {
          developer.log('Using very recent cached position (${age.inSeconds}s old)', name: 'Location');
          return LocationData(
            latitude: _lastKnownPosition!.latitude,
            longitude: _lastKnownPosition!.longitude,
            timestamp: _lastKnownPosition!.timestamp,
          );
        }
      }
      
      // Get last known position from system
      Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        return LocationData(
          latitude: lastPosition.latitude,
          longitude: lastPosition.longitude,
          timestamp: lastPosition.timestamp,
        );
      }
      
      // Fall back to current location with timeout
      return await getCurrentLocation();
    } catch (e) {
      developer.log('Error getting quick location: $e', name: 'Location', error: e);
      return null;
    }
  }
  
  void dispose() {
    _retryTimer?.cancel();
    _positionSubscription?.cancel();
    _locationController.close();
  }
}