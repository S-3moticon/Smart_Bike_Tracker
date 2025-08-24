// Smart Bike Tracker - ESP32 MCU Code (Optimized)
// Version: 2.0 - Performance Optimized

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <Preferences.h>
#include "esp_sleep.h"
#include "nvs_flash.h"
#include "esp_gap_ble_api.h"
#include "esp_gatt_common_api.h"

#include "ble_protocol.h"
#include "sim7070g.h"
#include "gps_handler.h"
#include "sms_handler.h"
#include "lsm6dsl_handler.h"

// ============================================================================
// CONSTANTS & CONFIGURATION
// ============================================================================
#define IR_SENSOR_PIN 13
#define BOOT_BLE_GRACE_PERIOD 30000
#define STATUS_UPDATE_INTERVAL 5000
#define IR_POLL_INTERVAL 250
#define BLE_MTU_SIZE 512
#define MAX_GPS_HISTORY_POINTS 7
#define GPS_CACHE_TIMEOUT 300000  // 5 minutes

// ============================================================================
// GLOBAL STATE VARIABLES  
// ============================================================================
BLEServer* pServer = nullptr;
BLECharacteristic* pConfigChar = nullptr;
BLECharacteristic* pStatusChar = nullptr;
BLECharacteristic* pHistoryChar = nullptr;
BLECharacteristic* pCommandChar = nullptr;

volatile bool deviceConnected = false;
bool oldDeviceConnected = false;
Preferences preferences;

struct Config {
  char phoneNumber[20];
  uint16_t updateInterval;
  bool alertEnabled;
  float motionSensitivity;
} config = {"", 600, true, 0.5};

struct Status {
  bool bleConnected;
  bool userPresent;
  String deviceMode;
  unsigned long lastGPSTime;
} status = {false, false, "DISCONNECTED", 0};

GPSData currentGPS;
extern LSM6DSL motionSensor;  // Defined in lsm6dsl_handler.cpp

// Timing variables
unsigned long lastMotionTime = 0;
unsigned long lastSMSTime = 0;
unsigned long bootTime = 0;
bool gracePeriodActive = false;
bool inSleepMode = false;

// RTC Memory (preserved across deep sleep)
RTC_DATA_ATTR bool disconnectSMSSent = false;
RTC_DATA_ATTR unsigned long lastDisconnectSMS = 0;
RTC_DATA_ATTR bool isTimerWake = false;
RTC_DATA_ATTR bool motionWakeNeedsSMS = false;
RTC_DATA_ATTR bool motionSensorInitialized = false;

// Forward declarations
void updateStatusCharacteristic();
void syncGPSHistory();
void clearConfiguration();
void parseConfigJSON(const String& json);
void sendGPSHistoryPage(int page);
void stopBLEAdvertising();
void startBLEAdvertising();
void applyMotionSensitivity();
void readIRSensor();
float getCurrentMotionThreshold();
void testGPSAndSMS();
bool handleDisconnectedSMS();
void enterSleepMode();
void processSerialCommand(const String& cmd);

// ============================================================================
// BLE CALLBACKS (Optimized)
// ============================================================================
class ServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) override {
      deviceConnected = true;
      status.bleConnected = true;
      status.userPresent = (digitalRead(IR_SENSOR_PIN) == LOW);
      updateStatusCharacteristic();
      
      delay(1000);
      syncGPSHistory();
    }

    void onDisconnect(BLEServer* pServer) override {
      deviceConnected = false;
      status.bleConnected = false;
      status.deviceMode = "DISCONNECTED";
    }
};

class ConfigCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pChar) override {
      String value = pChar->getValue();
      if (value.length() == 0) return;
      
      // Handle clear command
      if (value == "CLEAR" || value == "{\"clear\":true}") {
        clearConfiguration();
        return;
      }
      
      // Parse configuration JSON
      parseConfigJSON(value);
    }
};

class CommandCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pChar) override {
      String cmd = pChar->getValue().c_str();
      
      if (cmd.startsWith("GPS_PAGE:")) {
        sendGPSHistoryPage(cmd.substring(9).toInt());
      } else if (cmd == "SYNC") {
        syncGPSHistory();
      } else if (cmd == "CLEAR_HISTORY") {
        clearGPSHistory();
      }
    }
};

