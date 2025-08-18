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

// Motion Sensor Library
#include "lsm6dsl_handler.h"
#include "esp_sleep.h"

// Pin Definitions
#define IR_SENSOR_PIN 15   // HW-201 IR sensor input
// Note: LSM6DSL pins are defined in lsm6dsl_handler.h
// INT1_PIN = GPIO4, INT2_PIN = GPIO2, SDA = 21, SCL = 22

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

// Motion Detection Variables
bool motionDetected = false;
unsigned long lastMotionTime = 0;
unsigned long lastSMSTime = 0;
bool inSleepMode = false;

// SMS tracking variables (need to be global for deep sleep wake)
RTC_DATA_ATTR bool disconnectSMSSent = false;  // Preserved across deep sleep
RTC_DATA_ATTR unsigned long lastDisconnectSMS = 0;  // Preserved across deep sleep

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
  
  // Check wake reason
  esp_sleep_wakeup_cause_t wakeup_reason = esp_sleep_get_wakeup_cause();
  
  if (wakeup_reason == ESP_SLEEP_WAKEUP_EXT1) {
    uint64_t wakeup_pin_mask = esp_sleep_get_ext1_wakeup_status();
    if (wakeup_pin_mask & (1ULL << INT1_PIN)) {
      Serial.println("🚨 Woken by motion on INT1");
    }
    if (wakeup_pin_mask & (1ULL << INT2_PIN)) {
      Serial.println("🚨 Woken by motion on INT2");
    }
    inSleepMode = false;
    lastMotionTime = millis();
    // Motion wake means first SMS should be sent
    disconnectSMSSent = false;
  } else if (wakeup_reason == ESP_SLEEP_WAKEUP_TIMER) {
    Serial.println("⏰ Woken by timer from deep sleep");
    // Timer wake means we need to send next SMS
    // Mark that first SMS was already sent  
    disconnectSMSSent = true;
    // Set lastDisconnectSMS to 0 to trigger immediate SMS send
    lastDisconnectSMS = 0;
    // Skip BLE initialization for timer wake - just send SMS and go back to sleep
  } else {
    Serial.println("🔄 Normal boot (not wake from sleep)");
    // Reset persistent variables on normal boot
    disconnectSMSSent = false;
    lastDisconnectSMS = 0;
  }
  
  // Initialize hardware
  pinMode(IR_SENSOR_PIN, INPUT);
  status.bleConnected = false;
  status.userPresent = false;
  status.deviceMode = "DISCONNECTED";
  status.lastGPSTime = 0;
  
  // Load configuration first
  loadConfiguration();
  
  // Check if this is a timer wake for SMS - handle differently
  if (wakeup_reason == ESP_SLEEP_WAKEUP_TIMER && disconnectSMSSent) {
    Serial.println("📱 Timer wake for SMS - minimal initialization");
    
    // Load GPS history for logging
    initGPSHistory();
    
    // Load last known GPS location
    if (loadGPSData(currentGPS)) {
      Serial.println("📍 Using stored GPS location");
    }
    
    // Initialize SIM7070G for SMS
    if (!initializeSIM7070G()) {
      Serial.println("⚠️ SIM7070G init failed - going back to sleep");
      // Go back to sleep if we can't send SMS
      esp_sleep_enable_timer_wakeup(config.updateInterval * 1000000ULL);
      esp_deep_sleep_start();
    }
    
    // Skip BLE and motion sensor init - we'll send SMS and go back to sleep
    deviceConnected = false;
    oldDeviceConnected = false;
    
  } else {
    // Normal initialization for all other wake reasons
    initBLE();
    initGPSHistory();
    
    // Load last known GPS location
    if (loadGPSData(currentGPS)) {
      Serial.println("📍 Loaded last GPS location:");
      Serial.print("   Lat: ");
      Serial.println(currentGPS.latitude);
      Serial.print("   Lon: ");
      Serial.println(currentGPS.longitude);
    } else {
      Serial.println("📍 No previous GPS data available");
      currentGPS.valid = false;
    }
    
    // Initialize LSM6DSL motion sensor
    Serial.println("Initializing LSM6DSL motion sensor...");
    if (motionSensor.begin()) {
      Serial.println("✅ LSM6DSL initialized");
      lastMotionTime = millis();
    } else {
      Serial.println("⚠️ LSM6DSL not found - motion detection disabled");
    }
    
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
  }
  
  Serial.println("\n📡 Ready for BLE connections...\n");
}

