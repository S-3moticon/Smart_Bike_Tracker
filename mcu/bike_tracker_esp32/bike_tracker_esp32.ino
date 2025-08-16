// ESP32 BLE Libraries
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <Preferences.h>  // For persistent storage
#include "ble_protocol.h"

// Pin Definitions
#define LED_PIN 2          // Built-in LED for status indication

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
  char lastConfig[100];     // Last received config for debugging
  unsigned long configTime; // Time of last config update
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
      digitalWrite(LED_PIN, HIGH);  // LED on when connected
      Serial.println("✅ BLE Client Connected");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      status.bleConnected = false;
      digitalWrite(LED_PIN, LOW);   // LED off when disconnected
      Serial.println("❌ BLE Client Disconnected");
    }
};

// ============================================================================
// Configuration Characteristic Callbacks
// ============================================================================
class ConfigCharCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String value = pCharacteristic->getValue();
      
      if (value.length() > 0) {
        Serial.println("\n📥 Configuration Received:");
        Serial.println("=====================================");
        Serial.print("Raw data: ");
        Serial.println(value.c_str());
        Serial.print("Data length: ");
        Serial.println(value.length());
        
        // Store raw config for debugging
        strncpy(status.lastConfig, value.c_str(), sizeof(status.lastConfig) - 1);
        status.configTime = millis();
        
        // Parse JSON manually
        String jsonStr = String(value.c_str());
        bool configChanged = false;
        
        // Extract phone number
        int phoneStart = jsonStr.indexOf("\"phone_number\":\"");
        if (phoneStart >= 0) {
          phoneStart += 16;  // Length of "phone_number":"
          int phoneEnd = jsonStr.indexOf("\"", phoneStart);
          if (phoneEnd > phoneStart) {
            String phone = jsonStr.substring(phoneStart, phoneEnd);
            if (phone.length() > 0 && phone.length() < sizeof(config.phoneNumber)) {
              strncpy(config.phoneNumber, phone.c_str(), sizeof(config.phoneNumber) - 1);
              config.phoneNumber[sizeof(config.phoneNumber) - 1] = '\0';
              configChanged = true;
              Serial.print("📞 Phone Number: ");
              Serial.println(config.phoneNumber);
            }
          }
        }
        
        // Extract update interval
        int intervalStart = jsonStr.indexOf("\"update_interval\":");
        if (intervalStart >= 0) {
          intervalStart += 18;  // Length of "update_interval":
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
              Serial.print("⏱️ Update Interval: ");
              Serial.print(config.updateInterval);
              Serial.println(" seconds");
            }
          }
        }
        
        // Extract alert enabled flag
        int alertStart = jsonStr.indexOf("\"alert_enabled\":");
        if (alertStart >= 0) {
          alertStart += 16;  // Length of "alert_enabled":
          String alertSection = jsonStr.substring(alertStart, alertStart + 10);
          config.alertEnabled = (alertSection.indexOf("true") >= 0);
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
// Status Update
// ============================================================================
void updateStatusCharacteristic() {
  if (pStatusChar) {
    char jsonBuffer[256];
    snprintf(jsonBuffer, sizeof(jsonBuffer),
             "{\"ble_connected\":%s,\"phone_configured\":%s,\"phone\":\"%s\",\"interval\":%d,\"alerts\":%s,\"last_config_time\":%lu}",
             status.bleConnected ? "true" : "false",
             strlen(config.phoneNumber) > 0 ? "true" : "false",
             config.phoneNumber,
             config.updateInterval,
             config.alertEnabled ? "true" : "false",
             status.configTime);
    
    pStatusChar->setValue(jsonBuffer);
    
    if (deviceConnected) {
      pStatusChar->notify();
      Serial.println("📤 Status update sent to app");
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
  
  // Create BLE server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  
  // Create BLE service
  BLEService *pService = pServer->createService(SERVICE_UUID);
  
  // Create Config characteristic (WRITE)
  pConfigChar = pService->createCharacteristic(
                    CONFIG_CHAR_UUID,
                    BLECharacteristic::PROPERTY_WRITE
                  );
  pConfigChar->setCallbacks(new ConfigCharCallbacks());
  
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
  
  // Configure LED
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  
  // Initialize status
  status.bleConnected = false;
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
    updateStatusCharacteristic();
    
    // Print current configuration
    Serial.println("📊 Current Configuration:");
    Serial.print("  Phone: ");
    Serial.println(strlen(config.phoneNumber) > 0 ? config.phoneNumber : "(not set)");
    Serial.print("  Interval: ");
    Serial.print(config.updateInterval);
    Serial.println(" seconds");
    Serial.print("  Alerts: ");
    Serial.println(config.alertEnabled ? "Enabled" : "Disabled");
  }
  
  delay(10);
}