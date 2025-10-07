/*
 * sim7070g.cpp
 * 
 * Implementation of SIM7070G module interface
 */

#include "sim7070g.h"

// Hardware serial instance for SIM7070G communication
HardwareSerial simSerial(1);

// Track initialization state
static bool sim7070gInitialized = false;

/*
 * Check if SIM7070G is initialized
 */
bool isSIM7070GInitialized() {
  return sim7070gInitialized;
}

/*
 * Initialize the SIM7070G module
 * Sets up UART, performs module reset, and configures basic settings
 */
bool initializeSIM7070G() {
  // If already initialized, just return true
  if (sim7070gInitialized) {
    Serial.println("📡 SIM7070G already initialized");
    return true;
  }
  // Initialize serial communication
  simSerial.begin(115200, SERIAL_8N1, SIM_RX_PIN, SIM_TX_PIN);
  delay(2000);
  
  Serial.println("📡 Initializing SIM7070G module...");
  
  // Check if module responds
  int attempts = 0;
  while (!sendATCommand("AT", "OK") && attempts < 5) {
    delay(1000);
    attempts++;
  }
  
  if (attempts >= 5) {
    Serial.println("❌ SIM7070G not responding");
    return false;
  }
  
  Serial.println("✅ SIM7070G module detected");
  
  // Skip reset on initial boot to save time and power
  // Module will be reset when BLE disconnects if needed
  
  // Check signal quality
  sendATCommand("AT+CSQ", "OK", 5000);
  delay(1000);
  
  // Configure SMS text mode
  sendATCommand("AT+CMGF=1", "OK");
  sendATCommand("AT+CSMP=17,167,0,0", "OK");
  
  Serial.println("✅ SIM7070G initialization complete");
  sim7070gInitialized = true;
  return true;
}

/*
 * Send AT command and wait for expected response
 */
bool sendATCommand(const String& cmd, const String& expectedResp, uint32_t timeout) {
  // Clear any pending data
  while (simSerial.available()) {
    simSerial.read();
  }
  
  // Send command
  simSerial.println(cmd);
  
  // Wait for response
  uint32_t start = millis();
  String buffer = "";
  
  while (millis() - start < timeout) {
    while (simSerial.available()) {
      char c = simSerial.read();
      buffer += c;
      
      // Check if we got expected response
      if (buffer.indexOf(expectedResp) != -1) {
        return true;
      }
      
      // Check for error
      if (buffer.indexOf("ERROR") != -1) {
        return false;
      }
    }
    delay(10);
  }
  
  return false;
}

/*
 * Check network registration status
 */
bool checkNetworkRegistration() {
  Serial.println("📶 Checking network registration...");
  
  int attempts = 0;
  while (attempts < 30) {
    if (sendATCommand("AT+CREG?", "0,1", NETWORK_TIMEOUT) || 
        sendATCommand("AT+CREG?", "0,5", NETWORK_TIMEOUT)) {
      Serial.println("✅ Network registered");
      
      // Check operator
      sendATCommand("AT+COPS?", "OK", 5000);
      return true;
    }
    delay(2000);
    attempts++;
  }
  
  Serial.println("❌ Network registration failed");
  return false;
}

/*
 * Check if module is ready for operations
 */
bool isModuleReady() {
  return sendATCommand("AT", "OK", 1000);
}

/*
 * Enable GNSS power
 */
bool enableGNSSPower() {
  Serial.println("🛰️ Enabling GPS...");
  bool result = sendATCommand("AT+CGNSPWR=1", "OK", 5000);
  if (result) {
    Serial.println("✅ GPS powered on");
  } else {
    Serial.println("❌ Failed to power on GPS");
  }
  return result;
}

/*
 * Disable GNSS power to save battery
 */
bool disableGNSSPower() {
  Serial.println("🛰️ Disabling GPS...");
  bool result = sendATCommand("AT+CGNSPWR=0", "OK", 5000);
  if (result) {
    Serial.println("✅ GPS powered off");
  } else {
    Serial.println("❌ Failed to power off GPS");
  }
  return result;
}

/*
 * Clear serial buffer
 */
void clearSerialBuffer() {
  while (simSerial.available()) {
    simSerial.read();
  }
}

/*
 * Read response from module
 */
String readResponse(uint32_t timeout) {
  String response = "";
  uint32_t start = millis();
  
  while (millis() - start < timeout) {
    while (simSerial.available()) {
      char c = simSerial.read();
      response += c;
    }
    
    if (response.length() > 0 && 
        (response.indexOf("OK") != -1 || response.indexOf("ERROR") != -1)) {
      break;
    }
    delay(10);
  }
  
  return response;
}

/*
 * Reset the SIM7070G module
 * Performs a clean reset to ensure module is in known state
 */
bool resetModule() {
  bool result = sendATCommand("AT+CFUN=1,1", "OK", 10000);
  
  if (result) {
    delay(10000);  // Wait for module to restart
    
    // Verify module is ready
    int attempts = 0;
    while (!sendATCommand("AT", "OK") && attempts < 10) {
      delay(1000);
      attempts++;
    }
    return attempts < 10;
  }
  
  return false;
}

/*
 * Disable RF functionality (AT+CFUN=0)
 * This turns off all RF circuits to save power
 */
bool disableRF() {
  Serial.println("📡 Disabling RF (AT+CFUN=0)...");
  bool result = sendATCommand("AT+CFUN=0", "OK", 5000);
  if (result) {
    Serial.println("✅ RF disabled - minimum power mode");
    delay(1000);  // Let module stabilize
  } else {
    Serial.println("❌ Failed to disable RF");
  }
  return result;
}

/*
 * Enable RF functionality (AT+CFUN=1)
 * This turns on RF circuits for normal operation
 */
bool enableRF() {
  Serial.println("📡 Enabling RF (AT+CFUN=1)...");
  bool result = sendATCommand("AT+CFUN=1", "OK", 10000);
  if (result) {
    Serial.println("✅ RF enabled - full functionality");
    delay(2000);  // Wait for RF to stabilize
    
    // Wait for network registration after enabling RF
    int attempts = 0;
    while (attempts < 10) {
      if (sendATCommand("AT+CREG?", "0,1", 2000) || 
          sendATCommand("AT+CREG?", "0,5", 2000)) {
        Serial.println("✅ Network registered after RF enable");
        break;
      }
      delay(1000);
      attempts++;
    }
  } else {
    Serial.println("❌ Failed to enable RF");
  }
  return result;
}