/*
 * LSM6DSL Motion Detection Test
 * Purpose: Test LSM6DSL accelerometer/gyroscope for bike motion detection
 * 
 * Hardware:
 * - ESP32 with LSM6DSL connected via I2C
 * - SDA: GPIO21, SCL: GPIO22
 * - I2C Address: 0x6A or 0x6B
 * 
 * Features:
 * - Motion detection based on acceleration changes
 * - Tilt detection for bike orientation changes
 * - Shock/impact detection for potential theft attempts
 */

#include <Wire.h>
#include <math.h>

// I2C Configuration
#define SDA_PIN 21
#define SCL_PIN 22

// LSM6DSL I2C Addresses
#define LSM6DSL_ADDR_PRIMARY 0x6A
#define LSM6DSL_ADDR_SECONDARY 0x6B

// LSM6DSL Registers
#define WHO_AM_I_REG 0x0F
#define CTRL1_XL_REG 0x10  // Accelerometer control
#define CTRL2_G_REG 0x11   // Gyroscope control
#define CTRL3_C_REG 0x12   // Common control
#define STATUS_REG 0x1E    // Status register
#define OUTX_L_G_REG 0x22  // Gyro output start
#define OUTX_L_XL_REG 0x28 // Accel output start

// Detection Thresholds
#define MOTION_THRESHOLD 0.15    // g - detect movement
#define TILT_THRESHOLD 0.3       // g - detect significant tilt
#define SHOCK_THRESHOLD 2.0      // g - detect impact/shock
#define GYRO_THRESHOLD 50.0      // dps - detect rotation

// Global Variables
uint8_t deviceAddress = 0;
float accelX, accelY, accelZ;
float gyroX, gyroY, gyroZ;
float prevAccelMag = 1.0;
bool motionDetected = false;
bool shockDetected = false;
bool tiltDetected = false;

// Timing
unsigned long lastReadTime = 0;
const unsigned long READ_INTERVAL = 50; // 20Hz sampling

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n=== LSM6DSL Motion Detection Test ===");
  Serial.println("Initializing...\n");
  
  // Initialize I2C
  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(100000);
  
  // Find and initialize LSM6DSL
  if (!initSensor()) {
    Serial.println("ERROR: LSM6DSL not found!");
    Serial.println("Check wiring: SDA=21, SCL=22");
    while (1) delay(1000);
  }
  
  Serial.println("LSM6DSL initialized successfully!");
  Serial.println("\nMonitoring motion...");
  Serial.println("----------------------------------------");
}

void loop() {
  if (millis() - lastReadTime >= READ_INTERVAL) {
    lastReadTime = millis();
    
    // Read sensor data
    if (readSensorData()) {
      // Detect different motion types
      detectMotion();
      detectShock();
      detectTilt();
      
      // Display status
      displayStatus();
    }
  }
}

bool initSensor() {
  // Try primary address first
  deviceAddress = LSM6DSL_ADDR_PRIMARY;
  if (checkDevice()) {
    configureSensor();
    return true;
  }
  
  // Try secondary address
  deviceAddress = LSM6DSL_ADDR_SECONDARY;
  if (checkDevice()) {
    configureSensor();
    return true;
  }
  
  return false;
}

bool checkDevice() {
  uint8_t whoami = readRegister(WHO_AM_I_REG);
  if (whoami == 0x6A) {
    Serial.print("Found LSM6DSL at 0x");
    Serial.println(deviceAddress, HEX);
    return true;
  }
  return false;
}

void configureSensor() {
  // Configure accelerometer
  // ODR = 104Hz, ±4g range, bandwidth filter
  writeRegister(CTRL1_XL_REG, 0x44);
  
  // Configure gyroscope  
  // ODR = 104Hz, ±250dps range
  writeRegister(CTRL2_G_REG, 0x40);
  
  // Enable block data update
  writeRegister(CTRL3_C_REG, 0x44);
  
  delay(100); // Let sensor stabilize
}

bool readSensorData() {
  // Check if new data available
  uint8_t status = readRegister(STATUS_REG);
  if ((status & 0x01) == 0) return false; // No new accel data
  
  // Read accelerometer (6 bytes)
  uint8_t accelData[6];
  readMultipleRegisters(OUTX_L_XL_REG, accelData, 6);
  
  // Convert to g values (±4g range)
  int16_t rawX = (accelData[1] << 8) | accelData[0];
  int16_t rawY = (accelData[3] << 8) | accelData[2];
  int16_t rawZ = (accelData[5] << 8) | accelData[4];
  
  accelX = (float)rawX * 4.0 / 32768.0;
  accelY = (float)rawY * 4.0 / 32768.0;
  accelZ = (float)rawZ * 4.0 / 32768.0;
  
  // Read gyroscope (6 bytes)
  uint8_t gyroData[6];
  readMultipleRegisters(OUTX_L_G_REG, gyroData, 6);
  
  // Convert to dps values (±250dps range)
  int16_t rawGX = (gyroData[1] << 8) | gyroData[0];
  int16_t rawGY = (gyroData[3] << 8) | gyroData[2];
  int16_t rawGZ = (gyroData[5] << 8) | gyroData[4];
  
  gyroX = (float)rawGX * 250.0 / 32768.0;
  gyroY = (float)rawGY * 250.0 / 32768.0;
  gyroZ = (float)rawGZ * 250.0 / 32768.0;
  
  return true;
}

