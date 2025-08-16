// ESP32 BLE Libraries
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <Preferences.h>  // For persistent storage
#include "ble_protocol.h"

// Pin Definitions
#define IR_SENSOR_PIN 25   // HW-201 IR sensor input

// BLE Service and Characteristic Pointers
BLEServer* pServer = NULL;
BLECharacteristic* pConfigChar = NULL;
BLECharacteristic* pStatusChar = NULL;

// Connection State
bool deviceConnected = false;
bool oldDeviceConnected = false;

// Configuration Storage
Preferences preferences;  // Non-volatile storage

// Configuration Structure
struct {
  char phoneNumber[20];     // Phone number for SMS alerts
  uint16_t updateInterval;  // Update interval in seconds
  bool alertEnabled;        // Alert enabled flag
} config;

// Status Structure
struct {
  bool bleConnected;
  bool userPresent;         // IR sensor status
  char lastConfig[100];     // Last received config for debugging
  unsigned long configTime; // Time of last config update
  String deviceMode;        // Current device mode (READY, AWAY, DISCONNECTED)
} status;

// Forward declarations
void saveConfiguration();
void updateStatusCharacteristic();

// ============================================================================
// BLE Server Callbacks
// ============================================================================
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      status.bleConnected = true;
      Serial.println("✅ BLE Client Connected");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      status.bleConnected = false;
      status.deviceMode = "DISCONNECTED";
      Serial.println("❌ BLE Client Disconnected");
    }
};

// ============================================================================
// Configuration Characteristic Callbacks
// ============================================================================
class ConfigCharCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      // Get the value directly as Arduino String
      String value = pCharacteristic->getValue();
      
      Serial.println("\n📥 Configuration Write Event Triggered!");
      Serial.println("=====================================");
      
      if (value.length() > 0) {
        Serial.print("Raw data length: ");
        Serial.println(value.length());
        Serial.print("Raw data (hex): ");
        for (size_t i = 0; i < value.length(); i++) {
          Serial.printf("%02X ", (uint8_t)value[i]);
        }
        Serial.println();
        Serial.print("Raw data (ASCII): ");
        Serial.println(value);
        Serial.print("First 10 chars: ");
        Serial.println(value.substring(0, 10));
        
        // Store raw config for debugging
        strncpy(status.lastConfig, value.c_str(), sizeof(status.lastConfig) - 1);
        status.lastConfig[sizeof(status.lastConfig) - 1] = '\0';  // Ensure null termination
        status.configTime = millis();
        
        // Parse JSON manually
        String jsonStr = value;  // Already an Arduino String
        bool configChanged = false;
        
        Serial.println("\n📋 Parsing Configuration:");
        Serial.println("-------------------");
        
        // Check if compact format (has "p" key instead of "phone_number")
        bool isCompact = jsonStr.indexOf("\"p\":") >= 0;
        Serial.print("Format: ");
        Serial.println(isCompact ? "Compact" : "Full");
        
        // Extract phone number
        int phoneStart = isCompact ? jsonStr.indexOf("\"p\":\"") : jsonStr.indexOf("\"phone_number\":\"");
        Serial.print("Looking for phone at index: ");
        Serial.println(phoneStart);
        if (phoneStart >= 0) {
          phoneStart += isCompact ? 5 : 16;  // Length of key + quotes
          int phoneEnd = jsonStr.indexOf("\"", phoneStart);
          Serial.print("Phone substring from ");
          Serial.print(phoneStart);
          Serial.print(" to ");
          Serial.println(phoneEnd);
          if (phoneEnd > phoneStart) {
            String phone = jsonStr.substring(phoneStart, phoneEnd);
            Serial.print("Extracted phone: ");
            Serial.println(phone);
            if (phone.length() > 0 && phone.length() < sizeof(config.phoneNumber)) {
              strncpy(config.phoneNumber, phone.c_str(), sizeof(config.phoneNumber) - 1);
              config.phoneNumber[sizeof(config.phoneNumber) - 1] = '\0';
              configChanged = true;
              Serial.print("✅ Phone Number Set: ");
              Serial.println(config.phoneNumber);
            }
          }
        } else {
          Serial.println("❌ phone_number field not found in JSON");
        }
        
        // Extract update interval
        int intervalStart = isCompact ? jsonStr.indexOf("\"i\":") : jsonStr.indexOf("\"update_interval\":");
        Serial.print("Looking for interval at index: ");
        Serial.println(intervalStart);
        if (intervalStart >= 0) {
          intervalStart += isCompact ? 4 : 18;  // Length of key + colon
          int intervalEnd = jsonStr.indexOf(",", intervalStart);
          if (intervalEnd < 0) {
            intervalEnd = jsonStr.indexOf("}", intervalStart);
          }
          Serial.print("Interval substring from ");
          Serial.print(intervalStart);
          Serial.print(" to ");
          Serial.println(intervalEnd);
          if (intervalEnd > intervalStart) {
            String interval = jsonStr.substring(intervalStart, intervalEnd);
            interval.trim();
            Serial.print("Extracted interval string: '");
            Serial.print(interval);
            Serial.println("'");
            int newInterval = interval.toInt();
            Serial.print("Parsed interval value: ");
            Serial.println(newInterval);
            if (newInterval >= 10 && newInterval <= 3600) {  // Valid range: 10s to 1 hour
              config.updateInterval = newInterval;
              configChanged = true;
              Serial.print("✅ Update Interval Set: ");
              Serial.print(config.updateInterval);
              Serial.println(" seconds");
            } else {
              Serial.println("❌ Interval out of range (10-3600)");
            }
          }
        } else {
          Serial.println("❌ update_interval field not found in JSON");
        }
        
        // Extract alert enabled flag
        int alertStart = isCompact ? jsonStr.indexOf("\"a\":") : jsonStr.indexOf("\"alert_enabled\":");
        if (alertStart >= 0) {
          alertStart += isCompact ? 4 : 16;  // Length of key + colon
          String alertSection = jsonStr.substring(alertStart, alertStart + 10);
          // In compact format: "1" = true, "0" = false
          // In full format: "true" or "false"
          config.alertEnabled = isCompact ? 
            (alertSection.indexOf("1") >= 0) : 
            (alertSection.indexOf("true") >= 0);
          configChanged = true;
          Serial.print("🚨 Alerts Enabled: ");
          Serial.println(config.alertEnabled ? "Yes" : "No");
        }
        
        // Save configuration to persistent storage if changed
        if (configChanged) {
          saveConfiguration();
          Serial.println("💾 Configuration saved to flash memory");
        }
        
        Serial.println("=====================================\n");
        
        // Update status characteristic
        updateStatusCharacteristic();
      } else {
        Serial.println("❌ No data received (empty value)");
      }
    }
};

