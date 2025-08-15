# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Smart Bike Tracker is a comprehensive bike anti-theft system combining an ESP32-based hardware tracker with a Flutter mobile application. The system provides real-time location tracking, sensor-based theft detection, and automated SMS alerts. The tracker uses motion sensors and infrared detection to identify potential theft scenarios, switching between phone GPS (when connected via BLE) and onboard SIM7070G GPS module (when disconnected) for continuous tracking.

**Project Documentation:**
- Requirements: `/req/requirement.md`
- Implementation Plan: `/PLAN.md`

## Essential Commands

### Development
```bash
flutter run                    # Run app in debug mode
flutter run --release         # Run in release mode
flutter devices               # List available devices
flutter clean                 # Clean build artifacts
```

### Testing & Quality
```bash
flutter test                  # Run all tests
flutter test test/widget_test.dart  # Run specific test file
flutter analyze              # Run static analysis
flutter format lib/          # Format code
```

### Building
```bash
flutter build apk             # Build Android APK
flutter build apk --split-per-abi  # Build optimized APKs per architecture
flutter build ios            # Build iOS app (macOS only)
flutter build appbundle      # Build Android App Bundle for Play Store
```

### Dependencies
```bash
flutter pub get              # Install dependencies
flutter pub upgrade          # Update dependencies
flutter pub outdated         # Check for outdated packages
```

## Architecture & Structure

### Recommended Project Structure
```
lib/
├── main.dart               # App entry point
├── models/                 # Data models
│   ├── bike_device.dart   # BLE device model
│   ├── location_data.dart # GPS location model
│   └── sensor_data.dart   # Sensor readings model
├── services/              # Business logic
│   ├── bluetooth_service.dart  # BLE communication
│   ├── location_service.dart   # GPS management
│   └── sms_service.dart       # SMS configuration
├── screens/               # UI screens
│   ├── home_screen.dart  # Main tracking screen
│   ├── settings_screen.dart  # Configuration
│   └── map_screen.dart   # Google Maps display
├── widgets/              # Reusable components
├── utils/                # Helper functions
└── constants/            # App constants, themes
```

### Core App Requirements
The app integrates with hardware components (ESP32, GPS module, sensors) via BLE and must:
- Operate offline without internet connectivity
- Display GPS location on custom map canvas (Tangram ES or similar offline solution)
- Allow phone number configuration for SMS alerts with configurable intervals
- Manage dual-source GPS tracking (phone GPS when BLE connected, SIM7070G when disconnected)
- Display location coordinates, source, and last update time
- Maintain location history log
- Support single-page design with intuitive controls

### Key Implementation Guidelines

1. **Bluetooth Integration**: 
   - Establish BLE connection with ESP32 MCU for all device communication
   - Handle connection states (connecting, connected, disconnected)
   - Implement auto-reconnection logic for dropped connections
   - Scan and filter devices with "BikeTrk_" prefix

2. **Location Services**: 
   - When BLE = TRUE: Use phone's GPS, MCU enters light sleep mode
   - When BLE = FALSE: Receive GPS data from SIM7070G module via ESP32
   - Display coordinates, source (Phone/SIM7070G), and last update timestamp
   - Implement seamless switching between GPS sources
   - Maintain location history in scrollable log

3. **Theft Detection Logic**: 
   - Normal Operation: [BLE = True | Motion = True | User = True]
   - Anti-Theft Mode: [BLE = False | Motion = True | User = True]
   - Shock Detection: [BLE = False | Motion = True | User = False]
   - MCU sends SMS alerts when theft conditions are met

4. **UI Design**: 
   - Single-page application with map, controls, and status display
   - Use matte color palette with theme-based styling (no hardcoded colors)
   - Implement small composable widgets with flex layouts
   - Custom offline map canvas for location visualization

5. **Logging**: 
   - Use `dart:developer` log instead of print statements
   - Implement different log levels (debug, info, warning, error)

## Required Dependencies

Add these packages to pubspec.yaml:
```yaml
dependencies:
  # BLE Communication
  flutter_blue_plus: ^1.32.12  # BLE device communication
  
  # Location Services
  geolocator: ^13.0.2  # Phone GPS access
  permission_handler: ^11.3.1  # Runtime permissions
  
  # Maps (Online with Caching)
  flutter_map: ^6.1.0  # Interactive tile-based map
  flutter_map_cache: ^1.5.1  # Tile caching support
  latlong2: ^0.9.1  # Coordinate handling
  dio: ^5.7.0  # HTTP client for tile fetching
  dio_cache_interceptor: ^3.5.0  # Cache management
  
  # State Management
  provider: ^6.1.2  # State management solution
  
  # Local Storage
  shared_preferences: ^2.3.3  # Persistent settings
  
  # Utilities
  url_launcher: ^latest  # For SMS functionality (optional)
```

## Platform Configuration

