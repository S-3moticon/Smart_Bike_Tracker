// Smart Bike Tracker - ESP32 MCU Code
// Version: 3.0 - Cleaned & Optimized

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <Preferences.h>
#include "esp_sleep.h"
#include "nvs_flash.h"

#include "ble_protocol.h"
#include "sim7070g.h"
#include "gps_handler.h"
#include "sms_handler.h"
#include "lsm6dsl_handler.h"

// Constants
#define IR_SENSOR_PIN 13
#define BOOT_BLE_GRACE_PERIOD 30000
#define STATUS_UPDATE_INTERVAL 5000
#define IR_POLL_INTERVAL 250
#define BLE_MTU_SIZE 512
#define MAX_GPS_HISTORY_POINTS 7
#define GPS_CACHE_TIMEOUT 300000

// Global Variables
BLEServer* pServer = nullptr;
BLECharacteristic* pConfigChar = nullptr;
BLECharacteristic* pStatusChar = nullptr;
BLECharacteristic* pHistoryChar = nullptr;
BLECharacteristic* pCommandChar = nullptr;

volatile bool deviceConnected = false;
bool oldDeviceConnected = false;
Preferences preferences;

struct {
  char phoneNumber[20];
  uint16_t updateInterval;
  bool alertEnabled;
  float motionSensitivity;
} config = {"", 600, true, 0.5};

struct {
  bool bleConnected;
  bool userPresent;
  String deviceMode;
  unsigned long lastGPSTime;
} status = {false, false, "DISCONNECTED", 0};

GPSData currentGPS;
extern LSM6DSL motionSensor;

unsigned long lastMotionTime = 0;
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
void initBLE();


// BLE Callbacks
class ServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) override {
      deviceConnected = true;
      status.bleConnected = true;
      status.userPresent = (digitalRead(IR_SENSOR_PIN) == LOW);
      updateStatusCharacteristic();
      
