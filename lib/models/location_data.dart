import 'package:latlong2/latlong.dart';

class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final String source;
  
  LocationData({
    required this.latitude,
    required this.longitude,
    this.accuracy = 10.0,
    required this.timestamp,
    this.source = 'phone',
  });
  
  String get formattedTimestamp {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
  
  String get formattedDate {
    final day = timestamp.day.toString().padLeft(2, '0');
    final month = timestamp.month.toString().padLeft(2, '0');
    final year = timestamp.year;
    return '$day/$month/$year';
  }
  
  String get formattedCoordinates {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }
  
  // Helper method to convert to LatLng
  LatLng toLatLng() => LatLng(latitude, longitude);
  
  @override
  String toString() {
    return 'LocationData(lat: $latitude, lng: $longitude, time: $formattedTimestamp)';
  }
}