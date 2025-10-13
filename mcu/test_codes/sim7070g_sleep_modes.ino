/*
 * SIM7070G Sleep Mode Test Suite
 *
 * Based on SIM7070_SIM7080_SIM7090 Series AT Command Manual V1.05+
 * Tests all available power-saving modes for the SIM7070G module
 *
 * Sleep Modes Tested:
 * 1. AT+CSCLK - Slow Clock Sleep Mode (~1.2mA @ DRX=2.56s)
 * 2. AT+CPSMS - Power Saving Mode (~9uA)
 * 3. AT+CFUN=0 - Minimum Functionality Mode
 * 4. AT+CPOWD=1 - Power Down Command
 *
 * Pin Configuration for ESP32-C3:
 * - SIM7070G TX -> ESP32 GPIO 20 (RX)
 * - SIM7070G RX -> ESP32 GPIO 21 (TX)
 * - DTR pin control for wake-up (optional, connect to GPIO if needed)
 *
 * Hardware Notes:
 * - DTR pin: Pull low to wake from CSCLK sleep mode
 * - PWRKEY pin: Long press (1.5s) to power on/off hardware
 */

#include <HardwareSerial.h>

// Pin definitions for ESP32-C3 Supermini
#define SIM_TX 21  // ESP32 TX -> SIM7070G RX
#define SIM_RX 20  // ESP32 RX -> SIM7070G TX
#define DTR_PIN 4  // DTR control pin (optional, for wake-up)

HardwareSerial simSerial(1);

// Test mode selection
enum TestMode {
  TEST_CSCLK_SLEEP,      // Slow clock sleep mode
  TEST_PSM_MODE,         // Power Saving Mode
  TEST_MIN_FUNC,         // Minimum functionality (CFUN=0)
  TEST_POWER_DOWN,       // Complete power down
  TEST_ALL_MODES         // Run all tests sequentially
};

// Current test configuration
TestMode currentTest = TEST_ALL_MODES;  // Change this to test specific mode

// Send AT command and wait for expected response
bool sendATCommand(String cmd, String expectedResp, uint32_t timeout = 2000) {
  Serial.println("\n> " + cmd);
  simSerial.println(cmd);

  uint32_t start = millis();
  String buffer = "";

  while (millis() - start < timeout) {
    while (simSerial.available()) {
      char c = simSerial.read();
      buffer += c;
    }

    if (buffer.indexOf(expectedResp) != -1) {
      Serial.println("< " + buffer);
      return true;
    }

    delay(10);
  }

  Serial.println("< " + buffer);
  Serial.println("✗ Expected: " + expectedResp);
  return false;
}

// Send AT command and return full response
String sendATCommandGetResponse(String cmd, uint32_t timeout = 2000) {
  Serial.println("\n> " + cmd);
  simSerial.println(cmd);

  delay(500);  // Give module time to respond

  String buffer = "";
  uint32_t start = millis();

  while (millis() - start < timeout) {
    while (simSerial.available()) {
      char c = simSerial.read();
      buffer += c;
    }
    delay(10);
  }

  Serial.println("< " + buffer);
  return buffer;
}

// Initialize module to known state
bool initializeModule() {
  Serial.println("\n╔════════════════════════════════════════╗");
  Serial.println("║   Module Initialization & Verify      ║");
  Serial.println("╚════════════════════════════════════════╝");

  // Test basic communication
  Serial.println("\n[1/5] Testing basic communication...");
  if (!sendATCommand("AT", "OK", 3000)) {
    Serial.println("✗ Module not responding");
    return false;
  }
  Serial.println("✓ Module responding");

  // Get module info
  Serial.println("\n[2/5] Getting module information...");
  sendATCommandGetResponse("ATI", 2000);

  // Check SIM card status
  Serial.println("\n[3/5] Checking SIM card status...");
  sendATCommandGetResponse("AT+CPIN?", 2000);

  // Check signal quality
  Serial.println("\n[4/5] Checking signal quality...");
  sendATCommandGetResponse("AT+CSQ", 2000);

  // Check network registration
  Serial.println("\n[5/5] Checking network registration...");
  sendATCommandGetResponse("AT+CREG?", 2000);

  Serial.println("\n✓ Initialization complete");
  return true;
}

