/*
 * lsm6dsl_handler.cpp
 * 
 * Implementation of LSM6DSL motion detection and power management
 */

#include "lsm6dsl_handler.h"

// Global instance
LSM6DSL motionSensor;

/*
 * Constructor
 */
LSM6DSL::LSM6DSL() {
  i2cAddress = LSM6DSL_ADDR1;
  motionDetectedFlag = false;
  lastMotionTime = 0;
  referenceAccel = {0, 0, 1.0, 1.0};  // Default to gravity on Z-axis
  currentAccel = {0, 0, 0, 0};
  initialized = false;
}

/*
 * Initialize the LSM6DSL sensor
 */
bool LSM6DSL::begin() {
  // Initialize I2C
  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(100000);  // 100kHz I2C clock
  delay(100);
  
  // Try address 0x6A first
  i2cAddress = LSM6DSL_ADDR1;
  uint8_t whoami = readRegister(LSM6DSL_WHO_AM_I);
  
  if (whoami != 0x6A) {
    // Try address 0x6B
    i2cAddress = LSM6DSL_ADDR2;
    whoami = readRegister(LSM6DSL_WHO_AM_I);
    if (whoami != 0x6A) {
      Serial.printf("LSM6DSL not found. WHO_AM_I: 0x%02X\n", whoami);
      initialized = false;
      return false;
    }
  }
  
  Serial.printf("LSM6DSL found at address 0x%02X\n", i2cAddress);
  
  // Software reset
  writeRegister(LSM6DSL_CTRL3_C, 0x01);
  delay(100);
  
  // Configure accelerometer: 52Hz, ±2g, normal mode
  writeRegister(LSM6DSL_CTRL1_XL, 0x30);
  delay(20);
  
  // Disable gyroscope to save power
  writeRegister(LSM6DSL_CTRL2_G, 0x00);
  delay(20);
  
  // Enable block data update
  writeRegister(LSM6DSL_CTRL3_C, 0x44);
  delay(20);
  
  // Set to normal mode (not high performance)
  writeRegister(LSM6DSL_CTRL6_C, 0x10);
  delay(20);
  
  // Initialize interrupt pins
  pinMode(INT1_PIN, INPUT_PULLUP);
  pinMode(INT2_PIN, INPUT_PULLUP);
  
  // Get initial reference acceleration
  delay(100);
  if (readAccelerometer()) {
    referenceAccel = currentAccel;
    Serial.printf("Reference acceleration: X=%.2f, Y=%.2f, Z=%.2f\n", 
                  referenceAccel.x, referenceAccel.y, referenceAccel.z);
  }
  
  lastMotionTime = millis();
  initialized = true;
  
  return true;
}

/*
 * Check if sensor is connected
 */
bool LSM6DSL::isConnected() {
  uint8_t whoami = readRegister(LSM6DSL_WHO_AM_I);
  return (whoami == 0x6A);
}

/*
 * Read accelerometer data
 */
bool LSM6DSL::readAccelerometer() {
  // Check data ready
  uint8_t status = readRegister(LSM6DSL_STATUS_REG);
  if (!(status & 0x01)) {
    return false;  // No new data
  }
  
  // Read 6 bytes of accelerometer data
  uint8_t xlo = readRegister(LSM6DSL_OUTX_L_XL);
  uint8_t xhi = readRegister(LSM6DSL_OUTX_H_XL);
  uint8_t ylo = readRegister(LSM6DSL_OUTY_L_XL);
  uint8_t yhi = readRegister(LSM6DSL_OUTY_H_XL);
  uint8_t zlo = readRegister(LSM6DSL_OUTZ_L_XL);
  uint8_t zhi = readRegister(LSM6DSL_OUTZ_H_XL);
  
  // Check for invalid data
  if (xlo == 0xFF || xhi == 0xFF) return false;
  
  // Convert to signed 16-bit values
  int16_t rawX = (xhi << 8) | xlo;
  int16_t rawY = (yhi << 8) | ylo;
  int16_t rawZ = (zhi << 8) | zlo;
  
  // Convert to g units (±2g range, 16-bit resolution)
  currentAccel.x = rawX / 16384.0f;
  currentAccel.y = rawY / 16384.0f;
  currentAccel.z = rawZ / 16384.0f;
  
  // Calculate magnitude
  currentAccel.magnitude = sqrt(currentAccel.x * currentAccel.x + 
                               currentAccel.y * currentAccel.y + 
                               currentAccel.z * currentAccel.z);
  
  return true;
}

