// Smart Bike Tracker - ESP32 MCU Code
// Version: 3.0 - Cleaned & Optimized

// Debug configuration - uncomment for debug mode
// #define DEBUG_ENABLED

#ifdef DEBUG_ENABLED
  #define DEBUG_PRINT(...)    Serial.printf(__VA_ARGS__)
  #define DEBUG_PRINTLN(...)  Serial.println(__VA_ARGS__)
#else
  #define DEBUG_PRINT(...)
  #define DEBUG_PRINTLN(...)
#endif

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
#include <Wire.h>
#include "SparkFun_VL53L1X.h"
SFEVL53L1X tof; 
enum{_IDLE,MEAS} s=_IDLE; 
const uint16_t TB=20; 
const uint32_t PERIOD=1000; 
uint32_t tNext=0;

// Constants
#define BOOT_BLE_GRACE_PERIOD 30000
#define STATUS_UPDATE_INTERVAL 5000
#define IR_POLL_INTERVAL 250
#define BLE_MTU_SIZE 512
#define MAX_GPS_HISTORY_POINTS 7
#define GPS_CACHE_TIMEOUT 300000

// Motion sensor wake threshold constants
#define WAKE_THRESHOLD_MAX      0.28f  // Maximum wake sensitivity (g)
#define WAKE_THRESHOLD_RANGE    0.23f  // Sensitivity adjustment range (0.28 - 0.05 = 0.23)

// Configuration limits
#define SMS_INTERVAL_MIN_SEC    60     // Minimum SMS interval (1 minute)
#define SMS_INTERVAL_MAX_SEC    3600   // Maximum SMS interval (1 hour)
#define MOTION_SENSITIVITY_MIN  0.1f   // Most sensitive (1.0g normal, 0.28g wake)
#define MOTION_SENSITIVITY_MAX  1.0f   // Least sensitive (2.0g normal, 0.05g wake)

// GPS precision for change detection
#define GPS_CHANGE_THRESHOLD    0.0001f  // ~11 meters at equator

// GPS acquisition constants
#define GPS_ACQUISITION_ATTEMPTS     30    // Standard GPS fix attempts (~1 minute)
#define CACHED_GPS_LIMIT              3    // Max consecutive cached GPS sends before no-location alert

// GPS status enumeration (return values from acquireGPSWithFallback)
enum GPSStatus {
  GPS_NONE = 0,      // No valid GPS data available
  GPS_FRESH = 1,     // Fresh GPS fix acquired
  GPS_CACHED = 2     // Using cached GPS data (< 30 min old)
};

// JSON buffer sizes
#define STATUS_JSON_SIZE        256
#define CONFIG_PHONE_MAX_LEN    20

int _distance = 0;
bool _near = false;

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
  char phoneNumber[CONFIG_PHONE_MAX_LEN];
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

// Status snapshot for change detection (reduces BLE traffic)
struct StatusSnapshot {
  bool bleConnected;
  bool userPresent;
  bool gpsValid;
  bool phoneConfigured;
  char mode[16];
  float lat;
  float lon;

  bool hasChanged(const StatusSnapshot& other) const {
    return bleConnected != other.bleConnected ||
           userPresent != other.userPresent ||
           gpsValid != other.gpsValid ||
           phoneConfigured != other.phoneConfigured ||
           strcmp(mode, other.mode) != 0 ||
           (gpsValid && (fabs(lat - other.lat) > GPS_CHANGE_THRESHOLD ||
                         fabs(lon - other.lon) > GPS_CHANGE_THRESHOLD));
  }
};

StatusSnapshot lastSentStatus = {false, false, false, false, "", 0, 0};

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
RTC_DATA_ATTR int consecutiveCachedGPS = 0;  // Track consecutive cached GPS sends

// External RTC variables from gps_handler.cpp
extern RTC_DATA_ATTR int logIndex;
extern RTC_DATA_ATTR int logCount;

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
void ensureMotionSensorInit();