// Test 1: CSCLK Sleep Mode (Slow Clock)
void testCSCLKSleepMode() {
  Serial.println("\n╔════════════════════════════════════════╗");
  Serial.println("║   TEST 1: AT+CSCLK Sleep Mode          ║");
  Serial.println("╚════════════════════════════════════════╝");

  Serial.println("\nMode Description:");
  Serial.println("- Slow clock sleep mode");
  Serial.println("- Current consumption: ~1.2mA @ DRX=2.56s");
  Serial.println("- Wake method: Pull DTR pin LOW or receive data");
  Serial.println("- Module remains network-registered");

  // Check current CSCLK setting
  Serial.println("\n[1/4] Checking current CSCLK setting...");
  sendATCommandGetResponse("AT+CSCLK?", 2000);

  // Disable sleep first (baseline)
  Serial.println("\n[2/4] Disabling sleep mode (AT+CSCLK=0)...");
  if (sendATCommand("AT+CSCLK=0", "OK")) {
    Serial.println("✓ Sleep mode disabled (baseline state)");
  }
  delay(1000);

  // Enable slow clock sleep mode
  Serial.println("\n[3/4] Enabling slow clock sleep (AT+CSCLK=1)...");
  if (sendATCommand("AT+CSCLK=1", "OK")) {
    Serial.println("✓ Sleep mode enabled");
    Serial.println("\nModule will enter sleep after few seconds of inactivity");
    Serial.println("Monitor current consumption to verify sleep entry");
  } else {
    Serial.println("✗ Failed to enable sleep mode");
    return;
  }

  // Wait and test wake-up
  Serial.println("\n[4/4] Testing wake-up...");
  Serial.println("Waiting 10 seconds for module to enter sleep...");
  delay(10000);

  Serial.println("Attempting to wake module with AT command...");
  if (sendATCommand("AT", "OK", 5000)) {
    Serial.println("✓ Module woke up successfully");
  } else {
    Serial.println("✗ Wake-up failed or module did not respond");
  }

  // Restore to non-sleep mode
  Serial.println("\nRestoring normal mode (AT+CSCLK=0)...");
  sendATCommand("AT+CSCLK=0", "OK");

  Serial.println("\n✓ TEST 1 COMPLETE");
}

// Test 2: Power Saving Mode (PSM)
void testPSMMode() {
  Serial.println("\n╔════════════════════════════════════════╗");
  Serial.println("║   TEST 2: AT+CPSMS Power Saving Mode   ║");
  Serial.println("╚════════════════════════════════════════╝");

  Serial.println("\nMode Description:");
  Serial.println("- Ultra-low power mode: ~9uA");
  Serial.println("- Module remains network-registered");
  Serial.println("- Network can't reach module during PSM");
  Serial.println("- Periodic wake-up based on T3412 timer");
  Serial.println("- Best for IoT applications with periodic reporting");

  // Check PSM support
  Serial.println("\n[1/5] Checking PSM support...");
  String response = sendATCommandGetResponse("AT+CPSMS=?", 2000);

  // Query current PSM settings
  Serial.println("\n[2/5] Querying current PSM settings...");
  sendATCommandGetResponse("AT+CPSMS?", 2000);

  // Disable PSM first (baseline)
  Serial.println("\n[3/5] Disabling PSM (baseline)...");
  if (sendATCommand("AT+CPSMS=0", "OK")) {
    Serial.println("✓ PSM disabled");
  }
  delay(1000);

  // Enable PSM with timer configuration
  Serial.println("\n[4/5] Enabling PSM with timers...");
  Serial.println("\nTimer Configuration:");
  Serial.println("- T3412 (Extended TAU): 01000111 = 70 minutes");
  Serial.println("- T3324 (Active Time): 00000000 = 0 seconds");
  Serial.println("- Sleep duration: ~70 minutes");

  // AT+CPSMS=1,,,"T3412","T3324"
  String psmCmd = "AT+CPSMS=1,,,\"01000111\",\"00000000\"";
  if (sendATCommand(psmCmd, "OK", 5000)) {
    Serial.println("✓ PSM configured successfully");
    Serial.println("\nNOTE: PSM will activate after network detach");
    Serial.println("Module must complete network procedures first");
    Serial.println("Actual PSM entry may take several minutes");
  } else {
    Serial.println("✗ PSM configuration failed");
    Serial.println("Possible reasons:");
    Serial.println("- Network doesn't support PSM");
    Serial.println("- SIM card not inserted");
    Serial.println("- Not registered to network");
  }

  // Query PSM settings to verify
  Serial.println("\n[5/5] Verifying PSM configuration...");
  sendATCommandGetResponse("AT+CPSMS?", 2000);

  // Disable PSM for next tests
  Serial.println("\nDisabling PSM for safety...");
  sendATCommand("AT+CPSMS=0", "OK");

  Serial.println("\n✓ TEST 2 COMPLETE");
  Serial.println("\nNOTE: For actual PSM testing, leave PSM enabled");
  Serial.println("and monitor current consumption over time");
}