/*
 * Detect motion based on acceleration changes
 */
bool LSM6DSL::detectMotion() {
  if (!readAccelerometer()) {
    return motionDetectedFlag;  // Return last state if no new data
  }
  
  // Calculate delta from reference
  float deltaX = fabs(currentAccel.x - referenceAccel.x);
  float deltaY = fabs(currentAccel.y - referenceAccel.y);
  float deltaZ = fabs(currentAccel.z - referenceAccel.z);
  float totalDelta = sqrt(deltaX*deltaX + deltaY*deltaY + deltaZ*deltaZ);
  
  // Check if motion exceeds threshold
  if (totalDelta > MOTION_THRESHOLD_LOW) {
    if (!motionDetectedFlag) {
      Serial.printf("Motion detected! Delta: %.3fg\n", totalDelta);
    }
    motionDetectedFlag = true;
    lastMotionTime = millis();
    
    // Slowly update reference (adaptive baseline)
    referenceAccel.x = referenceAccel.x * 0.98f + currentAccel.x * 0.02f;
    referenceAccel.y = referenceAccel.y * 0.98f + currentAccel.y * 0.02f;
    referenceAccel.z = referenceAccel.z * 0.98f + currentAccel.z * 0.02f;
  } else {
    // Check if motion has stopped for a while
    if (motionDetectedFlag && (millis() - lastMotionTime > 1000)) {
      Serial.println("Motion stopped");
      motionDetectedFlag = false;
      // Update reference to current position
      referenceAccel = currentAccel;
    }
  }
  
  return motionDetectedFlag;
}

/*
 * Get time since last motion in milliseconds
 */
unsigned long LSM6DSL::getTimeSinceLastMotion() {
  unsigned long currentTime = millis();
  
  // Handle overflow
  if (currentTime < lastMotionTime) {
    return 0;
  }
  
  return currentTime - lastMotionTime;
}

/*
 * Reset motion reference to current position
 */
void LSM6DSL::resetMotionReference() {
  if (readAccelerometer()) {
    referenceAccel = currentAccel;
    Serial.printf("Reference reset: X=%.2f, Y=%.2f, Z=%.2f\n", 
                  referenceAccel.x, referenceAccel.y, referenceAccel.z);
  }
}

/*
 * Get motion delta from reference
 */
float LSM6DSL::getMotionDelta() {
  if (!readAccelerometer()) {
    return 0;
  }
  
  float deltaX = fabs(currentAccel.x - referenceAccel.x);
  float deltaY = fabs(currentAccel.y - referenceAccel.y);
  float deltaZ = fabs(currentAccel.z - referenceAccel.z);
  
  return sqrt(deltaX*deltaX + deltaY*deltaY + deltaZ*deltaZ);
}

/*
 * Set LSM6DSL to low power mode (12.5Hz sampling)
 */
void LSM6DSL::setLowPowerMode() {
  // Accelerometer: 12.5Hz, ±2g, low power mode
  writeRegister(LSM6DSL_CTRL1_XL, 0x10);
  delay(10);
  
  // Ensure gyroscope is off
  writeRegister(LSM6DSL_CTRL2_G, 0x00);
  delay(10);
  
  Serial.println("LSM6DSL set to low power mode");
}

/*
 * Set LSM6DSL to power-down mode
 */
void LSM6DSL::setPowerDownMode() {
  // Power down accelerometer
  writeRegister(LSM6DSL_CTRL1_XL, 0x00);
  delay(10);
  
  // Power down gyroscope
  writeRegister(LSM6DSL_CTRL2_G, 0x00);
  delay(10);
  
  initialized = false;  // Mark as not initialized when powered down
  Serial.println("LSM6DSL powered down");
}

