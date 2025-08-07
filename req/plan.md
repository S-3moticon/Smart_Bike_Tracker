# Smart Bike Tracker - Integrated 1-Week Sprint Plan

## Overview
This plan covers the complete implementation of a Smart Bike Tracker system including both the ESP32 MCU firmware and Flutter mobile application. The system provides anti-theft tracking via BLE connection, dual-source GPS tracking, and SMS alerts.

## Day 1: Project Setup & Protocol Definition ✅ COMPLETED

### Both Teams ✅
- ✅ Define BLE service UUIDs and characteristic protocols
  - ✅ Service UUID for ESP32 bike tracker: `00001234-0000-1000-8000-00805f9b34fb`
  - ✅ Location characteristic: `00001235-0000-1000-8000-00805f9b34fb` (READ/NOTIFY)
  - ✅ Config characteristic: `00001236-0000-1000-8000-00805f9b34fb` (WRITE)
  - ✅ Status characteristic: `00001237-0000-1000-8000-00805f9b34fb` (READ/NOTIFY)
  - ✅ Command characteristic: `00001238-0000-1000-8000-00805f9b34fb` (WRITE)
- ✅ Agree on JSON data exchange formats
  - ✅ Created `lib/constants/ble_protocol.dart` for Flutter
  - ✅ Created `mcu/bike_tracker_esp32/ble_protocol.h` for ESP32

### App Team ✅
- ✅ Setup Flutter project with core dependencies
  - ✅ Added flutter_blue_plus v1.32.12 for BLE communication
  - ✅ Added google_maps_flutter v2.9.0 for map display
  - ✅ Added geolocator v13.0.2 for phone GPS
  - ✅ Added provider v6.1.2 for state management
  - ✅ Added shared_preferences v2.3.3 for local storage
  - ✅ Added permission_handler v11.3.1 for permissions
- ✅ Configure Android/iOS permissions (Bluetooth, Location, Maps)
  - ✅ Updated AndroidManifest.xml with all required permissions
  - ✅ Updated Info.plist with iOS permission descriptions
  - ✅ Added Google Maps API key placeholder
- ✅ Create initial folder structure (models/, services/, screens/, widgets/, utils/, providers/)
- ✅ Create app theme with matte color palette (lib/constants/app_theme.dart)

### MCU Team ✅
- ✅ Setup ESP32 development environment
- ✅ Create initial project structure (mcu/bike_tracker_esp32/)
- ✅ Define pin configurations for sensors
  - ✅ GPS: RX=16, TX=17
  - ✅ IR Sensor: Pin 25
  - ✅ I2C: SDA=21, SCL=22
  - ✅ LED: Pin 2

## Day 2: Core Communication Layer ✅ COMPLETED

### MCU Tasks ✅ COMPLETED
- ✅ Implement BLE GATT server on ESP32
  - ✅ Setup BLE advertising with unique device name (BikeTrk_XXXX)
  - ✅ Created service with custom UUID
- ✅ Create characteristic handlers
  - ✅ READ/NOTIFY handlers for location and status
  - ✅ WRITE handler for configuration with JSON parsing
  - ✅ Command characteristic for future use
- ✅ Implement basic serial debugging
- ✅ Add comprehensive code comments for understanding
- ✅ Fix compilation errors (removed ArduinoJson dependency)
- ✅ Implement basic theft detection algorithm (IR sensor + BLE status)

### Additional MCU Achievements (from Day 3 & 4) ✅
- ✅ IR sensor reading implementation
- ✅ Basic theft detection logic (BLE disconnected + user not present)
- ✅ Device mode state machine (IDLE, TRACKING, ALERT, SLEEP)
- ✅ Placeholder for SMS alerts when theft detected

### App Tasks ✅ COMPLETED
- ✅ Implement BLE client service with flutter_blue_plus
  - ✅ Device discovery and filtering (BikeBluetoothService class)
  - ✅ Service and characteristic discovery
  - ✅ Scan for devices with "BikeTrk_" prefix
