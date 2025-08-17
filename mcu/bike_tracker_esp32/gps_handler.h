/*
 * gps_handler.h
 * 
 * GPS data handling and parsing for SIM7070G module
 */

#ifndef GPS_HANDLER_H
#define GPS_HANDLER_H

#include <Arduino.h>
#include <Preferences.h>

// GPS data structure
struct GPSData {
  String latitude;
  String longitude;
  String datetime;
  String altitude;
  String speed;
  String course;
  bool valid;
  unsigned long timestamp;  // Millis when acquired
};

// GPS History Configuration
#define MAX_GPS_HISTORY 50  // Maximum number of GPS points to store
#define GPS_LOG_NAMESPACE "gps-log"

// GPS History Entry for logging
struct GPSLogEntry {
  float lat;
  float lon;
  unsigned long timestamp;
  uint8_t source;  // 0=Phone, 1=SIM7070G
};

// GPS functions
bool acquireGPSFix(GPSData& data, uint32_t maxAttempts = 60);
bool parseGNSSData(const String& gpsData, GPSData& data);
bool requestGNSSInfo(String& response);

// GPS data persistence
void saveGPSData(const GPSData& data);
bool loadGPSData(GPSData& data);
bool hasValidStoredGPS();

// GPS History Logging
void initGPSHistory();
bool logGPSPoint(const GPSData& data, uint8_t source);
bool logGPSPoint(float lat, float lon, uint8_t source);
int getGPSHistoryCount();
String getGPSHistoryJSON(int maxPoints = 10);
void clearGPSHistory();
bool getGPSLogEntry(int index, GPSLogEntry& entry);

// Utility functions
String formatGoogleMapsLink(const GPSData& data);
String formatGeoURI(const GPSData& data);
float calculateDistance(const GPSData& pos1, const GPSData& pos2);

#endif // GPS_HANDLER_H