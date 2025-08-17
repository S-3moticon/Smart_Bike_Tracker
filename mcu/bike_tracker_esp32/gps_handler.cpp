/*
 * gps_handler.cpp
 * 
 * Implementation of GPS data handling functions
 */

#include "gps_handler.h"
#include "sim7070g.h"

// Preferences for GPS data storage
static Preferences gpsPrefs;

/*
 * Acquire GPS fix with retry mechanism
 * Returns true when valid fix is obtained
 */
bool acquireGPSFix(GPSData& data, uint32_t maxAttempts) {
  // Reset module before GPS operation for clean state
  if (!resetModule()) {
    Serial.println("⚠️ Module reset failed");
  }
  delay(2000);
  
  // Enable GPS if not already on
  if (!enableGNSSPower()) {
    return false;
  }
  
  // Wait for GPS to initialize
  delay(2000);
  
  uint32_t attemptCount = 0;
  bool fixAcquired = false;
  
  while (!fixAcquired && attemptCount < maxAttempts) {
    attemptCount++;
    
    String response;
    if (requestGNSSInfo(response)) {
      if (parseGNSSData(response, data)) {
        fixAcquired = true;
        data.timestamp = millis();
        saveGPSData(data);
      }
    }
    
    if (!fixAcquired) {
      delay(2000);  // Wait before next attempt
    }
  }
  
  return fixAcquired;
}

/*
 * Request GNSS information from module
 */
bool requestGNSSInfo(String& response) {
  clearSerialBuffer();
  simSerial.println("AT+CGNSINF");
  delay(500);
  
  response = "";
  uint32_t start = millis();
  
  while (millis() - start < 2000) {
    while (simSerial.available()) {
      char c = simSerial.read();
      response += c;
    }
    
    if (response.indexOf("OK") != -1) {
      return true;
    }
  }
  
  return false;
}

/*
 * Parse GNSS data from AT+CGNSINF response
 * Format: +CGNSINF: <run>,<fix>,<datetime>,<lat>,<lon>,<alt>,<speed>,...
 */
bool parseGNSSData(const String& gpsData, GPSData& data) {
  // Check for valid fix (run=1, fix=1)
  if (gpsData.indexOf("+CGNSINF: 1,1") == -1) {
    return false;
  }
  
  // Extract data after colon
  int startIndex = gpsData.indexOf(":") + 1;
  if (startIndex < 1) return false;
  
  String dataStr = gpsData.substring(startIndex);
  dataStr.trim();
  
  // Parse CSV fields
  String fields[22];
  int fieldIndex = 0;
  int lastComma = -1;
  
  for (int i = 0; i <= dataStr.length() && fieldIndex < 22; i++) {
    if (i == dataStr.length() || dataStr[i] == ',' || dataStr[i] == '\n' || dataStr[i] == '\r') {
      fields[fieldIndex] = dataStr.substring(lastComma + 1, i);
      fields[fieldIndex].trim();
      fieldIndex++;
      lastComma = i;
    }
  }
  
  // Map fields to GPS data
  data.datetime = fields[2];
  data.latitude = fields[3];
  data.longitude = fields[4];
  data.altitude = fields[5];
  data.speed = fields[6];
  data.course = fields[7];
  
  // Validate coordinates
  if (data.latitude.length() > 0 && data.longitude.length() > 0 &&
      data.latitude != "0.000000" && data.longitude != "0.000000" &&
      data.latitude != "" && data.longitude != "") {
    data.valid = true;
    return true;
  }
  
  data.valid = false;
  return false;
}

/*
 * Save GPS data to flash memory
 */
void saveGPSData(const GPSData& data) {
  gpsPrefs.begin("gps-data", false);
  gpsPrefs.putString("lat", data.latitude);
  gpsPrefs.putString("lon", data.longitude);
  gpsPrefs.putString("datetime", data.datetime);
  gpsPrefs.putString("alt", data.altitude);
  gpsPrefs.putString("speed", data.speed);
  gpsPrefs.putString("course", data.course);
  gpsPrefs.putBool("valid", data.valid);
  gpsPrefs.putULong("timestamp", data.timestamp);
  gpsPrefs.end();
}

/*
 * Load GPS data from flash memory
 */
bool loadGPSData(GPSData& data) {
  gpsPrefs.begin("gps-data", true);  // Read-only mode
  
  data.latitude = gpsPrefs.getString("lat", "");
  data.longitude = gpsPrefs.getString("lon", "");
  data.datetime = gpsPrefs.getString("datetime", "");
  data.altitude = gpsPrefs.getString("alt", "");
  data.speed = gpsPrefs.getString("speed", "");
  data.course = gpsPrefs.getString("course", "");
  data.valid = gpsPrefs.getBool("valid", false);
  data.timestamp = gpsPrefs.getULong("timestamp", 0);
  
  gpsPrefs.end();
  
  return data.valid;
}

/*
 * Check if valid GPS data exists in storage
 */
bool hasValidStoredGPS() {
  GPSData tempData;
  return loadGPSData(tempData);
}
/*
 * Format GPS data as geo URI (opens in maps apps)
 */
String formatGeoURI(const GPSData& data) {
  if (!data.valid) return "";
  
  return "geo:" + data.latitude + "," + data.longitude;
}

/*
 * Calculate distance between two GPS positions (in meters)
 * Using simplified formula for small distances
 */