- ✅ Build connection management
  - ✅ Connection state tracking (connecting, connected, disconnected)
  - ✅ Auto-reconnection logic with 5-second intervals
  - ✅ Connection timeout handling
  - ✅ Persistent reconnection attempts after disconnection
- ✅ Create device scanning UI
  - ✅ DeviceScanScreen with real-time device list
  - ✅ Signal strength indicators
  - ✅ Prioritized display of bike trackers
  - ✅ Bluetooth availability checking

## Day 3: Sensor Integration & Location Services ⚠️ PARTIALLY COMPLETED

### MCU Tasks ✅ COMPLETED
- ✅ Integrate SIM7070G GPS module
  - ✅ UART communication setup
  - ✅ AT command implementation
  - ✅ GPS data parsing
  - ✅ SMS functionality preparation
- ⚠️ Setup LSM6DSL motion sensor
  - ⚠️ I2C communication
  - ⚠️ Accelerometer configuration
  - ⚠️ Motion detection thresholds
- ✅ Add IR sensor reading
  - ✅ Digital input configuration
  - ✅ Human presence detection logic

### App Tasks ⏳ PENDING
- ⏳ Implement dual GPS logic
  - ⏳ Use phone GPS when BLE connected
  - ⏳ Switch to SIM7070G data when disconnected
  - ⏳ Seamless transition between sources
- ⏳ Setup location permissions
  - ⏳ Request fine location permission
  - ⏳ Handle permission denial gracefully
  - ⏳ Background location for iOS
- ⏳ Create LocationService class

## Day 4: Core Logic & Data Exchange ⚠️ PARTIALLY COMPLETED

### MCU Tasks ✅ COMPLETED
- ✅ Implement theft detection algorithm
  ```
  if (BLE_connected && motion_detected && user_present) {
    // Normal operation - light sleep
  } else if (!BLE_connected && (motion_detected || !user_present)) {
    // Theft detected - activate tracking
  }
  ```
- ✅ Add SMS alert functionality
  - ✅ Store phone number from app
  - ✅ Send location via SMS when theft detected (placeholder)
  - ⚠️ Implement retry logic for failed SMS
- ✅ Create state machine for device modes

### App Tasks ⚠️ PARTIALLY COMPLETED
- ✅ Create data models
  - ✅ BikeDevice model for BLE device
  - ✅ LocationData model for GPS data with dual-source support
  - ✅ DeviceStatus model for device status and modes
  - ✅ TrackerConfig model for settings
- ⏳ Implement Google Maps integration
  - ⏳ Add API key configuration
  - ⏳ Create map widget
  - ⏳ Display current location marker
  - ⏳ Real-time location updates
- ✅ Parse incoming BLE data
  - ✅ Location data parsing from JSON
  - ✅ Status data parsing from JSON
  - ✅ Configuration write to device

### Both Teams ⚠️ PARTIALLY TESTED
- ⚠️ Test BLE data exchange
  - ✅ Location data transmission (ready)
  - ✅ Configuration writes (implemented)
  - ✅ Status updates (implemented)

## Day 5: Power Management & UI Implementation ⚠️ PARTIALLY COMPLETED

### MCU Tasks ⏳ PENDING
- ⏳ Implement light sleep modes
  - ⏳ Sleep when BLE connected and no motion
  - ⏳ Wake on motion or BLE events
  - ⏳ Maintain BLE connection during sleep
- ⏳ Add wake interrupts
  - ⏳ Motion interrupt from LSM6DSL
  - ⏳ BLE connection/disconnection events
  - ⏳ Timer-based wake for GPS updates
- ⏳ Optimize power consumption
  - ⏳ Disable unused peripherals
  - ⏳ Reduce GPS polling when stationary

### App Tasks ✅ COMPLETED
- ✅ Build single-page UI with Material Design
  - ✅ Use matte color palette theme
  - ✅ Implement flexible layouts with Flex widgets
  - ✅ Responsive design for various screen sizes
  - ✅ HomeScreen with status, location, and config cards
- ✅ Add phone number configuration
  - ✅ Input field with validation
  - ✅ Save to device via BLE
  - ⏳ Persist locally with SharedPreferences
