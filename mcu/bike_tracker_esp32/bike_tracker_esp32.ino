// ESP32 BLE Libraries
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <Preferences.h>  // For persistent storage
#include "ble_protocol.h"

// GPS/SMS Module Libraries
#include "sim7070g.h"
#include "gps_handler.h"
#include "sms_handler.h"

// Pin Definitions
#define IR_SENSOR_PIN 25   // HW-201 IR sensor input

// BLE Service and Characteristic Pointers
BLEServer* pServer = NULL;
BLECharacteristic* pConfigChar = NULL;
BLECharacteristic* pStatusChar = NULL;
BLECharacteristic* pHistoryChar = NULL;

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
  String deviceMode;        // Current device mode (READY, AWAY, DISCONNECTED)
  unsigned long lastGPSTime; // Last GPS acquisition time
} status;

// GPS Data
GPSData currentGPS;

// Forward declarations
void saveConfiguration();
void clearConfiguration();
void updateStatusCharacteristic();
void testGPSAndSMS();
void syncGPSHistory();

// ============================================================================
// BLE Server Callbacks
// ============================================================================
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      status.bleConnected = true;
      Serial.println("✅ BLE Client Connected");
      
      // Sync GPS history when device reconnects
      delay(1000);  // Give BLE time to stabilize
      syncGPSHistory();
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
      
      if (value.length() > 0) {
        // Check for clear command
        if (value == "CLEAR" || value == "clear" || value == "{\"clear\":true}") {
          clearConfiguration();
          updateStatusCharacteristic();
          return;
        }
        
        // Parse JSON manually
        String jsonStr = value;
        bool configChanged = false;
        
        // Check if compact format (has "p" key instead of "phone_number")
        bool isCompact = jsonStr.indexOf("\"p\":") >= 0;
        
        // Extract phone number
        int phoneStart = isCompact ? jsonStr.indexOf("\"p\":\"") : jsonStr.indexOf("\"phone_number\":\"");
        if (phoneStart >= 0) {
          phoneStart += isCompact ? 5 : 16;  // Length of key + quotes
          int phoneEnd = jsonStr.indexOf("\"", phoneStart);
          if (phoneEnd >= phoneStart) {  // Changed from > to >= to handle empty string
            String phone = jsonStr.substring(phoneStart, phoneEnd);
            
            // Check if phone number is empty (clear command from app)
            if (phone.length() == 0) {
              // Clear configuration when empty phone number is received
              clearConfiguration();
              updateStatusCharacteristic();
              return;
            } else if (phone.length() < sizeof(config.phoneNumber)) {
              strncpy(config.phoneNumber, phone.c_str(), sizeof(config.phoneNumber) - 1);
              config.phoneNumber[sizeof(config.phoneNumber) - 1] = '\0';
              configChanged = true;
            }
          }
        }
        
        // Extract update interval
        int intervalStart = isCompact ? jsonStr.indexOf("\"i\":") : jsonStr.indexOf("\"update_interval\":");
        if (intervalStart >= 0) {
          intervalStart += isCompact ? 4 : 18;  // Length of key + colon
          int intervalEnd = jsonStr.indexOf(",", intervalStart);
          if (intervalEnd < 0) {
            intervalEnd = jsonStr.indexOf("}", intervalStart);
          }
          if (intervalEnd > intervalStart) {
            String interval = jsonStr.substring(intervalStart, intervalEnd);
            interval.trim();
            int newInterval = interval.toInt();
            if (newInterval >= 10 && newInterval <= 3600) {  // Valid range: 10s to 1 hour
              config.updateInterval = newInterval;
              configChanged = true;
            }
          }
        }
        
        // Extract alert enabled flag
        int alertStart = isCompact ? jsonStr.indexOf("\"a\":") : jsonStr.indexOf("\"alert_enabled\":");
        if (alertStart >= 0) {
          alertStart += isCompact ? 4 : 16;  // Length of key + colon
          String alertSection = jsonStr.substring(alertStart, alertStart + 10);
          config.alertEnabled = isCompact ? 
            (alertSection.indexOf("1") >= 0) : 
            (alertSection.indexOf("true") >= 0);
          configChanged = true;
        }
        
        // Save configuration if changed
        if (configChanged) {
          saveConfiguration();
          updateStatusCharacteristic();
        }
      }
    }
};

// ============================================================================
// Configuration Management
// ============================================================================
void loadConfiguration() {
  preferences.begin("bike-tracker", false);
  preferences.getString("phone", config.phoneNumber, sizeof(config.phoneNumber));
  config.updateInterval = preferences.getUShort("interval", 300);  // Default 5 minutes
  config.alertEnabled = preferences.getBool("alerts", true);       // Default enabled
  preferences.end();
}

void saveConfiguration() {
  preferences.begin("bike-tracker", false);
  preferences.putString("phone", config.phoneNumber);
  preferences.putUShort("interval", config.updateInterval);
  preferences.putBool("alerts", config.alertEnabled);
  preferences.end();
}

