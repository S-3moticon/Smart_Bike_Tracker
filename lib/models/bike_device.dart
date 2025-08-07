import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BikeDevice {
  final BluetoothDevice device;
  final String name;
  final String id;
  final int rssi;
  final DateTime lastSeen;
  
  BikeDevice({
    required this.device,
    required this.name,
    required this.id,
    required this.rssi,
    required this.lastSeen,
  });
  
  factory BikeDevice.fromScanResult(ScanResult result) {
    final deviceName = result.device.platformName.isNotEmpty 
        ? result.device.platformName 
        : 'Unknown Device';
    
    return BikeDevice(
      device: result.device,
      name: deviceName,
      id: result.device.remoteId.toString(),
      rssi: result.rssi,
      lastSeen: DateTime.now(),
    );
  }
  
  bool get isBikeTracker => name.startsWith('BikeTrk_');
  
  String get displayName => isBikeTracker ? name : '$name (Not a Bike Tracker)';
  
  int get signalStrength {
    if (rssi >= -50) return 4;
    if (rssi >= -60) return 3;
    if (rssi >= -70) return 2;
    if (rssi >= -80) return 1;
    return 0;
  }
}