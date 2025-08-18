#include <Wire.h>
#include "esp_sleep.h"

// Pin Definitions
#define LED_PIN 15
#define INT1_PIN GPIO_NUM_4
#define INT2_PIN GPIO_NUM_2
#define SDA_PIN 21
#define SCL_PIN 22

// LSM6DSL I2C Addresses
#define LSM6DSL_ADDR1 0x6A
#define LSM6DSL_ADDR2 0x6B
uint8_t LSM6DSL_ADDR = LSM6DSL_ADDR1;

// LSM6DSL Registers
#define WHO_AM_I 0x0F
#define CTRL1_XL 0x10
#define CTRL2_G 0x11
#define CTRL3_C 0x12
#define CTRL4_C 0x13
#define CTRL5_C 0x14
#define CTRL6_C 0x15
#define CTRL7_G 0x16
#define CTRL8_XL 0x17
#define CTRL9_XL 0x18
#define CTRL10_C 0x19

#define WAKE_UP_SRC 0x1B
#define TAP_CFG 0x58
#define WAKE_UP_THS 0x5B
#define WAKE_UP_DUR 0x5C
#define FREE_FALL 0x5D
#define MD1_CFG 0x5E
#define MD2_CFG 0x5F

#define FUNC_CFG_ACCESS 0x01
#define FUNC_SRC1 0x53
#define FUNC_SRC2 0x54

#define OUTX_L_XL 0x28
#define OUTY_L_XL 0x2A
#define OUTZ_L_XL 0x2C

// Motion detection settings
#define MOTION_THRESHOLD_LOW 0.10
#define MOTION_THRESHOLD_MED 0.25
#define MOTION_THRESHOLD_HIGH 0.50
#define NO_MOTION_SLEEP_TIME 10000  // 10 seconds to sleep

// Global variables
float lastX = 0, lastY = 0, lastZ = 0;
bool motionDetected = false;
unsigned long lastMotionTime = 0;
unsigned long motionStartTime = 0;
unsigned long lastDisplayTime = 0;
RTC_DATA_ATTR int motionEventCount = 0;
RTC_DATA_ATTR int wakeCount = 0;

void setup() {
  Serial.begin(115200);
  
  // Wait for serial connection with timeout
  unsigned long serialStart = millis();
  while (!Serial && (millis() - serialStart < 5000)) {
    delay(10);
  }
  
  delay(1000);  // Extra delay for stability
  
  Serial.println("\n\n========================================");
  Serial.println("ESP32 LSM6DSL Wake-on-Motion System");
  Serial.println("========================================");
  Serial.flush();
  delay(100);
  
  pinMode(LED_PIN, OUTPUT);
  pinMode(INT1_PIN, INPUT_PULLUP);
  pinMode(INT2_PIN, INPUT_PULLUP);
  
  // Blink LED to show board is alive
  for(int i = 0; i < 3; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(100);
    digitalWrite(LED_PIN, LOW);
    delay(100);
  }
  
  // Check wake reason
  esp_sleep_wakeup_cause_t wakeup_reason = esp_sleep_get_wakeup_cause();
  
  if (wakeup_reason == ESP_SLEEP_WAKEUP_EXT1) {
    wakeCount++;
    Serial.println("\n🚨 MOTION WAKE - ESP32 AWAKE!");
    
    uint64_t wakeup_pin_mask = esp_sleep_get_ext1_wakeup_status();
    if (wakeup_pin_mask & (1ULL << INT1_PIN)) {
      Serial.println("Woken by INT1 (GPIO4)");
    }
    if (wakeup_pin_mask & (1ULL << INT2_PIN)) {
      Serial.println("Woken by INT2 (GPIO2)");
    }
    
    Serial.printf("Wake count: %d | Total events: %d\n\n", wakeCount, motionEventCount);
    digitalWrite(LED_PIN, HIGH);
    delay(1000);
    digitalWrite(LED_PIN, LOW);
  } else {
    Serial.println("\nNormal boot (not wake from sleep)");
    Serial.println("System will sleep after 10 seconds of no motion");
    Serial.println("Motion will wake ESP32 via INT1/INT2\n");
  }
  
  Serial.println("Initializing I2C...");
  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(100000);
  delay(100);
  
  // Scan I2C
  scanI2C();
  
  // Initialize LSM6DSL
  Serial.println("Initializing LSM6DSL...");
  if (!initLSM6DSL()) {
    Serial.println("❌ LSM6DSL not found! Check wiring:");
    Serial.println("INT1->GPIO4, INT2->GPIO2");
    Serial.println("SDA->GPIO21, SCL->GPIO22");
    Serial.println("VCC->3.3V, GND->GND");
    while(1) {
      digitalWrite(LED_PIN, !digitalRead(LED_PIN));
      delay(500);
    }
  }
  
  Serial.println("✅ LSM6DSL initialized successfully");
  Serial.printf("Address: 0x%02X\n", LSM6DSL_ADDR);
  
  // Test interrupts
  testInterrupts();
  
  Serial.println("\nMonitoring motion...\n");
  lastMotionTime = millis();
}