void clearConfiguration() {
  // Clear config structure
  memset(config.phoneNumber, 0, sizeof(config.phoneNumber));
  config.updateInterval = 300;  // Reset to default 5 minutes
  config.alertEnabled = true;   // Reset to default enabled
  
  // Clear from persistent storage
  preferences.begin("bike-tracker", false);
  preferences.clear();
  preferences.end();
  
  Serial.println("✅ Configuration cleared");
  Serial.println("  Phone: (empty)");
  Serial.println("  Interval: 300 seconds");
  Serial.println("  Alerts: Enabled");
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
    // Check if phone is configured (not empty)
    bool phoneConfigured = strlen(config.phoneNumber) > 0;
    
    char jsonBuffer[300];
    snprintf(jsonBuffer, sizeof(jsonBuffer),
             "{\"ble\":%s,\"phone_configured\":%s,\"phone\":\"%s\",\"interval\":%d,\"alerts\":%s,"
             "\"user\":%s,\"mode\":\"%s\","
             "\"gps_valid\":%s,\"lat\":\"%s\",\"lon\":\"%s\"}",
             status.bleConnected ? "true" : "false",
             phoneConfigured ? "true" : "false",
             config.phoneNumber,
             config.updateInterval,
             config.alertEnabled ? "true" : "false",
             status.userPresent ? "true" : "false",
             status.deviceMode.c_str(),
             currentGPS.valid ? "true" : "false",
             currentGPS.valid ? currentGPS.latitude.c_str() : "",
             currentGPS.valid ? currentGPS.longitude.c_str() : "");
    
    pStatusChar->setValue(jsonBuffer);
    
    if (deviceConnected) {
      pStatusChar->notify();
    }
  }
}

