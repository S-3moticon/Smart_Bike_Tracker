import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'dart:developer' as developer;
import '../models/location_data.dart';
import '../services/map_download_service.dart';
import 'offline_tile_provider.dart';

class LocationMap extends StatefulWidget {
  final List<LocationData> locationHistory;
  final LocationData? currentLocation;
  final bool isTracking;
  final List<Map<String, dynamic>>? mcuGpsPoints;
  
  const LocationMap({
    super.key,
    required this.locationHistory,
    this.currentLocation,
    required this.isTracking,
    this.mcuGpsPoints,
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
  
  // Tile layer options
  int _selectedTileLayer = 0;
  final List<Map<String, String>> _tileLayers = [
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
  
  @override
  void didUpdateWidget(LocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    
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
    // Auto-center on new location if tracking
    else if (widget.isTracking && 
        widget.currentLocation != null &&
        oldWidget.currentLocation != widget.currentLocation) {
      setState(() {
        _center = LatLng(
          widget.currentLocation!.latitude,
          widget.currentLocation!.longitude,
        );
      });
    }
  }
  
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    
    // Add current location marker
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
    
    // Add history markers (show last 10 points)
    final historyToShow = widget.locationHistory.take(10).toList();
    for (int i = 0; i < historyToShow.length; i++) {
      final location = historyToShow[i];
      final opacity = 1.0 - (i * 0.08); // Fade older points
      
      markers.add(
        Marker(
          point: LatLng(location.latitude, location.longitude),
          width: 20,
          height: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withValues(alpha: opacity),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: opacity),
                width: 2,
              ),
            ),
          ),
        ),
      );
    }
    
    // Add MCU GPS points as individual markers (no trace)
    if (widget.mcuGpsPoints != null) {
      for (int i = 0; i < widget.mcuGpsPoints!.length; i++) {
        final point = widget.mcuGpsPoints![i];
        final lat = point['latitude'] ?? 0.0;
        final lng = point['longitude'] ?? 0.0;
        
        // Skip invalid points
        if (lat == 0.0 && lng == 0.0) continue;
        
        // Style differently from phone GPS markers
        // Use a diamond shape for MCU GPS points
        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 24,
            height: 24,
            child: Transform.rotate(
              angle: 0.785398, // 45 degrees in radians
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.8),
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Transform.rotate(
                  angle: -0.785398, // Rotate icon back
                  child: const Icon(
                    Icons.satellite_alt,
                    color: Colors.white,
                    size: 12,
                  ),
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
    if (widget.locationHistory.isEmpty) return [];
    
    // Create trail from last 20 points
    return widget.locationHistory
        .take(20)
        .map((loc) => LatLng(loc.latitude, loc.longitude))
        .toList()
        .reversed
        .toList();
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
            if (widget.locationHistory.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _buildPolylinePoints(),
                    color: theme.colorScheme.primary.withValues(alpha: 0.6),
                    strokeWidth: 4,
                    gradientColors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.3),
                    ],
                  ),
                ],
              ),
            
            // Marker layer
            MarkerLayer(
              markers: _buildMarkers(),
            ),
          ],
        ),
        
        // Map controls
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            children: [
              // Switch tile layer button
              FloatingActionButton(
                mini: true,
                onPressed: _switchTileLayer,
                backgroundColor: theme.colorScheme.surface,
                tooltip: 'Switch map style',
                child: Icon(
                  Icons.layers,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              // Offline mode toggle (only show if offline maps exist)
              if (_offlineMapInfo?['exists'] ?? false) ...[              
                FloatingActionButton(
                  mini: true,
                  onPressed: _toggleOfflineMode,
                  backgroundColor: _useOfflineMode 
                    ? theme.colorScheme.primaryContainer 
                    : theme.colorScheme.surface,
                  tooltip: _useOfflineMode ? 'Using offline maps' : 'Using online maps',
                  child: Icon(
                    _useOfflineMode ? Icons.offline_pin : Icons.cloud_outlined,
                    color: _useOfflineMode 
                      ? theme.colorScheme.onPrimaryContainer 
                      : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Center on location button
              FloatingActionButton(
                mini: true,
                onPressed: widget.currentLocation != null ? _centerOnCurrentLocation : null,
                backgroundColor: theme.colorScheme.surface,
                tooltip: 'Center on location',
                child: Icon(
                  Icons.my_location,
                  color: widget.currentLocation != null 
                    ? theme.colorScheme.primary 
                    : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              // Zoom in
              FloatingActionButton(
                mini: true,
                onPressed: () {
                  _mapController.move(_center, (_zoom + 1).clamp(3, 18));
                },
                backgroundColor: theme.colorScheme.surface,
                tooltip: 'Zoom in',
                child: Icon(
                  Icons.add,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              // Zoom out
              FloatingActionButton(
                mini: true,
                onPressed: () {
                  _mapController.move(_center, (_zoom - 1).clamp(3, 18));
                },
                backgroundColor: theme.colorScheme.surface,
                tooltip: 'Zoom out',
                child: Icon(
                  Icons.remove,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
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