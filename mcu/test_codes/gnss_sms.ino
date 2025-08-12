#include <HardwareSerial.h>
#include <Preferences.h>

HardwareSerial simSerial(1);
Preferences preferences;

#define SIM_TX 16
#define SIM_RX 17

String phoneNumber = "+639811932238";

// GPS data structure
struct GPSData {
  String latitude;
  String longitude;
  String datetime;
  String altitude;
  String speed;
  String course;
  bool valid;
};

GPSData lastGPSFix;

// Send AT command and wait for response
bool sendATCommand(String cmd, String resp, uint32_t timeout = 2000) {
  simSerial.println(cmd);
  uint32_t start = millis();
  String buffer = "";
  
  while (millis() - start < timeout) {
    while (simSerial.available()) {
      char c = simSerial.read();
      buffer += c;
      if (buffer.indexOf(resp) != -1) {
        Serial.println(buffer);
        return true;
      }
    }
  }
  
  Serial.println(buffer);
  return false;
}

// Save GPS data to ESP32 flash memory
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
  
  Serial.println("\n=== GPS Data Saved to ESP32 ===");
  Serial.println("Latitude: " + data.latitude);
  Serial.println("Longitude: " + data.longitude);
  Serial.println("DateTime: " + data.datetime);
  Serial.println("Altitude: " + data.altitude + " m");
  Serial.println("Speed: " + data.speed + " km/h");
  Serial.println("Course: " + data.course + " degrees");
}

// Parse GNSS data from AT+CGNSINF response
bool parseGNSSData(String gpsData, GPSData &data) {
  // Check for valid fix: +CGNSINF: 1,1 means GNSS is on and has fix
  if (gpsData.indexOf("+CGNSINF: 1,1") == -1) {
    return false;
  }
  
  // Parse CSV fields
  int startIndex = gpsData.indexOf(":") + 1;
  gpsData = gpsData.substring(startIndex);
  gpsData.trim();
  
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
  
  // Extract relevant fields
  data.latitude = fields[3];   // Latitude
  data.longitude = fields[4];  // Longitude
  data.altitude = fields[5];   // Altitude
  data.speed = fields[6];      // Speed
  data.course = fields[7];     // Course
  data.datetime = fields[2];   // UTC date/time
  
  // Validate coordinates
  if (data.latitude.length() > 0 && data.longitude.length() > 0 && 
      data.latitude != "0.000000" && data.longitude != "0.000000") {
    data.valid = true;
    return true;
  }
  
  return false;
}

// Send SMS with simple text message
bool sendSMS(String message) {
  Serial.println("\n--- Sending SMS ---");
  Serial.println("To: " + phoneNumber);
  Serial.println("Message: " + message);
  
  // Clear any pending data
  while (simSerial.available()) {
    simSerial.read();
  }
  
  // Exit any pending SMS mode
  simSerial.write(27); // ESC
  delay(1000);
  
  // Set SMS text mode
  if (!sendATCommand("AT+CMGF=1", "OK")) {
    Serial.println("Failed to set SMS text mode");
    return false;
  }
  
  delay(500);
  
  // Start SMS send
  simSerial.print("AT+CMGS=\"");
  simSerial.print(phoneNumber);
  simSerial.println("\"");
  
  // Wait for ">" prompt
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
    Serial.println("Failed to get SMS prompt");
    return false;
  }
  
  // Send message
  Serial.println("Sending message content...");
  delay(100);
  simSerial.print(message);
  delay(100);
  simSerial.write(26); // CTRL+Z
  
  // Wait for response
  uint32_t start = millis();
  String response = "";
  
  while (millis() - start < 30000) {
    if (simSerial.available()) {
      char c = simSerial.read();
      response += c;
      
      if (response.indexOf("+CMGS:") != -1 && response.indexOf("OK") != -1) {
        Serial.println("SMS sent successfully!");
        return true;
      }
      
      if (response.indexOf("ERROR") != -1) {
        Serial.println("SMS failed: " + response);
        return false;
      }
    }
    delay(10);
  }
  
  Serial.println("SMS timeout");
  return false;
}