// ============================================================================
// GPS and SMS Test Functions
// ============================================================================
void testGPSAndSMS() {
  if (strlen(config.phoneNumber) == 0) {
    Serial.println("❌ No phone number configured");
    return;
  }
  
  Serial.println("\n🛰️ Acquiring GPS...");
  bool gotFix = acquireGPSFix(currentGPS, 20);
  
  if (gotFix) {
    Serial.print("✅ GPS: ");
    Serial.print(currentGPS.latitude);
    Serial.print(", ");
    Serial.println(currentGPS.longitude);
    
    saveGPSData(currentGPS);
    status.lastGPSTime = millis();
    logGPSPoint(currentGPS, 1);  // Source: 1 = SIM7070G
    
    if (sendLocationSMS(config.phoneNumber, currentGPS, ALERT_TEST)) {
      Serial.println("✅ SMS sent");
    } else {
      Serial.println("❌ SMS failed");
    }
  } else {
    // Try last known location
    if (loadGPSData(currentGPS)) {
      Serial.println("📍 Using last known location");
      sendLocationSMS(config.phoneNumber, currentGPS, ALERT_TEST);
    } else {
      // Send simple test SMS
      sendTestSMS(config.phoneNumber);
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
  
  Serial.print("🔷 BLE Device: ");
  Serial.println(deviceName);
  
  BLEDevice::init(deviceName);
  BLEDevice::setMTU(185);  // For JSON config
  
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  
  BLEService *pService = pServer->createService(SERVICE_UUID);
  
  // Config characteristic (WRITE)
  pConfigChar = pService->createCharacteristic(
                    CONFIG_CHAR_UUID,
                    BLECharacteristic::PROPERTY_WRITE
                  );
  pConfigChar->setCallbacks(new ConfigCharCallbacks());
  
  // Status characteristic (READ, NOTIFY)
  pStatusChar = pService->createCharacteristic(
                    STATUS_CHAR_UUID,
                    BLECharacteristic::PROPERTY_READ |
                    BLECharacteristic::PROPERTY_NOTIFY
                  );
  pStatusChar->addDescriptor(new BLE2902());
  
  // History characteristic (READ, NOTIFY)
  pHistoryChar = pService->createCharacteristic(
                    HISTORY_CHAR_UUID,
                    BLECharacteristic::PROPERTY_READ |
                    BLECharacteristic::PROPERTY_NOTIFY
                  );
  pHistoryChar->addDescriptor(new BLE2902());
  
  // Start service
  pService->start();
  
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  BLEDevice::startAdvertising();
  
  Serial.println("✅ BLE Service started");
}

// ============================================================================
// GPS History Sync
// ============================================================================
void syncGPSHistory() {
  if (!deviceConnected || !pHistoryChar) {
    return;
  }
  
  Serial.println("📤 Syncing GPS history to app...");
  
  // Get GPS history as JSON
  String historyJson = getGPSHistoryJSON(20);  // Send last 20 points
  
  // Send via BLE
  pHistoryChar->setValue(historyJson.c_str());
  pHistoryChar->notify();
  
  Serial.print("   Sent ");
  Serial.print(getGPSHistoryCount());
  Serial.println(" GPS points to app");
}

// ============================================================================
// SETUP
// ============================================================================
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n🚴 Smart Bike Tracker v1.0");
  Serial.println("==============================\n");
  
  // Initialize hardware
  pinMode(IR_SENSOR_PIN, INPUT);
  status.bleConnected = false;
  status.userPresent = false;
  status.deviceMode = "DISCONNECTED";
  status.lastGPSTime = 0;
  
  // Load configuration and initialize services
  loadConfiguration();
  initBLE();
  initGPSHistory();
  
  // Initialize SIM7070G
  if (initializeSIM7070G()) {
    if (checkNetworkRegistration()) {
      Serial.println("✅ Ready (Network OK)");
    } else {
      Serial.println("⚠️ Ready (No network)");
    }
  } else {
    Serial.println("⚠️ SIM7070G not available");
  }
  
  Serial.println("\n📡 Ready for BLE connections...\n");
}

// ============================================================================
// MAIN LOOP
// ============================================================================
void loop() {
  static unsigned long lastStatusUpdate = 0;
  
  // Handle BLE connection changes
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    oldDeviceConnected = deviceConnected;
  }
  
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
    updateStatusCharacteristic();
  }
  
  // Read sensors
  readSensors();
  
  // Check for serial commands
  if (Serial.available() > 0) {
    String command = Serial.readStringUntil('\n');
    command.trim();
    
    if (command == "test") {
      // Run GPS and SMS test
      testGPSAndSMS();
    } else if (command == "gps") {
      Serial.println("\n🛰️ Testing GPS...");
      if (acquireGPSFix(currentGPS, 20)) {
        Serial.print("✅ GPS: ");
        Serial.print(currentGPS.latitude);
        Serial.print(", ");
        Serial.println(currentGPS.longitude);
        saveGPSData(currentGPS);
        logGPSPoint(currentGPS, 1);
      } else {
        Serial.println("❌ GPS failed");
      }
    } else if (command == "sms") {
      // Send test SMS
      if (strlen(config.phoneNumber) > 0) {
        Serial.println("\n📱 Sending test SMS...");
        if (currentGPS.valid) {
          if (sendLocationSMS(config.phoneNumber, currentGPS, ALERT_TEST)) {
            Serial.println("✅ SMS sent with location!");
          } else {
            Serial.println("❌ Failed to send SMS");
          }
        } else {
          if (sendTestSMS(config.phoneNumber)) {
            Serial.println("✅ Simple test SMS sent!");
          } else {
            Serial.println("❌ Failed to send SMS");
          }
        }
      } else {
        Serial.println("❌ No phone number configured");
      }
    } else if (command == "status") {
      // Print current status
      Serial.println("\n📊 Current Status:");
      Serial.print("  👤 IR Sensor: User ");
      Serial.println(status.userPresent ? "Present" : "Away");
      Serial.print("  📍 Mode: ");
      Serial.println(status.deviceMode);
      Serial.print("  🔗 BLE: ");
      Serial.println(deviceConnected ? "Connected" : "Disconnected");
      Serial.print("  📞 Phone: ");
      Serial.println(strlen(config.phoneNumber) > 0 ? config.phoneNumber : "(not set)");
      Serial.print("  ⏱️ Interval: ");
      Serial.print(config.updateInterval);
      Serial.println(" seconds");
      Serial.print("  🚨 Alerts: ");
      Serial.println(config.alertEnabled ? "Enabled" : "Disabled");
      if (currentGPS.valid) {
        Serial.print("  🛰️ GPS: ");
        Serial.print(currentGPS.latitude);
        Serial.print(", ");
        Serial.println(currentGPS.longitude);
      } else {
        Serial.println("  🛰️ GPS: No valid fix");
      }
    } else if (command == "history") {
      // Show GPS history
      Serial.println("\n📍 GPS History:");
      int count = getGPSHistoryCount();
      Serial.print("  Total points: ");
      Serial.println(count);
      if (count > 0) {
        Serial.println("  Last 5 points:");
        Serial.println(getGPSHistoryJSON(5));
      }
    } else if (command == "clear") {
      // Clear GPS history
      clearGPSHistory();
      Serial.println("✅ GPS history cleared");
    } else if (command == "clearconfig") {
      // Clear configuration
      clearConfiguration();
      updateStatusCharacteristic();
    } else if (command == "sync") {
      // Force sync GPS history
      if (deviceConnected) {
        syncGPSHistory();
      } else {
        Serial.println("❌ No BLE device connected");
      }
    } else if (command == "help") {
      Serial.println("\n📚 Available Commands:");
      Serial.println("  test       - Test GPS acquisition and SMS sending");
      Serial.println("  gps        - Test GPS acquisition only");
      Serial.println("  sms        - Send test SMS");
      Serial.println("  status     - Show current status");
      Serial.println("  history    - Show GPS history");
      Serial.println("  clear      - Clear GPS history");
      Serial.println("  clearconfig- Clear all configuration");
      Serial.println("  sync       - Sync GPS history to app");
      Serial.println("  help       - Show this help menu");
    } else {
      Serial.print("❓ Unknown command: ");
      Serial.println(command);
      Serial.println("Type 'help' for available commands");
    }
  }
  
  // Periodic status update (every 10 seconds when connected)
  if (deviceConnected && (millis() - lastStatusUpdate > 10000)) {
    lastStatusUpdate = millis();
    updateStatusCharacteristic();
  }
  
  delay(10);
}