void loop() {
  static unsigned long lastDebugPrint = 0;
  
  // Print debug info every 2 seconds
  if (millis() - lastDebugPrint > 2000) {
    if (readAccelerometer()) {
      Serial.printf("Status - X:%.2f Y:%.2f Z:%.2f | INT1:%d INT2:%d\n", 
                    lastX, lastY, lastZ, 
                    digitalRead(INT1_PIN), digitalRead(INT2_PIN));
    }
    lastDebugPrint = millis();
  }
  
  if (readAccelerometer()) {
    float x = lastX;
    float y = lastY;
    float z = lastZ;
    
    static float refX = 0, refY = 0, refZ = 1.0;
    static bool firstReading = true;
    
    if (firstReading) {
      refX = x;
      refY = y;
      refZ = z;
      firstReading = false;
    }
    
    float deltaX = abs(x - refX);
    float deltaY = abs(y - refY);
    float deltaZ = abs(z - refZ);
    float totalDelta = sqrt(deltaX*deltaX + deltaY*deltaY + deltaZ*deltaZ);
    
    if (totalDelta > MOTION_THRESHOLD_LOW) {
      if (!motionDetected) {
        motionDetected = true;
        motionStartTime = millis();
        motionEventCount++;
        digitalWrite(LED_PIN, HIGH);
        
        Serial.println("🚨 MOTION DETECTED!");
        Serial.printf("Event #%d | Delta: %.3fg\n", motionEventCount, totalDelta);
      }
      
      lastMotionTime = millis();
      
      // Update reference slowly
      refX = refX * 0.98 + x * 0.02;
      refY = refY * 0.98 + y * 0.02;
      refZ = refZ * 0.98 + z * 0.02;
      
    } else {
      if (motionDetected && (millis() - lastMotionTime > 1000)) {
        unsigned long duration = (millis() - motionStartTime) / 1000;
        Serial.printf("✅ Motion stopped (duration: %lu sec)\n\n", duration);
        
        motionDetected = false;
        digitalWrite(LED_PIN, LOW);
        
        refX = x;
        refY = y;
        refZ = z;
      }
    }
    
    // Check for sleep
    unsigned long noMotionTime = millis() - lastMotionTime;
    if (!motionDetected && noMotionTime > NO_MOTION_SLEEP_TIME) {
      Serial.println("\n💤 No motion for 10 seconds");
      prepareForSleep();
    } else if (!motionDetected && noMotionTime > 5000) {
      int secondsToSleep = (NO_MOTION_SLEEP_TIME - noMotionTime) / 1000;
      static int lastPrintedSecond = -1;
      if (secondsToSleep != lastPrintedSecond && secondsToSleep > 0) {
        Serial.printf("Sleep in %d seconds...\n", secondsToSleep);
        lastPrintedSecond = secondsToSleep;
      }
    }
  }
  
  delay(50);
}