/*
 * Set LSM6DSL to normal operating mode
 */
void LSM6DSL::setNormalMode() {
  // Accelerometer: 52Hz, ±2g, normal mode
  writeRegister(LSM6DSL_CTRL1_XL, 0x30);
  delay(10);
  
  // Gyroscope remains off to save power
  writeRegister(LSM6DSL_CTRL2_G, 0x00);
  delay(10);
  
  Serial.println("LSM6DSL set to normal mode");
}

/*
 * Configure wake-on-motion interrupts
 */
void LSM6DSL::configureWakeOnMotion() {
  Serial.println("Configuring LSM6DSL for wake-on-motion...");
  
  // Clear any pending interrupts
  clearMotionInterrupts();
  
  // Reset interrupt configuration
  writeRegister(LSM6DSL_TAP_CFG, 0x00);
  delay(10);
  
  // Keep accelerometer running at low power for motion detection
  writeRegister(LSM6DSL_CTRL1_XL, 0x10);  // 12.5Hz, ±2g, low power
  delay(10);
  
  // Configure wake-up detection
  writeRegister(LSM6DSL_WAKE_UP_DUR, 0x01);  // Require some duration
  writeRegister(LSM6DSL_WAKE_UP_THS, 0x08);  // Less sensitive threshold (was 0x02)
  delay(10);
  
  // Enable interrupts with latch mode
  writeRegister(LSM6DSL_TAP_CFG, 0x81);  // Enable interrupts, latch mode
  delay(10);
  
  // Route wake-up to both INT1 and INT2
  writeRegister(LSM6DSL_MD1_CFG, 0x20);  // Wake-up on INT1
  writeRegister(LSM6DSL_MD2_CFG, 0x20);  // Wake-up on INT2
  delay(10);
  
  // Clear any pending interrupts again
  clearMotionInterrupts();
  
  // Verify configuration
  uint8_t md1 = readRegister(LSM6DSL_MD1_CFG);
  uint8_t md2 = readRegister(LSM6DSL_MD2_CFG);
  Serial.printf("Wake interrupts configured - MD1: 0x%02X, MD2: 0x%02X\n", md1, md2);
}

/*
 * Clear motion interrupt flags
 */
void LSM6DSL::clearMotionInterrupts() {
  // Read all interrupt sources to clear them
  uint8_t wake_src = readRegister(LSM6DSL_WAKE_UP_SRC);
  uint8_t status = readRegister(LSM6DSL_STATUS_REG);
  
  // Read accelerometer data to clear data ready flag
  readAccelerometer();
  
  // Disable and re-enable interrupts to ensure clean state
  writeRegister(LSM6DSL_MD1_CFG, 0x00);
  writeRegister(LSM6DSL_MD2_CFG, 0x00);
  delay(10);
  writeRegister(LSM6DSL_MD1_CFG, 0x20);  // Re-enable wake-up on INT1
  writeRegister(LSM6DSL_MD2_CFG, 0x20);  // Re-enable wake-up on INT2
  
  Serial.printf("Cleared interrupts - Wake: 0x%02X, Status: 0x%02X\n", wake_src, status);
  
  // Reset motion detection state
  lastMotionTime = millis();
  motionDetectedFlag = false;
}

/*
 * Get wake-up source register
 */
uint8_t LSM6DSL::getWakeSource() {
  return readRegister(LSM6DSL_WAKE_UP_SRC);
}

/*
 * Read a register from LSM6DSL
 */
uint8_t LSM6DSL::readRegister(uint8_t reg) {
  Wire.beginTransmission(i2cAddress);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) {
    return 0xFF;  // Error
  }
  
  Wire.requestFrom(i2cAddress, (uint8_t)1);
  if (Wire.available()) {
    return Wire.read();
  }
  
  return 0xFF;  // Error
}

/*
 * Write a value to a register
 */
void LSM6DSL::writeRegister(uint8_t reg, uint8_t value) {
  Wire.beginTransmission(i2cAddress);
  Wire.write(reg);
  Wire.write(value);
  Wire.endTransmission();
  delay(5);  // Small delay for register write
}