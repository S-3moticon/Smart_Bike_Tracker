/*
 * VL53L1X ToF User Detection Test - ESP32-C3 Supermini
 *
 * Pin Configuration:
 * - SDA   -> GPIO 6 (shared I2C with LSM6DSL)
 * - SCL   -> GPIO 7 (shared I2C with LSM6DSL)
 * - INT   -> GPIO 3 (interrupt for measurement ready)
 * - XSHUT -> GPIO 20 (shutdown/power management)
 *
 * Library: SparkFun VL53L1X Arduino Library
 * Install via: Arduino Library Manager -> "SparkFun VL53L1X"
 */

#include <Wire.h>
#include "SparkFun_VL53L1X.h"

// Pin definitions
#define SDA_PIN 6
#define SCL_PIN 7
#define INT_PIN 3
#define SHUTDOWN_PIN 20

// User detection thresholds (mm)
#define USER_PRESENT_MM 800   // User detected if < 800mm
#define USER_AWAY_MM 1000     // User away if > 1000mm

// Sensor object
SFEVL53L1X sensor;

// State tracking
bool userPresent = false;
volatile bool dataReady = false;

// ISR
void IRAM_ATTR onDataReady() {
  dataReady = true;
}

void setup() {
  Serial.begin(115200);
  delay(500);

  // XSHUT pin (power control)
  pinMode(SHUTDOWN_PIN, OUTPUT);
  digitalWrite(SHUTDOWN_PIN, HIGH);
  delay(10);

  // I2C init
  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(400000);

  // Sensor init
  Serial.println("\n=== VL53L1X User Detection Test ===");
  if (sensor.begin() != 0) {
    Serial.println("ERROR: Sensor init failed");
    Serial.println("Check: SDA=6, SCL=7, XSHUT=20, Power=3.3V");
    while (1);
  }

  Serial.println("Sensor OK");
  Serial.printf("Threshold: <=%dmm=PRESENT, >%dmm=AWAY\n", USER_PRESENT_MM, USER_AWAY_MM);

  // Configure for user detection
  sensor.setDistanceModeShort();
  sensor.setTimingBudgetInMs(50);
  sensor.setIntermeasurementPeriod(50);

  // Test 1: Basic Detection
  testBasicDetection();

  // Test 2: Interrupt Mode
  testInterruptMode();

  // Test 3: Power Management
  testPowerManagement();

  // Start continuous monitoring
  Serial.println("\n=== Continuous Monitoring ===");
  Serial.println("Commands: stop, start, status, help\n");
  sensor.startRanging();
}

void testBasicDetection() {
  Serial.println("\n--- Test 1: Basic Detection (10s) ---");
  sensor.startRanging();
  delay(100);

  bool lastState = false;
  unsigned long start = millis();
  int count = 0;

  while (millis() - start < 10000) {
    while (!sensor.checkForDataReady()) delay(1);

    int distance = sensor.getDistance();
    byte status = sensor.getRangeStatus();
    count++;

    if (status == 0) {  // Valid measurement
      bool state = (distance < USER_PRESENT_MM) ? true :
                   (distance > USER_AWAY_MM) ? false : lastState;

      if (state != lastState) {
        Serial.printf("[%4lums] %4dmm -> %s\n", millis()-start, distance,
                      state ? "PRESENT" : "AWAY");
        lastState = state;
      }
    }
    sensor.clearInterrupt();
  }

  sensor.stopRanging();
  Serial.printf("Done. %d measurements (%.1f Hz)\n", count, count/10.0);
}