void prepareForSleep() {
  Serial.println("Preparing for deep sleep...");
  
  // Configure LSM6DSL for wake-on-motion
  Serial.println("Configuring sensor for wake-on-motion...");
  
  // Reset interrupt configuration
  writeRegister(TAP_CFG, 0x00);
  delay(10);
  
  // Configure accelerometer for low power mode but keep it running
  writeRegister(CTRL1_XL, 0x30);  // 52Hz, ±2g, keep running
  delay(10);
  
  // Configure wake-up detection
  writeRegister(WAKE_UP_DUR, 0x00);  // No duration, immediate wake
  writeRegister(WAKE_UP_THS, 0x02);  // Very sensitive threshold
  delay(10);
  
  // Enable interrupts and latch mode
  writeRegister(TAP_CFG, 0x80 | 0x01);  // Enable interrupts, latch mode
  delay(10);
  
  // Route wake-up to both INT1 and INT2
  writeRegister(MD1_CFG, 0x20);  // Wake-up on INT1
  writeRegister(MD2_CFG, 0x20);  // Wake-up on INT2
  delay(10);
  
  // Clear any pending interrupts
  uint8_t wake_src = readRegister(WAKE_UP_SRC);
  Serial.printf("Cleared wake source: 0x%02X\n", wake_src);
  
  // Verify interrupt configuration
  uint8_t md1 = readRegister(MD1_CFG);
  uint8_t md2 = readRegister(MD2_CFG);
  uint8_t tap = readRegister(TAP_CFG);
  Serial.printf("MD1_CFG: 0x%02X, MD2_CFG: 0x%02X, TAP_CFG: 0x%02X\n", md1, md2, tap);
  
  // Test if interrupts are working before sleep
  Serial.println("Testing interrupts before sleep...");
  Serial.println("Move sensor NOW to test:");
  
  unsigned long testStart = millis();
  bool int1Triggered = false;
  bool int2Triggered = false;
  
  while (millis() - testStart < 2000) {
    if (digitalRead(INT1_PIN) == HIGH && !int1Triggered) {
      Serial.println("✅ INT1 triggered!");
      int1Triggered = true;
    }
    if (digitalRead(INT2_PIN) == HIGH && !int2Triggered) {
      Serial.println("✅ INT2 triggered!");
      int2Triggered = true;
    }
    if (int1Triggered || int2Triggered) break;
    delay(10);
  }
  
  if (!int1Triggered && !int2Triggered) {
    Serial.println("⚠️ No interrupts detected - wake may not work!");
  }
  
  // Clear interrupts again before sleep
  wake_src = readRegister(WAKE_UP_SRC);
  
  // Final pin states
  Serial.printf("Final INT1: %d, INT2: %d\n", 
                digitalRead(INT1_PIN), digitalRead(INT2_PIN));
  
  digitalWrite(LED_PIN, LOW);
  
  // Configure ESP32 wake-up on multiple pins
  uint64_t ext_wakeup_pin_mask = (1ULL << INT1_PIN) | (1ULL << INT2_PIN);
  esp_sleep_enable_ext1_wakeup(ext_wakeup_pin_mask, ESP_EXT1_WAKEUP_ANY_HIGH);
  
  Serial.println("\n🛌 Entering deep sleep...");
  Serial.println("Move sensor to wake ESP32!");
  Serial.flush();
  delay(100);
  
  // Enter deep sleep
  esp_deep_sleep_start();
}

void scanI2C() {
  Serial.println("Scanning I2C bus...");
  int count = 0;
  
  for (uint8_t addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    if (Wire.endTransmission() == 0) {
      Serial.printf("Found: 0x%02X", addr);
      if (addr == 0x6A || addr == 0x6B) Serial.print(" (LSM6DSL)");
      Serial.println();
      count++;
    }
  }
  
  if (count == 0) {
    Serial.println("No I2C devices found!");
  } else {
    Serial.printf("Total devices: %d\n\n", count);
  }
}

