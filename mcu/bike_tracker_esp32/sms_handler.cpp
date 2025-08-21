/*
 * sms_handler.cpp
 * 
 * Implementation of SMS sending functionality for SIM7070G module
 */

#include "sms_handler.h"
#include "sim7070g.h"
#include <Preferences.h>

// Track last SMS time
static unsigned long lastSMSTime = 0;
static Preferences smsPrefs;

/*
 * Send SMS message to specified phone number
 * Note: Caller should disable GPS before calling this function
 */
bool sendSMS(const String& phoneNumber, const String& message) {
  
  // Clear any pending SMS mode
  clearSerialBuffer();
  simSerial.write(27);  // ESC key to exit any pending mode
  delay(500);  // Reduced delay
  
  // Quick module check - no need for extensive verification
  if (!sendATCommand("AT", "OK", 1000)) {
    Serial.println("❌ Module not responding");
    return false;
  }
  
  // Verify network registration with reduced delay
  if (!checkNetworkRegistration()) {
    Serial.println("❌ Network not registered");
    return false;
  }
  delay(1000);  // Reduced delay
  
  // Set SMS text mode
  if (!sendATCommand("AT+CMGF=1", "OK")) {
    Serial.println("❌ Failed to set text mode");
    return false;
  }
  
  delay(500);
  
  // Set recipient number
  String cmd = "AT+CMGS=\"" + phoneNumber + "\"";
  simSerial.print(cmd);
  simSerial.println();
  
  // Wait for prompt
  delay(1000);  // Reduced delay
  unsigned long start = millis();
  bool promptReceived = false;
  
  while (millis() - start < 3000) {  // Reduced timeout
    if (simSerial.available()) {
      char c = simSerial.read();
      if (c == '>') {
        promptReceived = true;
        break;
      }
    }
    delay(10);
  }
  
  if (!promptReceived) {
    Serial.println("❌ No SMS prompt received");
    // Send ESC to cancel SMS mode
    simSerial.write(27);
    delay(500);
    clearSerialBuffer();
    return false;
  }
  
  // Send message content
  delay(100);
  simSerial.print(message);
  delay(100);
  simSerial.write(26);  // Ctrl+Z to send
  
  // Wait for confirmation with reduced timeout
  start = millis();
  String response = "";
  
  while (millis() - start < 15000) {  // Reduced timeout from 30s to 15s
    if (simSerial.available()) {
      char c = simSerial.read();
      response += c;
      
      // Check for success response
      if (response.indexOf("+CMGS:") != -1 && response.indexOf("OK") != -1) {
        updateLastSMSTime();
        return true;
      }
      
      // Check for error - fail fast
      if (response.indexOf("ERROR") != -1 || response.indexOf("+CMS ERROR") != -1) {
        Serial.println("❌ SMS send error detected");
        return false;
      }
    }
    delay(10);
  }
  
  Serial.println("❌ SMS send timeout");
  return false;
}

/*
 * Send SMS pair - optimized for sending two messages quickly
 * Assumes GPS is already disabled by caller
 */
