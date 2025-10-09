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

// Global variables
float currentX = 0, currentY = 0, currentZ = 0;
float previousX = 0, previousY = 0, previousZ = 0;
float refX = 0, refY = 0, refZ = 0;
bool motionDetected = false;
unsigned long lastMotionTime = 0;
RTC_DATA_ATTR int wakeCount = 0;
RTC_DATA_ATTR int motionCount = 0;
bool sensorAvailable = false;
bool firstReading = true;

void setup() {
  Serial.begin(115200);
  while (!Serial) { delay(10); }
  
  Serial.println("\n=== ESP32-C3 LSM6DSL Motion System ===");
  
  pinMode(INT1_PIN, INPUT_PULLUP);
  pinMode(INT2_PIN, INPUT_PULLUP);
  
  // Check wake reason
  if (esp_sleep_get_wakeup_cause() == ESP_SLEEP_WAKEUP_GPIO) {
    wakeCount++;
    Serial.printf("WAKE FROM MOTION! Count: %d\n", wakeCount);
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
    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(WAKE_UP_THS);
    Wire.write(0x02);  // High sensitivity - very low threshold (~30mg)
    Wire.endTransmission();
    
    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(WAKE_UP_DUR);
    Wire.write(0x00);
    Wire.endTransmission();
    
    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(TAP_CFG);
    Wire.write(0x80);
    Wire.endTransmission();
    
    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(MD1_CFG);
    Wire.write(0x20);
    Wire.endTransmission();
    
    Wire.beginTransmission(LSM6DSL_ADDR);
    Wire.write(MD2_CFG);
    Wire.write(0x20);
    Wire.endTransmission();
  }
}

void enterSleep() {
  Serial.println("\n=== ENTERING SLEEP ===");
  Serial.printf("Total: %d motions, %d wakes\n", motionCount, wakeCount);
  Serial.flush();
  delay(100);
  
  if (sensorAvailable) {
    configureSleepInterrupts();
  }
  
  esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);
  
  if (digitalRead(INT1_PIN) == HIGH && digitalRead(INT2_PIN) == HIGH) {
    gpio_wakeup_enable((gpio_num_t)INT1_PIN, GPIO_INTR_LOW_LEVEL);
    gpio_wakeup_enable((gpio_num_t)INT2_PIN, GPIO_INTR_LOW_LEVEL);
  } else {
    gpio_wakeup_enable((gpio_num_t)INT1_PIN, GPIO_INTR_HIGH_LEVEL);
    gpio_wakeup_enable((gpio_num_t)INT2_PIN, GPIO_INTR_HIGH_LEVEL);
  }
  
  esp_sleep_enable_gpio_wakeup();
  esp_deep_sleep_start();
}