void detectMotion() {
  // Calculate acceleration magnitude
  float accelMag = sqrt(accelX*accelX + accelY*accelY + accelZ*accelZ);
  
  // Detect motion based on change in acceleration
  float accelChange = fabs(accelMag - prevAccelMag);
  prevAccelMag = accelMag;
  
  // Check gyroscope for rotation
  float gyroMag = sqrt(gyroX*gyroX + gyroY*gyroY + gyroZ*gyroZ);
  
  // Motion detected if acceleration changes or rotation detected
  bool newMotion = (accelChange > MOTION_THRESHOLD) || (gyroMag > GYRO_THRESHOLD);
  
  if (newMotion && !motionDetected) {
    Serial.println("\n>>> MOTION DETECTED <<<");
  } else if (!newMotion && motionDetected) {
    Serial.println("\n--- Motion stopped ---");
  }
  
  motionDetected = newMotion;
}

void detectShock() {
  // Calculate total acceleration magnitude
  float totalAccel = sqrt(accelX*accelX + accelY*accelY + accelZ*accelZ);
  
  // Detect shock/impact
  bool newShock = (totalAccel > SHOCK_THRESHOLD);
  
  if (newShock && !shockDetected) {
    Serial.println("\n!!! SHOCK/IMPACT DETECTED !!!");
    Serial.print("Impact force: ");
    Serial.print(totalAccel, 2);
    Serial.println("g");
  }
  
  shockDetected = newShock;
}

void detectTilt() {
  // Detect significant tilt from vertical (Z-axis deviation)
  // When upright, Z ≈ 1g, X ≈ 0g, Y ≈ 0g
  float zDeviation = fabs(accelZ - 1.0);
  float xyMag = sqrt(accelX*accelX + accelY*accelY);
  
  bool newTilt = (zDeviation > TILT_THRESHOLD) || (xyMag > TILT_THRESHOLD);
  
  if (newTilt && !tiltDetected) {
    Serial.println("\n*** TILT DETECTED ***");
    float tiltAngle = atan2(xyMag, accelZ) * 180.0 / PI;
    Serial.print("Tilt angle: ");
    Serial.print(tiltAngle, 1);
    Serial.println(" degrees");
  } else if (!newTilt && tiltDetected) {
    Serial.println("\n--- Tilt cleared ---");
  }
  
  tiltDetected = newTilt;
}

void displayStatus() {
  static unsigned long lastDisplay = 0;
  
  // Display detailed readings every 500ms
  if (millis() - lastDisplay >= 500) {
    lastDisplay = millis();
    
    Serial.print("Accel[g]: X=");
    Serial.print(accelX, 2);
    Serial.print(" Y=");
    Serial.print(accelY, 2);
    Serial.print(" Z=");
    Serial.print(accelZ, 2);
    
    Serial.print(" | Gyro[dps]: X=");
    Serial.print(gyroX, 1);
    Serial.print(" Y=");
    Serial.print(gyroY, 1);
    Serial.print(" Z=");
    Serial.print(gyroZ, 1);
    
    Serial.print(" | Status: ");
    if (motionDetected) Serial.print("[MOVING] ");
    if (tiltDetected) Serial.print("[TILTED] ");
    if (shockDetected) Serial.print("[SHOCK] ");
    if (!motionDetected && !tiltDetected && !shockDetected) Serial.print("[IDLE]");
    
    Serial.println();
  }
}

// I2C Helper Functions
uint8_t readRegister(uint8_t reg) {
  Wire.beginTransmission(deviceAddress);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return 0xFF;
  
  Wire.requestFrom(deviceAddress, (uint8_t)1);
  if (Wire.available()) {
    return Wire.read();
  }
  return 0xFF;
}

void writeRegister(uint8_t reg, uint8_t value) {
  Wire.beginTransmission(deviceAddress);
  Wire.write(reg);
  Wire.write(value);
  Wire.endTransmission();
}

void readMultipleRegisters(uint8_t startReg, uint8_t* buffer, uint8_t length) {
  Wire.beginTransmission(deviceAddress);
  Wire.write(startReg);
  Wire.endTransmission(false);
  
  Wire.requestFrom(deviceAddress, length);
  for (uint8_t i = 0; i < length && Wire.available(); i++) {
    buffer[i] = Wire.read();
  }
}