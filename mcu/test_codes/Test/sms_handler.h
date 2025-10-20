/*
 * sms_handler.h
 *
 * SMS sending functionality for SIM7070G module
 */

#ifndef SMS_HANDLER_H
#define SMS_HANDLER_H

#include <Arduino.h>
#include "gps_handler.h"

// SMS alert types
enum AlertType {
  ALERT_LOCATION_UPDATE,
  ALERT_LOW_BATTERY,
  ALERT_TEST,
  ALERT_BLE_DISCONNECT
};

// SMS functions
bool sendSMS(const String& phoneNumber, const String& message);
bool sendSMSPair(const String& phoneNumber, const String& firstMsg, const String& secondMsg);
bool sendLocationSMS(const String& phoneNumber, const GPSData& gpsData, AlertType type = ALERT_LOCATION_UPDATE);
bool sendDisconnectSMS(const String& phoneNumber, const GPSData& gpsData, bool userPresent, uint16_t updateInterval);
bool sendNoLocationSMS(const String& phoneNumber, bool userPresent, bool hasCachedGPS, const GPSData& cachedGPS, uint16_t updateInterval);
bool sendTestSMS(const String& phoneNumber);

// SMS tracking
void updateLastSMSTime();
bool shouldSendSMS(unsigned long intervalSeconds);
unsigned long getTimeSinceLastSMS();

#endif // SMS_HANDLER_H