# Smart Bike Tracker - Implementation Plan

## Project Overview
Smart Bike Tracker is a comprehensive anti-theft system combining ESP32 hardware with a Flutter mobile app. The system detects theft through motion sensors and IR presence detection, automatically sending SMS alerts with GPS coordinates when unauthorized movement is detected. It features dual-source GPS tracking (phone when BLE connected, SIM7070G when disconnected) and 24-hour battery operation.

**Core Requirements Source:** `/req/requirement.md`

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
  - ⚠️ Wake interrupt configuration (only when IR detects no user)
- ✅ Add IR sensor reading (HW-201)
  - ✅ Digital input configuration
  - ✅ Human presence detection logic

### App Tasks ⏳ PENDING
- ⏳ Implement dual GPS logic per requirements
  - ⏳ Use phone GPS when BLE connected (MCU sleeps)
  - ⏳ Display SIM7070G data when BLE disconnected
  - ⏳ Show GPS source indicator (Phone/SIM7070G)
  - ⏳ Display coordinates and last update time
- ⏳ Setup location permissions
  - ⏳ Request fine location permission
  - ⏳ Handle permission denial gracefully
  - ⏳ Background location for continuous tracking
- ⏳ Create LocationService class with dual-source support

## Day 4: Core Logic & Data Exchange ⚠️ PARTIALLY COMPLETED

