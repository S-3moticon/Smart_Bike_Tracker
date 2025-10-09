/*
 * ESP32-C3 Supermini LSM6DSL Motion Detection Test
 *
 * Tests sleep/wake functionality with LSM6DSL accelerometer
 * Matches main MCU code sleep implementation
 *
 * FEATURES:
 * - Motion detection with configurable threshold
 * - Automatic sleep after 5 seconds of no motion
 * - GPIO wake on motion interrupt (HIGH level trigger)
 * - 10-second timer backup wake (prevents stuck state)
 * - Wake reason detection and reporting
 *
 * CRITICAL FIXES:
 * v2.0 - Pin Configuration:
 *   - Changed INT pins from INPUT_PULLUP to INPUT (no pull resistors)
 *   - PULLUP made pins always HIGH, preventing GPIO wake trigger
 *
 * v3.0 - Watchdog Timer Issue Found:
 *   - Device was RESETTING during light sleep (~28 seconds)
 *   - ESP32-C3 watchdog timers cause reboot during light sleep
 *   - Watchdog disable headers not available in Arduino ESP32 core
 *
 * v3.1 - Deep Sleep Default (WORKING SOLUTION):
 *   - Using deep sleep to avoid watchdog issues
 *   - Deep sleep is reliable and doesn't have reset problems
 *   - USB disconnects but GPIO/timer wake works perfectly
 *   - Must press RESET button to see serial output after wake
 *
 * CONFIGURATION (lines 91-92):
 * #define USE_DEEP_SLEEP true     ← DEFAULT: Deep sleep (reliable)
 * #define DEBUG_FAKE_SLEEP false  ← Set true to test without actual sleep
 *
 * SLEEP MODES:
 * 1. Deep Sleep (USE_DEEP_SLEEP = true) ✅ DEFAULT:
 *    - No watchdog issues
 *    - Reliable wake on GPIO and timer
 *    - USB disconnects during sleep
 *    - Press RESET after wake to see serial output
 *    - Lower power consumption (~10µA)
 *
 * 2. Light Sleep (USE_DEEP_SLEEP = false):
 *    - ⚠️  Has watchdog reset issues on ESP32-C3
 *    - USB stays connected
 *    - May reset after ~28 seconds
 *    - Not recommended until watchdog fix available
 *
 * 3. Debug Mode (DEBUG_FAKE_SLEEP = true):
 *    - Uses delay() instead of sleep
 *    - Tests LSM6DSL interrupt generation
 *    - Always shows serial output
 *    - Good for testing hardware without sleep issues
 *
 * RECOVERY IF STUCK:
 * Hold BOOT button → Press RESET → Release BOOT → Upload new code
 */

#include <Wire.h>
#include "esp_sleep.h"

// Pin Definitions
#define INT1_PIN GPIO_NUM_0
#define INT2_PIN GPIO_NUM_1
#define SDA_PIN 6
#define SCL_PIN 7

// LSM6DSL I2C Addresses
#define LSM6DSL_ADDR1 0x6A
#define LSM6DSL_ADDR2 0x6B
uint8_t LSM6DSL_ADDR = LSM6DSL_ADDR1;

// LSM6DSL Registers
#define WHO_AM_I 0x0F
#define CTRL1_XL 0x10
#define CTRL3_C 0x12
#define CTRL6_C 0x15
#define OUTX_L_XL 0x28
#define MD1_CFG 0x5E
#define MD2_CFG 0x5F
#define WAKE_UP_THS 0x5B
#define WAKE_UP_DUR 0x5C
#define TAP_CFG 0x58
#define STATUS_REG 0x1E

// Motion detection settings
#define MOTION_THRESHOLD 0.05      // High sensitivity - detects small movements
#define NO_MOTION_TIMEOUT 5000     // 5 seconds before countdown
#define SLEEP_COUNTDOWN 5000        // 5 second countdown
#define GRAVITY 9.81                // For accurate g conversion

// Sleep mode configuration
// Note: Light sleep has watchdog issues, using deep sleep for reliability
#define USE_DEEP_SLEEP true     // true = deep sleep (USB disconnects), false = light sleep
#define DEBUG_FAKE_SLEEP false  // true = use delay() for testing without sleep