bool initLSM6DSL() {
  // Try address 0x6A first
  LSM6DSL_ADDR = LSM6DSL_ADDR1;
  uint8_t whoami = readRegister(WHO_AM_I);
  
  if (whoami != 0x6A) {
    // Try address 0x6B
    LSM6DSL_ADDR = LSM6DSL_ADDR2;
    whoami = readRegister(WHO_AM_I);
    if (whoami != 0x6A) {
      Serial.printf("WHO_AM_I failed: 0x%02X\n", whoami);
      return false;
    }
  }
  
  Serial.printf("Found LSM6DSL at 0x%02X\n", LSM6DSL_ADDR);
  
  // Software reset
  writeRegister(CTRL3_C, 0x01);
  delay(100);
  
  // Configure accelerometer: 52Hz, ±2g, high performance
  writeRegister(CTRL1_XL, 0x30);
  delay(20);
  
  // Block data update
  writeRegister(CTRL3_C, 0x44);
  delay(20);
  
  // High performance mode
  writeRegister(CTRL6_C, 0x00);
  delay(20);
  
  // Verify configuration
  uint8_t ctrl1 = readRegister(CTRL1_XL);
  Serial.printf("CTRL1_XL: 0x%02X (expected 0x30)\n", ctrl1);
  
  return true;
}

void testInterrupts() {
  Serial.println("\n=== INTERRUPT TEST ===");
  Serial.println("Configuring interrupts...");
  
  // Configure wake-up interrupt
  writeRegister(WAKE_UP_DUR, 0x00);
  writeRegister(WAKE_UP_THS, 0x02);
  writeRegister(TAP_CFG, 0x80);
  writeRegister(MD1_CFG, 0x20);
  writeRegister(MD2_CFG, 0x20);
  delay(50);
  
  Serial.println("Move sensor to test interrupts (3 sec)...");
  
  unsigned long testStart = millis();
  bool int1OK = false, int2OK = false;
  
  while (millis() - testStart < 3000) {
    bool int1 = digitalRead(INT1_PIN);
    bool int2 = digitalRead(INT2_PIN);
    
    if (int1 && !int1OK) {
      Serial.println("✅ INT1 working!");
      int1OK = true;
    }
    if (int2 && !int2OK) {
      Serial.println("✅ INT2 working!");
      int2OK = true;
    }
    
    if (int1OK && int2OK) break;
    delay(10);
  }
  
  if (!int1OK && !int2OK) {
    Serial.println("❌ No interrupts detected!");
  } else if (!int1OK) {
    Serial.println("⚠️ INT1 not working");
  } else if (!int2OK) {
    Serial.println("⚠️ INT2 not working");
  }
  
  // Clear interrupts
  readRegister(WAKE_UP_SRC);
  Serial.println("===================\n");
}

bool readAccelerometer() {
  uint8_t xlo = readRegister(OUTX_L_XL);
  uint8_t xhi = readRegister(OUTX_L_XL + 1);
  uint8_t ylo = readRegister(OUTY_L_XL);
  uint8_t yhi = readRegister(OUTY_L_XL + 1);
  uint8_t zlo = readRegister(OUTZ_L_XL);
  uint8_t zhi = readRegister(OUTZ_L_XL + 1);
  
  if (xlo == 0xFF || xhi == 0xFF) return false;
  
  int16_t rawX = (xhi << 8) | xlo;
  int16_t rawY = (yhi << 8) | ylo;
  int16_t rawZ = (zhi << 8) | zlo;
  
  lastX = rawX / 16384.0;
  lastY = rawY / 16384.0;
  lastZ = rawZ / 16384.0;
  
  return true;
}

uint8_t readRegister(uint8_t reg) {
  Wire.beginTransmission(LSM6DSL_ADDR);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return 0xFF;
  
  Wire.requestFrom(LSM6DSL_ADDR, (uint8_t)1);
  if (Wire.available()) {
    return Wire.read();
  }
  return 0xFF;
}

void writeRegister(uint8_t reg, uint8_t value) {
  Wire.beginTransmission(LSM6DSL_ADDR);
  Wire.write(reg);
  Wire.write(value);
  Wire.endTransmission();
  delay(5);
}