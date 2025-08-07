class DeviceStatus {
  final bool bleConnected;
  final bool motionDetected;
  final bool userPresent;
  final DeviceMode mode;
  final DateTime lastUpdate;
  
  DeviceStatus({
    required this.bleConnected,
    required this.motionDetected,
    required this.userPresent,
    required this.mode,
    required this.lastUpdate,
  });
  
  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      bleConnected: json['ble_connected'] as bool,
      motionDetected: json['motion_detected'] as bool,
      userPresent: json['user_present'] as bool,
      mode: DeviceMode.fromString(json['mode'] as String),
      lastUpdate: DateTime.now(),
    );
  }
  
  factory DeviceStatus.initial() {
    return DeviceStatus(
      bleConnected: false,
      motionDetected: false,
      userPresent: false,
      mode: DeviceMode.idle,
      lastUpdate: DateTime.now(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'ble_connected': bleConnected,
      'motion_detected': motionDetected,
      'user_present': userPresent,
      'mode': mode.value,
      'last_update': lastUpdate.toIso8601String(),
    };
  }
  
  bool get isTheftDetected => mode == DeviceMode.alert;
  
  String get statusMessage {
    if (isTheftDetected) return 'THEFT DETECTED!';
    if (mode == DeviceMode.tracking) return 'Tracking Active';
    if (!userPresent) return 'User Not Present';
    if (motionDetected) return 'Motion Detected';
    return 'System Normal';
  }
  
  DeviceStatus copyWith({
    bool? bleConnected,
    bool? motionDetected,
    bool? userPresent,
    DeviceMode? mode,
    DateTime? lastUpdate,
  }) {
    return DeviceStatus(
      bleConnected: bleConnected ?? this.bleConnected,
      motionDetected: motionDetected ?? this.motionDetected,
      userPresent: userPresent ?? this.userPresent,
      mode: mode ?? this.mode,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}

enum DeviceMode {
  idle('IDLE'),
  tracking('TRACKING'),
  alert('ALERT'),
  sleep('SLEEP');
  
  final String value;
  const DeviceMode(this.value);
  
  static DeviceMode fromString(String value) {
    return DeviceMode.values.firstWhere(
      (mode) => mode.value == value,
      orElse: () => DeviceMode.idle,
    );
  }
}