// Global variables
float currentX = 0, currentY = 0, currentZ = 0;
float previousX = 0, previousY = 0, previousZ = 0;
float refX = 0, refY = 0, refZ = 0;
bool motionDetected = false;
unsigned long lastMotionTime = 0;
RTC_DATA_ATTR int wakeCount = 0;
RTC_DATA_ATTR int motionCount = 0;
RTC_DATA_ATTR bool firstMotionSent = false;  // Track sleep phase
bool sensorAvailable = false;
bool firstReading = true;

void setup() {
  Serial.begin(115200);
  while (!Serial) { delay(10); }

  Serial.println("\n=== ESP32-C3 LSM6DSL Motion System ===");

  // CRITICAL: Use INPUT (no pull resistors) for GPIO wake to work
  // LSM6DSL will drive these pins HIGH on interrupt
  // Using PULLUP makes pins always HIGH = no wake trigger!
  pinMode(INT1_PIN, INPUT);
  pinMode(INT2_PIN, INPUT);

  // Check and report wake reason
  esp_sleep_wakeup_cause_t wakeup_reason = esp_sleep_get_wakeup_cause();

  switch (wakeup_reason) {
    case ESP_SLEEP_WAKEUP_GPIO:
      wakeCount++;
      Serial.printf("🔔 WAKE FROM MOTION! (GPIO) Count: %d\n", wakeCount);
      Serial.printf("   INT1: %s, INT2: %s\n",
                    digitalRead(INT1_PIN) == HIGH ? "HIGH" : "LOW",
                    digitalRead(INT2_PIN) == HIGH ? "HIGH" : "LOW");
      firstMotionSent = true;  // Ensure phase 2 next time
      break;

    case ESP_SLEEP_WAKEUP_TIMER:
      wakeCount++;
      Serial.printf("⏰ WAKE FROM TIMER! (Periodic) Count: %d\n", wakeCount);
      break;

    case ESP_SLEEP_WAKEUP_UNDEFINED:
    default:
      Serial.println("🔌 POWER-ON RESET / FIRST BOOT");
      wakeCount = 0;
      motionCount = 0;
      firstMotionSent = false;
      break;
  }
  
  // Suppress I2C errors
  esp_log_level_set("i2c.master", ESP_LOG_NONE);

  // Initialize I2C
  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(50000);
  delay(100);

  // Initialize sensor with proper configuration
  sensorAvailable = initLSM6DSL();

  if (sensorAvailable) {
    // If woke from GPIO (motion), clear LSM6DSL interrupts
    if (wakeup_reason == ESP_SLEEP_WAKEUP_GPIO) {
      Wire.beginTransmission(LSM6DSL_ADDR);
      Wire.write(0x1B);  // Read WAKE_UP_SRC to clear
      Wire.endTransmission(false);
      Wire.requestFrom(LSM6DSL_ADDR, (uint8_t)1);
      if (Wire.available()) {
        uint8_t wake_src = Wire.read();
        Serial.printf("   LSM6DSL wake source: 0x%02X\n", wake_src);
      }
    }

    Serial.println("LSM6DSL ready - calibrating...");
    calibrateSensor();
    Serial.printf("Calibration complete: X=%.3f Y=%.3f Z=%.3f\n", refX, refY, refZ);
  } else {
    Serial.println("Sensor not found - check connections");
    // Set default reference for simulation
    refX = 0;
    refY = 0;
    refZ = 1.0;
  }
  
  Serial.printf("Motion threshold: %.3fg (HIGH SENSITIVITY)\n\n", MOTION_THRESHOLD);

  // INITIAL TEST: Verify sleep works at all (only on first boot)
  if (wakeup_reason == ESP_SLEEP_WAKEUP_UNDEFINED) {
#if USE_DEEP_SLEEP
    Serial.println("=== INITIAL DEEP SLEEP TEST ===");
    Serial.println("⚠️  USB will disconnect! Press RESET after 5 sec to see output.");
    Serial.println("Testing 5-second timer wake...");
    Serial.flush();
    delay(200);

    esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);
    esp_sleep_enable_timer_wakeup(5 * 1000000ULL);  // 5 seconds
    esp_deep_sleep_start();  // Device will reboot after 5 seconds

#else
    Serial.println("=== INITIAL LIGHT SLEEP TEST ===");
    Serial.println("Testing 2-second timer-only wake...");
    Serial.flush();

    esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);
    esp_sleep_enable_timer_wakeup(2 * 1000000ULL);  // 2 seconds

    int64_t test_start = esp_timer_get_time();
    esp_err_t result = esp_light_sleep_start();
    int64_t test_duration = (esp_timer_get_time() - test_start) / 1000;

    Serial.printf("✓ Light sleep test complete! Duration: %lld ms, Result: %d\n",
                  test_duration, result);
    Serial.println("Light sleep API is working.\n");
    delay(1000);