// BLE Callbacks
class ServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) override {
      deviceConnected = true;
      status.bleConnected = true;
      status.userPresent = (_near == HIGH);
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

/*
 * Parse configuration JSON from BLE
 * Uses char* operations to avoid String heap fragmentation
 */
void parseConfigJSON(const String& json) {
  bool changed = false;
  const char* jsonStr = json.c_str();

  // Detect compact vs full format
  bool isCompact = (strstr(jsonStr, "\"p\":") != nullptr);

  // Parse phone number
  const char* phoneKey = isCompact ? "\"p\":\"" : "\"phone_number\":\"";
  const char* phoneStart = strstr(jsonStr, phoneKey);
  if (phoneStart) {
    phoneStart += strlen(phoneKey);
    const char* phoneEnd = strchr(phoneStart, '"');
    if (phoneEnd && phoneEnd > phoneStart) {
      size_t phoneLen = phoneEnd - phoneStart;
      if (phoneLen == 0) {
        clearConfiguration();
        return;
      }
      size_t copyLen = min(phoneLen, sizeof(config.phoneNumber) - 1);
      memcpy(config.phoneNumber, phoneStart, copyLen);
      config.phoneNumber[copyLen] = '\0';
      changed = true;
    }
  }

  // Parse update interval
  const char* intervalKey = isCompact ? "\"i\":" : "\"update_interval\":";
  const char* intervalStart = strstr(jsonStr, intervalKey);
  if (intervalStart) {
    intervalStart += strlen(intervalKey);
    int interval = atoi(intervalStart);
    if (interval >= SMS_INTERVAL_MIN_SEC && interval <= SMS_INTERVAL_MAX_SEC) {
      config.updateInterval = interval;
      changed = true;
    }
  }

  // Parse alert enabled
  const char* alertKey = isCompact ? "\"a\":" : "\"alert_enabled\":";
  const char* alertStart = strstr(jsonStr, alertKey);
  if (alertStart) {
    alertStart += strlen(alertKey);
    // Check for true/1 or false/0
    config.alertEnabled = (strstr(alertStart, "true") == alertStart ||
                          strstr(alertStart, "1") == alertStart);
    changed = true;
  }

  // Parse motion sensitivity
  const char* sensKey = isCompact ? "\"s\":" : "\"motion_sensitivity\":";
  const char* sensStart = strstr(jsonStr, sensKey);
  if (sensStart) {
    sensStart += strlen(sensKey);
    float sens = atof(sensStart);
    if (sens >= MOTION_SENSITIVITY_MIN && sens <= MOTION_SENSITIVITY_MAX) {
      config.motionSensitivity = sens;
      if (motionSensorInitialized) applyMotionSensitivity();
      changed = true;
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
  bool currentUserPresent = (_near == HIGH);
  
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

  // Capture current status
  StatusSnapshot current;
  current.bleConnected = status.bleConnected;
  current.userPresent = status.userPresent;
  current.gpsValid = currentGPS.valid;
  current.phoneConfigured = (strlen(config.phoneNumber) > 0);
  strncpy(current.mode, status.deviceMode.c_str(), sizeof(current.mode) - 1);
  current.mode[sizeof(current.mode) - 1] = '\0';
  current.lat = currentGPS.valid ? atof(currentGPS.latitude.c_str()) : 0;
  current.lon = currentGPS.valid ? atof(currentGPS.longitude.c_str()) : 0;

  // Only send if changed (reduces BLE traffic ~80%)
  if (!current.hasChanged(lastSentStatus)) {
    DEBUG_PRINT("Status unchanged, skipping BLE update\n");
    return;
  }

  char json[STATUS_JSON_SIZE];
  snprintf(json, sizeof(json),
    "{\"ble\":%s,\"phone_configured\":%s,\"phone\":\"%s\",\"interval\":%d,"
    "\"alerts\":%s,\"user_present\":%s,\"mode\":\"%s\","
    "\"gps_valid\":%s,\"lat\":\"%s\",\"lon\":\"%s\"}",
    status.bleConnected ? "true" : "false",
    current.phoneConfigured ? "true" : "false",
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

  lastSentStatus = current;
  DEBUG_PRINT("Status updated via BLE\n");
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

/*
 * Acquire GPS with fallback to cached data
 *
 * Attempts to acquire fresh GPS fix, falls back to cached data if acquisition fails.
 * Cached data is only used if less than 30 minutes old (GPS_CACHE_TIMEOUT).
 *
 * @param gpsData      Reference to GPSData structure to populate
 * @param maxAttempts  Maximum number of GPS fix attempts (typically GPS_ACQUISITION_ATTEMPTS=30)
 * @return GPS_FRESH   Fresh GPS fix successfully acquired
 *         GPS_CACHED  Using valid cached GPS data (< 30 min old)
 *         GPS_NONE    No valid GPS data available
 */
GPSStatus acquireGPSWithFallback(GPSData& gpsData, uint32_t maxAttempts) {
  unsigned long currentTime = millis();

  // Try to acquire fresh GPS
  DEBUG_PRINT("📍 Attempting GPS acquisition...\n");
  if (acquireGPSFix(gpsData, maxAttempts)) {
    status.lastGPSTime = currentTime;
    saveGPSData(gpsData);
    if (logGPSPoint(gpsData, 2)) {
      Serial.printf("📍 Fresh GPS logged at index %d (total: %d)\n",
                    (logIndex - 1 + MAX_GPS_HISTORY) % MAX_GPS_HISTORY, logCount);
      delay(50);  // Allow NVS write to complete
    }
    return GPS_FRESH;
  }

  // GPS acquisition failed - try to load cached data
  Serial.println("⚠️ GPS acquisition failed, checking cached data...");
  if (loadGPSData(gpsData) && gpsData.valid) {
    unsigned long gpsCacheAge = currentTime - status.lastGPSTime;
    // Accept cached GPS if less than 30 minutes old
    if (gpsCacheAge < GPS_CACHE_TIMEOUT) {
      Serial.printf("📍 Using cached GPS (age: %lu seconds)\n", gpsCacheAge / 1000);
      return GPS_CACHED;
    } else {
      Serial.printf("⚠️ Cached GPS too old (%lu seconds)\n", gpsCacheAge / 1000);
    }
  }

  Serial.println("❌ No valid GPS data available");
  return GPS_NONE;
}

/*
 * Send SMS with GPS fallback logic
 *
 * Intelligently handles GPS status and sends appropriate SMS:
 * - GPS_FRESH: Sends location SMS, resets cached counter
 * - GPS_CACHED: Sends location SMS up to CACHED_GPS_LIMIT times, then switches to no-location alert
 * - GPS_NONE: Sends no-location alert with last known location if available
 *
 * This function manages the consecutiveCachedGPS counter to prevent sending stale
 * location data indefinitely when GPS module is not functioning.
 *
 * @param phoneNumber    Phone number to send SMS to
 * @param userPresent    Whether IR sensor detects user presence
 * @param updateInterval SMS update interval in seconds
 * @param gpsData        GPS data (fresh, cached, or invalid)
 * @param gpsStatus      GPS acquisition status (GPS_FRESH, GPS_CACHED, or GPS_NONE)
 * @return true if SMS sent successfully, false otherwise
 */
bool sendSMSWithGPSFallback(
  const char* phoneNumber,
  bool userPresent,
  uint16_t updateInterval,
  GPSData& gpsData,
  GPSStatus gpsStatus
) {
  bool smsSent = false;

  // Check if we've sent cached GPS too many times
  if (gpsStatus == GPS_CACHED) {
    consecutiveCachedGPS++;
    Serial.printf("⚠️ Using cached GPS (%d/%d consecutive)\n",
                  consecutiveCachedGPS, CACHED_GPS_LIMIT);

    if (consecutiveCachedGPS >= CACHED_GPS_LIMIT) {
      // Too many cached sends - send no-location alert instead
      Serial.println("❌ Cached GPS limit reached - sending no-location alert");
      GPSData cachedGPS = gpsData;  // Keep last cached for reference
      smsSent = sendNoLocationSMS(phoneNumber, userPresent, true, cachedGPS, updateInterval);
    } else {
      // Still within limit - send cached location
      smsSent = sendDisconnectSMS(phoneNumber, gpsData, userPresent, updateInterval);
    }
  } else if (gpsStatus == GPS_FRESH) {
    // Fresh GPS acquired - reset counter and send location
    consecutiveCachedGPS = 0;
    Serial.println("✅ Fresh GPS acquired - counter reset");
    smsSent = sendDisconnectSMS(phoneNumber, gpsData, userPresent, updateInterval);
  } else {
    // No GPS at all - send no-location alert
    GPSData cachedGPS;
    bool hasCached = loadGPSData(cachedGPS) && cachedGPS.valid;
    smsSent = sendNoLocationSMS(phoneNumber, userPresent, hasCached, cachedGPS, updateInterval);
  }

  return smsSent;
}

bool handleDisconnectedSMS() {
  if (strlen(config.phoneNumber) == 0 || !config.alertEnabled) return false;

  unsigned long currentTime = millis();
  unsigned long intervalMillis = config.updateInterval * 1000;

  // Handle motion wake SMS (first disconnect after motion detected)
  if (motionWakeNeedsSMS) {
    stopBLEAdvertising();
    Serial.println("📱 Motion wake - acquiring GPS for disconnect alert");

    // Update user presence before sending SMS
    readIRSensor();

    // Try to acquire GPS with fallback
    GPSStatus gpsStatus = acquireGPSWithFallback(currentGPS, GPS_ACQUISITION_ATTEMPTS);

    // Send SMS with GPS fallback logic
    bool smsSent = sendSMSWithGPSFallback(
      config.phoneNumber,
      status.userPresent,
      config.updateInterval,
      currentGPS,
      gpsStatus
    );

    if (smsSent) {
      disconnectSMSSent = true;
      lastDisconnectSMS = currentTime;
      motionWakeNeedsSMS = false;
      return true;
    }
    return false;
  }

  // Handle periodic SMS (regular motion detection or periodic interval)
  bool shouldSend = (!disconnectSMSSent && motionSensor.detectMotion()) ||
                    (disconnectSMSSent && (currentTime - lastDisconnectSMS >= intervalMillis));

  if (shouldSend) {
    stopBLEAdvertising();
    if (!isSIM7070GInitialized() && !initializeSIM7070G()) return false;

    Serial.println("📱 Periodic update - acquiring GPS");

    // Update user presence before sending SMS
    readIRSensor();

    // Try to acquire GPS with fallback
    GPSStatus gpsStatus = acquireGPSWithFallback(currentGPS, GPS_ACQUISITION_ATTEMPTS);

    // Send SMS with GPS fallback logic
    bool smsSent = sendSMSWithGPSFallback(
      config.phoneNumber,
      status.userPresent,
      config.updateInterval,
      currentGPS,
      gpsStatus
    );

    if (smsSent) {
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
    // First disconnect - wake on motion only (DEEP sleep)
    if (motionSensorInitialized) {
      // Stop ToF to release I2C bus before sleep
      tof.stopRanging();
      delay(50);

      // Calculate sensitive threshold for wake interrupts (0.05g to 0.28g range)
      float wakeThreshold = WAKE_THRESHOLD_MAX - (config.motionSensitivity * WAKE_THRESHOLD_RANGE);
      motionSensor.configureWakeOnMotion(wakeThreshold);
      delay(100);
      motionSensor.clearMotionInterrupts();

      // Set pins to INPUT mode for LSM6DSL push-pull output
      pinMode(INT1_PIN, INPUT);
      pinMode(INT2_PIN, INPUT);

      // ESP32-C3 deep sleep GPIO wake API (bitmask + trigger level)
      esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);
      uint64_t gpio_mask = (1ULL << INT1_PIN) | (1ULL << INT2_PIN);
      esp_deep_sleep_enable_gpio_wakeup(gpio_mask, ESP_GPIO_WAKEUP_GPIO_HIGH);

      Serial.println("Entering deep sleep - wake on motion");
      Serial.flush();
      delay(100);

      motionWakeNeedsSMS = true;
      esp_deep_sleep_start();
      // Device resets on wake - execution continues in setup()
    }
    
  } else {
    // Calculate time until next SMS (prevent unsigned underflow)
    unsigned long timeSinceLastSMS = millis() - lastDisconnectSMS;
    unsigned long intervalMillis = config.updateInterval * 1000UL;
    unsigned long timeUntilNextSMS;

    if (timeSinceLastSMS >= intervalMillis) {
      // Already past interval - use full interval
      timeUntilNextSMS = intervalMillis;
    } else {
      // Calculate remaining time
      timeUntilNextSMS = intervalMillis - timeSinceLastSMS;
    }

    // Ensure minimum sleep time of 1 second
    if (timeUntilNextSMS < 1000) timeUntilNextSMS = intervalMillis;

    // Stop ToF to release I2C bus before sleep
    tof.stopRanging();
    delay(50);

    esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);
    if (motionSensorInitialized) motionSensor.setPowerDownMode();
    pinMode(INT1_PIN, INPUT);
    pinMode(INT2_PIN, INPUT);

    // Ensure all NVS writes are completed before deep sleep
    delay(100);

    Serial.printf("Entering deep sleep - wake in %lu seconds\n", timeUntilNextSMS / 1000);
    Serial.flush();

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
  Wire.begin(6,7);
  if(tof.begin()!=0) while(1);
  tof.setDistanceModeShort(); tof.setTimingBudgetInMs(TB);
  esp_err_t ret = nvs_flash_init();
  if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
    nvs_flash_erase();
    nvs_flash_init();
  }
  
  esp_sleep_wakeup_cause_t wakeup_reason = esp_sleep_get_wakeup_cause();
  Serial.println("\nMCU STARTUP");
  
  switch(wakeup_reason) {
    case ESP_SLEEP_WAKEUP_GPIO:
      Serial.println("Wake: MOTION (GPIO)");
      lastMotionTime = millis();
      if (disconnectSMSSent) lastDisconnectSMS = 0;
      // Initialize SIM7070G for GPS acquisition after motion wake
      if (motionWakeNeedsSMS) {
        Serial.println("📡 Motion wake - initializing SIM7070G for GPS acquisition");
        if (!initializeSIM7070G()) {
          Serial.println("❌ SIM7070G init failed on motion wake");
        }
      }
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
      consecutiveCachedGPS = 0;  // Reset cached GPS counter on boot
  }

  loadConfiguration();
  bool hasValidConfig = (strlen(config.phoneNumber) > 0 && config.alertEnabled);
  
  if (isTimerWake && hasValidConfig) {
    stopBLEAdvertising();
    Serial.println("📍 Timer wake - acquiring GPS for periodic update");

    // Initialize SIM7070G for GPS acquisition
    if (!initializeSIM7070G()) {
      Serial.println("❌ SIM7070G init failed on timer wake");
    }

    // Try to acquire GPS with fallback
    GPSStatus gpsStatus = acquireGPSWithFallback(currentGPS, GPS_ACQUISITION_ATTEMPTS);

    // Send SMS with GPS fallback logic (userPresent=false for timer wake)
    sendSMSWithGPSFallback(
      config.phoneNumber,
      false,  // userPresent = false (no IR check during timer wake)
      config.updateInterval,
      currentGPS,
      gpsStatus
    );

    isTimerWake = false;

    // Allow time for NVS writes to complete
    delay(100);

    esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);
    esp_sleep_enable_timer_wakeup(config.updateInterval * 1000000ULL);
    esp_deep_sleep_start();
  }
  
  // Skip BLE initialization if waking from motion to send SMS
  if ((wakeup_reason != ESP_SLEEP_WAKEUP_TIMER || !disconnectSMSSent) &&
      !motionWakeNeedsSMS) {
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

// Helper function to ensure motion sensor is initialized
void ensureMotionSensorInit() {
  if (motionSensorInitialized) return;

  if (motionSensor.begin()) {
    motionSensorInitialized = true;
    applyMotionSensitivity();
    DEBUG_PRINT("Motion sensor initialized\n");
  } else {
    DEBUG_PRINT("Motion sensor init failed\n");
  }
}

// Main Loop
void loop() 
{
  uint32_t _now=millis();
  if(s==_IDLE && (int32_t)(_now-tNext)>=0){ tof.startRanging(); s=MEAS; }
  if(s==MEAS && tof.checkForDataReady())
  {
    _distance = tof.getDistance(); 
    if (_distance < 600)
    {
      _near = HIGH;
    }
    if (_distance >= 600)
    {
      _near = LOW;
    }
    Serial.println(_distance); tof.clearInterrupt(); tof.stopRanging();
    tNext=_now+PERIOD; s=_IDLE;
  }
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
      ensureMotionSensorInit();
      if (motionSensorInitialized) {
        motionSensor.setNormalMode();
        motionSensor.resetMotionReference();
      }
      lastMotionTime = currentTime;
      inSleepMode = false;
    } else {
      ensureMotionSensorInit();
      if (!isTimerWake) disconnectSMSSent = false;
      consecutiveCachedGPS = 0;  // Reset cached GPS counter on BLE reconnect
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
