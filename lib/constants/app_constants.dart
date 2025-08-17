/// Application-wide constants
class AppConstants {
  // Prevent instantiation
  AppConstants._();
  
  // BLE Related
  static const String bleDevicePrefix = 'BikeTrk_';
  static const int bleConnectionTimeout = 10; // seconds
  static const int bleScanTimeout = 10; // seconds
  static const int bleReconnectionInterval = 5; // seconds
  static const int bleMtuSize = 185; // bytes
  
  // BLE UUIDs (from MCU ble_protocol.h)
  static const String serviceUuid = '00001234-0000-1000-8000-00805f9b34fb';
  static const String locationCharUuid = '00001235-0000-1000-8000-00805f9b34fb';
  static const String configCharUuid = '00001236-0000-1000-8000-00805f9b34fb';
  static const String statusCharUuid = '00001237-0000-1000-8000-00805f9b34fb';
  static const String commandCharUuid = '00001238-0000-1000-8000-00805f9b34fb';
  static const String historyCharUuid = '00001239-0000-1000-8000-00805f9b34fb';
  
  // Location Related
  static const int maxLocationHistory = 500;
  static const int locationUpdateInterval = 5; // seconds
  static const double defaultMapZoom = 15.0;
  static const double minMapZoom = 3.0;
  static const double maxMapZoom = 18.0;
  
  // SMS Configuration
  static const int defaultSmsInterval = 300; // seconds (5 minutes)
  static const int minSmsInterval = 10; // seconds
  static const int maxSmsInterval = 3600; // seconds (1 hour)
  static const List<int> smsIntervalPresets = [10, 30, 60, 120, 300, 600, 900, 1800, 3600];
  
  // Map Download
  static const int defaultDownloadRadius = 5; // km
  static const int maxDownloadRadius = 50; // km
  static const int minZoomLevel = 10;
  static const int maxZoomLevel = 16;
  
  // UI Related
  static const Duration snackbarDuration = Duration(seconds: 2);
  static const Duration snackbarErrorDuration = Duration(seconds: 3);
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration connectionStabilizationDelay = Duration(seconds: 1);
  
  // Storage Keys
  static const String keyLastDevice = 'last_connected_device_id';
  static const String keyLastDeviceName = 'last_connected_device_name';
  static const String keyAutoConnect = 'auto_connect_enabled';
  static const String keyConfigPhone = 'config_phone';
  static const String keyConfigInterval = 'config_interval';
  static const String keyConfigAlerts = 'config_alerts';
  static const String keyLocationHistory = 'location_history';
  static const String keyOfflineMapTiles = 'offline_map_tiles';
}