      delay(500);
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

// Configuration Functions
void loadConfiguration() {
  preferences.begin("bike-tracker", true);
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
  
  if (motionSensorInitialized) applyMotionSensitivity();
  updateStatusCharacteristic();
}

void parseConfigJSON(const String& json) {
  bool changed = false;
  bool isCompact = json.indexOf("\"p\":") >= 0;
  
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
  
  int alertStart = isCompact ? json.indexOf("\"a\":") + 4 : json.indexOf("\"alert_enabled\":") + 16;
  if (alertStart >= 4) {
    String alertSection = json.substring(alertStart, alertStart + 10);
    config.alertEnabled = isCompact ? 
      (alertSection.indexOf("1") >= 0) : 
      (alertSection.indexOf("true") >= 0);
    changed = true;
  }
  
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

// Sensor Functions
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

// GPS & SMS Functions
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
  
  bool shouldSend = (!disconnectSMSSent && motionSensor.detectMotion()) ||
                    (disconnectSMSSent && (currentTime - lastDisconnectSMS >= intervalMillis));
  
  if (shouldSend) {
    stopBLEAdvertising();
    if (!isSIM7070GInitialized() && !initializeSIM7070G()) return false;
    
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

// BLE Functions
void initBLE() {
  char deviceName[32];
  sprintf(deviceName, "%s%02X%02X", DEVICE_NAME_PREFIX, 
          (uint8_t)(ESP.getEfuseMac() >> 8), 
          (uint8_t)(ESP.getEfuseMac()));
  
  BLEDevice::init(deviceName);
  BLEDevice::setMTU(BLE_MTU_SIZE);
  
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());
  
  BLEService *pService = pServer->createService(SERVICE_UUID);
  
  pConfigChar = pService->createCharacteristic(CONFIG_CHAR_UUID,
                    BLECharacteristic::PROPERTY_WRITE);
  pConfigChar->setCallbacks(new ConfigCallbacks());
  
  pStatusChar = pService->createCharacteristic(STATUS_CHAR_UUID,
                    BLECharacteristic::PROPERTY_READ | 
                    BLECharacteristic::PROPERTY_NOTIFY);
  pStatusChar->addDescriptor(new BLE2902());
  
  pHistoryChar = pService->createCharacteristic(HISTORY_CHAR_UUID,
                    BLECharacteristic::PROPERTY_READ |
                    BLECharacteristic::PROPERTY_NOTIFY);
  pHistoryChar->addDescriptor(new BLE2902());
  
  pCommandChar = pService->createCharacteristic(COMMAND_CHAR_UUID,
                    BLECharacteristic::PROPERTY_WRITE);
  pCommandChar->setCallbacks(new CommandCallbacks());
  
  String initialHistory = getGPSHistoryJSON(MAX_GPS_HISTORY_POINTS);
  if (initialHistory.length() > BLE_MTU_SIZE) initialHistory = getGPSHistoryJSON(5);
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

// Sleep Functions
void enterSleepMode() {
  if (inSleepMode) return;
  
  if (!disconnectSMSSent) {
    // First disconnect - wake on motion only (light sleep)
    if (motionSensorInitialized) {
      motionSensor.configureWakeOnMotion();
      delay(100);
      motionSensor.clearMotionInterrupts();
    }
    
    esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);
    uint64_t ext_wakeup_pin_mask = (1ULL << INT1_PIN) | (1ULL << INT2_PIN);
    esp_sleep_enable_ext1_wakeup(ext_wakeup_pin_mask, ESP_EXT1_WAKEUP_ANY_HIGH);
    
    inSleepMode = true;  // Set flag BEFORE sleeping
    esp_light_sleep_start();
    inSleepMode = false;  // Clear flag AFTER waking
    
    esp_sleep_wakeup_cause_t wakeup_reason = esp_sleep_get_wakeup_cause();
    if (wakeup_reason == ESP_SLEEP_WAKEUP_EXT1 && motionSensorInitialized) {
      motionSensor.clearMotionInterrupts();
      if (motionSensor.getMotionDelta() > getCurrentMotionThreshold()) {
        lastMotionTime = millis();
        motionWakeNeedsSMS = true;
        return;
      }
    }
    inSleepMode = true;
    
  } else {
    unsigned long timeUntilNextSMS = config.updateInterval * 1000 - (millis() - lastDisconnectSMS);
    if (timeUntilNextSMS < 1000) timeUntilNextSMS = config.updateInterval * 1000;
    
    
    esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);
    if (motionSensorInitialized) motionSensor.setPowerDownMode();
    pinMode(INT1_PIN, INPUT_PULLDOWN);
    pinMode(INT2_PIN, INPUT_PULLDOWN);
    delay(50);
    esp_sleep_enable_timer_wakeup(timeUntilNextSMS * 1000ULL);
    esp_deep_sleep_start();
  }
}

float getCurrentMotionThreshold() {
  return config.motionSensitivity <= 0.3 ? MOTION_THRESHOLD_HIGH :
         config.motionSensitivity <= 0.7 ? MOTION_THRESHOLD_MED :
         MOTION_THRESHOLD_LOW;
}

// Command Processing
void processSerialCommand(const String& cmd) {
  static const struct {
    const char* command;
    void (*handler)();
  } commands[] = {
    {"test", []() { testGPSAndSMS(); }},
    {"gps", []() { 
      if (acquireGPSFix(currentGPS, 20)) {
        Serial.printf("GPS: %s, %s\n", currentGPS.latitude.c_str(), currentGPS.longitude.c_str());
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
      Serial.printf("\nStatus:\n  User: %s\n  Mode: %s\n  BLE: %s\n  Phone: %s\n  Interval: %ds\n",
        status.userPresent ? "Present" : "Away",
        status.deviceMode.c_str(),
        deviceConnected ? "Connected" : "Disconnected",
        strlen(config.phoneNumber) > 0 ? config.phoneNumber : "(not set)",
        config.updateInterval);
    }},
    {"history", []() {
      Serial.printf("\nGPS History: %d points\n", getGPSHistoryCount());
      if (getGPSHistoryCount() > 0) {
        Serial.println(getGPSHistoryJSON(5));
      }
    }},
    {"clear", []() { clearGPSHistory(); }},
    {"clearconfig", []() { clearConfiguration(); }},
    {"sync", []() { if (deviceConnected) syncGPSHistory(); }},
    {"help", []() {
      Serial.println("\nCommands: test, gps, sms, status, history, clear, clearconfig, sync, help");
    }}
  };
  
  for (const auto& c : commands) {
    if (cmd == c.command) {
      c.handler();
      return;
    }
  }
  Serial.println("Unknown command. Type 'help'");
}

void testGPSAndSMS() {
  if (strlen(config.phoneNumber) == 0) return;
  
  if (acquireGPSFix(currentGPS, 20)) {
    Serial.printf("GPS: %s, %s\n", currentGPS.latitude.c_str(), currentGPS.longitude.c_str());
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

// Setup
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  esp_err_t ret = nvs_flash_init();
  if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
    nvs_flash_erase();
    nvs_flash_init();
  }
  
  esp_sleep_wakeup_cause_t wakeup_reason = esp_sleep_get_wakeup_cause();
  Serial.println("\nMCU STARTUP");
  
  switch(wakeup_reason) {
    case ESP_SLEEP_WAKEUP_EXT1:
      Serial.println("Wake: MOTION");
      lastMotionTime = millis();
      if (disconnectSMSSent) lastDisconnectSMS = 0;
      break;
    case ESP_SLEEP_WAKEUP_TIMER:
      Serial.println("Wake: TIMER");
      isTimerWake = true;
      lastDisconnectSMS = 0;
      break;
    default:
      Serial.println("Wake: BOOT");
      disconnectSMSSent = false;
      lastDisconnectSMS = 0;
      isTimerWake = false;
      motionWakeNeedsSMS = false;
      motionSensorInitialized = false;
  }
  
  pinMode(IR_SENSOR_PIN, INPUT);
  loadConfiguration();
  bool hasValidConfig = (strlen(config.phoneNumber) > 0 && config.alertEnabled);
  
  if (isTimerWake && hasValidConfig) {
    stopBLEAdvertising();
    if (acquireGPSFix(currentGPS, 30)) {
      saveGPSData(currentGPS);
      logGPSPoint(currentGPS, 2);
    } else {
      loadGPSData(currentGPS);
    }
    sendDisconnectSMS(config.phoneNumber, currentGPS, false, config.updateInterval);
    isTimerWake = false;
    esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);
    esp_sleep_enable_timer_wakeup(config.updateInterval * 1000000ULL);
    esp_deep_sleep_start();
  }
  
  if (wakeup_reason != ESP_SLEEP_WAKEUP_TIMER || !disconnectSMSSent) {
    initBLE();
  }
  initGPSHistory();
  loadGPSData(currentGPS);
  
  if (motionSensor.begin()) {
    motionSensorInitialized = true;
    applyMotionSensitivity();
    lastMotionTime = millis();
  }
  
  if (hasValidConfig && wakeup_reason == ESP_SLEEP_WAKEUP_UNDEFINED) {
    if (initializeSIM7070G()) disableRF();
    if (!deviceConnected) {
      bootTime = millis();
      gracePeriodActive = true;
    }
  }
}

// Main Loop
void loop() {
  static unsigned long lastStatusUpdate = 0;
  static unsigned long lastIRCheck = 0;
  unsigned long currentTime = millis();
  
  if (gracePeriodActive) {
    if (deviceConnected) {
      gracePeriodActive = false;
      oldDeviceConnected = true;
    } else if (currentTime - bootTime > BOOT_BLE_GRACE_PERIOD) {
      gracePeriodActive = false;
      stopBLEAdvertising();
    }
  }
  
  if (deviceConnected != oldDeviceConnected) {
    if (!deviceConnected) {
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
      if (!motionSensorInitialized && motionSensor.begin()) {
        motionSensorInitialized = true;
        applyMotionSensitivity();
      }
      if (!isTimerWake) disconnectSMSSent = false;
      updateStatusCharacteristic();
      if (motionSensorInitialized) motionSensor.setLowPowerMode();
    }
    oldDeviceConnected = deviceConnected;
  }
  
  if (!deviceConnected && strlen(config.phoneNumber) > 0 && config.alertEnabled) {
    bool smsSent = handleDisconnectedSMS();
    if (!isTimerWake && !gracePeriodActive && motionSensorInitialized) {
      if ((smsSent && disconnectSMSSent) || 
          (disconnectSMSSent && !inSleepMode) ||
          (!disconnectSMSSent && !inSleepMode && 
           motionSensor.getTimeSinceLastMotion() > NO_MOTION_SLEEP_TIME)) {
        inSleepMode = false;
        enterSleepMode();
      }
    }
  }
  
  if (currentTime - lastIRCheck > IR_POLL_INTERVAL) {
    lastIRCheck = currentTime;
    readIRSensor();
  }
  
  if (deviceConnected && (currentTime - lastStatusUpdate > STATUS_UPDATE_INTERVAL)) {
    lastStatusUpdate = currentTime;
    updateStatusCharacteristic();
  }
  
  if (Serial.available() > 0) {
    String command = Serial.readStringUntil('\n');
    command.trim();
    processSerialCommand(command);
  }
  
  delay(10);
}