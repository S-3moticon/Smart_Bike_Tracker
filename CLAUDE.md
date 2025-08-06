# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Smart Bike Tracker is a Flutter mobile application for a bike anti-theft tracking system. The app connects to an ESP32 MCU via Bluetooth Low Energy to monitor bike location and provide real-time tracking capabilities.

## Essential Commands

### Development
```bash
flutter run                    # Run app in debug mode
flutter run --release         # Run in release mode
```

### Testing & Quality
```bash
flutter test                  # Run all tests
flutter analyze              # Run static analysis
```

### Building
```bash
flutter build apk             # Build Android APK
flutter build ios            # Build iOS app (macOS only)
```

### Dependencies
```bash
flutter pub get              # Install dependencies
flutter pub upgrade          # Update dependencies
```

## Architecture & Structure

### Core App Requirements
The app integrates with hardware components (ESP32, GPS module, sensors) via BLE and must:
- Operate offline without internet connectivity
- Display GPS location on Google Maps
- Allow phone number configuration for SMS alerts
- Manage location update intervals

### Key Implementation Guidelines

1. **Bluetooth Integration**: The app must establish BLE connection with ESP32 MCU for all device communication
2. **Location Services**: 
   - When Bluetooth connection is TRUE: Use phone's GPS (request location permissions)
   - When Bluetooth connection is FALSE: GPS data comes from SIM7070G module via the ESP32
3. **UI Design**: Use matte color palette with theme-based styling (avoid hardcoded colors), implement small composable widgets with flex layouts
4. **Logging**: Use `dart:developer` log instead of print statements for debugging

### Project Status
Currently initialized with Flutter template. Core bike tracking functionality needs to be implemented including:
- BLE communication service
- Location tracking UI with dual GPS source management
- Google Maps integration
- SMS alert configuration
- Location permission handling

### Hardware Context
The app interfaces with:
- ESP32 MCU (main controller)
- SIM7070G (GPS/GNSS/SMS module - used when BLE disconnected)
- LSM6DSL (motion sensor)
- IR sensor (human verification)

Detailed requirements are in `/req/plan-requirement.md`.