// ============================================================================
// CONFIGURATION MANAGEMENT (Optimized)
// ============================================================================
void loadConfiguration() {
  preferences.begin("bike-tracker", true);  // Read-only
  preferences.getString("phone", config.phoneNumber, sizeof(config.phoneNumber));
  config.updateInterval = preferences.getUShort("interval", 600);
  config.alertEnabled = preferences.getBool("alerts", true);
  config.motionSensitivity = preferences.getFloat("sensitivity", 0.5);
  preferences.end();
}

void saveConfiguration() {
  preferences.begin("bike-tracker", false);
  preferences.putString("phone", config.phoneNumber);
  preferences.putUShort("interval", config.updateInterval);
  preferences.putBool("alerts", config.alertEnabled);
  preferences.putFloat("sensitivity", config.motionSensitivity);
  preferences.end();
}

void clearConfiguration() {
  memset(config.phoneNumber, 0, sizeof(config.phoneNumber));
  config.updateInterval = 600;
  config.alertEnabled = true;
  config.motionSensitivity = 0.5;
  
  preferences.begin("bike-tracker", false);
  preferences.clear();
  preferences.end();
  
  if (motionSensorInitialized) {
    applyMotionSensitivity();
  }
  updateStatusCharacteristic();
}

void parseConfigJSON(const String& json) {
  bool changed = false;
  bool isCompact = json.indexOf("\"p\":") >= 0;
  
  // Extract phone number
  int phoneStart = isCompact ? json.indexOf("\"p\":\"") + 5 : json.indexOf("\"phone_number\":\"") + 16;
  if (phoneStart >= 5) {
    int phoneEnd = json.indexOf("\"", phoneStart);
    if (phoneEnd >= phoneStart) {
      String phone = json.substring(phoneStart, phoneEnd);
      if (phone.length() == 0) {
        clearConfiguration();
        return;
      }
      strncpy(config.phoneNumber, phone.c_str(), sizeof(config.phoneNumber) - 1);
      changed = true;
    }
  }
  
  // Extract update interval
  int intervalStart = isCompact ? json.indexOf("\"i\":") + 4 : json.indexOf("\"update_interval\":") + 18;
  if (intervalStart >= 4) {
    int intervalEnd = json.indexOf(",", intervalStart);
    if (intervalEnd < 0) intervalEnd = json.indexOf("}", intervalStart);
    if (intervalEnd > intervalStart) {
      int interval = json.substring(intervalStart, intervalEnd).toInt();
      if (interval >= 60 && interval <= 3600) {
        config.updateInterval = interval;
        changed = true;
      }
    }
  }
  
  // Extract alert enabled
  int alertStart = isCompact ? json.indexOf("\"a\":") + 4 : json.indexOf("\"alert_enabled\":") + 16;
  if (alertStart >= 4) {
    String alertSection = json.substring(alertStart, alertStart + 10);
    config.alertEnabled = isCompact ? 
      (alertSection.indexOf("1") >= 0) : 
      (alertSection.indexOf("true") >= 0);
    changed = true;
  }
  
  // Extract motion sensitivity
  int sensStart = isCompact ? json.indexOf("\"s\":") + 4 : json.indexOf("\"motion_sensitivity\":") + 21;
  if (sensStart >= 4) {
    int sensEnd = json.indexOf(',', sensStart);
    if (sensEnd < 0) sensEnd = json.indexOf('}', sensStart);
    if (sensEnd > sensStart) {
      float sens = json.substring(sensStart, sensEnd).toFloat();
      if (sens >= 0.1 && sens <= 1.0) {
        config.motionSensitivity = sens;
        if (motionSensorInitialized) applyMotionSensitivity();
        changed = true;
      }
    }
  }
  
  if (changed) {
    saveConfiguration();
    updateStatusCharacteristic();
  }
}

// ============================================================================
// SENSOR MANAGEMENT (Optimized)
// ============================================================================
inline void readIRSensor() {
  static bool lastUserPresent = false;
  bool currentUserPresent = (digitalRead(IR_SENSOR_PIN) == LOW);
  
  if (currentUserPresent != lastUserPresent) {
    status.userPresent = currentUserPresent;
    lastUserPresent = currentUserPresent;
    
    status.deviceMode = status.bleConnected ? 
      (status.userPresent ? "READY" : "AWAY") : "DISCONNECTED";
    
    if (deviceConnected) {
      updateStatusCharacteristic();
    }
  }
}