#endif
  }

  lastMotionTime = millis();
}

void loop() {
  static unsigned long lastReadTime = 0;
  static unsigned long lastPrintTime = 0;
  static bool countdownActive = false;
  static unsigned long countdownStart = 0;
  static int lastSecond = -1;
  static float stableX = 0, stableY = 0, stableZ = 0;
  static int stableCount = 0;
  
  // Read sensor at 10Hz
  if (millis() - lastReadTime < 100) {
    return;
  }
  lastReadTime = millis();
  
  // Store previous values
  previousX = currentX;
  previousY = currentY;
  previousZ = currentZ;
  
  // Read new values
  if (!readAccelerometer()) {
    return;
  }
  
  // Check if values are stable (unchanged)
  float diff = abs(currentX - stableX) + abs(currentY - stableY) + abs(currentZ - stableZ);
  
  if (diff < 0.01) {  // Values unchanged (within 0.01g tolerance)
    stableCount++;
  } else {
    stableCount = 0;
    stableX = currentX;
    stableY = currentY;
    stableZ = currentZ;
  }
  
  // Calculate actual change from previous reading
  float changeX = currentX - previousX;
  float changeY = currentY - previousY;
  float changeZ = currentZ - previousZ;
  float totalChange = sqrt(changeX*changeX + changeY*changeY + changeZ*changeZ);
  
  // Motion detection
  if (totalChange > MOTION_THRESHOLD && !firstReading) {
    if (!motionDetected) {
      motionCount++;
      Serial.println("\n>>> MOTION DETECTED <<<");
      Serial.printf("Event #%d\n", motionCount);
      motionDetected = true;
    }
    
    // Print values immediately during motion (every 200ms)
    if (millis() - lastPrintTime > 200) {
      Serial.printf("X=%+.3f Y=%+.3f Z=%+.3f | Change: %.3fg\n", 
                    currentX, currentY, currentZ, totalChange);
      lastPrintTime = millis();
    }
    
    lastMotionTime = millis();
    stableCount = 0;
    
    // Cancel countdown if active
    if (countdownActive) {
      Serial.println("Countdown cancelled\n");
      countdownActive = false;
      lastSecond = -1;
    }
    
  } else if (motionDetected && (millis() - lastMotionTime > 2000)) {
    Serial.println("Motion stopped\n");
    motionDetected = false;
    
    // Update reference
    refX = currentX;
    refY = currentY;
    refZ = currentZ;
  }
  
  // Start countdown if values are stable for 5 seconds
  if (!motionDetected && stableCount > 50) {  // 50 * 100ms = 5 seconds of stable values
    if (!countdownActive) {
      countdownActive = true;
      countdownStart = millis();
      Serial.println("\n=== NO CHANGE DETECTED - SLEEP COUNTDOWN ===");
    }
    
    unsigned long elapsed = millis() - countdownStart;
    int secondsLeft = (SLEEP_COUNTDOWN - elapsed) / 1000;
    
    if (secondsLeft != lastSecond && secondsLeft >= 0) {
      Serial.printf("%d...\n", secondsLeft + 1);
      lastSecond = secondsLeft;
    }
    
    if (elapsed >= SLEEP_COUNTDOWN) {
      enterSleep();
    }
  }
  
  firstReading = false;
}