### MCU Tasks ✅ COMPLETED
- ✅ Implement theft detection algorithm per requirements
  ```
  // Normal Operation
  if (BLE_connected && motion_detected && user_present) {
    // ESP32 enters light sleep, app uses phone GPS
  }
  
  // Anti-Theft Function
  if (!BLE_connected && motion_detected && user_present) {
    // Moving without BLE - send SMS alerts
  }
  
  // Shock Detection
  if (!BLE_connected && motion_detected && !user_present) {
    // Movement detected without user - high alert
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
- ✅ Implement Offline Map Solution
  - ✅ Custom canvas-based map widget
  - ✅ Display current location marker
  - ✅ Real-time location updates
  - ✅ Map-like visualization with street grids
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
- ⏳ Implement power management per requirements
  - ⏳ Light sleep when BLE connected (phone GPS active)
  - ⏳ Wake every 10 min (configurable) for SMS updates
  - ⏳ Maintain BLE connection during sleep
  - ⏳ 24-hour operation with 14650 Li-ion battery
- ⏳ Add wake interrupts
  - ⏳ LSM6DSL motion interrupt (only when IR shows no user)
  - ⏳ BLE connection/disconnection events
  - ⏳ Timer-based wake for GPS/SMS updates
- ⏳ Optimize for battery life
  - ⏳ Disable SIM7070G when BLE connected
  - ⏳ Store GPS data internally when not sending

### App Tasks ✅ COMPLETED
- ✅ Build single-page UI per requirements
  - ✅ Use matte color palette theme (no hardcoded colors)
  - ✅ Implement flexible layouts with Flex widgets
  - ✅ Responsive design for various screen sizes
  - ✅ Single page with map, controls, and status display
- ✅ Add configuration features
  - ✅ Phone number input for SMS alerts
  - ✅ Update interval slider (default: 10 minutes)
  - ✅ Save configuration to ESP32 via BLE
  - ⏳ Persist settings with SharedPreferences
- ✅ Implement location features
  - ✅ Custom offline map canvas (Tangram ES style)
  - ✅ Current location display with marker
  - ✅ Manual location update button
  - ⏳ Location history log below map
  - ⏳ Display coordinates, source, and timestamp

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

### MCU Firmware (ESP32)
- ✅ BLE GATT server with custom protocol
- ✅ Theft detection algorithm implementation
- ✅ IR sensor integration (HW-201) for user presence
- ⚠️ SIM7070G GPS/SMS module (basic integration)
- ⏳ LSM6DSL accelerometer integration
- ⏳ Power optimization for 24-hour operation
- ⏳ Light sleep mode when BLE connected
- ⏳ SMS alerts with GPS coordinates

### Mobile Application (Flutter)
- ✅ Single-page app with matte theme
- ✅ BLE scanning and connection management
- ✅ Android 12+ permission handling
- ✅ Custom offline map canvas
- ✅ Phone number configuration for SMS
- ✅ Update interval settings (10 min default)
- ⏳ Dual-source GPS display (Phone/SIM7070G)
- ⏳ Location history log
- ⏳ Coordinates and timestamp display
- ⏳ SharedPreferences for settings persistence

### System Integration
- ✅ BLE communication protocol established
- ✅ Basic theft detection logic
- ⏳ Seamless GPS source switching
- ⏳ SMS alerts when theft detected
- ⏳ 24-hour battery operation
- ⏳ Complete sensor integration

## Current Status Summary (Updated: 2025-08-13)

### ✅ Completed Components

#### MCU (ESP32) - mcu/bike_tracker_esp32/
- BLE GATT server with custom protocol
- Basic theft detection algorithm
- IR sensor integration for user presence
- Device state machine (IDLE, TRACKING, ALERT, SLEEP)
- SIM7070G GPS module basic integration
- Configuration reception from app

#### Mobile App (Flutter) - lib/
- BLE scanning and connection management
- Android 12+ runtime permissions
- Custom offline map canvas widget
- Phone number configuration UI
- SMS interval settings (10-300 seconds)
- Single-page responsive design
- Matte color theme implementation
- Auto-reconnection logic

### ⚠️ In Progress
- LSM6DSL accelerometer integration (I2C setup needed)
- SMS alert implementation with retry logic
- Dual-source GPS tracking in app

### ⏳ Pending Implementation

#### MCU Tasks
- Complete LSM6DSL motion sensor setup
- Implement wake interrupts (motion + BLE events)
- Add power management and sleep modes
- SMS sending with GPS coordinates
- Battery level monitoring
- Configuration persistence in flash

#### App Tasks
- Implement phone GPS tracking when BLE connected
- Display GPS source indicator (Phone/SIM7070G)
- Add location history log below map
- Show coordinates and timestamp
- SharedPreferences for settings persistence
- Provider state management integration

#### System Integration
- Test complete theft detection scenarios
- Verify GPS source switching
- Validate SMS alert delivery
- Ensure 24-hour battery operation
- Full end-to-end testing

## Implementation Priorities

### High Priority (Core Functionality)
1. ⏳ Complete LSM6DSL accelerometer integration
2. ⏳ Implement dual-source GPS tracking in app
3. ⏳ Complete SMS alert system with SIM7070G
4. ⏳ Add location history logging in app
5. ⏳ Implement power management for 24-hour operation

### Medium Priority (User Experience)
1. ⏳ Add SharedPreferences for settings persistence
2. ⏳ Display GPS source indicator in UI
3. ⏳ Show coordinates and timestamp in app
4. ⏳ Improve offline map visualization
5. ⏳ Add location history scrollable list

### Low Priority (Optimization)
1. ⏳ Fine-tune motion detection thresholds
2. ⏳ Optimize BLE connection stability
3. ⏳ Improve battery consumption
4. ⏳ Add error recovery mechanisms
5. ⏳ Create comprehensive documentation

## Risk Mitigation
- **BLE Connection Issues**: ✅ RESOLVED - Fixed Android 12+ permissions (Day 8)
  - Robust reconnection logic implemented (Day 2)
  - Runtime permission handling added (Day 8)
  - Device detection improved with flexible name matching
- **Power Consumption**: ⏳ Power optimization needs to start
- **GPS Accuracy**: ⏳ Both GPS sources need testing
- **SMS Delivery**: ⚠️ Basic implementation ready, needs retry mechanism
- **Integration Delays**: ✅ BLE integration tested and working

## Success Criteria (Per Requirements)
1. ✅ Theft Detection: ESP32 detects [BLE=False | Motion=True | User=True/False]
2. ⚠️ SMS Alerts: Send GPS coordinates to configured number (partial)
3. ⏳ Dual GPS Sources: Phone GPS when connected, SIM7070G when disconnected
4. ⏳ Battery Life: 24-hour operation with 14650 Li-ion battery
5. ⏳ Power Management: MCU sleeps when BLE connected
6. ✅ Configuration: Phone number and SMS interval settings via app
7. ✅ BLE Communication: Reliable connection with auto-reconnect
8. ⏳ Location Display: Offline map with coordinates, source, and timestamp
9. ⏳ Location History: Scrollable log of previous locations
10. ⏳ Human Verification: IR sensor distinguishes authorized use from theft