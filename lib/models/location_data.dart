class LocationData {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double speed;
  final int satellites;
  final int battery;
  final LocationSource source;
  
  LocationData({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.speed = 0.0,
    this.satellites = 0,
    this.battery = 100,
    required this.source,
  });
  
  factory LocationData.fromJson(Map<String, dynamic> json, LocationSource source) {
    return LocationData(
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      satellites: json['satellites'] as int? ?? 0,
      battery: json['battery'] as int? ?? 100,
      source: source,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'lat': latitude,
      'lng': longitude,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'speed': speed,
      'satellites': satellites,
      'battery': battery,
      'source': source.name,
    };
  }
  
  String get formattedCoordinates => '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  
  String get formattedSpeed => '${speed.toStringAsFixed(1)} km/h';
  
  String get formattedTime => '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  
  bool get isValid => latitude != 0.0 && longitude != 0.0;
}

enum LocationSource {
  phone,
  sim7070g,
  unknown
}