/*
 * SIM7070G GPS Tracker
 * 
 * This program uses a SIM7070G module to:
 * 1. Acquire GPS location fix
 * 2. Save coordinates to ESP32 flash memory
 * 3. Send location via SMS in a format compatible with Google Maps
 * 
 * The program ensures GPS is only powered when needed to save battery,
 * and automatically retries SMS sending if initial attempts fail.
 * 
 * Hardware connections:
 * - SIM7070G TX -> ESP32 GPIO 17
 * - SIM7070G RX -> ESP32 GPIO 16
 */

#include <HardwareSerial.h>
#include <Preferences.h>

// Serial communication with SIM7070G module
HardwareSerial simSerial(1);

// ESP32 flash storage for GPS data persistence
Preferences preferences;

// Pin definitions for UART communication
#define SIM_TX 16
#define SIM_RX 17

// Target phone number for SMS alerts
String phoneNumber = "+639811932238";

// Structure to hold GPS fix data
struct GPSData {
  String latitude;
  String longitude;
  String datetime;
  String altitude;
  String speed;
  String course;
  bool valid;
};

// Global storage for last acquired GPS fix
GPSData lastGPSFix;

/*
 * Sends an AT command to the SIM7070G and waits for expected response
 * Returns true if expected response received within timeout period
 */
bool sendATCommand(String cmd, String resp, uint32_t timeout = 2000) {
  simSerial.println(cmd);
  uint32_t start = millis();
  String buffer = "";
  
  while (millis() - start < timeout) {
    while (simSerial.available()) {
      char c = simSerial.read();
      buffer += c;
      if (buffer.indexOf(resp) != -1) {
        return true;
      }
    }
  }
  return false;
}

/*
 * Persists GPS data to ESP32's non-volatile flash memory
 * Data survives power cycles and can be retrieved later
 */
void saveGPSData(GPSData &data) {
  preferences.begin("gps-data", false);
  preferences.putString("lat", data.latitude);
  preferences.putString("lon", data.longitude);
  preferences.putString("datetime", data.datetime);
  preferences.putString("alt", data.altitude);
  preferences.putString("speed", data.speed);
  preferences.putString("course", data.course);
  preferences.putBool("valid", data.valid);
  preferences.end();
}

/*
 * Parses GNSS data from AT+CGNSINF command response
 * Returns true only when valid GPS fix is acquired
 * 
 * Response format: +CGNSINF: <run>,<fix>,<datetime>,<lat>,<lon>,<alt>,<speed>,...
 * Valid fix requires: run=1 (GNSS on) and fix=1 (position fixed)
 */
bool parseGNSSData(String gpsData, GPSData &data) {
  // Verify GNSS is running and has valid fix
  if (gpsData.indexOf("+CGNSINF: 1,1") == -1) {
    return false;
  }
  
  // Extract CSV fields from response
  int startIndex = gpsData.indexOf(":") + 1;
  gpsData = gpsData.substring(startIndex);
  gpsData.trim();
  
  // Parse comma-separated values
  String fields[22];
  int fieldIndex = 0;
  int lastComma = -1;
  
  for (int i = 0; i <= gpsData.length() && fieldIndex < 22; i++) {
    if (i == gpsData.length() || gpsData[i] == ',' || gpsData[i] == '\n') {
      fields[fieldIndex] = gpsData.substring(lastComma + 1, i);
      fieldIndex++;
      lastComma = i;
    }
  }
  
  // Map fields to GPS data structure
  data.latitude = fields[3];   
  data.longitude = fields[4];  
  data.altitude = fields[5];   
  data.speed = fields[6];      
  data.course = fields[7];     
  data.datetime = fields[2];   
  
  // Validate coordinates are not zero/empty
  if (data.latitude.length() > 0 && data.longitude.length() > 0 && 
      data.latitude != "0.000000" && data.longitude != "0.000000") {
    data.valid = true;
    return true;
  }
  
  return false;
}

/*
 * Sends SMS with GPS coordinates to configured phone number
 * Handles SMS mode entry, message composition, and sending
 * Returns true if SMS sent successfully
 */