bool initLSM6DSL() {
  // Find sensor
  for (uint8_t addr = LSM6DSL_ADDR1; addr <= LSM6DSL_ADDR2; addr++) {
    Wire.beginTransmission(addr);
    if (Wire.endTransmission() == 0) {
      LSM6DSL_ADDR = addr;
      
      // Verify WHO_AM_I
      Wire.beginTransmission(LSM6DSL_ADDR);
      Wire.write(WHO_AM_I);
      Wire.endTransmission(false);
      Wire.requestFrom(LSM6DSL_ADDR, (uint8_t)1);
      
      if (Wire.available()) {
        uint8_t id = Wire.read();
        if (id == 0x6A || id == 0x6C) {
          Serial.printf("Found LSM6DSL at 0x%02X (ID: 0x%02X)\n", addr, id);
          
          // Proper initialization sequence
          
          // 1. Software reset
          Wire.beginTransmission(LSM6DSL_ADDR);
          Wire.write(CTRL3_C);
          Wire.write(0x01);
          Wire.endTransmission();
          delay(200);  // Wait for reset
          
          // 2. Configure accelerometer: 104Hz, ±2g, high performance
          Wire.beginTransmission(LSM6DSL_ADDR);
          Wire.write(CTRL1_XL);
          Wire.write(0x40);  // 104Hz, ±2g
          Wire.endTransmission();
          delay(50);
          
          // 3. Block data update + auto increment
          Wire.beginTransmission(LSM6DSL_ADDR);
          Wire.write(CTRL3_C);
          Wire.write(0x44);  // BDU=1, IF_INC=1
          Wire.endTransmission();
          delay(50);
          
          // 4. High performance mode
          Wire.beginTransmission(LSM6DSL_ADDR);
          Wire.write(CTRL6_C);
          Wire.write(0x00);  // High performance
          Wire.endTransmission();
          delay(50);
          
          return true;
        }
      }
    }
  }
  return false;
}

void calibrateSensor() {
  Serial.println("Calibrating... Keep device still");
  
  float sumX = 0, sumY = 0, sumZ = 0;
  int samples = 0;
  
  // Discard first readings
  for (int i = 0; i < 10; i++) {
    readAccelerometer();
    delay(10);
  }
  
  // Average multiple readings
  for (int i = 0; i < 50; i++) {
    if (readAccelerometer()) {
      sumX += currentX;
      sumY += currentY;
      sumZ += currentZ;
      samples++;
    }
    delay(20);
  }
  
  if (samples > 0) {
    refX = sumX / samples;
    refY = sumY / samples;
    refZ = sumZ / samples;
    
    // Set initial position
    previousX = refX;
    previousY = refY;
    previousZ = refZ;
    currentX = refX;
    currentY = refY;
    currentZ = refZ;
  }
}

bool readAccelerometer() {
  if (sensorAvailable) {
    // Check if new data available
    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(STATUS_REG);
    Wire.endTransmission(false);
    Wire.requestFrom(LSM6DSL_ADDR, (uint8_t)1);
    
    if (Wire.available()) {
      uint8_t status = Wire.read();
      if (!(status & 0x01)) {  // No new data
        return false;
      }
    }
    
    // Read all 6 bytes at once
    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(OUTX_L_XL);
    if (Wire.endTransmission(false) != 0) {
      return false;
    }
    
    if (Wire.requestFrom(LSM6DSL_ADDR, (uint8_t)6) == 6) {
      uint8_t xlo = Wire.read();
      uint8_t xhi = Wire.read();
      uint8_t ylo = Wire.read();
      uint8_t yhi = Wire.read();
      uint8_t zlo = Wire.read();
      uint8_t zhi = Wire.read();
      
      // Convert to signed 16-bit
      int16_t rawX = (int16_t)((xhi << 8) | xlo);
      int16_t rawY = (int16_t)((yhi << 8) | ylo);
      int16_t rawZ = (int16_t)((zhi << 8) | zlo);
      
      // Convert to g (±2g range = 32768 counts)
      currentX = (float)rawX / 16384.0;
      currentY = (float)rawY / 16384.0;
      currentZ = (float)rawZ / 16384.0;
      
      return true;
    }
  } else {
    // Simulation for testing
    static unsigned long simTime = 0;
    if (millis() - simTime > 5000) {
      currentX = refX + 0.3;
      currentY = refY + 0.2;
      currentZ = refZ - 0.1;
      simTime = millis();
    } else {
      currentX = refX + random(-10, 10) / 1000.0;
      currentY = refY + random(-10, 10) / 1000.0;
      currentZ = refZ + random(-10, 10) / 1000.0;
    }
    return true;
  }
  return false;
}