void testInterruptMode() {
  Serial.println("\n--- Test 2: Interrupt Mode (10s) ---");

  pinMode(INT_PIN, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(INT_PIN), onDataReady, FALLING);

  sensor.startRanging();
  delay(100);

  bool lastState = false;
  unsigned long start = millis();
  int count = 0;

  while (millis() - start < 10000) {
    if (dataReady) {
      dataReady = false;
      int distance = sensor.getDistance();
      byte status = sensor.getRangeStatus();
      count++;

      if (status == 0) {
        bool state = (distance < USER_PRESENT_MM) ? true :
                     (distance > USER_AWAY_MM) ? false : lastState;

        if (state != lastState) {
          Serial.printf("[INT#%d] %4dmm -> %s\n", count, distance,
                        state ? "PRESENT" : "AWAY");
          lastState = state;
        }
      }
      sensor.clearInterrupt();
    }
    delay(1);
  }

  sensor.stopRanging();
  detachInterrupt(digitalPinToInterrupt(INT_PIN));
  Serial.printf("Done. %d interrupts (%.1f Hz)\n", count, count/10.0);
}

void testPowerManagement() {
  Serial.println("\n--- Test 3: Power Management ---");

  // Active mode
  Serial.println("Active mode:");
  sensor.startRanging();
  delay(100);
  for (int i = 0; i < 3; i++) {
    while (!sensor.checkForDataReady()) delay(1);
    Serial.printf("  %dmm\n", sensor.getDistance());
    sensor.clearInterrupt();
    delay(100);
  }
  sensor.stopRanging();

  // Standby mode (XSHUT LOW)
  Serial.println("Entering standby (XSHUT=LOW)...");
  digitalWrite(SHUTDOWN_PIN, LOW);
  Serial.println("Standby: ~5uA (sleeping 3s)");
  delay(3000);

  // Wake up
  Serial.println("Waking (XSHUT=HIGH)...");
  digitalWrite(SHUTDOWN_PIN, HIGH);
  delay(10);

  // Re-init after wake
  if (sensor.begin() != 0) {
    Serial.println("ERROR: Re-init failed");
  } else {
    Serial.println("Sensor re-initialized OK");
    sensor.setDistanceModeShort();
    sensor.setTimingBudgetInMs(50);
    sensor.setIntermeasurementPeriod(50);

    // Verify operation
    sensor.startRanging();
    delay(100);
    while (!sensor.checkForDataReady()) delay(1);
    Serial.printf("  Verify: %dmm\n", sensor.getDistance());
    sensor.clearInterrupt();
    sensor.stopRanging();
  }
  Serial.println("Power test complete");
}

void loop() {
  static bool ranging = true;
  static unsigned long lastUpdate = 0;

  // Serial commands
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    cmd.toLowerCase();

    if (cmd == "stop") {
      sensor.stopRanging();
      ranging = false;
      Serial.println("Stopped");
    } else if (cmd == "start") {
      sensor.startRanging();
      ranging = true;
      userPresent = false;
      Serial.println("Started");
    } else if (cmd == "status") {
      Serial.printf("User: %s, Threshold: <=%dmm/>%dmm\n",
                    userPresent ? "PRESENT" : "AWAY",
                    USER_PRESENT_MM, USER_AWAY_MM);
    } else if (cmd == "help") {
      Serial.println("stop | start | status | help");
    }
  }

  // User detection
  if (ranging && sensor.checkForDataReady()) {
    int distance = sensor.getDistance();
    byte status = sensor.getRangeStatus();
    bool prevState = userPresent;

    if (status == 0) {  // Valid
      if (distance < USER_PRESENT_MM) userPresent = true;
      else if (distance > USER_AWAY_MM) userPresent = false;
    }

    // Report changes
    if (userPresent != prevState) {
      Serial.printf("[%lus] %4dmm -> %s\n", millis()/1000, distance,
                    userPresent ? "PRESENT" : "AWAY");
    }

    // Periodic update (5s)
    if (millis() - lastUpdate > 5000) {
      lastUpdate = millis();
      Serial.printf("[%lus] %4dmm | %s\n", millis()/1000, distance,
                    userPresent ? "PRESENT" : "AWAY");
    }

    sensor.clearInterrupt();
  }

  delay(10);
}