// Test 3: Minimum Functionality Mode
void testMinimumFunctionality() {
  Serial.println("\n╔════════════════════════════════════════╗");
  Serial.println("║   TEST 3: AT+CFUN Minimum Function     ║");
  Serial.println("╚════════════════════════════════════════╝");

  Serial.println("\nMode Description:");
  Serial.println("- Minimum functionality mode");
  Serial.println("- RF circuits disabled (no TX/RX)");
  Serial.println("- Lower power than full function");
  Serial.println("- Module still responsive to AT commands");
  Serial.println("- Good for configuration without network");

  // Check current functionality level
  Serial.println("\n[1/3] Checking current functionality level...");
  sendATCommandGetResponse("AT+CFUN?", 2000);

  // Set to minimum functionality
  Serial.println("\n[2/3] Setting minimum functionality (AT+CFUN=0)...");
  if (sendATCommand("AT+CFUN=0", "OK", 5000)) {
    Serial.println("✓ Minimum functionality mode activated");
    Serial.println("RF circuits are now disabled");
  } else {
    Serial.println("✗ Failed to set minimum functionality");
    return;
  }

  delay(2000);

  // Test communication in min function mode
  Serial.println("\nTesting AT communication in min function mode...");
  if (sendATCommand("AT", "OK")) {
    Serial.println("✓ Module still responds to AT commands");
  }

  // Check functionality level
  sendATCommandGetResponse("AT+CFUN?", 2000);

  // Restore full functionality
  Serial.println("\n[3/3] Restoring full functionality (AT+CFUN=1)...");
  if (sendATCommand("AT+CFUN=1", "OK", 10000)) {
    Serial.println("✓ Full functionality restored");
    Serial.println("Waiting for network registration...");
    delay(5000);
    sendATCommandGetResponse("AT+CREG?", 2000);
  } else {
    Serial.println("✗ Failed to restore full functionality");
  }

  Serial.println("\n✓ TEST 3 COMPLETE");
}

// Test 4: Power Down Command
void testPowerDown() {
  Serial.println("\n╔════════════════════════════════════════╗");
  Serial.println("║   TEST 4: AT+CPOWD Power Down          ║");
  Serial.println("╚════════════════════════════════════════╝");

  Serial.println("\nMode Description:");
  Serial.println("- Complete software power-down");
  Serial.println("- Module will not respond until hardware restart");
  Serial.println("- Requires PWRKEY toggle to power back on");
  Serial.println("- Safest way to power off the module");

  Serial.println("\n⚠ WARNING: This test will power down the module!");
  Serial.println("You will need to manually restart it using PWRKEY");
  Serial.println("\nSkipping actual power down for safety...");
  Serial.println("\nTo manually test power down, send:");
  Serial.println("AT+CPOWD=1  (normal power down)");
  Serial.println("AT+CPOWD=0  (emergency power down)");

  Serial.println("\n✓ TEST 4 COMPLETE (Informational only)");
}

