/*
 * ESP32-C3 LSM6DSL Motion Detection & Sleep Test
 *
 * Pin Config: INT1=GPIO0, INT2=GPIO1, SDA=GPIO6, SCL=GPIO7
 * Sleep Mode: Deep sleep (reliable, no watchdog issues)
 * Wake Sources: GPIO (motion) + Timer (10s periodic)
 *
 * Phase 1: Deep sleep, GPIO wake only (first motion detection)
 * Phase 2: Deep sleep, timer wake (periodic 10s after first motion)
 *
 * Note: USB disconnects in deep sleep. Press RESET to see output after wake.
 */

#include <Wire.h>
#include "esp_sleep.h"

// Pin Definitions
#define INT1_PIN GPIO_NUM_0
#define INT2_PIN GPIO_NUM_1
#define SDA_PIN 6
#define SCL_PIN 7

// LSM6DSL I2C
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

// Motion settings
#define MOTION_THRESHOLD 0.05
#define NO_MOTION_TIMEOUT 5000
#define SLEEP_COUNTDOWN 5000

// Globals
float currentX = 0, currentY = 0, currentZ = 0;
float previousX = 0, previousY = 0, previousZ = 0;
float refX = 0, refY = 0, refZ = 0;
bool motionDetected = false;
unsigned long lastMotionTime = 0;
RTC_DATA_ATTR int wakeCount = 0;
RTC_DATA_ATTR int motionCount = 0;
RTC_DATA_ATTR bool firstMotionSent = false;
bool sensorAvailable = false;
bool firstReading = true;

void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10);

  pinMode(INT1_PIN, INPUT);
  pinMode(INT2_PIN, INPUT);

  // Check wake reason
  esp_sleep_wakeup_cause_t wakeup_reason = esp_sleep_get_wakeup_cause();

  switch (wakeup_reason) {
    case ESP_SLEEP_WAKEUP_GPIO:
      wakeCount++;
      Serial.printf("\n🔔 WAKE: Motion (GPIO) #%d\n", wakeCount);
      firstMotionSent = true;
      break;

    case ESP_SLEEP_WAKEUP_TIMER:
      wakeCount++;
      Serial.printf("\n⏰ WAKE: Timer #%d\n", wakeCount);
      break;

    default:
      Serial.println("\n🔌 POWER-ON RESET");
      wakeCount = 0;
      motionCount = 0;
      firstMotionSent = false;
      break;
  }

  esp_log_level_set("i2c.master", ESP_LOG_NONE);

  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(50000);
  delay(100);

  sensorAvailable = initLSM6DSL();

  if (sensorAvailable) {
    if (wakeup_reason == ESP_SLEEP_WAKEUP_GPIO) {
      Wire.beginTransmission(LSM6DSL_ADDR);
      Wire.write(0x1B);
      Wire.endTransmission(false);
      Wire.requestFrom(LSM6DSL_ADDR, (uint8_t)1);
      if (Wire.available()) Wire.read();
    }

    calibrateSensor();
  } else {
    refX = 0;
    refY = 0;
    refZ = 1.0;
  }

  Serial.printf("Threshold: %.3fg\n\n", MOTION_THRESHOLD);
  lastMotionTime = millis();
}

