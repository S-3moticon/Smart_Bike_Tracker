/*
 * gps_handler.cpp
 * 
 * Implementation of GPS data handling functions
 */

#include "gps_handler.h"
#include "sim7070g.h"
#include <time.h>

// Preferences for GPS data storage
static Preferences gpsPrefs;

/*
 * Convert GPS datetime string to Unix timestamp in milliseconds
 * GPS datetime format: YYYYMMDDHHMMSS.sss
 * Returns: Unix timestamp in milliseconds
 */
uint64_t parseGPSDateTimeToUnixMillis(const String& datetime) {
  if (datetime.length() < 14) {
    // Return a reasonable current time estimate (Dec 2024)
    return 1735689600000ULL; // Dec 2024 baseline
  }
  
  // Extract date and time components
  int year = datetime.substring(0, 4).toInt();
  int month = datetime.substring(4, 6).toInt();
  int day = datetime.substring(6, 8).toInt();
  int hour = datetime.substring(8, 10).toInt();
  int minute = datetime.substring(10, 12).toInt();
  int second = datetime.substring(12, 14).toInt();
  
  // Validate components
  if (year < 2020 || year > 2100 || month < 1 || month > 12 || 
      day < 1 || day > 31 || hour > 23 || minute > 59 || second > 59) {
    // Return current time estimate
    return 1735689600000ULL; // Dec 2024 baseline
  }
  
  // Use a simpler approach - calculate seconds since 2024
  // This avoids overflow issues with large numbers
  uint64_t secondsSince2024 = 0;
  
  // Years since 2024
  for (int y = 2024; y < year; y++) {
    if ((y % 4 == 0 && y % 100 != 0) || (y % 400 == 0)) {
      secondsSince2024 += 366ULL * 86400ULL; // Leap year
    } else {
      secondsSince2024 += 365ULL * 86400ULL;
    }
  }
  
  // Days in current year
  int daysInMonth[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
  if ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)) {
    daysInMonth[1] = 29; // February in leap year
  }
  
  uint64_t daysThisYear = 0;
  for (int m = 1; m < month; m++) {
    daysThisYear += daysInMonth[m - 1];
  }
  daysThisYear += (day - 1);
  
  secondsSince2024 += daysThisYear * 86400ULL;
  secondsSince2024 += hour * 3600ULL;
  secondsSince2024 += minute * 60ULL;
  secondsSince2024 += second;
  
  // Add Unix timestamp for Jan 1, 2024 00:00:00 UTC
  uint64_t unixTime2024 = 1704067200ULL;
  uint64_t totalSeconds = unixTime2024 + secondsSince2024;
  
  // Convert to milliseconds
  return totalSeconds * 1000ULL;
}

/*
 * Acquire GPS fix with retry mechanism
 * Returns true when valid fix is obtained
 */