void updateStatusCharacteristic() {
  if (!pStatusChar) return;
  
  char json[256];
  snprintf(json, sizeof(json),
    "{\"ble\":%s,\"phone_configured\":%s,\"phone\":\"%s\",\"interval\":%d,"
    "\"alerts\":%s,\"user_present\":%s,\"mode\":\"%s\","
    "\"gps_valid\":%s,\"lat\":\"%s\",\"lon\":\"%s\"}",
    status.bleConnected ? "true" : "false",
    strlen(config.phoneNumber) > 0 ? "true" : "false",
    config.phoneNumber,
    config.updateInterval,
    config.alertEnabled ? "true" : "false",
    status.userPresent ? "true" : "false",
    status.deviceMode.c_str(),
    currentGPS.valid ? "true" : "false",
    currentGPS.valid ? currentGPS.latitude.c_str() : "",
    currentGPS.valid ? currentGPS.longitude.c_str() : "");
  
  pStatusChar->setValue(json);
  if (deviceConnected) pStatusChar->notify();
}

void applyMotionSensitivity() {
  if (!motionSensorInitialized) return;
  
  float threshold = config.motionSensitivity <= 0.3 ? MOTION_THRESHOLD_HIGH :
                    config.motionSensitivity <= 0.7 ? MOTION_THRESHOLD_MED :
                    MOTION_THRESHOLD_LOW;
  
  motionSensor.setMotionThreshold(threshold);
}

// ============================================================================
// GPS & SMS FUNCTIONS (Optimized)
// ============================================================================
void syncGPSHistory() {
  if (!deviceConnected || !pHistoryChar) return;
  
  String historyJson = getGPSHistoryJSON(MAX_GPS_HISTORY_POINTS);
  if (historyJson.length() > BLE_MTU_SIZE) {
    historyJson = getGPSHistoryJSON(5);
  }
  
  pHistoryChar->setValue(historyJson.c_str());
  pHistoryChar->notify();
}

void sendGPSHistoryPage(int page) {
  if (!pHistoryChar) return;
  
  const int POINTS_PER_PAGE = 5;
  String json = getGPSHistoryPageJSON(page, POINTS_PER_PAGE);
  
  pHistoryChar->setValue(json.c_str());
  pHistoryChar->notify();
}

bool handleDisconnectedSMS() {
  if (strlen(config.phoneNumber) == 0 || !config.alertEnabled) return false;
  
  unsigned long currentTime = millis();
  unsigned long intervalMillis = config.updateInterval * 1000;
  
  // Handle motion wake SMS
  if (motionWakeNeedsSMS) {
    stopBLEAdvertising();
    
    bool gpsValid = currentGPS.valid && (currentTime - status.lastGPSTime < GPS_CACHE_TIMEOUT);
    if (!gpsValid) {
      gpsValid = acquireGPSFix(currentGPS, 30);
      if (gpsValid) {
        status.lastGPSTime = currentTime;
        saveGPSData(currentGPS);
        logGPSPoint(currentGPS, 2);
      }
    }
    
    if (sendDisconnectSMS(config.phoneNumber, currentGPS, status.userPresent, config.updateInterval)) {
      disconnectSMSSent = true;
      lastDisconnectSMS = currentTime;
      motionWakeNeedsSMS = false;
      return true;
    }
  }
  
  // Check for regular interval SMS
  bool shouldSend = (!disconnectSMSSent && motionSensor.detectMotion()) ||
                    (disconnectSMSSent && (currentTime - lastDisconnectSMS >= intervalMillis));
  
  if (shouldSend) {
    stopBLEAdvertising();
    
    if (!isSIM7070GInitialized() && !initializeSIM7070G()) {
      return false;
    }
    
    bool gpsValid = currentGPS.valid && (currentTime - status.lastGPSTime < GPS_CACHE_TIMEOUT);
    if (!gpsValid) {
      gpsValid = acquireGPSFix(currentGPS, 30);
      if (gpsValid) {
        status.lastGPSTime = currentTime;
        saveGPSData(currentGPS);
        logGPSPoint(currentGPS, 2);
      }
    }
    
    if (sendDisconnectSMS(config.phoneNumber, currentGPS, status.userPresent, config.updateInterval)) {
      disconnectSMSSent = true;
      lastDisconnectSMS = currentTime;
      return true;
    }
  }
  
  return false;
}

