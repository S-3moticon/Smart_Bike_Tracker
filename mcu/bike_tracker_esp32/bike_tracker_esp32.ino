// ESP32 BLE Libraries for Bluetooth Low Energy functionality
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>
// I2C library for sensor communication
#include <Wire.h>
// Custom header with BLE protocol definitions
#include "ble_protocol.h"

// Pin Definitions for Hardware Connections
#define GPS_RX_PIN 16      // UART RX pin for SIM7070G GPS module
#define GPS_TX_PIN 17      // UART TX pin for SIM7070G GPS module  
#define IR_SENSOR_PIN 25   // Digital input for IR proximity sensor
#define LED_PIN 2          // Built-in LED for status indication

// I2C pins for LSM6DSL motion sensor communication
#define I2C_SDA 21         // I2C data line
#define I2C_SCL 22         // I2C clock line

// BLE Service and Characteristic Pointers
BLEServer* pServer = NULL;                    // BLE server instance
BLECharacteristic* pLocationChar = NULL;      // Characteristic for GPS location data
BLECharacteristic* pConfigChar = NULL;        // Characteristic for app configuration
BLECharacteristic* pStatusChar = NULL;        // Characteristic for device status
BLECharacteristic* pCommandChar = NULL;       // Characteristic for commands from app

// Connection State Tracking
bool deviceConnected = false;      // Current BLE connection status
bool oldDeviceConnected = false;   // Previous connection status for state change detection

// Data Structures (defined in ble_protocol.h)
LocationData currentLocation = {0};           // Stores current GPS location data
ConfigData config = {"", 300, true};          // Stores configuration (phone, interval, alerts)
StatusData status = {false, false, false, MODE_IDLE}; // Stores device status

// Timing Variables for Non-blocking Operations
unsigned long lastLocationUpdate = 0;  // Last time GPS location was updated
unsigned long lastMotionCheck = 0;     // Last time motion/theft was checked
unsigned long lastSMSAlert = 0;        // Last time SMS alert was sent

// RTC Memory Variable - Survives deep sleep but not power loss
RTC_DATA_ATTR int bootCount = 0;       // Counts number of device boots

// BLE Server Callbacks - Handles connection events
class MyServerCallbacks: public BLEServerCallbacks {
    // Called when a BLE client (phone app) connects
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      status.bleConnected = true;
      Serial.println("BLE Client Connected");
    };

    // Called when a BLE client disconnects
    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      status.bleConnected = false;
      Serial.println("BLE Client Disconnected");
    }
};

// Configuration Characteristic Callbacks - Handles configuration updates from app
class ConfigCharCallbacks: public BLECharacteristicCallbacks {
    // Called when app writes configuration data
    void onWrite(BLECharacteristic *pCharacteristic) {
      // Get value as Arduino String directly
      String value = pCharacteristic->getValue();
      if (value.length() > 0) {
        Serial.println("Config received:");
        Serial.println(value);
        
        // Simple JSON parsing without ArduinoJson library
        // Expected format: {"phone_number":"+1234567890","update_interval":300,"alert_enabled":true}
        
        // Parse phone number
        int phoneStart = value.indexOf("\"phone_number\":\"") + 16;
        int phoneEnd = value.indexOf("\"", phoneStart);
        if (phoneStart > 15 && phoneEnd > phoneStart) {
          String phoneStr = value.substring(phoneStart, phoneEnd);
          phoneStr.toCharArray(config.phoneNumber, 16);
        }
        
        // Parse update interval
        int intervalStart = value.indexOf("\"update_interval\":") + 18;
        int intervalEnd = value.indexOf(",", intervalStart);
        if (intervalEnd == -1) intervalEnd = value.indexOf("}", intervalStart);
        if (intervalStart > 17 && intervalEnd > intervalStart) {
          String intervalStr = value.substring(intervalStart, intervalEnd);
          config.updateInterval = intervalStr.toInt();
        }
        
        // Parse alert enabled
        int alertStart = value.indexOf("\"alert_enabled\":");
        if (alertStart > 0) {
          config.alertEnabled = value.indexOf("true", alertStart) > 0;
        }
        
        // Print parsed configuration
        Serial.print("Phone: ");
        Serial.println(config.phoneNumber);
        Serial.print("Update Interval: ");
        Serial.println(config.updateInterval);
        Serial.print("Alert Enabled: ");
        Serial.println(config.alertEnabled);
      }
    }
};