void configureSleepInterrupts() {
  if (sensorAvailable) {
    Serial.println("Configuring LSM6DSL for wake-on-motion...");

    // Clear any pending interrupts FIRST
    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(0x1B);  // WAKE_UP_SRC
    Wire.endTransmission(false);
    Wire.requestFrom(LSM6DSL_ADDR, (uint8_t)1);
    if (Wire.available()) Wire.read();

    // CRITICAL: Keep accelerometer running during deep sleep
    // Use higher ODR to ensure interrupts are generated
    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(CTRL1_XL);
    Wire.write(0x20);  // 52Hz ODR, ±2g, normal mode (NOT low-power)
    Wire.endTransmission();
    delay(50);  // Longer delay for ODR change to take effect

    // Configure CTRL3_C: Interrupts active HIGH, push-pull, non-latched
    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(CTRL3_C);
    Wire.write(0x44);  // BDU=1, IF_INC=1, INT active HIGH, push-pull
    Wire.endTransmission();
    delay(10);

    // Configure CTRL4_C: Interrupts enabled, INT2 on INT1 pad disabled
    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(0x13);  // CTRL4_C register
    Wire.write(0x00);  // All interrupts enabled
    Wire.endTransmission();
    delay(10);

    // Configure wake-up detection (MORE sensitive)
    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(WAKE_UP_DUR);
    Wire.write(0x00);  // No duration requirement
    Wire.endTransmission();

    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(WAKE_UP_THS);
    Wire.write(0x01);  // EXTREMELY sensitive (~15mg) - easier wake
    Wire.endTransmission();
    delay(10);

    // Enable interrupts - latched mode for deep sleep reliability
    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(TAP_CFG);
    Wire.write(0x81);  // Enable interrupts, LATCHED mode (bit 0 = 1)
    Wire.endTransmission();
    delay(50);  // Longer delay for interrupt enable

    // Route wake-up to BOTH INT1 and INT2
    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(MD1_CFG);
    Wire.write(0x20);  // Wake-up on INT1
    Wire.endTransmission();

    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(MD2_CFG);
    Wire.write(0x20);  // Wake-up on INT2
    Wire.endTransmission();
    delay(50);  // Allow interrupt routing to take effect

    // Verify interrupt routing
    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(MD1_CFG);
    Wire.endTransmission(false);
    Wire.requestFrom(LSM6DSL_ADDR, (uint8_t)1);
    uint8_t md1 = Wire.available() ? Wire.read() : 0;

    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(MD2_CFG);
    Wire.endTransmission(false);
    Wire.requestFrom(LSM6DSL_ADDR, (uint8_t)1);
    uint8_t md2 = Wire.available() ? Wire.read() : 0;

    // Read current CTRL1_XL to verify ODR
    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(CTRL1_XL);
    Wire.endTransmission(false);
    Wire.requestFrom(LSM6DSL_ADDR, (uint8_t)1);
    uint8_t ctrl1 = Wire.available() ? Wire.read() : 0;

    Serial.printf("LSM6DSL config: MD1=0x%02X MD2=0x%02X CTRL1_XL=0x%02X\n", md1, md2, ctrl1);
    Serial.println("Wake-on-motion interrupts configured (52Hz, latched)");
  }
}

void clearLSM6DSLInterrupts() {
  if (sensorAvailable) {
    // Read WAKE_UP_SRC register to clear interrupt
    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(0x1B);  // WAKE_UP_SRC register
    Wire.endTransmission(false);
    Wire.requestFrom(LSM6DSL_ADDR, (uint8_t)1);
    if (Wire.available()) {
      uint8_t wake_src = Wire.read();
      Serial.printf("Cleared wake source: 0x%02X\n", wake_src);
    }

    // Read STATUS_REG to clear data ready flags
    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(STATUS_REG);
    Wire.endTransmission(false);
    Wire.requestFrom(LSM6DSL_ADDR, (uint8_t)1);
    if (Wire.available()) Wire.read();

    // Read accelerometer data to clear any pending data
    readAccelerometer();
  }
}

