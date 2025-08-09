/*
  ESP32 Test Code for IR Sensor (HW-201)
  - Detects object presence
  - Prints status to Serial Monitor
*/

#define IR_SENSOR_PIN  15  // Change to your GPIO pin

void setup() {
  Serial.begin(115200);
  pinMode(IR_SENSOR_PIN, INPUT);
  Serial.println("IR Sensor Test Starting...");
}

void loop() {
  int sensorState = digitalRead(IR_SENSOR_PIN);

  if (sensorState == LOW) {
    Serial.println("🚨 Object detected!");
  } else {
    Serial.println("No object detected");
  }

  delay(500); // Small delay for readability
}