bool sendSMSPair(const String& phoneNumber, const String& firstMsg, const String& secondMsg) {
  
  // Clear any pending SMS mode
  clearSerialBuffer();
  simSerial.write(27);  // ESC key
  delay(500);  // Reduced delay
  
  // Quick module check
  if (!sendATCommand("AT", "OK", 1000)) {
    Serial.println("❌ Module not responding");
    return false;
  }
  
  if (!checkNetworkRegistration()) {
    Serial.println("❌ Network not registered");
    return false;
  }
  delay(1000);  // Reduced delay
  
  // Send first message
  Serial.println("📱 Sending first SMS (geo URI)...");
  if (!sendATCommand("AT+CMGF=1", "OK")) {
    Serial.println("❌ Failed to set text mode");
    return false;
  }
  delay(500);
  
  String cmd = "AT+CMGS=\"" + phoneNumber + "\"";
  simSerial.print(cmd);
  simSerial.println();
  
  delay(1000);  // Reduced delay
  bool promptReceived = false;
  unsigned long start = millis();
  
  while (millis() - start < 3000) {  // Reduced timeout
    if (simSerial.available()) {
      char c = simSerial.read();
      if (c == '>') {
        promptReceived = true;
        break;
      }
    }
    delay(10);
  }
  
  if (!promptReceived) {
    Serial.println("❌ No SMS prompt for first message");
    simSerial.write(27);
    delay(500);
    clearSerialBuffer();
    return false;
  }
  
  // Send first message content
  delay(100);
  simSerial.print(firstMsg);
  delay(100);
  simSerial.write(26);  // Ctrl+Z
  
  // Wait for first message confirmation
  start = millis();
  String response = "";
  bool firstSent = false;
  
  while (millis() - start < 15000) {  // Reduced timeout
    if (simSerial.available()) {
      char c = simSerial.read();
      response += c;
      if (response.indexOf("+CMGS:") != -1 && response.indexOf("OK") != -1) {
        firstSent = true;
        Serial.println("✅ First SMS sent");
        break;
      }
      if (response.indexOf("ERROR") != -1 || response.indexOf("+CMS ERROR") != -1) {
        Serial.println("❌ First SMS failed - aborting");
        return false;
      }
    }
    delay(10);
  }
  
  if (!firstSent) {
    Serial.println("❌ First SMS timeout");
    return false;
  }
  
  // Send second message with minimal delay
  delay(2000);  // Reduced delay between messages
  Serial.println("📱 Sending second SMS (instructions)...");
  
  // Clear buffer and send second message
  clearSerialBuffer();
  
  // Re-set text mode quickly
  sendATCommand("AT+CMGF=1", "OK", 1000);
  delay(300);  // Reduced delay
  
  cmd = "AT+CMGS=\"" + phoneNumber + "\"";
  simSerial.print(cmd);
  simSerial.println();
  
  delay(2000);
  promptReceived = false;
  start = millis();
  
  while (millis() - start < 5000) {
    if (simSerial.available()) {
      char c = simSerial.read();
      if (c == '>') {
        promptReceived = true;
        break;
      }
    }
    delay(10);
  }
  
  if (!promptReceived) {
    Serial.println("⚠️ No prompt for second message");
    simSerial.write(27);
    delay(500);
    clearSerialBuffer();
    return true;  // First message was sent
  }
  
  // Send second message content
  delay(100);
  simSerial.print(secondMsg);
  delay(100);
  simSerial.write(26);  // Ctrl+Z
  
  // Wait for second message confirmation
  start = millis();
  response = "";
  
  while (millis() - start < 30000) {
    if (simSerial.available()) {
      char c = simSerial.read();
      response += c;
      if (response.indexOf("+CMGS:") != -1 && response.indexOf("OK") != -1) {
        Serial.println("✅ Second SMS sent");
        updateLastSMSTime();
        return true;
      }
      if (response.indexOf("ERROR") != -1 || response.indexOf("+CMS ERROR") != -1) {
        Serial.println("⚠️ Second SMS failed");
        break;
      }
    }
    delay(10);
  }
  
  updateLastSMSTime();  // Update time since first message was sent
  return true;  // Success if first message was sent
}

/*
 * Send location SMS with GPS coordinates
 * Sends two messages: 1st with geo URI, 2nd with instructions
 */
bool sendLocationSMS(const String& phoneNumber, const GPSData& gpsData, AlertType type) {
  if (!gpsData.valid) {
    Serial.println("⚠️ Invalid GPS data, cannot send location SMS");
    return false;
  }
  
  // CRITICAL: Enable RF for SMS operation (GPS and SMS share RF)
  // First disable GPS if it was on
  disableGNSSPower();
  delay(500);
  // Then enable RF for SMS
  enableRF();
  delay(1000);  // Let RF stabilize
  
  // First message: geo URI only
  String firstMessage = "geo:" + gpsData.latitude + "," + gpsData.longitude;
  
  // Second message: instructions with coordinates
  String secondMessage = "If the map did not load, Please Copy and Paste the Lat and Long to your Map application.\n";
  secondMessage += "Location: ";
  secondMessage += gpsData.latitude;
  secondMessage += " ";
  secondMessage += gpsData.longitude;
  
  // Add alert type indicator
  switch (type) {
    case ALERT_LOCATION_UPDATE:
      secondMessage += "\nLocation Update";
      break;
    case ALERT_TEST:
      secondMessage += "\nTest Alert";
      break;
    case ALERT_LOW_BATTERY:
      secondMessage += "\nLow Battery Alert";
      break;
    case ALERT_BLE_DISCONNECT:
      secondMessage += "\nBLE Disconnected Alert";
      break;
    default:
      break;
  }
  
  // Use the optimized SMS pair function
  bool result = sendSMSPair(phoneNumber, firstMessage, secondMessage);
  
  // After SMS, disable RF to save power
  Serial.println("📡 Disabling RF after SMS...");
  disableRF();
  
  return result;
}

/*
 * Send BLE disconnect SMS with device status
 * Includes GPS location, user presence, and SMS interval
 */