// ============================================================================
// SETUP FUNCTION - Runs once when ESP32 starts or resets
// ============================================================================
void setup() {
  // Initialize serial communication for debugging
  Serial.begin(115200);
  Serial.println("Smart Bike Tracker ESP32 Starting...");
  
  // Track boot count (survives deep sleep)
  bootCount++;
  Serial.print("Boot number: ");
  Serial.println(bootCount);
  
  // Configure GPIO pins
  pinMode(LED_PIN, OUTPUT);        // LED for visual theft alert
  pinMode(IR_SENSOR_PIN, INPUT);   // IR sensor for human detection
  
  // Initialize I2C bus for LSM6DSL motion sensor
  Wire.begin(I2C_SDA, I2C_SCL);
  
  // Initialize Bluetooth Low Energy
  initBLE();
  
  Serial.println("Setup complete. Waiting for connections...");
}

// ============================================================================
// BLE INITIALIZATION - Sets up BLE server and characteristics
// ============================================================================
void initBLE() {
  // Generate unique device name using MAC address
  // Format: BikeTrk_XXXX where XXXX is last 2 bytes of MAC
  char deviceName[32];
  sprintf(deviceName, "%s%02X%02X", DEVICE_NAME_PREFIX, 
          (uint8_t)(ESP.getEfuseMac() >> 8), 
          (uint8_t)(ESP.getEfuseMac()));
  
  // Initialize BLE with unique device name
  BLEDevice::init(deviceName);
  
  // Create BLE server and set connection callbacks
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  
  // Create BLE service with our custom UUID
  BLEService *pService = pServer->createService(SERVICE_UUID);
  
  // Create Location characteristic (READ, NOTIFY)
  // App reads GPS location from this characteristic
  pLocationChar = pService->createCharacteristic(
                    LOCATION_CHAR_UUID,
                    BLECharacteristic::PROPERTY_READ |
                    BLECharacteristic::PROPERTY_NOTIFY
                  );
  pLocationChar->addDescriptor(new BLE2902()); // Enable notifications
  
  // Create Config characteristic (WRITE)
  // App writes phone number and settings to this characteristic
  pConfigChar = pService->createCharacteristic(
                    CONFIG_CHAR_UUID,
                    BLECharacteristic::PROPERTY_WRITE
                  );
  pConfigChar->setCallbacks(new ConfigCharCallbacks());
  
  // Create Status characteristic (READ, NOTIFY)
  // Reports device status (motion, user presence, mode)
  pStatusChar = pService->createCharacteristic(
                    STATUS_CHAR_UUID,
                    BLECharacteristic::PROPERTY_READ |
                    BLECharacteristic::PROPERTY_NOTIFY
                  );
  pStatusChar->addDescriptor(new BLE2902()); // Enable notifications
  
  // Create Command characteristic (WRITE)
  // App sends commands (e.g., request immediate location)
  pCommandChar = pService->createCharacteristic(
                    COMMAND_CHAR_UUID,
                    BLECharacteristic::PROPERTY_WRITE
                  );
  
  // Start the BLE service
  pService->start();
  
  // Configure BLE advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);  // Advertise our service
  pAdvertising->setScanResponse(true);         // Allow scan response
  pAdvertising->setMinPreferred(0x06);         // Min connection interval 7.5ms
  pAdvertising->setMinPreferred(0x12);         // Max connection interval 15ms
  BLEDevice::startAdvertising();               // Start advertising
  
  Serial.print("BLE Device Name: ");
  Serial.println(deviceName);
}

// ============================================================================
// UPDATE LOCATION - Sends GPS location data via BLE
// ============================================================================
void updateLocationCharacteristic() {
  if (deviceConnected && pLocationChar) {
    // Create JSON string using char array for better compatibility
    char jsonBuffer[256];
    snprintf(jsonBuffer, sizeof(jsonBuffer), 
             "{\"lat\":%.6f,\"lng\":%.6f,\"timestamp\":%lu,\"speed\":%.1f,\"satellites\":%d,\"battery\":%d}",
             currentLocation.lat, 
             currentLocation.lng, 
             currentLocation.timestamp,
             currentLocation.speed,
             currentLocation.satellites,
             currentLocation.battery);
    
    // Send location data to connected app
    pLocationChar->setValue(jsonBuffer);
    pLocationChar->notify();
    
    Serial.print("Location sent: ");
    Serial.println(jsonBuffer);
  }
}