// Compare all sleep modes
void printSleepModeComparison() {
  Serial.println("\n╔════════════════════════════════════════╗");
  Serial.println("║   Sleep Mode Comparison Summary        ║");
  Serial.println("╚════════════════════════════════════════╝");

  Serial.println("\n┌─────────────┬─────────────┬──────────────┬───────────────┐");
  Serial.println("│ Mode        │ Current     │ Wake Method  │ Network       │");
  Serial.println("├─────────────┼─────────────┼──────────────┼───────────────┤");
  Serial.println("│ Normal      │ ~100-500mA  │ N/A          │ Active        │");
  Serial.println("│ CSCLK=1     │ ~1.2mA      │ DTR/AT cmd   │ Registered    │");
  Serial.println("│ PSM         │ ~9uA        │ Timer/Event  │ Registered    │");
  Serial.println("│ CFUN=0      │ ~10-50mA    │ AT cmd       │ Detached      │");
  Serial.println("│ CPOWD       │ 0mA         │ PWRKEY       │ Off           │");
  Serial.println("└─────────────┴─────────────┴──────────────┴───────────────┘");

  Serial.println("\nRecommendations:");
  Serial.println("• For GPS tracking with frequent updates: CSCLK=1");
  Serial.println("• For periodic IoT reporting (10min+): PSM mode");
  Serial.println("• For long-term storage: CPOWD=1");
  Serial.println("• For configuration only: CFUN=0");
}

void setup() {
  Serial.begin(115200);
  simSerial.begin(115200, SERIAL_8N1, SIM_RX, SIM_TX);

  #ifdef DTR_PIN
  pinMode(DTR_PIN, OUTPUT);
  digitalWrite(DTR_PIN, HIGH);  // DTR HIGH = allow sleep, LOW = wake
  #endif

  Serial.println("\n");
  Serial.println("╔════════════════════════════════════════╗");
  Serial.println("║  SIM7070G Sleep Mode Test Suite       ║");
  Serial.println("║  Firmware: ESP32-C3 Supermini          ║");
  Serial.println("╚════════════════════════════════════════╝");

  delay(3000);  // Wait for module to boot

  // Initialize and verify module
  if (!initializeModule()) {
    Serial.println("\n✗ Initialization failed!");
    Serial.println("Check connections and restart");
    while(1) delay(1000);
  }

  // Run tests based on selected mode
  delay(2000);

  if (currentTest == TEST_CSCLK_SLEEP || currentTest == TEST_ALL_MODES) {
    testCSCLKSleepMode();
    delay(3000);
  }

  if (currentTest == TEST_PSM_MODE || currentTest == TEST_ALL_MODES) {
    testPSMMode();
    delay(3000);
  }

  if (currentTest == TEST_MIN_FUNC || currentTest == TEST_ALL_MODES) {
    testMinimumFunctionality();
    delay(3000);
  }

  if (currentTest == TEST_POWER_DOWN || currentTest == TEST_ALL_MODES) {
    testPowerDown();
    delay(3000);
  }

  if (currentTest == TEST_ALL_MODES) {
    printSleepModeComparison();
  }

  Serial.println("\n╔════════════════════════════════════════╗");
  Serial.println("║   ALL TESTS COMPLETED                  ║");
  Serial.println("╚════════════════════════════════════════╝");
  Serial.println("\nModule is in normal operation mode");
  Serial.println("You can now send manual AT commands via Serial Monitor");
}

void loop() {
  // Echo between Serial and SIM module for manual testing
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    if (cmd.length() > 0) {
      simSerial.println(cmd);
      Serial.println("> " + cmd);
    }
  }

  if (simSerial.available()) {
    String response = simSerial.readString();
    Serial.print("< " + response);
  }
}