bool acquireGPSFix(GPSData& data, uint32_t maxAttempts) {
  // Ensure SIM7070G is initialized before GPS acquisition
  if (!isSIM7070GInitialized()) {
    Serial.println("🔄 Initializing SIM7070G for GPS...");
    if (!initializeSIM7070G()) {
      Serial.println("❌ Failed to initialize SIM7070G");
      return false;
    }
  }
  
  // First disable RF to prepare for GPS operation
  Serial.println("📡 Switching to GPS mode...");
  disableRF();
  delay(500);
  
  // Enable GPS
  if (!enableGNSSPower()) {
    Serial.println("❌ Failed to enable GPS");
    // Re-enable RF on failure
    enableRF();
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
        // Convert GPS datetime to Unix timestamp in milliseconds
        data.timestamp = parseGPSDateTimeToUnixMillis(data.datetime);
        Serial.printf("🛰️ GPS Fix acquired: lat=%s, lon=%s, speed=%s km/h\n", 
                      data.latitude.c_str(), data.longitude.c_str(), data.speed.c_str());
        saveGPSData(data);
      }
    }
    
    if (!fixAcquired) {
      delay(2000);  // Wait before next attempt
    }
  }
  
  // After GPS operation, disable GPS and re-enable RF for normal operation
  disableGNSSPower();
  delay(500);
  enableRF();
  
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
  // Debug: show raw CGNSINF response
  Serial.print("📡 Raw CGNSINF: ");
  Serial.println(gpsData.substring(0, min(150, (int)gpsData.length())));
  
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
  
  Serial.printf("📡 Parsed GPS fields: speed='%s' (field[6])\n", fields[6].c_str());
  
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
  // Store 64-bit timestamp as two 32-bit values
  gpsPrefs.putULong("timestamp_hi", (uint32_t)(data.timestamp >> 32));
  gpsPrefs.putULong("timestamp_lo", (uint32_t)(data.timestamp & 0xFFFFFFFF));
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
  // Load 64-bit timestamp from two 32-bit values
  uint32_t timestamp_hi = gpsPrefs.getULong("timestamp_hi", 0);
  uint32_t timestamp_lo = gpsPrefs.getULong("timestamp_lo", 0);
  data.timestamp = ((uint64_t)timestamp_hi << 32) | timestamp_lo;
  
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
  if (!data.valid) {
    Serial.println("⚠️ Skipping invalid GPS data");
    return false;
  }
  
  Serial.print("📍 Converting GPS strings: lat='");
  Serial.print(data.latitude);
  Serial.print("', lon='");
  Serial.print(data.longitude);
  Serial.print("', speed='");
  Serial.print(data.speed);
  Serial.println("'");
  
  float lat = data.latitude.toFloat();
  float lon = data.longitude.toFloat();
  
  if (lat == 0.0 && lon == 0.0) {
    Serial.println("⚠️ GPS conversion resulted in 0,0 - strings may be empty or invalid");
  }
  
  // Use the timestamp from GPSData if available
  gpsLogPrefs.begin(GPS_LOG_NAMESPACE, false);
  
  // Create key for this entry
  String keyLat = "lat_" + String(logIndex);
  String keyLon = "lon_" + String(logIndex);
  String keySpeed = "spd_" + String(logIndex);
  String keyTime = "time_" + String(logIndex);
  String keySrc = "src_" + String(logIndex);
  
  // Store the GPS point with proper timestamp
  gpsLogPrefs.putFloat(keyLat.c_str(), lat);
  gpsLogPrefs.putFloat(keyLon.c_str(), lon);
  
  // Store speed (convert string to float)
  float speed = data.speed.toFloat();
  gpsLogPrefs.putFloat(keySpeed.c_str(), speed);
  Serial.printf("📍 Storing GPS from data: index=%d, lat=%.7f, lon=%.7f, speed=%.2fkm/h, src=%d\n", 
                logIndex, lat, lon, speed, source);
  // Store 64-bit timestamp as two 32-bit values
  String keyTimeHi = "timeH_" + String(logIndex);
  String keyTimeLo = "timeL_" + String(logIndex);
  gpsLogPrefs.putULong(keyTimeHi.c_str(), (uint32_t)(data.timestamp >> 32));
  gpsLogPrefs.putULong(keyTimeLo.c_str(), (uint32_t)(data.timestamp & 0xFFFFFFFF));
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
 * Log a GPS point with coordinates
 */
bool logGPSPoint(float lat, float lon, uint8_t source) {
  gpsLogPrefs.begin(GPS_LOG_NAMESPACE, false);
  
  // Create key for this entry
  String keyLat = "lat_" + String(logIndex);
  String keyLon = "lon_" + String(logIndex);
  String keySpeed = "spd_" + String(logIndex);
  String keyTime = "time_" + String(logIndex);
  String keySrc = "src_" + String(logIndex);
  
  // Store the GPS point
  gpsLogPrefs.putFloat(keyLat.c_str(), lat);
  gpsLogPrefs.putFloat(keyLon.c_str(), lon);
  gpsLogPrefs.putFloat(keySpeed.c_str(), 0.0);  // Default speed for phone GPS
  
  Serial.printf("📍 Storing GPS (no speed): index=%d, lat=%.7f, lon=%.7f, src=%d\n",
                logIndex, lat, lon, source);
  
  // For phone GPS (source 0), use an estimated Unix timestamp
  uint64_t timestamp;
  if (source == 0) {
    // Phone GPS - use current time estimate
    // Since we don't have real time from phone, use a fixed recent date
    timestamp = 1735689600000ULL + millis(); // Dec 31, 2024 baseline + millis
  } else {
    // SIM7070G GPS should have proper timestamp from GPSData
    // This shouldn't happen, but use fallback if needed
    GPSData lastGPS;
    if (loadGPSData(lastGPS) && lastGPS.timestamp > 1609459200000ULL) {
      timestamp = lastGPS.timestamp;
    } else {
      timestamp = 1735689600000ULL + millis(); // Dec 31, 2024 baseline
    }
  }
  
  // Store 64-bit timestamp as two 32-bit values
  String keyTimeHi = "timeH_" + String(logIndex);
  String keyTimeLo = "timeL_" + String(logIndex);
  gpsLogPrefs.putULong(keyTimeHi.c_str(), (uint32_t)(timestamp >> 32));
  gpsLogPrefs.putULong(keyTimeLo.c_str(), (uint32_t)(timestamp & 0xFFFFFFFF));
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
  String keySpeed = "spd_" + String(actualIndex);
  String keyTimeHi = "timeH_" + String(actualIndex);
  String keyTimeLo = "timeL_" + String(actualIndex);
  String keySrc = "src_" + String(actualIndex);
  
  entry.lat = gpsLogPrefs.getFloat(keyLat.c_str(), 0);
  entry.lon = gpsLogPrefs.getFloat(keyLon.c_str(), 0);
  entry.speed = gpsLogPrefs.getFloat(keySpeed.c_str(), 0);
  
  // Debug logging
  Serial.print("     Reading index ");
  Serial.print(index);
  Serial.print(" -> actual ");
  Serial.print(actualIndex);
  Serial.print(": ");
  Serial.print(keyLat);
  Serial.print("=");
  Serial.print(entry.lat, 7);
  Serial.print(", ");
  Serial.print(keyLon);
  Serial.print("=");
  Serial.println(entry.lon, 7);
  
  // Read 64-bit timestamp from two 32-bit values
  uint32_t timestamp_hi = gpsLogPrefs.getULong(keyTimeHi.c_str(), 0);
  uint32_t timestamp_lo = gpsLogPrefs.getULong(keyTimeLo.c_str(), 0);
  entry.timestamp = ((uint64_t)timestamp_hi << 32) | timestamp_lo;
  
  // Fallback for old format (if timestamp_hi is 0, try old single value)
  if (timestamp_hi == 0) {
    String keyTime = "time_" + String(actualIndex);
    entry.timestamp = gpsLogPrefs.getULong(keyTime.c_str(), 0);
    // If old value looks like millis (small number), add baseline
    if (entry.timestamp < 1000000000000ULL) {
      entry.timestamp = 1735689600000ULL + entry.timestamp; // Dec 31, 2024 baseline
    }
  }
  
  entry.source = gpsLogPrefs.getUChar(keySrc.c_str(), 0);
  
  gpsLogPrefs.end();
  
  return true;
}

