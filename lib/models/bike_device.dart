import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../constants/ble_protocol.dart';

class BikeDevice {
  final BluetoothDevice device;
  final String name;
  final String id;
  final int rssi;
  final DateTime lastSeen;
  final bool hasServiceUuid;
  
  BikeDevice({
    required this.device,
    required this.name,
    required this.id,
    required this.rssi,
    required this.lastSeen,
    this.hasServiceUuid = false,
  });
  
  factory BikeDevice.fromScanResult(ScanResult result) {
    // Try multiple sources to get the device name
    String deviceName = '';
    
    // First try: Advertisement data contains the advertised name
    if (result.advertisementData.advName.isNotEmpty) {
      deviceName = result.advertisementData.advName;
    } 
    // Second try: Device's advertised name
    else if (result.device.advName.isNotEmpty) {
      deviceName = result.device.advName;
    }
    // Third try: Platform-specific name (might be empty for non-paired devices)
    else if (result.device.platformName.isNotEmpty) {
      deviceName = result.device.platformName;
    }
    // Fallback: Use device ID
    else {
      deviceName = 'Device ${result.device.remoteId.toString().substring(0, 8)}';
    }
    
    // Check if device advertises our service UUID
    bool hasOurService = false;
    try {
      hasOurService = result.advertisementData.serviceUuids
          .any((uuid) => uuid.toString().toLowerCase() == BleProtocol.serviceUuid.toLowerCase());
    } catch (e) {
      // Ignore errors in service UUID checking
    }
    
    return BikeDevice(
      device: result.device,
      name: deviceName,
      id: result.device.remoteId.toString(),
      rssi: result.rssi,
      lastSeen: DateTime.now(),
      hasServiceUuid: hasOurService,
    );
  }
  
  bool get isBikeTracker => name.startsWith('BikeTrk_') || hasServiceUuid;
  
  String get displayName => isBikeTracker ? name : '$name (Not a Bike Tracker)';
  
  int get signalStrength {
    if (rssi >= -50) return 4;
    if (rssi >= -60) return 3;
    if (rssi >= -70) return 2;
    if (rssi >= -80) return 1;
    return 0;
  }
}