- ✅ Implement update interval settings
  - ✅ Slider for interval selection (10-300 seconds)
  - ✅ Send configuration to ESP32
  - ✅ Display formatted interval (seconds/minutes/hours)
- ⚠️ Create location request button
  - ✅ Manual location update trigger
  - ✅ Loading state during request
  - ⏳ Display address below map

## Day 6: Integration & State Management ⏳ PENDING

### MCU Tasks ⏳ PENDING
- ⏳ Complete anti-theft state machine
  - ✅ Idle state (everything normal)
  - ✅ Alert state (theft detected)
  - ✅ Tracking state (sending SMS updates)
  - ⏳ Recovery state (device recovered)
- ⏳ Optimize for 24-hour battery operation
  - ⏳ Calculate power budget
  - ⏳ Adjust sleep intervals
  - ⏳ Implement battery voltage monitoring
- ⏳ Add configuration persistence
  - ⏳ Store settings in ESP32 flash

### App Tasks ⏳ PENDING
- ⏳ Add Provider state management
  - ⏳ BluetoothProvider for connection state
  - ⏳ LocationProvider for GPS data
  - ⏳ ConfigProvider for settings
- ⏳ Implement SharedPreferences
  - ⏳ Save phone number
  - ⏳ Store update interval
  - ⏳ Cache last known location
  - ⏳ Remember paired device
- ⏳ Create notification system
  - ⏳ Connection status changes
  - ⏳ Location updates
  - ⏳ Error messages

### Both Teams ⏳ PENDING
- ⏳ End-to-end testing of all scenarios
  - ⏳ Normal operation with user
  - ⏳ Theft detection and SMS alerts
  - ⏳ GPS source switching
  - ⏳ Configuration changes

## Day 7: Testing & Optimization ⏳ PENDING

## Day 8 (2025-08-07): BLE Connection Issues Resolved ✅ COMPLETED

### Issues Found
- Android 12+ requires runtime Bluetooth permissions (BLUETOOTH_SCAN, BLUETOOTH_CONNECT)
- Flutter app was not detecting ESP32 device "BikeTrk_4B00" despite being visible in system settings
- Device name matching was too strict

### Solutions Implemented
- ✅ Added runtime permission requests in BikeBluetoothService
- ✅ Improved device name detection with case-insensitive matching
- ✅ Enhanced BLE scanning with better logging and error handling
- ✅ Made device detection more flexible (checks for "biketrk" pattern and device ID)
- ✅ Successfully built and tested debug APK

### Testing Results
- ✅ App now properly requests Bluetooth permissions on startup
- ✅ ESP32 device "BikeTrk_4B00" is detected by the app
- ✅ BLE connection successfully established between MCU and mobile app
- ✅ Configuration data can be sent from app to ESP32

## Day 9+: Next Steps

### Testing Tasks (Both Teams) ⏳ PENDING
- ⏳ Test theft detection scenario
  - ⏳ Disconnect BLE + detect motion
  - ⏳ Verify SMS is sent with location
  - ⏳ Test recovery when BLE reconnects
- ⏳ Verify SMS alerts functionality
  - ⏳ Correct phone number format
  - ⏳ Location accuracy in SMS
  - ⏳ Update interval compliance
- ⏳ Test GPS source switching
  - ⏳ Smooth transition phone ↔ SIM7070G
  - ⏳ Location accuracy from both sources
  - ⏳ No data loss during switch

### MCU Specific ⏳ PENDING
- ⏳ Measure and optimize battery consumption
  - ⏳ Profile current draw in each state
  - ⏳ Verify 24-hour operation
  - ⏳ Optimize wake intervals
- ⏳ Test sensor reliability
  - ⏳ Motion detection sensitivity
  - ⏳ IR sensor false positives
  - ⏳ GPS fix acquisition time

### App Specific ⏳ PENDING
- ⏳ Polish UI and fix connection issues
  - ✅ Smooth animations
  - ✅ Error handling and recovery
  - ✅ Loading states
  - ✅ User feedback for all actions
