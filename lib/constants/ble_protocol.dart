class BleProtocol {
  static const String serviceUuid = '00001234-0000-1000-8000-00805f9b34fb';
  
  static const String locationCharUuid = '00001235-0000-1000-8000-00805f9b34fb';
  static const String configCharUuid = '00001236-0000-1000-8000-00805f9b34fb';
  static const String statusCharUuid = '00001237-0000-1000-8000-00805f9b34fb';
  static const String commandCharUuid = '00001238-0000-1000-8000-00805f9b34fb';
  
  static const String deviceNamePrefix = 'BikeTrk_';
}

class DataFormats {
  static Map<String, dynamic> createLocationData({
    required double lat,
    required double lng,
    required int timestamp,
    double? speed,
    int? satellites,
    int? battery,
  }) {
    return {
      'lat': lat,
      'lng': lng,
      'timestamp': timestamp,
      'speed': speed ?? 0.0,
      'satellites': satellites ?? 0,
      'battery': battery ?? 100,
    };
  }

  static Map<String, dynamic> createConfigData({
    required String phoneNumber,
    required int updateInterval,
    required bool alertEnabled,
  }) {
    return {
      'phone_number': phoneNumber,
      'update_interval': updateInterval,
      'alert_enabled': alertEnabled,
    };
  }

  static Map<String, dynamic> createStatusData({
    required bool bleConnected,
    required bool motionDetected,
    required bool userPresent,
    required String mode,
  }) {
    return {
      'ble_connected': bleConnected,
      'motion_detected': motionDetected,
      'user_present': userPresent,
      'mode': mode,
    };
  }
}

class DeviceModes {
  static const String idle = 'IDLE';
  static const String tracking = 'TRACKING';
  static const String alert = 'ALERT';
  static const String sleep = 'SLEEP';
}