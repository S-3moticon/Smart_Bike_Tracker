I want to build a simple tracking app connected to a Micro Controller Unit (MCU) that can be used to monitor the locations its been to.

# IMPORTANT NOTE
 - This Project project doesn't conenct to the internet so any useless files, command, or code in relation to connecting, attempting, and reading internet should be remove.

# Project Work Flow

## Components Used
 - Main MCU - ESP32
 - Speedometer/Accelerometer/Motion Detection - LSM6DSL
 - Human Factor verification - IR sensor
 - GPS Tracker- SIM7070G GNSS/GPS/SMS 
 - Smart Phone

## MCU function Algorithm:
1. Initialize the MCU.
2. The MCU will check for BLE connection, Motion, and User.
2.1. if [BLE = True | Motion = True | User = True] The ESP32 will enter light sleep mode, all functions of the MCU are disabled except for the bluetooth to enable communication between the app and the MCU. The app will handle the currentLocation function using the device GPS function.
2.2. if [BLE = False | Motion = True | User = True] The ESP32 will start getting the location using the SIM7070G and will send it to the assigned number.
3. After sending the location the MCU will enter to Light sleep mode again disabling Acceleration/Speed monitoring except GPS monitoring to preserve energy and will try go back to step 2.1 after 10 minutes.

## Application Function Algorithm:
1. When the app initialized for the first time, it will ask for persmission for using the device bluetooth (Requirement to proceed). 
2. The App will have to scan for near bluetooth devices in which the user will have to select the MCU bluetooth device.
3. When connected to the MCU, user should see the following from the screen: A user input for assigning number | Button for requesting currentLocation | Button for changing sending location frequency | GMAP with the current location of the device.
4. If the user clicked the button for getting current location the app should update the GMAP with the current location/address underneath. 
5. If the user clicked the button for 

# Application Features

The should app should be built with flutter and have the following features:

## Basic UI

Simple page app with:
 - Button for configuring bluetooth connection to the MCU.
 - Button for requesting current location.

## Theme

 - The app should use a pallete easy for the eyes, e.g. Matte color. 
 - The theme should not be a hardcoded colors and sizes in the widgets themselves, instead it should be done by setting 'theme' and 'MaterialApp.