bool sendDisconnectSMS(const String& phoneNumber, const GPSData& gpsData, bool userPresent, uint16_t updateInterval) {
  if (!gpsData.valid) {
    Serial.println("⚠️ Invalid GPS data, cannot send location SMS");
    return false;
  }
  
  // CRITICAL: Enable RF for SMS operation (GPS and SMS share RF)
  // First disable GPS if it was on
  disableGNSSPower();
  delay(500);
  // Then enable RF for SMS
  enableRF();
  delay(1000);  // Let RF stabilize
  
  // First message: geo URI only
  String firstMessage = "geo:" + gpsData.latitude + "," + gpsData.longitude;
  
  // Second message: simplified format without special characters
  String secondMessage = "If map did not load, copy coordinates to your map app\n";
  secondMessage += "Location: ";
  secondMessage += gpsData.latitude;
  secondMessage += ",";
  secondMessage += gpsData.longitude;
  secondMessage += "\n\n";
  secondMessage += "Device Status\n";
  secondMessage += "User: ";
  secondMessage += userPresent ? "Present" : "Away";
  secondMessage += "\n";
  secondMessage += "SMS Interval: ";
  secondMessage += String(updateInterval);
  secondMessage += " sec";
  
  // Use the optimized SMS pair function
  bool result = sendSMSPair(phoneNumber, firstMessage, secondMessage);
  
  // After SMS, disable RF to save power
  Serial.println("📡 Disabling RF after SMS...");
  disableRF();
  
  return result;
}

/*
 * Send test SMS to verify functionality
 */
bool sendTestSMS(const String& phoneNumber) {
  String message = "Bike Tracker Test SMS\n";
  message += "System operational\n";
  message += "Time: ";
  message += String(millis() / 1000);
  message += " seconds since boot";
  
  // Enable RF for SMS
  enableRF();
  delay(1000);
  
  bool result = sendSMS(phoneNumber, message);
  
  // Disable RF after SMS to save power
  disableRF();
  
  return result;
}

/*
 * Format alert message based on alert type
 */
String formatAlertMessage(const GPSData& gpsData, AlertType type) {
  String message = "";
  
  // CRITICAL: geo URI must be on the first line for proper recognition
  message += "geo:";
  message += gpsData.latitude;
  message += ",";
  message += gpsData.longitude;
  message += "\n\n";
  
  // Add alert header based on type
  switch (type) {
    case ALERT_LOCATION_UPDATE:
      message += "Location Update\n";
      break;
      
    case ALERT_LOW_BATTERY:
      message += "Low Battery Alert\n";
      break;
      
    case ALERT_TEST:
      message += "Test Alert\n";
      break;
      
    case ALERT_BLE_DISCONNECT:
      message += "BLE Disconnected Alert\n";
      break;
      
    default:
      message += "Location Alert\n";
      break;
  }
  
  message += "\n";
  
  // Add coordinates for manual entry if needed
  message += "Coordinates:\n";
  message += "Lat: ";
  message += gpsData.latitude;
  message += "\n";
  message += "Lon: ";
  message += gpsData.longitude;
  
  return message;
}

/*
 * Format simple location message (coordinates only)
 */
String formatSimpleLocationMessage(const GPSData& gpsData) {
  String message = "";
  
  // CRITICAL: geo URI must be on the first line for proper recognition
  message += "geo:";
  message += gpsData.latitude;
  message += ",";
  message += gpsData.longitude;
  message += "\n\n";
  
  message += "Bike Location\n\n";
  
  message += "Coordinates:\n";
  message += "Lat: ";
  message += gpsData.latitude;
  message += "\n";
  message += "Lon: ";
  message += gpsData.longitude;
  
  return message;
}

/*
 * Update the last SMS sent timestamp
 */
void updateLastSMSTime() {
  lastSMSTime = millis();
  
  // Also save to preferences for persistence
  smsPrefs.begin("sms-data", false);
  smsPrefs.putULong("lastSMS", lastSMSTime);
  smsPrefs.end();
}

/*
 * Check if enough time has passed to send another SMS
 * Prevents SMS flooding
 */
bool shouldSendSMS(unsigned long intervalSeconds) {
  unsigned long intervalMillis = intervalSeconds * 1000;
  unsigned long currentTime = millis();
  
  // Handle overflow
  if (currentTime < lastSMSTime) {
    lastSMSTime = 0;
  }
  
  return (currentTime - lastSMSTime) >= intervalMillis;
}

/*
 * Get time since last SMS in seconds
 */
unsigned long getTimeSinceLastSMS() {
  unsigned long currentTime = millis();
  
  // Handle overflow
  if (currentTime < lastSMSTime) {
    return 0;
  }
  
  return (currentTime - lastSMSTime) / 1000;
}