// ============================================================================
// BLE MANAGEMENT (Optimized)
// ============================================================================
void initBLE() {
  char deviceName[32];
  sprintf(deviceName, "%s%02X%02X", DEVICE_NAME_PREFIX, 
          (uint8_t)(ESP.getEfuseMac() >> 8), 
          (uint8_t)(ESP.getEfuseMac()));
  
  BLEDevice::init(deviceName);
  BLEDevice::setMTU(BLE_MTU_SIZE);
  
  // Configure Data Length Extension
  esp_bd_addr_t bd_addr = {0};
  esp_ble_gap_set_pkt_data_len(bd_addr, 251);
  esp_ble_gap_set_prefer_conn_params(bd_addr, 0x06, 0x06, 0x00, 0x0190);
  
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());
  
  BLEService *pService = pServer->createService(SERVICE_UUID);
  
  // Config characteristic
  pConfigChar = pService->createCharacteristic(CONFIG_CHAR_UUID,
                    BLECharacteristic::PROPERTY_WRITE);
  pConfigChar->setCallbacks(new ConfigCallbacks());
  
  // Status characteristic  
  pStatusChar = pService->createCharacteristic(STATUS_CHAR_UUID,
                    BLECharacteristic::PROPERTY_READ | 
                    BLECharacteristic::PROPERTY_NOTIFY);
  pStatusChar->addDescriptor(new BLE2902());
  
  // History characteristic
  pHistoryChar = pService->createCharacteristic(HISTORY_CHAR_UUID,
                    BLECharacteristic::PROPERTY_READ |
                    BLECharacteristic::PROPERTY_NOTIFY);
  pHistoryChar->addDescriptor(new BLE2902());
  
  // Command characteristic
  pCommandChar = pService->createCharacteristic(COMMAND_CHAR_UUID,
                    BLECharacteristic::PROPERTY_WRITE);
  pCommandChar->setCallbacks(new CommandCallbacks());
  
  // Initialize history
  String initialHistory = getGPSHistoryJSON(MAX_GPS_HISTORY_POINTS);
  if (initialHistory.length() > BLE_MTU_SIZE) {
    initialHistory = getGPSHistoryJSON(5);
  }
  pHistoryChar->setValue(initialHistory.c_str());
  
  pService->start();
  
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  BLEDevice::startAdvertising();
}

void stopBLEAdvertising() {
  if (pServer) {
    pServer->getAdvertising()->stop();
  }
}

void startBLEAdvertising() {
  if (pServer) {
    pServer->startAdvertising();
  }
}

// ============================================================================
// SLEEP MANAGEMENT (Optimized)
// ============================================================================
void enterSleepMode() {
  if (inSleepMode) return;
  
  if (!disconnectSMSSent) {
    // First disconnect - wake on motion only
    if (motionSensorInitialized) {
      motionSensor.configureWakeOnMotion();
      delay(100);
      motionSensor.clearMotionInterrupts();
    }
    
    esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);
    uint64_t ext_wakeup_pin_mask = (1ULL << INT1_PIN) | (1ULL << INT2_PIN);
    esp_sleep_enable_ext1_wakeup(ext_wakeup_pin_mask, ESP_EXT1_WAKEUP_ANY_HIGH);
    
    esp_light_sleep_start();
    
    // Check wake reason
    esp_sleep_wakeup_cause_t wakeup_reason = esp_sleep_get_wakeup_cause();
    if (wakeup_reason == ESP_SLEEP_WAKEUP_EXT1) {
      if (motionSensorInitialized) {
        motionSensor.clearMotionInterrupts();
        if (motionSensor.getMotionDelta() > getCurrentMotionThreshold()) {
          lastMotionTime = millis();
          motionWakeNeedsSMS = true;
          inSleepMode = false;
          return;
        }
      }
    }
  } else {
    // After first SMS - deep sleep with timer wake
    unsigned long timeUntilNextSMS = config.updateInterval * 1000 - (millis() - lastDisconnectSMS);
    
    esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);
    
    if (motionSensorInitialized) {
      motionSensor.setPowerDownMode();
    }
    
    pinMode(INT1_PIN, INPUT_PULLDOWN);
    pinMode(INT2_PIN, INPUT_PULLDOWN);
    delay(100);
    
    esp_sleep_enable_timer_wakeup(min(timeUntilNextSMS, config.updateInterval * 1000UL) * 1000ULL);
    esp_deep_sleep_start();
  }
  
  inSleepMode = true;
}

