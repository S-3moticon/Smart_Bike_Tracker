import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../models/location_data.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LocationService _locationService = LocationService();
  GoogleMapController? _mapController;
  StreamSubscription<LocationData>? _locationSubscription;
  
  final Set<Marker> _markers = {};
  LocationData? _currentLocation;
  bool _isMapReady = false;
  bool _isFollowingLocation = true;
  
  static const _defaultZoom = 16.0;
  static const _defaultLocation = LatLng(37.7749, -122.4194);
  
  @override
  void initState() {
    super.initState();
    _initializeMap();
  }
  
  Future<void> _initializeMap() async {
    await _locationService.initialize();
    
    _locationSubscription = _locationService.locationStream.listen((location) {
      _updateLocation(location);
    });
    
    final lastLocation = _locationService.lastLocation;
    if (lastLocation != null) {
      _updateLocation(lastLocation);
    }
  }
  
  void _updateLocation(LocationData location) {
    if (!mounted) return;
    
    setState(() {
      _currentLocation = location;
      _updateMarker(location);
    });
    
    if (_isMapReady && _isFollowingLocation) {
      _animateToLocation(location);
    }
  }
  
  void _updateMarker(LocationData location) {
    _markers.clear();
    
    final markerIcon = location.source == LocationSource.phone
        ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)
        : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    
    _markers.add(
      Marker(
        markerId: const MarkerId('bike_location'),
        position: LatLng(location.latitude, location.longitude),
        icon: markerIcon,
        infoWindow: InfoWindow(
          title: 'Bike Location',
          snippet: 'Source: ${location.source.name}\nSpeed: ${location.formattedSpeed}',
        ),
      ),
    );
  }
  
  Future<void> _animateToLocation(LocationData location) async {
    if (_mapController == null || !_isMapReady) return;
    
    try {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(location.latitude, location.longitude),
        ),
      );
    } catch (e) {
      developer.log('Error animating to location: $e', name: 'MapScreen');
    }
  }
  
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    setState(() {
      _isMapReady = true;
    });
    
    if (_currentLocation != null) {
      _animateToLocation(_currentLocation!);
    }
  }
  
  void _toggleFollowLocation() {
    setState(() {
      _isFollowingLocation = !_isFollowingLocation;
    });
    
    if (_isFollowingLocation && _currentLocation != null) {
      _animateToLocation(_currentLocation!);
    }
  }
  
  Future<void> _refreshLocation() async {
    final location = await _locationService.getCurrentLocation();
    if (location != null) {
      _updateLocation(location);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initialPosition = _currentLocation != null
        ? LatLng(_currentLocation!.latitude, _currentLocation!.longitude)
        : _defaultLocation;
    
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: initialPosition,
              zoom: _defaultZoom,
            ),
            markers: _markers,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            mapType: MapType.normal,
            compassEnabled: true,
            zoomControlsEnabled: false,
            style: '''[
              {
                "elementType": "geometry",
                "stylers": [{"color": "#212121"}]
              },
              {
                "elementType": "labels.text.fill",
                "stylers": [{"color": "#757575"}]
              },
              {
                "elementType": "labels.text.stroke",
                "stylers": [{"color": "#212121"}]
              },
              {
                "featureType": "road",
                "elementType": "geometry",
                "stylers": [{"color": "#2c2c2c"}]
              },
              {
                "featureType": "water",
                "elementType": "geometry",
                "stylers": [{"color": "#000000"}]
              }
            ]''',
            onCameraMove: (position) {
              if (_isFollowingLocation) {
                setState(() {
                  _isFollowingLocation = false;
                });
              }
            },
          ),
          
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Card(
              color: theme.cardColor.withValues(alpha: 0.95),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: _currentLocation?.source == LocationSource.phone
                          ? Colors.blue
                          : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentLocation != null
                                ? _currentLocation!.formattedCoordinates
                                : 'Waiting for location...',
                            style: theme.textTheme.bodyLarge,
                          ),
                          if (_currentLocation != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Source: ${_currentLocation!.source.name} | ${_currentLocation!.formattedSpeed}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          Positioned(
            bottom: 32,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  mini: true,
                  onPressed: _toggleFollowLocation,
                  backgroundColor: _isFollowingLocation
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surface,
                  child: Icon(
                    _isFollowingLocation
                        ? Icons.my_location
                        : Icons.location_searching,
                    color: _isFollowingLocation
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _refreshLocation,
                  backgroundColor: theme.colorScheme.surface,
                  child: Icon(
                    Icons.refresh,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}