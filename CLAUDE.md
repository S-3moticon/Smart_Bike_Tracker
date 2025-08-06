# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Smart Bike Tracker is a Flutter mobile application for a bike anti-theft tracking system. The app connects to an ESP32 MCU via Bluetooth Low Energy to monitor bike location and provide real-time tracking capabilities.

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
- Display GPS location on Google Maps
- Allow phone number configuration for SMS alerts
- Manage location update intervals

### Key Implementation Guidelines

1. **Bluetooth Integration**: 
   - Establish BLE connection with ESP32 MCU for all device communication
   - Handle connection states (connecting, connected, disconnected)
   - Implement reconnection logic for dropped connections

2. **Location Services**: 
   - When Bluetooth connection is TRUE: Use phone's GPS (request location permissions)
   - When Bluetooth connection is FALSE: GPS data comes from SIM7070G module via the ESP32
   - Implement seamless switching between GPS sources

3. **UI Design**: 
   - Use matte color palette with theme-based styling (avoid hardcoded colors)
   - Implement small composable widgets with flex layouts
   - Follow Material Design guidelines for Android, Cupertino for iOS

4. **Logging**: 
   - Use `dart:developer` log instead of print statements for debugging
   - Implement different log levels (debug, info, warning, error)

## Required Dependencies

Add these packages to pubspec.yaml:
```yaml
dependencies:
  # BLE Communication
  flutter_blue_plus: ^latest  # or flutter_bluetooth_serial
  
  # Location Services
  geolocator: ^latest
  permission_handler: ^latest
  
  # Maps Integration
  google_maps_flutter: ^latest
  
  # State Management (choose one)
  provider: ^latest  # or riverpod, bloc, getx
  
  # Local Storage
  shared_preferences: ^latest
  
  # Utilities
  url_launcher: ^latest  # For SMS functionality
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

### Google Maps API Setup
1. Obtain API key from Google Cloud Console
2. Add to Android: `android/app/src/main/AndroidManifest.xml`
3. Add to iOS: `ios/Runner/AppDelegate.swift`
4. Store API key securely (use environment variables or secure storage)

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
// Expected GPS data format from ESP32
{
  "lat": double,
  "lng": double,
  "timestamp": int,
  "speed": double,
  "satellites": int,
  "battery": int
}

// Configuration data to ESP32
{
  "phone_number": String,
  "update_interval": int, // seconds
  "alert_enabled": bool
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
- **ESP32 MCU** (main controller) - Handles BLE communication
- **SIM7070G** (GPS/GNSS/SMS module) - Provides location when phone disconnected
- **LSM6DSL** (motion sensor) - Detects movement/theft
- **IR sensor** (human verification) - Confirms rider presence

## Project Status

Currently initialized with Flutter template. Core bike tracking functionality needs to be implemented including:
- BLE communication service with ESP32
- Dual-source location tracking (phone GPS when connected, SIM7070G when disconnected)
- Google Maps integration for location display
- SMS alert configuration interface
- Location permission handling
- Offline operation capability

Detailed requirements are in `/req/plan-requirement.md`.