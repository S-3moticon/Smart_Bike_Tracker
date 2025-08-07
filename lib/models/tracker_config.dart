class TrackerConfig {
  final String phoneNumber;
  final int updateInterval;
  final bool alertEnabled;
  
  TrackerConfig({
    required this.phoneNumber,
    required this.updateInterval,
    required this.alertEnabled,
  });
  
  factory TrackerConfig.defaultConfig() {
    return TrackerConfig(
      phoneNumber: '',
      updateInterval: 30,
      alertEnabled: true,
    );
  }
  
  factory TrackerConfig.fromJson(Map<String, dynamic> json) {
    return TrackerConfig(
      phoneNumber: json['phone_number'] as String? ?? '',
      updateInterval: json['update_interval'] as int? ?? 30,
      alertEnabled: json['alert_enabled'] as bool? ?? true,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'phone_number': phoneNumber,
      'update_interval': updateInterval,
      'alert_enabled': alertEnabled,
    };
  }
  
  String toJsonString() {
    return '{"phone_number":"$phoneNumber","update_interval":$updateInterval,"alert_enabled":$alertEnabled}';
  }
  
  bool get isPhoneNumberValid {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    return cleaned.length >= 10 && cleaned.length <= 15;
  }
  
  String get formattedUpdateInterval {
    if (updateInterval < 60) return '$updateInterval seconds';
    if (updateInterval < 3600) return '${(updateInterval / 60).round()} minutes';
    return '${(updateInterval / 3600).round()} hours';
  }
  
  TrackerConfig copyWith({
    String? phoneNumber,
    int? updateInterval,
    bool? alertEnabled,
  }) {
    return TrackerConfig(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      updateInterval: updateInterval ?? this.updateInterval,
      alertEnabled: alertEnabled ?? this.alertEnabled,
    );
  }
}