// Initialize module with AT command sequence
void initializeModule() {
  Serial.println("\n=== Module Initialization Sequence ===");
  
  // Step 1: Reset module
  Serial.println("Step 1: Module reset (AT+CFUN=1,1)...");
  if (sendATCommand("AT+CFUN=1,1", "OK", 10000)) {
    Serial.println("✓ Module reset successful");
  }
  
  // Step 2: Wait for stabilization
  Serial.println("Step 2: Waiting 10 seconds...");
  delay(10000);
  
  // Verify module ready
  while (!sendATCommand("AT", "OK")) {
    Serial.println("Waiting for module...");
    delay(1000);
  }
  
  // Step 3: Check signal quality
  Serial.println("Step 3: Signal quality check (AT+CSQ)...");
  sendATCommand("AT+CSQ", "OK", 5000);
  delay(2000);
  
  // Step 5: Check network registration
  Serial.println("Step 5: Network registration (AT+CREG?)...");
  int attempts = 0;
  while (attempts < 30) {
    if (sendATCommand("AT+CREG?", "0,1") || sendATCommand("AT+CREG?", "0,5")) {
      Serial.println("✓ Network registered");
      break;
    }
    Serial.println("Waiting for network...");
    delay(2000);
    attempts++;
  }
  delay(2000);
  
  // Step 7: Check operator
  Serial.println("Step 7: Operator check (AT+COPS?)...");
  sendATCommand("AT+COPS?", "OK", 5000);
  delay(2000);
  
  // Step 9: Power on GNSS
  Serial.println("Step 9: Power on GNSS (AT+CGNSPWR=1)...");
  if (sendATCommand("AT+CGNSPWR=1", "OK")) {
    Serial.println("✓ GNSS powered on");
  }
  
  // Configure SMS
  Serial.println("\nConfiguring SMS...");
  sendATCommand("AT+CMGF=1", "OK");  // Text mode
  sendATCommand("AT+CSMP=17,167,0,0", "OK");  // SMS parameters
  
  Serial.println("=== Initialization Complete ===\n");
}

void setup() {
  Serial.begin(115200);
  simSerial.begin(115200, SERIAL_8N1, SIM_RX, SIM_TX);
  
  Serial.println("\n==================================");
  Serial.println("    SIM7070G GPS Tracker v2.0");
  Serial.println("==================================");
  
  // Wait for module to be ready
  delay(2000);
  while (!sendATCommand("AT", "OK")) {
    Serial.println("Waiting for SIM7070G module...");
    delay(1000);
  }
  
  // Initialize module with AT command sequence
  initializeModule();
  
  // Start GPS scanning
  Serial.println("\n=== Starting GPS Scan ===");
  Serial.println("Will continuously scan until fix is acquired...\n");
  
  int attemptCount = 0;
  bool fixAcquired = false;
  
  // Main GPS acquisition loop
  while (!fixAcquired) {
    attemptCount++;
    Serial.print("Scan #" + String(attemptCount) + ": ");
    
    // Request GNSS information
    simSerial.println("AT+CGNSINF");
    delay(500);
    
    String gpsData = "";
    while (simSerial.available()) {
      gpsData += char(simSerial.read());
    }
    
    // Try to parse GPS data
    GPSData currentFix;
    if (parseGNSSData(gpsData, currentFix)) {
      Serial.println("FIX ACQUIRED!");
      fixAcquired = true;
      
      // Save GPS data
      lastGPSFix = currentFix;
      saveGPSData(lastGPSFix);
      
      // Turn off GNSS to save power
      Serial.println("\nTurning off GNSS...");
      if (sendATCommand("AT+CGNSPWR=0", "OK")) {
        Serial.println("✓ GNSS powered off");
      }
      
      // Wait for module to stabilize
      delay(5000);
      
      // Re-check network before SMS
      Serial.println("\nVerifying network...");
      sendATCommand("AT+CREG?", "OK");
      delay(2000);
      
      // Create user-friendly SMS message
      String smsMessage = "GPS Location:\n";
      smsMessage += "Copy & paste in Google Maps:\n";
      smsMessage += lastGPSFix.latitude + "," + lastGPSFix.longitude;
      
      // Send SMS
      Serial.println("\n=== Sending Location via SMS ===");
      bool smsSent = false;
      int smsAttempts = 0;
      
      while (!smsSent && smsAttempts < 3) {
        smsAttempts++;
        Serial.println("\nAttempt " + String(smsAttempts) + " of 3");
        
        if (sendSMS(smsMessage)) {
          smsSent = true;
          Serial.println("\n✓ SMS sent successfully!");
        } else {
          Serial.println("✗ SMS failed");
          if (smsAttempts < 3) {
            Serial.println("Retrying in 5 seconds...");
            delay(5000);
          }
        }
      }
      
      // Final status
      Serial.println("\n==================================");
      Serial.println("         TASK COMPLETE");
      Serial.println("==================================");
      Serial.println("✓ GPS fix acquired");
      Serial.println("✓ Data saved to ESP32");
      Serial.println("✓ GNSS turned off");
      if (smsSent) {
        Serial.println("✓ Location sent via SMS");
        Serial.println("\nRecipient can copy coordinates:");
        Serial.println(lastGPSFix.latitude + "," + lastGPSFix.longitude);
        Serial.println("and paste in Google Maps");
      } else {
        Serial.println("✗ SMS sending failed");
        Serial.println("\nManual coordinates:");
        Serial.println(lastGPSFix.latitude + "," + lastGPSFix.longitude);
      }
      Serial.println("==================================");
      
    } else {
      Serial.println("No fix yet");
    }
    
    // Wait before next scan
    if (!fixAcquired) {
      delay(2000);
    }
  }
}

void loop() {
  // All tasks completed in setup
  delay(10000);
}
