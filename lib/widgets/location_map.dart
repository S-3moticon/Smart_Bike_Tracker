import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'dart:developer' as developer;
import 'dart:ui' as ui;
import '../models/location_data.dart';
import '../services/map_download_service.dart';
import 'offline_tile_provider.dart';
import 'speedometer_widget.dart';

class LocationMap extends StatefulWidget {
  final List<LocationData> locationHistory;
  final LocationData? currentLocation;
  final bool isTracking;
  final List<Map<String, dynamic>>? mcuGpsPoints;
  final LatLng? selectedLocation;
  final Set<LatLng>? clickedPhoneLocations;
  final Set<LatLng>? clickedMcuLocations;
  final VoidCallback? onLocationSelected;
  final VoidCallback? onClearMarkers;
  
  const LocationMap({
    super.key,
    required this.locationHistory,
    this.currentLocation,
    required this.isTracking,
    this.mcuGpsPoints,
    this.selectedLocation,
    this.clickedPhoneLocations,
    this.clickedMcuLocations,
    this.onLocationSelected,
    this.onClearMarkers,
  });
  
  @override
  State<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap> with AutomaticKeepAliveClientMixin {
  late final MapController _mapController;
  late final Dio _dio;
  late final CacheStore _cacheStore;
  final MapDownloadService _downloadService = MapDownloadService();
  
  // Default center (will be updated with actual location)
  LatLng _center = const LatLng(0, 0);
  double _zoom = 15.0;
  bool _useOfflineMode = false;
  Map<String, dynamic>? _offlineMapInfo;
  bool _showTrail = true; // Toggle for showing location trail
  bool _autoFollowLocation = true; // Auto-center map on location updates
  
  int _selectedTileLayer = 4; // Default to Esri World Imagery
  static const List<Map<String, String>> _tileLayers = [
    {
      'name': 'OpenStreetMap',
      'url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      'attribution': '© OpenStreetMap contributors',
    },
    {
      'name': 'CartoDB Positron',
      'url': 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
      'attribution': '© CartoDB',
    },
    {
      'name': 'CartoDB Dark',
      'url': 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
      'attribution': '© CartoDB',
    },
    {
      'name': 'Esri World Street Map',
      'url': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
      'attribution': '© Esri',
    },
    {
      'name': 'Esri World Imagery',
      'url': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      'attribution': '© Esri',
    },
  ];
  
  bool _cacheInitialized = false;
  bool _hasInitiallyMoved = false;
  
  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    // Set initial center if we have location data
    if (widget.currentLocation != null) {
      _center = LatLng(
        widget.currentLocation!.latitude,
        widget.currentLocation!.longitude,
      );
      _zoom = 16.0; // Zoom in closer for current location
    } else if (widget.locationHistory.isNotEmpty) {
      final latest = widget.locationHistory.first;
      _center = LatLng(latest.latitude, latest.longitude);
      _zoom = 15.0;
    }
    
    // Defer cache initialization and auto-center to after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeCache();
        _checkOfflineMapAvailability();
        // Auto-center map on first load
        if (!_hasInitiallyMoved && (widget.currentLocation != null || widget.locationHistory.isNotEmpty)) {
          _mapController.move(_center, _zoom);
          _hasInitiallyMoved = true;
        }
      }
    });
    
    developer.log('Map initialized with center: $_center', name: 'LocationMap');
  }
  
  Future<void> _checkOfflineMapAvailability() async {
    final info = await _downloadService.getOfflineMapInfo();
    if (mounted) {
      setState(() {
        _offlineMapInfo = info;
      });
    }
  }
  
  void _initializeCache() {
    if (_cacheInitialized) return;
    
    // Simple memory cache for faster tile loading
    _cacheStore = MemCacheStore(maxSize: 100 * 1024 * 1024); // Reduced to 100MB for better performance
    
    _dio = Dio()
      ..interceptors.add(
        DioCacheInterceptor(
          options: CacheOptions(
            store: _cacheStore,
            policy: CachePolicy.forceCache,
            maxStale: const Duration(days: 7),
            priority: CachePriority.high,
            hitCacheOnErrorExcept: [], // Cache on all errors
          ),
        ),
      );
    
    _cacheInitialized = true;
    if (mounted) {
      setState(() {}); // Rebuild to use cached provider
    }
  }
  
  void _centerOnCurrentLocation() {
    if (widget.currentLocation != null) {
      final newCenter = LatLng(
        widget.currentLocation!.latitude,
        widget.currentLocation!.longitude,
      );
      _mapController.move(newCenter, 16.0);
      setState(() {
        _center = newCenter;
        _zoom = 16.0;
        _autoFollowLocation = true; // Re-enable auto-follow when centering
      });
      developer.log('Centered on current location, auto-follow enabled', name: 'LocationMap');
    }
  }
  
  void _switchTileLayer() {
    setState(() {
      _selectedTileLayer = (_selectedTileLayer + 1) % _tileLayers.length;
    });
    developer.log('Switched to tile layer: ${_tileLayers[_selectedTileLayer]['name']}', name: 'LocationMap');
  }
  
  void _toggleOfflineMode() {
    setState(() {
      _useOfflineMode = !_useOfflineMode;
    });
    developer.log('Offline mode: $_useOfflineMode', name: 'LocationMap');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_useOfflineMode ? 'Using offline maps' : 'Using online maps'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
    );
  }
  
  void _handleMenuSelection(String value) {
    switch (value) {
      case 'switch_layer':
        _switchTileLayer();
        break;
      case 'toggle_offline':
        _toggleOfflineMode();
        break;
      case 'center_location':
        _centerOnCurrentLocation();
        break;
      case 'toggle_trail':
        setState(() {
          _showTrail = !_showTrail;
        });
        _showSnackBar(_showTrail ? 'Trail enabled' : 'Trail hidden');
        break;
      case 'clear_markers':
        widget.onClearMarkers?.call();
        break;
    }
  }
  
  List<PopupMenuEntry<String>> _buildMenuItems(ThemeData theme) {
    final hasMarkers = (widget.clickedPhoneLocations?.isNotEmpty ?? false) || 
                       (widget.clickedMcuLocations?.isNotEmpty ?? false);
    final markerCount = (widget.clickedPhoneLocations?.length ?? 0) + 
                        (widget.clickedMcuLocations?.length ?? 0);
    
    return [
      // Map Style
      PopupMenuItem<String>(
        value: 'switch_layer',
        child: ListTile(
          leading: Icon(
            Icons.layers,
            color: theme.colorScheme.primary,
          ),
          title: const Text('Map Style'),
          subtitle: Text(
            _tileLayers[_selectedTileLayer]['name']!,
            style: theme.textTheme.bodySmall,
          ),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      
      // Offline Mode (conditional)
      if (_offlineMapInfo?['exists'] ?? false)
        PopupMenuItem<String>(
          value: 'toggle_offline',
          child: ListTile(
            leading: Icon(
              _useOfflineMode ? Icons.offline_pin : Icons.cloud_outlined,
              color: _useOfflineMode 
                ? theme.colorScheme.primary 
                : theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(_useOfflineMode ? 'Offline Mode' : 'Online Mode'),
            subtitle: Text(
              _useOfflineMode ? 'Using local maps' : 'Using internet',
              style: theme.textTheme.bodySmall,
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      
      const PopupMenuDivider(),
      
      // Center Location
      PopupMenuItem<String>(
        value: 'center_location',
        enabled: widget.currentLocation != null,
        child: ListTile(
          leading: Icon(
            _autoFollowLocation ? Icons.my_location : Icons.location_searching,
            color: widget.currentLocation != null
              ? (_autoFollowLocation 
                ? theme.colorScheme.primary 
                : theme.colorScheme.onSurfaceVariant)
              : theme.colorScheme.onSurface.withValues(alpha: 0.38),
          ),
          title: const Text('Center on Location'),
          subtitle: Text(
            _autoFollowLocation ? 'Auto-follow active' : 'Tap to enable',
            style: theme.textTheme.bodySmall,
          ),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      
      // Toggle Trail
      if (widget.locationHistory.isNotEmpty)
        PopupMenuItem<String>(
          value: 'toggle_trail',
          child: ListTile(
            leading: Icon(
              Icons.route,
              color: _showTrail 
                ? theme.colorScheme.primary 
                : theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(_showTrail ? 'Hide Trail' : 'Show Trail'),
            subtitle: Text(
              '${widget.locationHistory.length} points',
              style: theme.textTheme.bodySmall,
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      
      // Clear Markers
      if (hasMarkers) ...[
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'clear_markers',
          child: ListTile(
            leading: Icon(
              Icons.clear_all,
              color: theme.colorScheme.error,
            ),
            title: const Text('Clear Markers'),
            subtitle: Text(
              '$markerCount marker${markerCount > 1 ? 's' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ];
  }
  
  @override
  void didUpdateWidget(LocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if a location was selected from history
    if (widget.selectedLocation != null && 
        widget.selectedLocation != oldWidget.selectedLocation) {
      _navigateToLocation(widget.selectedLocation!);
      // Call the callback to clear the selected location
      widget.onLocationSelected?.call();
    }
    
    // Auto-center on first location received
    if (!_hasInitiallyMoved && widget.currentLocation != null && oldWidget.currentLocation == null) {
      _center = LatLng(
        widget.currentLocation!.latitude,
        widget.currentLocation!.longitude,
      );
      _zoom = 16.0;
      _mapController.move(_center, _zoom);
      _hasInitiallyMoved = true;
      developer.log('Auto-centered map on first location', name: 'LocationMap');
    }
    // Auto-center on new location if tracking and auto-follow is enabled
    else if (widget.isTracking && 
        _autoFollowLocation &&
        widget.currentLocation != null &&
        oldWidget.currentLocation != widget.currentLocation) {
      _center = LatLng(
        widget.currentLocation!.latitude,
        widget.currentLocation!.longitude,
      );
      // Actually move the map to the new location
      _mapController.move(_center, _zoom);
      developer.log('Auto-centered map to new location', name: 'LocationMap');
    }
    
    // Force rebuild when location history changes (for live trail updates)
    if (widget.locationHistory.length != oldWidget.locationHistory.length) {
      developer.log('Location history updated, refreshing trail. Points: ${widget.locationHistory.length}', 
                   name: 'LocationMap');
      // Force a rebuild to update the trail
      setState(() {
        // State change triggers rebuild which will call _buildPolylinePoints()
      });
    } else if (widget.locationHistory.isNotEmpty && oldWidget.locationHistory.isNotEmpty) {
      // Check if the latest location has changed (new GPS point added)
      final latestLocation = widget.locationHistory.first;
      final oldLatestLocation = oldWidget.locationHistory.first;
      
      if (latestLocation.latitude != oldLatestLocation.latitude ||
          latestLocation.longitude != oldLatestLocation.longitude ||
          latestLocation.timestamp != oldLatestLocation.timestamp) {
        developer.log('New GPS point detected, updating trail', name: 'LocationMap');
        setState(() {
          // Trigger rebuild to update the polyline
        });
      }
    }
  }
  
  void _navigateToLocation(LatLng location) {
    // Animate to the selected location with higher zoom
    _mapController.move(location, 18.0);
    setState(() {
      _center = location;
      _zoom = 18.0;
    });
    developer.log('Navigated to location: ${location.latitude}, ${location.longitude}', name: 'LocationMap');
  }
  
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    
    // Add current location marker (always shown)
    if (widget.currentLocation != null) {
      markers.add(
        Marker(
          point: LatLng(
            widget.currentLocation!.latitude,
            widget.currentLocation!.longitude,
          ),
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.my_location,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      );
    }
    
    // Add clicked phone locations as markers with phone icon
    if (widget.clickedPhoneLocations != null) {
      for (final location in widget.clickedPhoneLocations!) {
        markers.add(
          Marker(
            point: location,
            width: 36,
            height: 44,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Pin shape with shadow
                CustomPaint(
                  size: const Size(36, 44),
                  painter: _MapPinPainter(
                    color: Colors.blue,
                    borderColor: Colors.white,
                  ),
                ),
                // Phone icon inside the pin
                const Positioned(
                  top: 8,
                  child: Icon(
                    Icons.phone_android,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    
    // Add clicked MCU locations as markers with satellite icon
    if (widget.clickedMcuLocations != null) {
      for (final location in widget.clickedMcuLocations!) {
        markers.add(
          Marker(
            point: location,
            width: 36,
            height: 44,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Pin shape with shadow
                CustomPaint(
                  size: const Size(36, 44),
                  painter: _MapPinPainter(
                    color: Colors.orange,
                    borderColor: Colors.white,
                  ),
                ),
                // Satellite icon inside the pin
                const Positioned(
                  top: 8,
                  child: Icon(
                    Icons.satellite_alt,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    
    // Add only the LATEST MCU GPS point (not all history)
    if (widget.mcuGpsPoints != null && widget.mcuGpsPoints!.isNotEmpty) {
      // Get only the first (latest) point
      final latestPoint = widget.mcuGpsPoints!.first;
      final lat = latestPoint['lat'] ?? latestPoint['latitude'] ?? 0.0;
      final lng = latestPoint['lon'] ?? latestPoint['longitude'] ?? 0.0;
      
      // Skip invalid points
      if (lat != 0.0 || lng != 0.0) {
        // Use a Google Maps-style pin marker for the latest MCU GPS point
        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 36,
            height: 44,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Pin shape with shadow
                CustomPaint(
                  size: const Size(36, 44),
                  painter: _MapPinPainter(
                    color: Colors.orange,
                    borderColor: Colors.white,
                  ),
                ),
                // Icon inside the pin
                const Positioned(
                  top: 8,
                  child: Icon(
                    Icons.satellite_alt,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    
    // Add trail point markers (small circles every 5th GPS point)
    if (_showTrail && widget.locationHistory.isNotEmpty) {
      for (int i = 0; i < widget.locationHistory.length; i += 5) {
        final location = widget.locationHistory[i];
        markers.add(
          Marker(
            point: LatLng(location.latitude, location.longitude),
            width: 8,
            height: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 1,
                ),
              ),
            ),
          ),
        );
      }
    }
    
    return markers;
  }
  
  List<LatLng> _buildPolylinePoints() {
    // Build trail from location history
    final points = <LatLng>[];
    
    // Since locationHistory is already sorted with newest first (index 0),
    // we need to reverse it to draw the trail chronologically
    for (final location in widget.locationHistory.reversed) {
      final point = LatLng(location.latitude, location.longitude);
      // Avoid duplicate consecutive points
      if (points.isEmpty || points.last != point) {
        points.add(point);
      }
    }
    
    // Add current location if available and different from last point
    if (widget.currentLocation != null) {
      final currentPoint = LatLng(
        widget.currentLocation!.latitude,
        widget.currentLocation!.longitude,
      );
      // Only add if it's different from the last point
      if (points.isEmpty || points.last != currentPoint) {
        points.add(currentPoint);
      }
    }
    
    developer.log('Trail points: ${points.length}', name: 'LocationMap');
    return points;
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final currentTileLayer = _tileLayers[_selectedTileLayer];
    
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: _zoom,
            minZoom: 3,
            maxZoom: 18,
            onPositionChanged: (position, hasGesture) {
              if (hasGesture && position.center != null && position.zoom != null) {
                // User manually moved the map, disable auto-follow
                if (_autoFollowLocation) {
                  setState(() {
                    _autoFollowLocation = false;
                    developer.log('Auto-follow disabled due to manual pan', name: 'LocationMap');
                  });
                }
                setState(() {
                  _center = position.center!;
                  _zoom = position.zoom!;
                });
              }
            },
          ),
          children: [
            // Tile layer - use offline, cached, or network provider based on settings
            TileLayer(
              urlTemplate: currentTileLayer['url']!,
              userAgentPackageName: 'com.example.smart_bike_tracker',
              maxNativeZoom: 19,
              tileProvider: _useOfflineMode && (_offlineMapInfo?['exists'] ?? false)
                ? OfflineTileProvider(fallbackUrl: currentTileLayer['url']!)
                : (_cacheInitialized 
                    ? CachedTileProvider(
                        dio: _dio,
                        maxStale: const Duration(days: 7),
                        store: _cacheStore,
                      )
                    : NetworkTileProvider()),
              errorTileCallback: (tile, error, stackTrace) {
                // Only log errors in debug mode to reduce overhead
                assert(() {
                  developer.log(
                    'Tile error: ${tile.coordinates}', 
                    name: 'LocationMap',
                  );
                  return true;
                }());
              },
              subdomains: const ['a', 'b', 'c'],
              retinaMode: false, // Disable for better performance
              keepBuffer: 1, // Reduced for better performance
              panBuffer: 1, // Reduced for better performance
            ),
            
            // Attribution layer
            SimpleAttributionWidget(
              source: Text(
                currentTileLayer['attribution']!,
                style: const TextStyle(fontSize: 10),
              ),
              backgroundColor: Colors.white.withValues(alpha: 0.7),
            ),
            
            // Polyline layer for location trail
            if (_showTrail && widget.locationHistory.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _buildPolylinePoints(),
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    strokeWidth: 3.5,
                    gradientColors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.4),
                    ],
                    borderColor: theme.colorScheme.primary.withValues(alpha: 0.9),
                    borderStrokeWidth: 0.5,
                  ),
                ],
              ),
            
            // Marker layer
            MarkerLayer(
              markers: _buildMarkers(),
            ),
          ],
        ),
        
        // Map controls dropdown menu
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: PopupMenuButton<String>(
              icon: Icon(
                Icons.menu,
                color: theme.colorScheme.primary,
              ),
              tooltip: 'Map Options',
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: _handleMenuSelection,
              itemBuilder: (context) => _buildMenuItems(theme),
            ),
          ),
        ),
        
        // Tracking indicator
        if (widget.isTracking)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tracking',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // Trail info indicator
        if (_showTrail && widget.locationHistory.isNotEmpty)
          Positioned(
            bottom: 100,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timeline,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Trail: ${widget.locationHistory.length} points',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // Map style indicator
        Positioned(
          top: 16,
          left: widget.isTracking ? 110 : 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              currentTileLayer['name']!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        
        // Location info overlay - moved to top to not block controls
        if (widget.currentLocation != null)
          Positioned(
            top: 60,
            left: 16,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Current Location',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lat: ${widget.currentLocation!.latitude.toStringAsFixed(5)}',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                  Text(
                    'Lng: ${widget.currentLocation!.longitude.toStringAsFixed(5)}',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                  Text(
                    widget.currentLocation!.formattedTimestamp,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // Speedometer widget
        if (widget.isTracking && widget.currentLocation != null)
          Positioned(
            bottom: 24,
            right: 24,
            child: SpeedometerWidget(
              speed: widget.currentLocation!.speed,
              isVisible: widget.isTracking,
              source: widget.currentLocation!.source,
            ),
          ),
        
        // Speedometer for MCU GPS (when no current location but have MCU points)
        if (!widget.isTracking && 
            widget.currentLocation == null && 
            widget.mcuGpsPoints != null && 
            widget.mcuGpsPoints!.isNotEmpty)
          Positioned(
            bottom: 24,
            right: 24,
            child: Builder(
              builder: (context) {
                final latestPoint = widget.mcuGpsPoints!.first;
                final speed = latestPoint['speed'] ?? 0.0;
                return SpeedometerWidget(
                  speed: speed.toDouble(),
                  isVisible: true,
                  source: 'mcu',
                );
              },
            ),
          ),
      ],
    );
  }
  
  @override
  bool get wantKeepAlive => true; // Keep the map widget alive
  
  @override
  void dispose() {
    _mapController.dispose();
    if (_cacheInitialized) {
      _dio.close();
    }
    super.dispose();
  }
}

// Custom painter for Google Maps-style pin marker
class _MapPinPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  _MapPinPainter({
    required this.color,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final path = ui.Path();
    
    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3);
    
    final shadowPath = ui.Path();
    shadowPath.addOval(Rect.fromCenter(
      center: Offset(size.width / 2, size.height - 2),
      width: 12,
      height: 6,
    ));
    canvas.drawPath(shadowPath, shadowPaint);
    
    // Create pin shape path
    final centerX = size.width / 2;
    final radius = size.width / 2.5;
    final pinHeight = size.height;
    
    // Start from the bottom point
    path.moveTo(centerX, pinHeight);
    
    // Create the pin shape with smooth curves
    path.quadraticBezierTo(
      centerX - radius * 0.5, pinHeight - radius * 1.5,
      centerX - radius, pinHeight - radius * 2,
    );
    
    // Top circle part
    path.arcToPoint(
      Offset(centerX + radius, pinHeight - radius * 2),
      radius: Radius.circular(radius),
      clockwise: true,
    );
    
    // Right side curve to bottom
    path.quadraticBezierTo(
      centerX + radius * 0.5, pinHeight - radius * 1.5,
      centerX, pinHeight,
    );
    
    path.close();
    
    // Draw white border
    paint.color = borderColor;
    paint.style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
    
    // Draw colored fill (slightly smaller for border effect)
    final scale = 0.85;
    canvas.save();
    canvas.translate(centerX * (1 - scale), (pinHeight - radius * 2) * (1 - scale));
    canvas.scale(scale, scale);
    
    paint.color = color;
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}