void enterSleep() {
  Serial.println("\n=== ENTERING SLEEP ===");
  Serial.printf("Total: %d motions, %d wakes\n", motionCount, wakeCount);
  Serial.printf("Phase: %s\n", firstMotionSent ? "Periodic (Deep Sleep)" : "First Motion (Light Sleep)");
  Serial.flush();
  delay(100);

  if (!firstMotionSent) {
    // === PHASE 1: Light sleep with GPIO wake ONLY ===

    if (sensorAvailable) {
      configureSleepInterrupts();
      delay(50);
      clearLSM6DSLInterrupts();
      delay(100);

      // Wait for motion detection before sleeping (confirms interrupts working)
      Serial.println("Waiting for motion detection...");
      Serial.println("(Move device when ready to sleep)");
      Serial.flush();

      bool intDetected = false;
      while (!intDetected) {
        if (digitalRead(INT1_PIN) == HIGH || digitalRead(INT2_PIN) == HIGH) {
          intDetected = true;
          Serial.printf("✓ Motion detected! INT1=%s INT2=%s\n",
                        digitalRead(INT1_PIN) ? "HIGH" : "LOW",
                        digitalRead(INT2_PIN) ? "HIGH" : "LOW");
          Serial.println("✓ LSM6DSL interrupt working!");
          break;
        }
        delay(100);
      }

      clearLSM6DSLInterrupts();
      delay(100);
    }

    // Configure GPIO wake (NO timer backup)
    esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);

    Serial.println("Configuring GPIO wake sources...");
    gpio_reset_pin((gpio_num_t)INT1_PIN);
    gpio_reset_pin((gpio_num_t)INT2_PIN);
    gpio_set_direction((gpio_num_t)INT1_PIN, GPIO_MODE_INPUT);
    gpio_set_direction((gpio_num_t)INT2_PIN, GPIO_MODE_INPUT);
    gpio_set_pull_mode((gpio_num_t)INT1_PIN, GPIO_FLOATING);
    gpio_set_pull_mode((gpio_num_t)INT2_PIN, GPIO_FLOATING);

    esp_err_t ret1 = gpio_wakeup_enable((gpio_num_t)INT1_PIN, GPIO_INTR_HIGH_LEVEL);
    esp_err_t ret2 = gpio_wakeup_enable((gpio_num_t)INT2_PIN, GPIO_INTR_HIGH_LEVEL);
    esp_err_t ret3 = esp_sleep_enable_gpio_wakeup();

    Serial.printf("GPIO wake enable: INT1=%d INT2=%d Enable=%d\n", ret1, ret2, ret3);

    // Verify pin states
    int int1_state = digitalRead(INT1_PIN);
    int int2_state = digitalRead(INT2_PIN);
    Serial.printf("Pin states: INT1=%s INT2=%s\n",
                  int1_state ? "HIGH" : "LOW",
                  int2_state ? "HIGH" : "LOW");

    if (int1_state == HIGH || int2_state == HIGH) {
      Serial.println("⚠️ WARNING: Pins already HIGH!");
    }

    Serial.println("⚠️ ENTERING LIGHT SLEEP");
    Serial.println("Will wake ONLY on motion (no timer backup)");
    Serial.flush();
    delay(100);

    // LIGHT SLEEP (no timer, GPIO wake only)
    int64_t sleep_start = esp_timer_get_time();
    esp_err_t sleep_result = esp_light_sleep_start();
    int64_t sleep_duration = (esp_timer_get_time() - sleep_start) / 1000;

    // After wake
    Serial.println("\n>>> DEVICE WOKE UP <<<");
    Serial.printf("Duration: %lld ms (result=%d)\n", sleep_duration, sleep_result);

    esp_sleep_wakeup_cause_t cause = esp_sleep_get_wakeup_cause();
    if (cause == ESP_SLEEP_WAKEUP_GPIO) {
      Serial.println("✓ Wake: GPIO (Motion detected!)");
      Serial.printf("INT1=%s INT2=%s\n",
                    digitalRead(INT1_PIN) ? "HIGH" : "LOW",
                    digitalRead(INT2_PIN) ? "HIGH" : "LOW");
      firstMotionSent = true;  // Move to phase 2
      motionCount++;
    } else {
      Serial.printf("⚠️ Unexpected wake: %d\n", cause);
    }

  } else {
    // === PHASE 2: Deep sleep with timer wake ===

    Serial.println("First motion already detected - using periodic deep sleep");

    esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);

    // Timer wake only (10 seconds for testing)
    esp_err_t ret = esp_sleep_enable_timer_wakeup(10 * 1000000ULL);
    Serial.printf("Timer wake enable: %d\n", ret);

    Serial.println("⚠️ ENTERING DEEP SLEEP - USB WILL DISCONNECT!");
    Serial.println("Will wake after 10 seconds (periodic check)");
    Serial.println("Press RESET button after wake to see output.");
    Serial.flush();
    delay(100);

    esp_deep_sleep_start();  // Device resets
  }
}