// ============================================================================
// UPDATE STATUS - Sends device status via BLE
// ============================================================================
void updateStatusCharacteristic() {
  if (pStatusChar) {
    // Convert mode enum to string
    const char* modeStr = "IDLE";
    switch(status.mode) {
      case MODE_TRACKING: modeStr = "TRACKING"; break;
      case MODE_ALERT: modeStr = "ALERT"; break;
      case MODE_SLEEP: modeStr = "SLEEP"; break;
    }
    
    // Create JSON string using char array for better compatibility
    char jsonBuffer[200];
    snprintf(jsonBuffer, sizeof(jsonBuffer),
             "{\"ble_connected\":%s,\"motion_detected\":%s,\"user_present\":%s,\"mode\":\"%s\"}",
             status.bleConnected ? "true" : "false",
             status.motionDetected ? "true" : "false",
             status.userPresent ? "true" : "false",
             modeStr);
    
    // Update characteristic value
    pStatusChar->setValue(jsonBuffer);
    
    // Send notification if connected
    if (deviceConnected) {
      pStatusChar->notify();
    }
  }
}

// ============================================================================
// USER PRESENCE CHECK - Reads IR sensor to detect if user is on bike
// ============================================================================
bool checkUserPresence() {
  // IR sensor returns HIGH when object (user) is detected
  return digitalRead(IR_SENSOR_PIN) == HIGH;
}

// ============================================================================
// THEFT DETECTION - Main anti-theft logic
// ============================================================================
void checkTheftCondition() {
  // Check if user is present using IR sensor
  status.userPresent = checkUserPresence();
  
  // THEFT CONDITION: BLE disconnected AND (motion detected OR user not present)
  if (!status.bleConnected && (status.motionDetected || !status.userPresent)) {
    if (status.mode != MODE_ALERT) {
      Serial.println("THEFT DETECTED!");
      status.mode = MODE_ALERT;
      digitalWrite(LED_PIN, HIGH);  // Turn on LED alert
      // SMS alert will be sent in main loop
    }
  } 
  // RECOVERY CONDITION: BLE connected AND user present
  else if (status.bleConnected && status.userPresent) {
    if (status.mode == MODE_ALERT) {
      Serial.println("Device recovered");
      status.mode = MODE_IDLE;
      digitalWrite(LED_PIN, LOW);   // Turn off LED alert
    }
  }
}

// ============================================================================
// MAIN LOOP - Runs continuously after setup
// ============================================================================
void loop() {
  unsigned long currentMillis = millis();
  
  // ===== CHECK THEFT CONDITION EVERY SECOND =====
  if (currentMillis - lastMotionCheck >= 1000) {
    lastMotionCheck = currentMillis;
    
    // Check for theft based on BLE connection, motion, and user presence
    checkTheftCondition();
    
    // Update device status characteristic for app
    updateStatusCharacteristic();
  }
  
  // ===== UPDATE GPS LOCATION AT CONFIGURED INTERVAL =====
  if (currentMillis - lastLocationUpdate >= (config.updateInterval * 1000)) {
    lastLocationUpdate = currentMillis;
    
    // TEMPORARY: Generate fake GPS data for testing
    // TODO: Replace with actual GPS data from SIM7070G module
    currentLocation.lat = 37.7749 + (random(100) - 50) * 0.0001;
    currentLocation.lng = -122.4194 + (random(100) - 50) * 0.0001;
    currentLocation.timestamp = millis() / 1000;
    currentLocation.speed = random(0, 30);
    currentLocation.satellites = random(4, 12);
    currentLocation.battery = 85;
    
    // Send location update via BLE if connected
    updateLocationCharacteristic();
    
    // Send SMS alert if in theft mode
    if (status.mode == MODE_ALERT && config.alertEnabled) {
      // TODO: Implement actual SMS sending via SIM7070G
      Serial.println("Would send SMS alert here");
      // Format: "ALERT: Bike at LAT,LNG - https://maps.google.com/?q=LAT,LNG"
    }
  }
  
  // ===== HANDLE BLE DISCONNECTION =====
  // Restart advertising when client disconnects
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);  // Give BLE stack time to clean up
    pServer->startAdvertising();
    Serial.println("Start advertising");
    oldDeviceConnected = deviceConnected;
  }
  
  // ===== HANDLE BLE CONNECTION =====
  // Update connection state tracking
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }
  // Small delay to prevent watchdog timer issues
  delay(10);
}
