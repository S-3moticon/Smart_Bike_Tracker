import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_data.dart';

/// Optimized location tracking view with map
class LocationTrackingView extends StatelessWidget {
  final List<LocationData> locations;
  final LocationData? currentLocation;
  final List<Map<String, dynamic>> mcuGpsHistory;
  final bool isTracking;
  final LatLng? selectedLocation;
  final Function(LatLng) onLocationTap;
  
  const LocationTrackingView({
    super.key,
    required this.locations,
    required this.currentLocation,
    required this.mcuGpsHistory,
    required this.isTracking,
    required this.selectedLocation,
    required this.onLocationTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildMap(context),
        _buildStatusOverlay(context),
      ],
    );
  }
  
  Widget _buildMap(BuildContext context) {
    final center = selectedLocation ?? 
                   currentLocation?.toLatLng() ?? 
                   const LatLng(0, 0);
    
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15,
        onTap: (_, point) => onLocationTap(point),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.smartbiketracker.app',
        ),
        MarkerLayer(
          markers: _buildMarkers(context),
        ),
        if (locations.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: locations.map((l) => l.toLatLng()).toList(),
                strokeWidth: 3,
                color: Colors.blue.withValues(alpha: 0.7),
              ),
            ],
          ),
      ],
    );
  }
  
  List<Marker> _buildMarkers(BuildContext context) {
    final markers = <Marker>[];
    
    // Current location marker
    if (currentLocation != null) {
      markers.add(
        Marker(
          point: currentLocation!.toLatLng(),
          width: 40,
          height: 40,
          child: Icon(
            Icons.my_location,
            color: Theme.of(context).colorScheme.primary,
            size: 40,
          ),
        ),
      );
    }
    
    // Selected location marker
    if (selectedLocation != null) {
      markers.add(
        Marker(
          point: selectedLocation!,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.place,
            color: Colors.red,
            size: 40,
          ),
        ),
      );
    }
    
    // MCU GPS history markers
    for (var point in mcuGpsHistory.take(10)) {
      final lat = point['lat']?.toDouble();
      final lng = point['lng']?.toDouble() ?? point['lon']?.toDouble();
      
      if (lat != null && lng != null) {
        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 30,
            height: 30,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.history,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        );
      }
    }
    
    return markers;
  }
  
  Widget _buildStatusOverlay(BuildContext context) {
    return Positioned(
      top: 8,
      left: 8,
      right: 8,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Icon(
                isTracking ? Icons.location_on : Icons.location_off,
                color: isTracking ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                isTracking ? 'Tracking Active' : 'Tracking Inactive',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              if (currentLocation != null)
                Text(
                  '${currentLocation!.latitude.toStringAsFixed(5)}, '
                  '${currentLocation!.longitude.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}