float getCurrentMotionThreshold() {
  return config.motionSensitivity <= 0.3 ? MOTION_THRESHOLD_HIGH :
         config.motionSensitivity <= 0.7 ? MOTION_THRESHOLD_MED :
         MOTION_THRESHOLD_LOW;
}

// ============================================================================
// COMMAND PROCESSING (Optimized)
// ============================================================================
void processSerialCommand(const String& cmd) {
  static const struct {
    const char* command;
    void (*handler)();
  } commands[] = {
    {"test", []() { testGPSAndSMS(); }},
    {"gps", []() { 
      if (acquireGPSFix(currentGPS, 20)) {
        Serial.printf("✅ GPS: %s, %s\n", currentGPS.latitude.c_str(), currentGPS.longitude.c_str());
        saveGPSData(currentGPS);
        logGPSPoint(currentGPS, 1);
      }
    }},
    {"sms", []() {
      if (strlen(config.phoneNumber) > 0) {
        sendTestSMS(config.phoneNumber);
      }
    }},
    {"status", []() {
      Serial.printf("\n📊 Status:\n  👤 User: %s\n  📍 Mode: %s\n  🔗 BLE: %s\n  📞 Phone: %s\n  ⏱️ Interval: %ds\n",
        status.userPresent ? "Present" : "Away",
        status.deviceMode.c_str(),
        deviceConnected ? "Connected" : "Disconnected",
        strlen(config.phoneNumber) > 0 ? config.phoneNumber : "(not set)",
        config.updateInterval);
    }},
    {"history", []() {
      Serial.printf("\n📍 GPS History: %d points\n", getGPSHistoryCount());
      if (getGPSHistoryCount() > 0) {
        Serial.println(getGPSHistoryJSON(5));
      }
    }},
    {"clear", []() { clearGPSHistory(); }},
    {"clearconfig", []() { clearConfiguration(); }},
    {"sync", []() { if (deviceConnected) syncGPSHistory(); }},
    {"help", []() {
      Serial.println("\n📚 Commands: test, gps, sms, status, history, clear, clearconfig, sync, help");
    }}
  };
  
  for (const auto& c : commands) {
    if (cmd == c.command) {
      c.handler();
      return;
    }
  }
  Serial.println("❓ Unknown command. Type 'help' for commands.");
}

void testGPSAndSMS() {
  if (strlen(config.phoneNumber) == 0) {
    Serial.println("❌ No phone number configured");
    return;
  }
  
  bool gotFix = acquireGPSFix(currentGPS, 20);
  if (gotFix) {
    Serial.printf("✅ GPS: %s, %s\n", currentGPS.latitude.c_str(), currentGPS.longitude.c_str());
    saveGPSData(currentGPS);
    status.lastGPSTime = millis();
    logGPSPoint(currentGPS, 1);
    sendLocationSMS(config.phoneNumber, currentGPS, ALERT_TEST);
  } else if (loadGPSData(currentGPS)) {
    sendLocationSMS(config.phoneNumber, currentGPS, ALERT_TEST);
  } else {
    sendTestSMS(config.phoneNumber);
  }
}