void loop() {
  static unsigned long lastReadTime = 0;
  static bool countdownActive = false;
  static unsigned long countdownStart = 0;
  static int lastSecond = -1;
  static float stableX = 0, stableY = 0, stableZ = 0;
  static int stableCount = 0;

  if (millis() - lastReadTime < 100) return;
  lastReadTime = millis();

  previousX = currentX;
  previousY = currentY;
  previousZ = currentZ;

  if (!readAccelerometer()) return;

  float diff = abs(currentX - stableX) + abs(currentY - stableY) + abs(currentZ - stableZ);

  if (diff < 0.01) {
    stableCount++;
  } else {
    stableCount = 0;
    stableX = currentX;
    stableY = currentY;
    stableZ = currentZ;
  }

  float changeX = currentX - previousX;
  float changeY = currentY - previousY;
  float changeZ = currentZ - previousZ;
  float totalChange = sqrt(changeX * changeX + changeY * changeY + changeZ * changeZ);

  // Motion detection
  if (totalChange > MOTION_THRESHOLD && !firstReading) {
    if (!motionDetected) {
      motionCount++;
      Serial.printf("\n>>> MOTION #%d | Change: %.3fg\n", motionCount, totalChange);
      motionDetected = true;
    }

    lastMotionTime = millis();
    stableCount = 0;

    if (countdownActive) {
      countdownActive = false;
      lastSecond = -1;
    }

  } else if (motionDetected && (millis() - lastMotionTime > 2000)) {
    motionDetected = false;
    refX = currentX;
    refY = currentY;
    refZ = currentZ;
  }

  // Start countdown if stable for 5s
  if (!motionDetected && stableCount > 50) {
    if (!countdownActive) {
      countdownActive = true;
      countdownStart = millis();
      Serial.println("\n=== Sleep Countdown ===");
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
  for (uint8_t addr = LSM6DSL_ADDR1; addr <= LSM6DSL_ADDR2; addr++) {
    Wire.beginTransmission(addr);
    if (Wire.endTransmission() == 0) {
      LSM6DSL_ADDR = addr;

      Wire.beginTransmission(LSM6DSL_ADDR);
      Wire.write(WHO_AM_I);
      Wire.endTransmission(false);
      Wire.requestFrom(LSM6DSL_ADDR, (uint8_t)1);

      if (Wire.available()) {
        uint8_t id = Wire.read();
        if (id == 0x6A || id == 0x6C) {
          Serial.printf("LSM6DSL OK (0x%02X)\n", addr);

          // Reset
          Wire.beginTransmission(LSM6DSL_ADDR);
          Wire.write(CTRL3_C);
          Wire.write(0x01);
          Wire.endTransmission();
          delay(200);

          // 104Hz, ±2g
          Wire.beginTransmission(LSM6DSL_ADDR);
          Wire.write(CTRL1_XL);
          Wire.write(0x40);
          Wire.endTransmission();
          delay(50);

          // BDU + auto increment
          Wire.beginTransmission(LSM6DSL_ADDR);
          Wire.write(CTRL3_C);
          Wire.write(0x44);
          Wire.endTransmission();
          delay(50);

          // High performance
          Wire.beginTransmission(LSM6DSL_ADDR);
          Wire.write(CTRL6_C);
          Wire.write(0x00);
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
  float sumX = 0, sumY = 0, sumZ = 0;
  int samples = 0;

  // Discard first readings
  for (int i = 0; i < 10; i++) {
    readAccelerometer();
    delay(10);
  }

  // Average 50 readings
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

    previousX = refX;
    previousY = refY;
    previousZ = refZ;
    currentX = refX;
    currentY = refY;
    currentZ = refZ;

    Serial.printf("Calibrated: X=%.3f Y=%.3f Z=%.3f\n", refX, refY, refZ);
  }
}

bool readAccelerometer() {
  if (sensorAvailable) {
    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(STATUS_REG);
    Wire.endTransmission(false);
    Wire.requestFrom(LSM6DSL_ADDR, (uint8_t)1);

    if (Wire.available()) {
      uint8_t status = Wire.read();
      if (!(status & 0x01)) return false;
    }

    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(OUTX_L_XL);
    if (Wire.endTransmission(false) != 0) return false;

    if (Wire.requestFrom(LSM6DSL_ADDR, (uint8_t)6) == 6) {
      uint8_t xlo = Wire.read();
      uint8_t xhi = Wire.read();
      uint8_t ylo = Wire.read();
      uint8_t yhi = Wire.read();
      uint8_t zlo = Wire.read();
      uint8_t zhi = Wire.read();

      int16_t rawX = (int16_t)((xhi << 8) | xlo);
      int16_t rawY = (int16_t)((yhi << 8) | ylo);
      int16_t rawZ = (int16_t)((zhi << 8) | zlo);

      currentX = (float)rawX / 16384.0;
      currentY = (float)rawY / 16384.0;
      currentZ = (float)rawZ / 16384.0;

      return true;
    }
  }
  return false;
}

void configureSleepInterrupts() {
  if (!sensorAvailable) return;

  // Clear pending interrupts
  Wire.beginTransmission(LSM6DSL_ADDR);
  Wire.write(0x1B);
  Wire.endTransmission(false);
  Wire.requestFrom(LSM6DSL_ADDR, (uint8_t)1);
  if (Wire.available()) Wire.read();

  // 52Hz ODR, ±2g
  Wire.beginTransmission(LSM6DSL_ADDR);
  Wire.write(CTRL1_XL);
  Wire.write(0x20);
  Wire.endTransmission();
  delay(50);

  // INT active HIGH
  Wire.beginTransmission(LSM6DSL_ADDR);
  Wire.write(CTRL3_C);
  Wire.write(0x44);
  Wire.endTransmission();

  // Wake-up config
  Wire.beginTransmission(LSM6DSL_ADDR);
  Wire.write(WAKE_UP_DUR);
  Wire.write(0x00);
  Wire.endTransmission();

  Wire.beginTransmission(LSM6DSL_ADDR);
  Wire.write(WAKE_UP_THS);
  Wire.write(0x01);  // ~15mg sensitivity
  Wire.endTransmission();

  // Enable interrupts (latched)
  Wire.beginTransmission(LSM6DSL_ADDR);
  Wire.write(TAP_CFG);
  Wire.write(0x81);
  Wire.endTransmission();
  delay(50);

  // Route wake-up to INT1 and INT2
  Wire.beginTransmission(LSM6DSL_ADDR);
  Wire.write(MD1_CFG);
  Wire.write(0x20);
  Wire.endTransmission();

  Wire.beginTransmission(LSM6DSL_ADDR);
  Wire.write(MD2_CFG);
  Wire.write(0x20);
  Wire.endTransmission();
  delay(50);

  Serial.println("Wake-on-motion configured");
}

void clearLSM6DSLInterrupts() {
  if (!sensorAvailable) return;

  Wire.beginTransmission(LSM6DSL_ADDR);
  Wire.write(0x1B);
  Wire.endTransmission(false);
  Wire.requestFrom(LSM6DSL_ADDR, (uint8_t)1);
  if (Wire.available()) Wire.read();

  Wire.beginTransmission(LSM6DSL_ADDR);
  Wire.write(STATUS_REG);
  Wire.endTransmission(false);
  Wire.requestFrom(LSM6DSL_ADDR, (uint8_t)1);
  if (Wire.available()) Wire.read();

  readAccelerometer();
}

void enterSleep() {
  Serial.printf("\n=== SLEEP (Motions: %d, Wakes: %d) ===\n", motionCount, wakeCount);
  Serial.printf("Phase: %s\n", firstMotionSent ? "Periodic" : "First Motion");
  Serial.flush();
  delay(100);

  if (!firstMotionSent) {
    // Phase 1: GPIO wake only
    if (sensorAvailable) {
      configureSleepInterrupts();
      delay(50);
      clearLSM6DSLInterrupts();
      delay(100);

      // Wait for motion to confirm interrupts work
      Serial.println("Move device to confirm interrupt...");
      Serial.flush();

      while (digitalRead(INT1_PIN) == LOW && digitalRead(INT2_PIN) == LOW) {
        delay(100);
      }

      Serial.println("✓ Interrupt confirmed");
      clearLSM6DSLInterrupts();
      delay(100);
    }

    esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);
    pinMode(INT1_PIN, INPUT);
    pinMode(INT2_PIN, INPUT);

    uint64_t gpio_mask = (1ULL << INT1_PIN) | (1ULL << INT2_PIN);
    esp_deep_sleep_enable_gpio_wakeup(gpio_mask, ESP_GPIO_WAKEUP_GPIO_HIGH);

    Serial.println("Entering deep sleep (GPIO wake only)");
    Serial.flush();
    delay(100);

    esp_deep_sleep_start();

  } else {
    // Phase 2: Timer wake
    esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);
    esp_sleep_enable_timer_wakeup(10 * 1000000ULL);

    Serial.println("Entering deep sleep (10s timer)");
    Serial.println("Press RESET after wake for output");
    Serial.flush();
    delay(100);

    esp_deep_sleep_start();
  }
}