float calculateDistance(const GPSData& pos1, const GPSData& pos2) {
  if (!pos1.valid || !pos2.valid) return 0;
  
  float lat1 = pos1.latitude.toFloat();
  float lon1 = pos1.longitude.toFloat();
  float lat2 = pos2.latitude.toFloat();
  float lon2 = pos2.longitude.toFloat();
  
  // Convert to radians
  lat1 = lat1 * PI / 180.0;
  lon1 = lon1 * PI / 180.0;
  lat2 = lat2 * PI / 180.0;
  lon2 = lon2 * PI / 180.0;
  
  // Haversine formula
  float dlat = lat2 - lat1;
  float dlon = lon2 - lon1;
  
  float a = sin(dlat/2) * sin(dlat/2) + 
            cos(lat1) * cos(lat2) * sin(dlon/2) * sin(dlon/2);
  float c = 2 * atan2(sqrt(a), sqrt(1-a));
  
  // Earth radius in meters
  const float R = 6371000;
  
  return R * c;
}

// ============================================================================
// GPS History Logging Functions
// ============================================================================

static Preferences gpsLogPrefs;
static int logIndex = 0;
static int logCount = 0;

/*
 * Initialize GPS history logging system
 */
void initGPSHistory() {
  gpsLogPrefs.begin(GPS_LOG_NAMESPACE, false);
  logIndex = gpsLogPrefs.getInt("logIndex", 0);
  logCount = gpsLogPrefs.getInt("logCount", 0);
  gpsLogPrefs.end();
}

/*
 * Log a GPS point from GPSData structure
 */
bool logGPSPoint(const GPSData& data, uint8_t source) {
  if (!data.valid) return false;
  
  float lat = data.latitude.toFloat();
  float lon = data.longitude.toFloat();
  
  return logGPSPoint(lat, lon, source);
}

/*
 * Log a GPS point with coordinates
 */
bool logGPSPoint(float lat, float lon, uint8_t source) {
  gpsLogPrefs.begin(GPS_LOG_NAMESPACE, false);
  
  // Create key for this entry
  String keyLat = "lat_" + String(logIndex);
  String keyLon = "lon_" + String(logIndex);
  String keyTime = "time_" + String(logIndex);
  String keySrc = "src_" + String(logIndex);
  
  // Store the GPS point
  gpsLogPrefs.putFloat(keyLat.c_str(), lat);
  gpsLogPrefs.putFloat(keyLon.c_str(), lon);
  gpsLogPrefs.putULong(keyTime.c_str(), millis());
  gpsLogPrefs.putUChar(keySrc.c_str(), source);
  
  // Update index (circular buffer)
  logIndex = (logIndex + 1) % MAX_GPS_HISTORY;
  
  // Update count
  if (logCount < MAX_GPS_HISTORY) {
    logCount++;
  }
  
  // Save metadata
  gpsLogPrefs.putInt("logIndex", logIndex);
  gpsLogPrefs.putInt("logCount", logCount);
  gpsLogPrefs.end();
  
  return true;
}

/*
 * Get the number of GPS points in history
 */
int getGPSHistoryCount() {
  gpsLogPrefs.begin(GPS_LOG_NAMESPACE, true);
  int count = gpsLogPrefs.getInt("logCount", 0);
  gpsLogPrefs.end();
  return count;
}

/*
 * Get a specific GPS log entry by index
 */
bool getGPSLogEntry(int index, GPSLogEntry& entry) {
  if (index < 0 || index >= logCount) return false;
  
  gpsLogPrefs.begin(GPS_LOG_NAMESPACE, true);
  
  // Calculate actual storage index
  int actualIndex;
  if (logCount < MAX_GPS_HISTORY) {
    actualIndex = index;
  } else {
    // Handle circular buffer wraparound
    actualIndex = (logIndex - logCount + index + MAX_GPS_HISTORY) % MAX_GPS_HISTORY;
  }
  
  // Read the entry
  String keyLat = "lat_" + String(actualIndex);
  String keyLon = "lon_" + String(actualIndex);
  String keyTime = "time_" + String(actualIndex);
  String keySrc = "src_" + String(actualIndex);
  
  entry.lat = gpsLogPrefs.getFloat(keyLat.c_str(), 0);
  entry.lon = gpsLogPrefs.getFloat(keyLon.c_str(), 0);
  entry.timestamp = gpsLogPrefs.getULong(keyTime.c_str(), 0);
  entry.source = gpsLogPrefs.getUChar(keySrc.c_str(), 0);
  
  gpsLogPrefs.end();
  
  return true;
}

/*
 * Get GPS history as JSON string for BLE transmission
 */
String getGPSHistoryJSON(int maxPoints) {
  String json = "{\"history\":[";
  
  int count = getGPSHistoryCount();
  int pointsToSend = min(maxPoints, count);
  
  // Start from most recent points
  int startIdx = max(0, count - pointsToSend);
  
  for (int i = startIdx; i < count; i++) {
    GPSLogEntry entry;
    if (getGPSLogEntry(i, entry)) {
      if (i > startIdx) json += ",";
      
      json += "{";
      json += "\"lat\":" + String(entry.lat, 6) + ",";
      json += "\"lon\":" + String(entry.lon, 6) + ",";
      json += "\"time\":" + String(entry.timestamp) + ",";
      json += "\"src\":" + String(entry.source);
      json += "}";
    }
  }
  
  json += "],\"count\":" + String(count) + "}";
  
  return json;
}

/*
 * Clear all GPS history
 */
void clearGPSHistory() {
  gpsLogPrefs.begin(GPS_LOG_NAMESPACE, false);
  gpsLogPrefs.clear();
  gpsLogPrefs.end();
  
  logIndex = 0;
  logCount = 0;
}