// ============================================================================
// MAIN LOOP
// ============================================================================
void loop() {
  static unsigned long lastStatusUpdate = 0;
  static unsigned long lastSleepCheck = 0;
  
  // Special handling for timer wake - send SMS and go back to sleep
  if (esp_sleep_get_wakeup_cause() == ESP_SLEEP_WAKEUP_TIMER && disconnectSMSSent) {
    Serial.println("\n📱 Sending scheduled SMS after timer wake...");
    
    // Try to get fresh GPS if old
    unsigned long currentTime = millis();
    if (!currentGPS.valid || (currentTime - status.lastGPSTime > 300000)) {
      Serial.println("🛰️ Acquiring fresh GPS fix...");
      if (acquireGPSFix(currentGPS, 30)) {
        status.lastGPSTime = currentTime;
        saveGPSData(currentGPS);
        logGPSPoint(currentGPS, 2);
      }
    }
    
    // Send SMS
    if (currentGPS.valid) {
      if (sendDisconnectSMS(config.phoneNumber, currentGPS, false, config.updateInterval)) {
        Serial.println("✅ Scheduled SMS sent successfully!");
      } else {
        Serial.println("❌ Failed to send scheduled SMS");
      }
    }
    
    // Go back to deep sleep for next interval
    Serial.println("💤 Going back to deep sleep until next SMS...");
    
    // IMPORTANT: Disable all wake sources first
    esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);
    
    // Make sure interrupt pins are not floating
    pinMode(INT1_PIN, INPUT_PULLDOWN);
    pinMode(INT2_PIN, INPUT_PULLDOWN);
    delay(100);
    
    // Configure timer-only wake
    esp_sleep_enable_timer_wakeup(config.updateInterval * 1000000ULL);
    Serial.flush();
    delay(100);
    esp_deep_sleep_start();
    // Code will not reach here - system restarts on wake
  }
  
  // Handle BLE connection changes
  if (!deviceConnected && oldDeviceConnected) {
    // BLE just disconnected
    Serial.println("🔴 BLE Disconnected - Initializing for SMS mode");
    
    // Only reset module on first BLE disconnect, not on wake from sleep
    if (!disconnectSMSSent) {
      Serial.println("🔄 Resetting SIM7070G module...");
      if (!resetModule()) {
        Serial.println("⚠️ Module reset failed");
      }
      delay(2000);
    }
    
    delay(500);
    pServer->startAdvertising();
    oldDeviceConnected = deviceConnected;
    disconnectSMSSent = false;  // Reset flag for new disconnection
    lastDisconnectSMS = 0;  // Reset timer
    motionSensor.setNormalMode();  // Enable motion detection
    motionSensor.resetMotionReference();
    lastMotionTime = millis();
    inSleepMode = false;
  }
  
  if (deviceConnected && !oldDeviceConnected) {
    // BLE just connected
    Serial.println("🟢 BLE Connected - Disabling motion detection");
    oldDeviceConnected = deviceConnected;
    disconnectSMSSent = false;  // Reset flag when reconnected
    updateStatusCharacteristic();
    motionSensor.setLowPowerMode();  // Put sensor in low power
    inSleepMode = false;
  }
  
  // Handle BLE Connected state - Keep MCU awake but sensors in low power
  if (deviceConnected) {
    // Keep LSM6DSL in low power mode to save battery
    // MCU stays awake to maintain BLE connection
    static bool sensorLowPowerSet = false;
    if (!sensorLowPowerSet) {
      motionSensor.setLowPowerMode();
      Serial.println("📉 BLE Connected - LSM6DSL in low power mode");
      sensorLowPowerSet = true;
    }
    
    // Reset flag when disconnected
    if (!deviceConnected) {
      sensorLowPowerSet = false;
    }
  }
  
  // Handle BLE Disconnected state - Motion detection and SMS
  if (!deviceConnected && strlen(config.phoneNumber) > 0 && config.alertEnabled) {
    unsigned long currentTime = millis();
    unsigned long intervalMillis = config.updateInterval * 1000;
    
    // Check for motion
    bool motion = motionSensor.detectMotion();
    
    if (motion) {
      lastMotionTime = currentTime;
      if (inSleepMode) {
        Serial.println("🚨 Motion detected - Waking from sleep");
        inSleepMode = false;
        motionSensor.clearMotionInterrupts();
      }
    }
    
    // SMS sending logic
    bool shouldSendSMS = false;
    
    if (!disconnectSMSSent) {
      // First disconnect - wait for motion before sending SMS
      if (motion) {
        shouldSendSMS = true;
        Serial.println("\n📱 Motion detected after disconnect - Sending initial SMS...");
      }
    } else if (currentTime - lastDisconnectSMS >= intervalMillis) {
      // Subsequent SMS - send based on timer interval only
      shouldSendSMS = true;
      Serial.println("\n📱 SMS interval reached - Sending location SMS...");
    }
    
    if (shouldSendSMS) {
      
      // Try to get current GPS location
      bool gpsAcquired = false;
      if (!currentGPS.valid || (currentTime - status.lastGPSTime > 300000)) {  // If no GPS or older than 5 minutes
        Serial.println("🛰️ Acquiring fresh GPS fix...");
        gpsAcquired = acquireGPSFix(currentGPS, 30);  // Try for 30 seconds
        if (gpsAcquired) {
          status.lastGPSTime = currentTime;
          saveGPSData(currentGPS);
          logGPSPoint(currentGPS, 2);  // Type 2 for disconnect event
        }
      } else {
        Serial.println("📍 Using cached GPS location");
        gpsAcquired = true;
      }
      
      // Send SMS with location (current or last known)
      if (gpsAcquired || currentGPS.valid) {
        if (sendDisconnectSMS(config.phoneNumber, currentGPS, status.userPresent, config.updateInterval)) {
          Serial.println("✅ Location SMS sent successfully!");
          disconnectSMSSent = true;
          lastDisconnectSMS = currentTime;
          lastSMSTime = currentTime;
        } else {
          Serial.println("❌ Failed to send location SMS");
        }
      } else {
        // No GPS available, send simple notification
        String message = "Bike Tracker Alert\n\n";
        message += "GPS location unavailable\n";
        message += "Last known location may be outdated\n\n";
        message += "Device Status\n";
        message += "User: ";
        message += status.userPresent ? "Present" : "Away";
        message += "\n";
        message += "SMS Interval: ";
        message += String(config.updateInterval);
        message += " seconds";
        
        if (sendSMS(config.phoneNumber, message)) {
          Serial.println("✅ Alert SMS sent (no GPS)");
          disconnectSMSSent = true;
          lastDisconnectSMS = currentTime;
          lastSMSTime = currentTime;
        } else {
          Serial.println("❌ Failed to send alert SMS");
        }
      }
    }
    
    // Sleep management when disconnected
    if (!motion && !inSleepMode && motionSensor.getTimeSinceLastMotion() > NO_MOTION_SLEEP_TIME) {
      Serial.println("😴 No motion for 10 seconds - Preparing for sleep...");
      
      // Configure wake sources based on whether first SMS has been sent
      if (!disconnectSMSSent) {
        // First disconnect - wake on motion only
        Serial.println("🔍 First disconnect - configuring wake on motion only");
        
        // Configure motion wake
        motionSensor.configureWakeOnMotion();
        
        // IMPORTANT: Clear any pending interrupts before enabling wake
        delay(100);
        motionSensor.clearMotionInterrupts();
        delay(100);
        
        // Check interrupt pins are LOW before sleep
        if (digitalRead(INT1_PIN) == HIGH || digitalRead(INT2_PIN) == HIGH) {
          Serial.println("⚠️ Interrupt pins still HIGH, clearing again...");
          motionSensor.clearMotionInterrupts();
          delay(200);
        }
        
        // Disable all wake sources first
        esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);
        
        // Configure only EXT1 wake for motion
        uint64_t ext_wakeup_pin_mask = (1ULL << INT1_PIN) | (1ULL << INT2_PIN);
        esp_sleep_enable_ext1_wakeup(ext_wakeup_pin_mask, ESP_EXT1_WAKEUP_ANY_HIGH);
        
        Serial.println("💤 Entering light sleep...");
        Serial.println("Will wake on: Motion detection");
      } else {
        // After first SMS - wake on timer only for subsequent SMS
        unsigned long timeUntilNextSMS = intervalMillis - (currentTime - lastDisconnectSMS);
        
        // IMPORTANT: Disable all wake sources first
        esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);
        
        // Disable motion sensor interrupts completely before deep sleep
        motionSensor.setPowerDownMode();  // Power down the sensor
        
        // Make sure interrupt pins are not floating
        pinMode(INT1_PIN, INPUT_PULLDOWN);  // Pull down to prevent false triggers
        pinMode(INT2_PIN, INPUT_PULLDOWN);
        delay(100);
        
        // Now configure timer-only wake
        if (timeUntilNextSMS > 0 && timeUntilNextSMS < intervalMillis) {
          esp_sleep_enable_timer_wakeup(timeUntilNextSMS * 1000ULL);  // Convert to microseconds
          Serial.printf("⏰ Timer wake set for %lu seconds (next SMS)\n", timeUntilNextSMS / 1000);
        } else {
          esp_sleep_enable_timer_wakeup(intervalMillis * 1000ULL);
          Serial.printf("⏰ Timer wake set for %d seconds (interval)\n", config.updateInterval);
        }
        
        Serial.println("💤 Entering DEEP sleep for power savings...");
        Serial.println("Will wake on: Timer only");
        Serial.println("Note: System will restart on wake");
        Serial.flush();
        delay(100);
        
        // Deep sleep for better power savings after first SMS
        esp_deep_sleep_start();
        // Code will not reach here - system restarts on wake
      }
      
      Serial.flush();
      delay(100);
      
      // Light sleep (only for first disconnect waiting for motion)
      if (!disconnectSMSSent) {
        esp_light_sleep_start();
        
        // Check wake reason after light sleep
        esp_sleep_wakeup_cause_t wakeup_reason = esp_sleep_get_wakeup_cause();
        bool shouldStayAwake = true;
        
        if (wakeup_reason == ESP_SLEEP_WAKEUP_TIMER) {
          Serial.println("⏰ Woken by timer for next SMS");
          // For timer wake after first SMS, don't need motion
        } else if (wakeup_reason == ESP_SLEEP_WAKEUP_EXT1) {
        Serial.println("🚨 Wake interrupt triggered");
        
        // Clear interrupts first
        motionSensor.clearMotionInterrupts();
        delay(100);
        
        // Validate motion by checking actual sensor data
        bool realMotion = false;
        for (int i = 0; i < 5; i++) {
          if (motionSensor.getMotionDelta() > MOTION_THRESHOLD_LOW) {
            realMotion = true;
            break;
          }
          delay(50);
        }
        
        if (realMotion) {
          Serial.println("✅ Real motion confirmed");
          lastMotionTime = millis();
        } else {
          Serial.println("❌ False wake - no real motion detected");
          // Flag to go back to sleep
          shouldStayAwake = false;
        }
      }
      
      if (shouldStayAwake) {
        inSleepMode = false;
        
        // Re-initialize SIM7070G after wake from sleep
        Serial.println("🔄 Re-initializing SIM7070G after wake...");
        if (initializeSIM7070G()) {
          Serial.println("✅ SIM7070G re-initialized");
        } else {
          Serial.println("⚠️ SIM7070G re-initialization failed");
        }
      } else {
        // False wake - keep sleep mode active to go back to sleep
        inSleepMode = true;
        lastMotionTime = 0;  // Reset to trigger sleep again
      }
      
        // Restart BLE advertising after wake
        if (!deviceConnected && pServer && shouldStayAwake) {
          pServer->startAdvertising();
          Serial.println("📡 BLE advertising restarted");
        }
      }  // End of light sleep handling for first disconnect
    }  // End of no motion sleep condition
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