// ============================================================================
// Configuration Management
// ============================================================================
void loadConfiguration() {
  preferences.begin("bike-tracker", false);
  
  // Load saved configuration or use defaults
  preferences.getString("phone", config.phoneNumber, sizeof(config.phoneNumber));
  config.updateInterval = preferences.getUShort("interval", 300);  // Default 5 minutes
  config.alertEnabled = preferences.getBool("alerts", true);       // Default enabled
  
  preferences.end();
  
  Serial.println("📂 Configuration loaded from storage:");
  Serial.print("  Phone: ");
  Serial.println(strlen(config.phoneNumber) > 0 ? config.phoneNumber : "(not set)");
  Serial.print("  Interval: ");
  Serial.print(config.updateInterval);
  Serial.println(" seconds");
  Serial.print("  Alerts: ");
  Serial.println(config.alertEnabled ? "Enabled" : "Disabled");
}

void saveConfiguration() {
  preferences.begin("bike-tracker", false);
  
  preferences.putString("phone", config.phoneNumber);
  preferences.putUShort("interval", config.updateInterval);
  preferences.putBool("alerts", config.alertEnabled);
  
  preferences.end();
}

// ============================================================================
// Sensor Reading
// ============================================================================
void readSensors() {
  // Read IR sensor (HW-201) - LOW when human detected, HIGH when no detection
  status.userPresent = (digitalRead(IR_SENSOR_PIN) == LOW);
  
  // Determine device mode based on connection and IR sensor
  if (status.bleConnected) {
    if (status.userPresent) {
      status.deviceMode = "READY";  // User is present, ready to ride
    } else {
      status.deviceMode = "AWAY";   // User stepped away from bike
    }
  } else {
    status.deviceMode = "DISCONNECTED";  // BLE not connected
  }
}

// ============================================================================
// Status Update
// ============================================================================
void updateStatusCharacteristic() {
  // Read sensors before updating status
  readSensors();
  
  if (pStatusChar) {
    char jsonBuffer[350];
    snprintf(jsonBuffer, sizeof(jsonBuffer),
             "{\"ble_connected\":%s,\"phone_configured\":%s,\"phone\":\"%s\",\"interval\":%d,\"alerts\":%s,"
             "\"user_present\":%s,\"mode\":\"%s\",\"last_config_time\":%lu}",
             status.bleConnected ? "true" : "false",
             strlen(config.phoneNumber) > 0 ? "true" : "false",
             config.phoneNumber,
             config.updateInterval,
             config.alertEnabled ? "true" : "false",
             status.userPresent ? "true" : "false",
             status.deviceMode.c_str(),
             status.configTime);
    
    pStatusChar->setValue(jsonBuffer);
    
    if (deviceConnected) {
      pStatusChar->notify();
      Serial.println("📤 Status update sent to app");
      
      // Debug output
      Serial.print("  👤 User: ");
      Serial.print(status.userPresent ? "Present" : "Away");
      Serial.print(" | Mode: ");
      Serial.println(status.deviceMode);
    }
  }
}