bool sendSMS(String message) {
  // Clear serial buffer
  while (simSerial.available()) {
    simSerial.read();
  }
  
  // Ensure not in SMS mode
  simSerial.write(27); // ESC key
  delay(1000);
  
  // Configure text mode
  if (!sendATCommand("AT+CMGF=1", "OK")) {
    return false;
  }
  
  delay(500);
  
  // Initiate SMS sending
  simSerial.print("AT+CMGS=\"");
  simSerial.print(phoneNumber);
  simSerial.println("\"");
  
  // Wait for prompt character '>'
  delay(2000);
  uint32_t promptStart = millis();
  bool gotPrompt = false;
  
  while (millis() - promptStart < 5000) {
    if (simSerial.available()) {
      char c = simSerial.read();
      if (c == '>') {
        gotPrompt = true;
        break;
      }
    }
    delay(10);
  }
  
  if (!gotPrompt) {
    return false;
  }
  
  // Send message content and terminate with CTRL+Z
  delay(100);
  simSerial.print(message);
  delay(100);
  simSerial.write(26); // CTRL+Z
  
  // Wait for send confirmation
  uint32_t start = millis();
  String response = "";
  
  while (millis() - start < 30000) {
    if (simSerial.available()) {
      char c = simSerial.read();
      response += c;
      
      // Check for success response
      if (response.indexOf("+CMGS:") != -1 && response.indexOf("OK") != -1) {
        return true;
      }
      
      // Check for error
      if (response.indexOf("ERROR") != -1) {
        return false;
      }
    }
    delay(10);
  }
  
  return false;
}

/*
 * Initializes SIM7070G module with required AT command sequence
 * Performs module reset, network registration, and GPS power-on
 */
void initializeModule() {
  // Module reset for clean state
  sendATCommand("AT+CFUN=1,1", "OK", 10000);
  delay(10000);
  
  // Wait for module ready
  while (!sendATCommand("AT", "OK")) {
    delay(1000);
  }
  
  // Check signal quality
  sendATCommand("AT+CSQ", "OK", 5000);
  delay(2000);
  
  // Wait for network registration
  int attempts = 0;
  while (attempts < 30) {
    if (sendATCommand("AT+CREG?", "0,1") || sendATCommand("AT+CREG?", "0,5")) {
      break;
    }
    delay(2000);
    attempts++;
  }
  delay(2000);
  
  // Check network operator
  sendATCommand("AT+COPS?", "OK", 5000);
  delay(2000);
  
  // Enable GNSS power
  sendATCommand("AT+CGNSPWR=1", "OK");
  
  // Configure SMS parameters
  sendATCommand("AT+CMGF=1", "OK");
  sendATCommand("AT+CSMP=17,167,0,0", "OK");
}

void setup() {
  // Initialize serial communications
  Serial.begin(115200);
  simSerial.begin(115200, SERIAL_8N1, SIM_RX, SIM_TX);
  
  // Wait for module startup
  delay(2000);
  while (!sendATCommand("AT", "OK")) {
    delay(1000);
  }
  
  // Initialize module with AT command sequence
  initializeModule();
  
  // GPS acquisition loop - runs until valid fix obtained
  int attemptCount = 0;
  bool fixAcquired = false;
  
  while (!fixAcquired) {
    attemptCount++;
    
    // Request GNSS information
    simSerial.println("AT+CGNSINF");
    delay(500);
    
    // Read response
    String gpsData = "";
    while (simSerial.available()) {
      gpsData += char(simSerial.read());
    }
    
    // Parse and check for valid fix
    GPSData currentFix;
    if (parseGNSSData(gpsData, currentFix)) {
      fixAcquired = true;
      
      // Store GPS data
      lastGPSFix = currentFix;
      saveGPSData(lastGPSFix);
      
      // Power off GNSS to save battery
      sendATCommand("AT+CGNSPWR=0", "OK");
      delay(5000);
      
      // Verify network before SMS
      sendATCommand("AT+CREG?", "OK");
      delay(2000);
      
      // Compose user-friendly SMS message
      String smsMessage = "GPS Location:\n";
      smsMessage += "Copy & paste in Google Maps:\n";
      smsMessage += lastGPSFix.latitude + "," + lastGPSFix.longitude;
      
      // Attempt SMS sending with retries
      bool smsSent = false;
      int smsAttempts = 0;
      
      while (!smsSent && smsAttempts < 3) {
        smsAttempts++;
        if (sendSMS(smsMessage)) {
          smsSent = true;
        } else if (smsAttempts < 3) {
          delay(5000);
        }
      }
    }
    
    // Wait before next GPS scan attempt
    if (!fixAcquired) {
      delay(2000);
    }
  }
}

void loop() {
  // All operations completed in setup()
  // Loop remains empty as this is a one-shot operation
  delay(10000);
}
