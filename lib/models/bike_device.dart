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
    // Second try: Platform-specific name (might have cached name from system)
    else if (result.device.platformName.isNotEmpty) {
      deviceName = result.device.platformName;
    }
    // Third try: Device's advertised name
    else if (result.device.advName.isNotEmpty) {
      deviceName = result.device.advName;
    }
    // Fallback: Check if MAC address matches BikeTrk pattern
    else {
      String deviceId = result.device.remoteId.toString();
      // For unnamed devices, show partial MAC to help identify
      deviceName = 'Unknown (${deviceId.substring(deviceId.length > 8 ? deviceId.length - 8 : 0)})';
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
  
  bool get isBikeTracker {
    // Check multiple conditions to identify our bike tracker
    return name.toLowerCase().contains('biketrk') || 
           name.startsWith('BikeTrk_') || 
           hasServiceUuid ||
           // Also check if the device ID contains known patterns
           (name.contains('4B00') || id.contains('4B00'));  // Your device shows 4B00
  }
  
  String get displayName => isBikeTracker ? name : '$name (Not a Bike Tracker)';
  
  int get signalStrength {
    if (rssi >= -50) return 4;
    if (rssi >= -60) return 3;
    if (rssi >= -70) return 2;
    if (rssi >= -80) return 1;
    return 0;
  }
}