/*
 * Get GPS history as JSON string for BLE transmission
 */
String getGPSHistoryJSON(int maxPoints) {
  String json;
  json.reserve(512);  // Pre-allocate for efficiency
  json = "{\"history\":[";
  
  int count = getGPSHistoryCount();
  int pointsToSend = min(maxPoints, count);
  int startIdx = max(0, count - pointsToSend);
  
  bool first = true;
  for (int i = startIdx; i < count; i++) {
    GPSLogEntry entry;
    if (getGPSLogEntry(i, entry)) {
      if (!first) json += ",";
      first = false;
      
      json += "{\"lat\":" + String(entry.lat, 6);
      json += ",\"lon\":" + String(entry.lon, 6);
      json += ",\"speed\":" + String(entry.speed, 1);
      json += ",\"time\":" + String(entry.timestamp);
      json += ",\"src\":" + String(entry.source) + "}";
    }
  }
  
  json += "],\"count\":" + String(count) + "}";
  return json;
}

/*
 * Get GPS history page as JSON string for pagination
 */
String getGPSHistoryPageJSON(int page, int pointsPerPage) {
  String json;
  json.reserve(512);
  json = "{\"history\":[";
  
  int count = getGPSHistoryCount();
  int totalPages = count > 0 ? (count + pointsPerPage - 1) / pointsPerPage : 0;
  int startIdx = page * pointsPerPage;
  int endIdx = min(startIdx + pointsPerPage, count);
  
  // Check if page is valid
  if (page < 0 || page >= totalPages || count == 0) {
    json += "],\"page\":" + String(page) + ",";
    json += "\"totalPages\":" + String(totalPages) + ",";
    json += "\"totalPoints\":" + String(count) + ",";
    json += "\"pointsPerPage\":" + String(pointsPerPage) + "}";
    return json;
  }
  
  bool firstEntry = true;
  int validPoints = 0;
  for (int i = startIdx; i < endIdx; i++) {
    GPSLogEntry entry;
    if (getGPSLogEntry(i, entry)) {
      // Simplified debug log
      Serial.printf("   Point %d: lat=%.7f, lon=%.7f, src=%d\n", 
                    i, entry.lat, entry.lon, entry.source);
      
      // Only add valid GPS points (not 0,0)
      if (entry.lat != 0.0 || entry.lon != 0.0) {
        if (!firstEntry) json += ",";
        
        json += "{";
        json += "\"lat\":" + String(entry.lat, 7) + ",";
        json += "\"lon\":" + String(entry.lon, 7) + ",";
        json += "\"speed\":" + String(entry.speed, 1) + ",";
        json += "\"time\":" + String(entry.timestamp) + ",";
        json += "\"src\":" + String(entry.source);
        json += "}";
        firstEntry = false;
        validPoints++;
      }
    }
  }
  
  Serial.printf("   Added %d valid points to page\n", validPoints);
  
  json += "],\"page\":" + String(page);
  json += ",\"totalPages\":" + String(totalPages);
  json += ",\"totalPoints\":" + String(count);
  json += ",\"pointsPerPage\":" + String(pointsPerPage) + "}";
  
  Serial.printf("   JSON response: page=%d, totalPages=%d, totalPoints=%d, validPoints=%d\n",
                page, totalPages, count, validPoints);
  
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