// ============================================================================
// BLE Initialization
// ============================================================================
void initBLE() {
  // Generate unique device name
  char deviceName[32];
  sprintf(deviceName, "%s%02X%02X", DEVICE_NAME_PREFIX, 
          (uint8_t)(ESP.getEfuseMac() >> 8), 
          (uint8_t)(ESP.getEfuseMac()));
  
  Serial.print("🔷 Initializing BLE as: ");
  Serial.println(deviceName);
  
  // Initialize BLE
  BLEDevice::init(deviceName);
  
  // Set MTU to larger value to handle JSON config (default is 23, we need at least 100)
  BLEDevice::setMTU(185);  // This allows up to 182 bytes of data
  Serial.println("📏 MTU set to 185 bytes");
  
  // Create BLE server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  
  // Create BLE service
  Serial.print("🔵 Creating BLE service with UUID: ");
  Serial.println(SERVICE_UUID);
  BLEService *pService = pServer->createService(SERVICE_UUID);
  
  // Create Config characteristic (WRITE)
  Serial.print("Creating Config characteristic with UUID: ");
  Serial.println(CONFIG_CHAR_UUID);
  pConfigChar = pService->createCharacteristic(
                    CONFIG_CHAR_UUID,
                    BLECharacteristic::PROPERTY_WRITE
                  );
  pConfigChar->setCallbacks(new ConfigCharCallbacks());
  Serial.println("✅ Config characteristic created with WRITE property");
  
  // Create Status characteristic (READ, NOTIFY)
  pStatusChar = pService->createCharacteristic(
                    STATUS_CHAR_UUID,
                    BLECharacteristic::PROPERTY_READ |
                    BLECharacteristic::PROPERTY_NOTIFY
                  );
  pStatusChar->addDescriptor(new BLE2902());
  
  // Start service
  pService->start();
  
  // Configure advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  // 7.5ms
  pAdvertising->setMinPreferred(0x12);  // 15ms
  BLEDevice::startAdvertising();
  
  Serial.println("✅ BLE Service started and advertising");
}

// ============================================================================
// SETUP
// ============================================================================
void setup() {
  Serial.begin(115200);
  delay(1000);  // Give serial time to initialize
  
  Serial.println("\n\n========================================");
  Serial.println("🚴 Smart Bike Tracker - BLE Config Test");
  Serial.println("========================================\n");
  
  // Configure IR sensor pin
  pinMode(IR_SENSOR_PIN, INPUT);
  Serial.println("🔦 IR sensor configured on pin 25");
  
  // Initialize status
  status.bleConnected = false;
  status.userPresent = false;
  status.deviceMode = "DISCONNECTED";
  status.configTime = 0;
  memset(status.lastConfig, 0, sizeof(status.lastConfig));
  
  // Load saved configuration
  loadConfiguration();
  
  // Initialize BLE
  initBLE();
  
  Serial.println("\n📡 Ready for BLE connections...\n");
}

// ============================================================================
// MAIN LOOP
// ============================================================================
void loop() {
  static unsigned long lastStatusUpdate = 0;
  
  // Handle disconnection
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("🔄 Restarting advertising...");
    oldDeviceConnected = deviceConnected;
  }
  
  // Handle new connection
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
    Serial.println("🔗 Connection established");
    // Send initial status
    updateStatusCharacteristic();
  }
  
  // Periodic status update (every 10 seconds when connected)
  if (deviceConnected && (millis() - lastStatusUpdate > 10000)) {
    lastStatusUpdate = millis();
    
    // Read sensors and update status
    readSensors();
    updateStatusCharacteristic();
    
    // Print current status
    Serial.println("📊 Current Status:");
    Serial.print("  👤 IR Sensor: User ");
    Serial.println(status.userPresent ? "Present (READY)" : "Away");
    Serial.print("  📍 Mode: ");
    Serial.println(status.deviceMode);
    Serial.print("  📞 Phone: ");
    Serial.println(strlen(config.phoneNumber) > 0 ? config.phoneNumber : "(not set)");
    Serial.print("  ⏱️ Interval: ");
    Serial.print(config.updateInterval);
    Serial.println(" seconds");
  }
  
  delay(10);
}