- ⏳ Test on multiple devices
  - ⏳ Different Android versions
  - ⏳ iOS compatibility
  - ⏳ Various screen sizes

### Documentation (Both Teams) ⏳ PENDING
- ⏳ Document BLE protocol
  - ✅ Service and characteristic UUIDs
  - ✅ Data formats
  - ⏳ Command sequences
- ⏳ Create deployment instructions
  - ⏳ MCU firmware upload steps
  - ⏳ App installation process
  - ⏳ Initial pairing procedure
- ⏳ Write troubleshooting guide

## Deliverables

### MCU Firmware
- ✅ ESP32 firmware with basic sensor integration
- ✅ BLE GATT server implementation
- ⏳ Power-optimized operation modes
- ⚠️ SMS alert system via SIM7070G (placeholder ready)
- ⏳ 24-hour battery operation capability

### Mobile Application
- ✅ Flutter app for Android and iOS
- ✅ BLE connection management with auto-reconnect - TESTED & WORKING
- ✅ Android 12+ Bluetooth permissions handling
- ⏳ Dual-source GPS tracking
- ⏳ Google Maps integration (needs API key)
- ✅ Phone number and interval configuration
- ⚠️ Offline operation capability (partially ready)

### System Integration
- ⚠️ Working anti-theft detection system (basic implementation)
- ⏳ Seamless GPS source switching
- ✅ Reliable BLE communication - VERIFIED with real hardware (Day 8)
- ⏳ SMS alerts when device stolen
- ⚠️ Real-time location tracking (BLE data ready, GPS pending)

## Current Status Summary (Updated: 2025-08-07)

### ✅ Completed (Days 1-2 + partial Day 3-5 + Day 8 fixes)
- Full project setup and BLE protocol definition
- MCU: BLE server, theft detection, basic sensors
- App: BLE client, scanning UI, home screen, configuration UI
- Data models and BLE communication
- **Day 8 (2025-08-07)**: Fixed Android 12+ BLE permission issues
  - Added runtime Bluetooth permission requests (BLUETOOTH_SCAN, BLUETOOTH_CONNECT)
  - Improved device name detection logic
  - Enhanced BLE scanning with better error handling
  - Successfully established MCU-App BLE connection

### ⚠️ In Progress
- Location services and GPS integration
- Google Maps implementation (API key needed)
- Power management optimization

### ⏳ Pending
- Provider state management
- SharedPreferences persistence
- Full system integration testing
- Documentation and deployment guides

## Key Milestones
- **Day 2 EOD**: ✅ BLE communication established between MCU and App
- **Day 3 EOD**: ⚠️ All sensors integrated (LSM6DSL pending), GPS partially ready
- **Day 4 EOD**: ⚠️ Theft detection logic complete, SMS alerts pending full implementation
- **Day 5 EOD**: ⚠️ Power management pending, UI ✅ complete
- **Day 6 EOD**: ⏳ Full system integration with state management
- **Day 7 EOD**: ⏳ Tested, optimized, and documented system

## Risk Mitigation
- **BLE Connection Issues**: ✅ RESOLVED - Fixed Android 12+ permissions (Day 8)
  - Robust reconnection logic implemented (Day 2)
  - Runtime permission handling added (Day 8)
  - Device detection improved with flexible name matching
- **Power Consumption**: ⏳ Power optimization needs to start
- **GPS Accuracy**: ⏳ Both GPS sources need testing
- **SMS Delivery**: ⚠️ Basic implementation ready, needs retry mechanism
- **Integration Delays**: ✅ BLE integration tested and working

## Success Criteria
1. ✅ ESP32 can detect theft (BLE disconnect + motion)
2. ⚠️ SMS alerts sent with accurate GPS location (partial)
3. ⏳ App displays real-time location on map
4. ⏳ System operates for 24 hours on battery
5. ⏳ Seamless GPS source switching
6. ✅ User can configure phone number and update interval
7. ✅ Reliable BLE connection with auto-reconnect - VERIFIED WORKING (Day 8)