// ============================================================================
// SETUP
// ============================================================================
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  // Initialize NVS
  esp_err_t ret = nvs_flash_init();
  if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
    ESP_ERROR_CHECK(nvs_flash_erase());
    ret = nvs_flash_init();
  }
  
  // Check wake reason
  esp_sleep_wakeup_cause_t wakeup_reason = esp_sleep_get_wakeup_cause();
  
  switch(wakeup_reason) {
    case ESP_SLEEP_WAKEUP_EXT1:
      lastMotionTime = millis();
      if (disconnectSMSSent) lastDisconnectSMS = 0;
      break;
    case ESP_SLEEP_WAKEUP_TIMER:
      isTimerWake = true;
      lastDisconnectSMS = 0;
      break;
    default:
      disconnectSMSSent = false;
      lastDisconnectSMS = 0;
      isTimerWake = false;
      motionWakeNeedsSMS = false;
      motionSensorInitialized = false;
  }
  
  // Initialize hardware
  pinMode(IR_SENSOR_PIN, INPUT);
  loadConfiguration();
  
  bool hasValidConfig = (strlen(config.phoneNumber) > 0 && config.alertEnabled);
  
  // Handle timer wake
  if (isTimerWake && hasValidConfig) {
    stopBLEAdvertising();
    
    if (acquireGPSFix(currentGPS, 30)) {
      saveGPSData(currentGPS);
      logGPSPoint(currentGPS, 2);
    }
    
    sendDisconnectSMS(config.phoneNumber, currentGPS, false, config.updateInterval);
    
    isTimerWake = false;
    esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);
    esp_sleep_enable_timer_wakeup(config.updateInterval * 1000000ULL);
    esp_deep_sleep_start();
  }
  
  // Initialize BLE
  if (wakeup_reason != ESP_SLEEP_WAKEUP_TIMER || !disconnectSMSSent) {
    initBLE();
  }
  initGPSHistory();
  
  // Load last GPS
  loadGPSData(currentGPS);
  
  // Initialize motion sensor
  if (motionSensor.begin()) {
    motionSensorInitialized = true;
    applyMotionSensitivity();
    lastMotionTime = millis();
  }
  
  // Initialize SIM7070G if configured
  if (hasValidConfig && wakeup_reason == ESP_SLEEP_WAKEUP_UNDEFINED) {
    if (initializeSIM7070G()) {
      disableRF();
    }
  }
  
  // Start grace period on boot
  if (hasValidConfig && !deviceConnected && wakeup_reason == ESP_SLEEP_WAKEUP_UNDEFINED) {
    bootTime = millis();
    gracePeriodActive = true;
  }
}

// ============================================================================
// MAIN LOOP (Optimized)
// ============================================================================
void loop() {
  static unsigned long lastStatusUpdate = 0;
  static unsigned long lastIRCheck = 0;
  unsigned long currentTime = millis();
  
  // Handle grace period
  if (gracePeriodActive) {
    if (deviceConnected) {
      gracePeriodActive = false;
      oldDeviceConnected = true;
    } else if (currentTime - bootTime > BOOT_BLE_GRACE_PERIOD) {
      gracePeriodActive = false;
      stopBLEAdvertising();
    }
  }
  
  // Handle connection state changes
  if (deviceConnected != oldDeviceConnected) {
    if (!deviceConnected) {
      // Just disconnected
      stopBLEAdvertising();
      if (!motionSensorInitialized && motionSensor.begin()) {
        motionSensorInitialized = true;
        applyMotionSensitivity();
      }
      if (motionSensorInitialized) {
        motionSensor.setNormalMode();
        motionSensor.resetMotionReference();
      }
      lastMotionTime = currentTime;
      inSleepMode = false;
    } else {
      // Just connected
      if (!motionSensorInitialized && motionSensor.begin()) {
        motionSensorInitialized = true;
        applyMotionSensitivity();
      }
      if (!isTimerWake) disconnectSMSSent = false;
      updateStatusCharacteristic();
      if (motionSensorInitialized) {
        motionSensor.setLowPowerMode();
      }
    }
    oldDeviceConnected = deviceConnected;
  }
  
  // Handle disconnected state
  if (!deviceConnected && strlen(config.phoneNumber) > 0 && config.alertEnabled) {
    handleDisconnectedSMS();
    
    // Check for sleep conditions
    if (!isTimerWake && !gracePeriodActive && !inSleepMode && 
        motionSensorInitialized && 
        motionSensor.getTimeSinceLastMotion() > NO_MOTION_SLEEP_TIME) {
      enterSleepMode();
    }
  }
  
  // Fast IR sensor polling
  if (currentTime - lastIRCheck > IR_POLL_INTERVAL) {
    lastIRCheck = currentTime;
    readIRSensor();
  }
  
  // Periodic status updates
  if (deviceConnected && (currentTime - lastStatusUpdate > STATUS_UPDATE_INTERVAL)) {
    lastStatusUpdate = currentTime;
    updateStatusCharacteristic();
  }
  
  // Process serial commands
  if (Serial.available() > 0) {
    String command = Serial.readStringUntil('\n');
    command.trim();
    processSerialCommand(command);
  }
  
  delay(10);
}