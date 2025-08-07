I want to build a simple Bike Anti Theft tracking app connected to a Micro Controller Unit (MCU) that can be used to monitor the locations its been to.

# IMPORTANT NOTE
 - This Project project doesn't connect to the internet so any useless files, command, or code in relation to connecting, attempting, and reading internet should be remove.

# Project Work Flow

## Components Used
 - Main MCU - ESP32
 - Speedometer/Accelerometer/Motion Detection/Wake - LSM6DSL
 - Human Factor verification - IR sensor
 - GPS Tracker- SIM7070G GNSS/GPS/SMS 
 - Smart Phone
 - Battery 14650 Li-Po

## Core Functions 
1. BLE Application
1.1 Assign Number [Application Side]
1.2 GPS Location Update (When requested Application Side)
2. SMS GPS Location Update [MCU side] 
3. Human Verification [IR sensor] [MCU Side]
4. 24-hour long lasting operation [MCU side]

## MCU function Algorithm:
1. Initialize the MCU.
2. The MCU will check for BLE connection, Motion, and User.
2.1. if [BLE = True | Motion = True | User = True] The ESP32 will enter light sleep mode, some functions of the MCU are disabled [IR = Off | LSM = ON (For Acceleration measurement)] except for the bluetooth to enable communication between the app and the MCU. The app will handle the currentLocation function using the device GPS function while the MCU sleep. 
2.2. if [BLE = False | Motion = True | User = True] This means the AntiTheft function will initialize. The ESP32 will start getting the location using the SIM7070G and will send it to the assigned number [The user will add the number via the Application].
3. After sending the location the MCU will enter to Light sleep mode again disabling Acceleration/Speed monitoring except GPS monitoring to preserve energy and will try go back to step 2 and will wake every [The user will assign a time period inside the Application].

## GPS Logic
 - When the bluetooth is not connected with the user device but detected some value on the LSM6DSL or IR Sensors the ESP32 MCU will get the loction via SIM7070G and send it to the number the user registered using the application.
 - When the bluetooth is conencted with the user device and detected some value on the LSM6DSL or IR Sensors, the SIM7070G will still get location but will only save internally. The GPS data that will be used is from the users Device, this is to preserve the battery level of the prototype.

## Application Function Algorithm:
1. When the app initialized for the first time, it will ask for persmission for using the device bluetooth (Requirement to proceed). 
2. The App will have to scan for near bluetooth devices in which the user will have to select the MCU bluetooth device.
3. When connected to the MCU, user should see the following from the screen: A user input for assigning number | Button for requesting currentLocation | Button for changing sending location time period | GMAP with the current location of the device.
4. If the user clicked the button for getting current location the app should update the GMAP with the current location/address underneath using the device GPS Location function. 
5. GMAP should update the current position when moving.

# Application Features

The should app should be built with flutter and have the following features:

## Basic UI

 - Simple single page application compatible with both IOS and Android:
 - Button for requesting current location.

## Theme

 - The app should use a pallete easy for the eyes, e.g. Matte color. 
 - The theme should not be a hardcoded colors and sizes in the widgets themselves, instead it should be done by setting 'theme' and 'MaterialApp.

## Code Style
 - Ensure proper separation of concerns by creating a suitable folder structure
 - Prefer small composable widgets over large ones
 - Prefer using flex values over hardcoded sizes when creating widgets inside rows/columns, ensuring the UI adapts to various screen sizes
 - Use log from dart:developer rather than print or debugPrint for logging