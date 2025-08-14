I want to build a simple Bike Anti Theft tracking app connected to a Micro Controller Unit (MCU) that can be used to monitor the locations its been to.

# Smart Bike Tracker

## Project Overview
  The goal of this project is to develop a Smart Bike Tracker that provides real-time location tracking and improves bike security through sensor-based monitoring and cloud connectivity. It will use an accelerometer to detect irregular movements such as shaking, tilting, or sudden motion, which may indicate theft or tampering. An infrared sensor will help identify if a person is near the bike by allowing the system to recognize movement without a rider. If suspicious activity is detected, the device can send alerts to the user. The tracker also will include a GPS module for accurate location tracking, a SIM module for internet connection, and Bluetooth for access to a mobile app. The tracking app is designed for users to view the bike’s real-time location, receive alerts, manage device settings, and access travel history. All data is uploaded to Firebase, allowing users to monitor their bike remotely and receive important notifications.

## Key Features

### Battery Duration:
  The smart bike tracker will feature a 24-hour battery life, ensuring it can track the bike throughout the day without requiring frequent recharging.

### Location Tracking:

#### GPS Tracking: The tracker will continuously collect GPS location data or using a configurable interval

#### Data Storage: GPS data will be saved internally on the device, with updates sent every 10 minutes (or a configurable interval).

### Bluetooth Connectivity: The Bluetooth-enabled app can send user configuration.

### Sensors

#### Accelerometer: Detects the acceleration of the bike used for measuring motions. This sensor can detect any abnormal bike activity (e.g., sudden acceleration or deceleration).

#### Infrared (IR) Sensor: Provides human verification by distinguishing between normal riding behavior and potential theft scenarios. The system utilizes a combination of  acceleration data and presence detection to accurately confirm human presence. This integrated approach enhances the precision and reliability of identifying authorized operations while detecting potentially unauthorized or suspicious activity. 

#### Offline Tracking
##### GNSS Tracking: Using a SIM module and enabling real-time GPS location updates It receives location data directly from satellites to be sent via sms ensuring continuous and reliable communication between the tracker and the user.

##### Tracking Data Storage: GPS data from SIM7070G will be stored into the MCU.

# Project Work Flow

## Components Used
 - Main MCU -> ESP32
 - Accelerometer/Motion Detection/Wake Interupt -> LSM6DSL
 - Human Factor verification -> IR sensor [HW-201 sensor]
 - GPS Tracker -> SIM7070G GNSS/GPS/SMS 
 - Smart Phone
 - Battery 14650 Li-ion

## Core Functions 
 1. BLE Application
 1.1 Assign Contact Number Configuration & SMS Sending intervals [Application Side]
 1.2 GPS Location Update (Adjustable)[Application Side]
 2. SMS GPS Location Update when not connected to BLE device [MCU side] 
 3. Human Verification [IR sensor (HW-201 sensor)] [MCU Side]
 4. 24-hour long lasting operation [MCU side]
 5. SLEEP Function  (MCU when PHONE GPS is Used, only wake up When Theft function activates) [MCU side]
 6. Anti-Theft Function [BLE = False | LSM6DSL = True | IR = True] [MCU side] (Moving without connected to BLE) Send SMS alerts with GPS Location.
 7. Shock Detection [BLE = False | LSM6DSL = True | IR = False ] [MCU side] (Detected movement without user or BLE) Send SMS Potential tampering alert with GPS Location.

## MCU function Algorithm:
 1. Initialize the MCU.
 2. The MCU will check for BLE connection, Motion, and User.
 2.1. if [BLE = True | Motion = True | User = True] The ESP32 will enter light sleep mode, some functions will be disabled except for the bluetooth to enable continuous communication between the app and the MCU for it to be ready when recieving new configurations from the device. The app will handle the currentLocation updates function using the device GPS, while the MCU is put to SLEEP mode to conserve battery power. 
 2.2. if [BLE = False | Motion = True | User = True] This means the AntiTheft function will initialize. The ESP32 will start to getting the location using the SIM7070G and will send it to the assigned number configured from the application [The user will configure the number and sms interval via the Application].
 3. After sending the location the MCU will enter to Light sleep mode again disabling some functions except GPS monitoring to preserve battery power and will try go back to step 2 and will wake every 10 min (default) for sending the Tracker current GPS Location [but The user should be able to configure a time period inside the Application].
 4. Wake Interrupt of LSM6DSL should only activate when the IR sensor component detected IF there is no USER detected. It should only wake the MCU device when achieving a certain threshold of tilting, movement, or acceleration.

## IR Sensor Function
 - Human verification which is the IR sensor main function is to sense if there is a presence/user in front of it, if there is none, the MCU should also detect if the device is moving (LSM6DSL) without the user to trigger the Theft Detection.

## SMS Function
 - When the theft detection function activates, SMS should work when it has the coordinates from the SIM707G and the  Configured Phone number it should send the message to.

## GPS Logic
 - When the bluetooth is conencted with the user device and detected some value on the LSM6DSL or IR Sensors, the SIM7070G will still get location but will only save internally. The GPS data that will be used is from the users Device, this is to preserve the battery level of the prototype. Let the MCU sleep to conserve battery power.

 - When the MCU is not connected to the device, the MCU will get the GPS location via SIM7070G module and send the coordinates to the number stored from the MCU from the application number configured by the user, and NOT to the application, don't even attempt to send to the application.

 ## MCU Code Style
  - Ensure proper separation of concerns by creating a suitable folder structure.
  - Make each core function a separate file for easy and clean organization.
  - Utilize comments and debug prints for testing.


## Application Function Algorithm:
1. When the app initialized for the first time, it will ask for persmission for using the device bluetooth (Requirement to proceed). 
2. The App will have to scan for near bluetooth devices in which the user will have to select the MCU bluetooth device.
3. When connected to the MCU, user should see the following from the screen: A user input for assigning number | Button for requesting currentLocation | Button for changing sending location time period | MAP with the current location of the device.
4. If the user clicked the button for getting current location the app should update the MAP with the current location/address underneath using the device GPS Location function. 
5. MAP should update the current position when moving.


# Application Features
The should app should be built with flutter and have the following features:

## Basic UI
 - Simple single page application compatible with both IOS and Android:
 - Button for requesting current location.

## Theme
 - The app should use a pallete easy for the eyes, e.g. Matte color. 
 - The theme should not be a hardcoded colors and sizes in the widgets themselves, instead it should be done by setting 'theme' and 'MaterialApp.

## Application Code Style
 - Ensure proper separation of concerns by creating a suitable folder structure
 - Prefer small composable widgets over large ones
 - Prefer using flex values over hardcoded sizes when creating widgets inside rows/columns, ensuring the UI adapts to various screen sizes
 - Use log from dart:developer rather than print or debugPrint for logging

## Location Column
  - A Map should be displayed which can be monitored and tracked with a custom map canvas with a basic background template of a map [Tangram ES] for easier visual of the location.
 
 - The Location column should display the value of coordinates, source, and last update of GPS data from the device, Only the mentioned data should be shown. [DO NOT GET DATA FROM MCU, LET IT ON SLEEP MODE].

 - When getting location from the phone the user should be able to monitor its curernt location updates without requesting. 

 - A log of previous locations is displayed under the map. 