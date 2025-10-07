/*
 * lsm6dsl_handler.h
 * 
 * LSM6DSL accelerometer/gyroscope interface for motion detection
 * and power management in the Smart Bike Tracker system
 */

#ifndef LSM6DSL_HANDLER_H
#define LSM6DSL_HANDLER_H

#include <Arduino.h>
#include <Wire.h>

// Pin Definitions
#define INT1_PIN GPIO_NUM_0     // LSM6DSL interrupt 1
#define INT2_PIN GPIO_NUM_1     // LSM6DSL interrupt 2
#define SDA_PIN 6               // I2C data
#define SCL_PIN 7               // I2C clock

// LSM6DSL I2C Addresses
#define LSM6DSL_ADDR1 0x6A
#define LSM6DSL_ADDR2 0x6B

// LSM6DSL Register Definitions
#define LSM6DSL_WHO_AM_I        0x0F
#define LSM6DSL_CTRL1_XL        0x10  // Accelerometer control
#define LSM6DSL_CTRL2_G         0x11  // Gyroscope control
#define LSM6DSL_CTRL3_C         0x12  // Control register 3
#define LSM6DSL_CTRL4_C         0x13  // Control register 4
#define LSM6DSL_CTRL5_C         0x14  // Control register 5
#define LSM6DSL_CTRL6_C         0x15  // Control register 6
#define LSM6DSL_CTRL7_G         0x16  // Gyroscope control 7
#define LSM6DSL_CTRL8_XL        0x17  // Accelerometer control 8
#define LSM6DSL_CTRL9_XL        0x18  // Accelerometer control 9
#define LSM6DSL_CTRL10_C        0x19  // Control register 10

// Status and data registers
#define LSM6DSL_STATUS_REG      0x1E
#define LSM6DSL_OUTX_L_XL       0x28  // Accelerometer X-axis low byte
#define LSM6DSL_OUTX_H_XL       0x29  // Accelerometer X-axis high byte
#define LSM6DSL_OUTY_L_XL       0x2A  // Accelerometer Y-axis low byte
#define LSM6DSL_OUTY_H_XL       0x2B  // Accelerometer Y-axis high byte
#define LSM6DSL_OUTZ_L_XL       0x2C  // Accelerometer Z-axis low byte
#define LSM6DSL_OUTZ_H_XL       0x2D  // Accelerometer Z-axis high byte

// Wake-up and interrupt registers
#define LSM6DSL_WAKE_UP_SRC     0x1B  // Wake-up interrupt source
#define LSM6DSL_TAP_CFG         0x58  // Tap configuration
#define LSM6DSL_WAKE_UP_THS     0x5B  // Wake-up threshold
#define LSM6DSL_WAKE_UP_DUR     0x5C  // Wake-up duration
#define LSM6DSL_FREE_FALL       0x5D  // Free fall configuration
#define LSM6DSL_MD1_CFG         0x5E  // INT1 routing
#define LSM6DSL_MD2_CFG         0x5F  // INT2 routing

// Motion detection configuration
#define MOTION_THRESHOLD_LOW    1.00f  // Low threshold in g (high sensitivity)
#define MOTION_THRESHOLD_MED    1.50f  // Medium threshold in g (medium sensitivity)
#define MOTION_THRESHOLD_HIGH   2.00f  // High threshold in g (low sensitivity - max)
#define NO_MOTION_SLEEP_TIME    10000  // 10 seconds to sleep

// Accelerometer data structure
struct AccelData {
  float x;
  float y;
  float z;
  float magnitude;
};

// LSM6DSL class for motion detection
class LSM6DSL {
private:
  uint8_t i2cAddress;
  AccelData currentAccel;
  AccelData referenceAccel;
  bool motionDetectedFlag;
  unsigned long lastMotionTime;
  bool initialized;
  
  // I2C communication
  uint8_t readRegister(uint8_t reg);
  void writeRegister(uint8_t reg, uint8_t value);
  bool readAccelerometer();
  
public:
  LSM6DSL();
  
  // Initialization
  bool begin();
  bool isConnected();
  bool isInitialized() { return initialized; }
  
  // Motion detection
  bool detectMotion();
  bool isMotionDetected() { return motionDetectedFlag; }
  unsigned long getTimeSinceLastMotion();
  void resetMotionReference();
  
  // Power management
  void setLowPowerMode();
  void setPowerDownMode();
  void setNormalMode();
  
  // Wake-on-motion configuration
  void configureWakeOnMotion();
  void clearMotionInterrupts();
  uint8_t getWakeSource();
  
  // Motion sensitivity
  void setMotionThreshold(float threshold);
  
  // Get current acceleration data
  AccelData getAcceleration() { return currentAccel; }
  float getMotionDelta();
};

// Global instance
extern LSM6DSL motionSensor;

#endif // LSM6DSL_HANDLER_H