#include <Wire.h>
#include <Adafruit_LSM6DSOX.h> // Works for LSM6DSL too
#include "esp_sleep.h"

Adafruit_LSM6DSOX lsm6ds;
#define INT1_PIN 27  // LSM6DSL INT1 pin connected to ESP32

volatile bool motionDetected = false;

// Interrupt handler
void IRAM_ATTR imuISR() {
  motionDetected = true;
}

void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10);

  // I2C init
  if (!lsm6ds.begin_I2C()) {
    Serial.println("Failed to find LSM6DSL chip");
    while (1) delay(10);
  }
  Serial.println("LSM6DSL Found!");

  // Accelerometer settings
  lsm6ds.setAccelRange(LSM6DS_ACCEL_RANGE_2_G);
  lsm6ds.setAccelDataRate(LSM6DS_RATE_104_HZ);
  
  // Configure embedded wake-up & tilt detection
  configureWakeTilt();

  // Attach interrupt pin
  pinMode(INT1_PIN, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(INT1_PIN), imuISR, RISING);

  Serial.println("Setup complete. Going to light sleep...");
  delay(1000);

  // Initial sleep
  enterSleep();
}

void loop() {
  if (motionDetected) {
    motionDetected = false;

    Serial.println("Motion detected! Reading acceleration...");
    sensors_event_t accel, gyro, temp;
    lsm6ds.getEvent(&accel, &gyro, &temp);

    Serial.print("Accel X: "); Serial.print(accel.acceleration.x);
    Serial.print(" m/s², Y: "); Serial.print(accel.acceleration.y);
    Serial.print(" m/s², Z: "); Serial.println(accel.acceleration.z);

    Serial.println("Re-entering sleep in 3 seconds...");
    delay(3000);
    enterSleep();
  }
}

// Configure shock and tilt detection in LSM6DSL registers
void configureWakeTilt() {
  Wire.beginTransmission(0x6A); // LSM6DSL default I2C address
  Wire.write(0x10); // CTRL1_XL - Accelerometer
  Wire.write(0x40 | 0x0A); // ODR_XL=104Hz, FS_XL=2g
  Wire.endTransmission();

  // Wake-up duration (0x5C WAKE_DUR)
  Wire.beginTransmission(0x6A);
  Wire.write(0x5C);
  Wire.write(0x00); // minimal duration
  Wire.endTransmission();

  // Wake-up threshold (0x5B WAKE_THS)
  Wire.beginTransmission(0x6A);
  Wire.write(0x5B);
  Wire.write(0x02); // low threshold for shock
  Wire.endTransmission();

  // Tilt enable in TAP_CFG (0x58)
  Wire.beginTransmission(0x6A);
  Wire.write(0x58);
  Wire.write(0x20); // Enable tilt
  Wire.endTransmission();

  // INT1_CTRL (0x0D) - route wake-up & tilt to INT1
  Wire.beginTransmission(0x6A);
  Wire.write(0x0D);
  Wire.write(0x20 | 0x02); // tilt + wake-up
  Wire.endTransmission();
}

void enterSleep() {
  esp_sleep_enable_ext0_wakeup((gpio_num_t)INT1_PIN, 1); // Wake on INT1 HIGH
  Serial.println("Entering light sleep now...");
  delay(100);
  esp_light_sleep_start();
  Serial.println("Woke up from sleep!");
}
