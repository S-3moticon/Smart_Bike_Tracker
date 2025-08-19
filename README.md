# Smart Bike Tracker

An advanced anti-theft system for bicycles combining ESP32 hardware with a Flutter mobile application. The system detects theft through motion sensors and automatically sends SMS alerts with GPS coordinates when unauthorized movement is detected.

## Key Features

- **Theft Detection**: Multi-sensor approach using motion detection (LSM6DSL) and IR presence sensing (HW-201)
- **Dual GPS Tracking**: Phone GPS when connected via Bluetooth, SIM7070G module when disconnected
- **SMS Alerts**: Automatic SMS notifications with GPS coordinates when theft is detected
- **Real-time Tracking**: Live location updates displayed on interactive maps
- **Smart Power Management**: 24-hour battery operation with intelligent sleep modes
- **Auto-reconnection**: Seamless Bluetooth reconnection with saved device memory

## System Requirements

### Hardware
- ESP32 Development Board
- SIM7070G GPS/GSM Module
- LSM6DSL 6-axis IMU (Accelerometer/Gyroscope)
- HW-201 IR Sensor
- 14650 Li-ion Battery
- SIM card with SMS capability

### Software
- Flutter SDK 3.0+
- Android Studio / VS Code
- Arduino IDE or PlatformIO
- Android device (Android 6.0+)

## Quick Start

### MCU Setup (ESP32)

1. **Hardware Connections**:
   ```
   SIM7070G: RX=GPIO16, TX=GPIO17
   LSM6DSL:  SDA=GPIO21, SCL=GPIO22, INT1=GPIO4, INT2=GPIO2
   IR Sensor: GPIO13
   ```

2. **Upload Firmware**:
   - Open `mcu/bike_tracker_esp32/bike_tracker_esp32.ino` in Arduino IDE
   - Install required libraries (Wire, BLEDevice)
   - Select ESP32 board and correct port
   - Upload the sketch

3. **Configuration**:
   - Device will advertise as `BikeTrk_XXXX`
   - Default SMS interval: 10 minutes
   - Motion detection threshold: 0.5g

### Mobile App Setup (Flutter)

1. **Install Dependencies**:
   ```bash
   cd Smart_Bike_Tracker
   flutter pub get
   ```

2. **Configure Permissions**:
   - Android: Permissions are pre-configured in AndroidManifest.xml
   - iOS: Update Info.plist with your app details

3. **Run the App**:
   ```bash
   flutter run
   ```

## App Usage

1. **Initial Connection**:
   - Enable Bluetooth on your phone
   - Open the app and tap "Scan for Devices"
   - Select your `BikeTrk_XXXX` device
   - Device will auto-connect on subsequent app launches

2. **Configuration**:
   - Tap settings icon to configure:
     - Phone number for SMS alerts
     - SMS update interval (1-60 minutes)
     - Enable/disable alerts

3. **Monitoring**:
   - **Map Tab**: View real-time location on interactive map
   - **List Tab**: See location history with timestamps
   - **MCU Tab**: View GPS history from the tracker

## Power Management

- **Connected Mode**: MCU sleeps, minimal power consumption
- **Disconnected Mode**: 
  - First disconnect: Light sleep with motion wake
  - After first SMS: Deep sleep with timer wake

## Communication Protocol

### BLE Services
- **Service UUID**: `00001234-0000-1000-8000-00805f9b34fb`
- **Characteristics**:
  - Config: Write phone number and settings
  - Status: Read device status and GPS data
  - History: Read GPS history points

### Data Formats
All data exchanged in JSON format:
```json
{
  "lat": "12.345678",
  "lon": "98.765432",
  "timestamp": 1234567890,
  "source": 1  // 0=Phone, 1=SIM7070G
}
```

## Troubleshooting

### Common Issues

1. **Device Not Found**:
   - Ensure ESP32 is powered on
   - Check if device name starts with "BikeTrk"
   - Reset ESP32 if needed

2. **SMS Not Sending**:
   - Verify SIM card has credit
   - Check network registration (LED indicators)
   - Ensure correct phone number format

3. **GPS Not Working**:
   - Allow 30-60 seconds for initial fix
   - Ensure clear sky view
   - Check SIM7070G antenna connection

4. **App Permissions**:
   - Grant all requested permissions (Bluetooth, Location)
   - Enable location services on phone

## Project Structure

```
Smart_Bike_Tracker/
├── mcu/
│   └── bike_tracker_esp32/    # ESP32 firmware
│       ├── bike_tracker_esp32.ino
│       ├── ble_protocol.h
│       ├── sim7070g.cpp/h
│       ├── gps_handler.cpp/h
│       ├── sms_handler.cpp/h
│       └── lsm6dsl_handler.cpp/h
├── lib/
│   ├── models/                # Data models
│   ├── services/              # Business logic
│   ├── screens/               # UI screens
│   ├── widgets/               # Reusable widgets
│   └── constants/             # App constants
├── android/                   # Android specific files
├── ios/                       # iOS specific files
└── pubspec.yaml              # Flutter dependencies
```