### Android Permissions (android/app/src/main/AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS Permissions (ios/Runner/Info.plist)
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to your bike tracker</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to track your bike</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs location access to track your bike in background</string>
```

## Hardware Integration Protocol

### BLE Communication Structure
- **Service UUID**: Define unique service UUID for ESP32
- **Characteristics**:
  - Location Data (READ/NOTIFY)
  - Phone Number Config (WRITE)
  - Update Interval (WRITE)
  - Sensor Status (READ/NOTIFY)
  - Device Status (READ)

### Data Exchange Format
```dart
// GPS data from ESP32 (when BLE disconnected)
{
  "lat": double,
  "lng": double,
  "timestamp": int,
  "speed": double,
  "satellites": int,
  "battery": int,
  "source": "SIM7070G"  // GPS source indicator
}

// Configuration data to ESP32
{
  "phone_number": String,      // For SMS alerts
  "update_interval": int,      // SMS interval in seconds (default: 600)
  "alert_enabled": bool        // Enable/disable theft alerts
}

// Device status from ESP32
{
  "mode": String,              // IDLE, TRACKING, ALERT, SLEEP
  "ble_connected": bool,
  "motion_detected": bool,
  "user_present": bool,        // IR sensor status
  "battery_level": int,        // Percentage
  "last_alert": int            // Timestamp of last SMS sent
}
```

## Testing Strategy

### Unit Tests
- BLE service connection/disconnection
- GPS data parsing
- Location source switching logic
- Data validation

### Integration Tests
- BLE communication with mock ESP32
- Location services with mock GPS
- Maps integration

### Widget Tests
- UI components rendering
- User interaction flows
- Permission request flows

## Security & Privacy

1. **BLE Security**: Implement pairing/bonding for ESP32 connection
2. **Data Storage**: Use secure storage for sensitive data (phone numbers)
3. **Location Privacy**: Only request location when necessary
4. **SMS Security**: Validate phone numbers, implement rate limiting

## Development Environment Setup

1. **Flutter Setup**: Ensure Flutter 3.32.8+ with Dart 3.8.1+
2. **Android Studio**: Install for Android development (optional but recommended)
3. **Physical Device**: Required for BLE testing (emulators don't support BLE properly)
4. **ESP32 Hardware**: Need actual ESP32 with firmware for full testing

## Build & Release

### Android Release
```bash
# Generate keystore
keytool -genkey -v -keystore upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000

# Build release APK
flutter build apk --release

# Build App Bundle for Play Store
flutter build appbundle --release
```

### iOS Release
- Configure signing in Xcode
- Update bundle identifier
- Archive and upload via Xcode

## Hardware Context

The app interfaces with:
- **ESP32 MCU** (main controller) - Handles BLE communication and coordinates all sensors
  - Enters light sleep when BLE connected to conserve battery
  - Wakes on motion detection or disconnection events
  - Manages 24-hour battery operation with 14650 Li-ion battery
  
- **SIM7070G** (GPS/GNSS/SMS module) - Provides location when phone disconnected
  - Sends SMS alerts with GPS coordinates to configured phone number
  - Updates location at configurable intervals (default: 10 minutes)
  - Stores GPS data internally when BLE connected
  
- **LSM6DSL** (6-axis IMU: accelerometer/gyroscope) - Motion detection
  - Detects irregular movements (shaking, tilting, sudden motion)
  - Wake interrupt activates only when IR sensor detects no user
  - Threshold-based detection for theft scenarios
  
- **HW-201 IR sensor** (human verification) - Presence detection
  - Distinguishes between normal riding and potential theft
  - Combined with accelerometer for accurate threat assessment
  - Enables shock detection when no user present

## Project Status

### Completed Features
- ✅ BLE communication service with ESP32 (tested with real hardware)
- ✅ Android 12+ Bluetooth permissions handling
- ✅ Device scanning and connection UI with auto-reconnect
- ✅ Auto-connect to previously paired devices on app restart
- ✅ Phone GPS tracking when BLE connected (Geolocator implementation)
- ✅ Location history logging with timestamp display
- ✅ Interactive map display with multiple tile providers (OpenStreetMap, CartoDB, Esri)
- ✅ Map tile caching for improved performance
- ✅ TabBarView for Map/List dual interface
- ✅ Location history list view with detailed coordinates
- ✅ Map state preservation using AutomaticKeepAliveClientMixin
- ✅ Optimized map loading with deferred cache initialization
- ✅ SMS alert configuration interface (phone number & interval)
- ✅ Basic theft detection algorithm in MCU
- ✅ Data models and BLE protocol implementation

### In Progress
- ⚠️ Dual-source GPS tracking (SIM7070G integration pending)
- ⚠️ Power optimization for 24-hour operation

### Pending
- ⏳ Complete SMS alert system with SIM7070G
- ⏳ LSM6DSL motion sensor integration
- ⏳ State persistence with SharedPreferences for settings
- ⏳ GPS source indicator (Phone/SIM7070G) in UI
- ⏳ Full system integration testing

Detailed requirements: `/req/requirement.md`
Implementation status: `/PLAN.md`

Do not clear task at `/PLAN.md` automatically until confirmed by user