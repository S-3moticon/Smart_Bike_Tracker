#include <HardwareSerial.h>

HardwareSerial simSerial(1); // Use UART1

#define SIM_TX 17  // ESP32 TX -> SIM7070G RX
#define SIM_RX 16  // ESP32 RX -> SIM7070G TX
//#define SIM_PWR 4  // Optional SIM7070G PWRKEY pin

String phoneNumber = "+1234567890"; // Replace with target phone number

// Helper: Send AT command and wait for a specific response
bool sendATCommand(String cmd, String resp, uint32_t timeout = 2000) {
  simSerial.println(cmd);
  uint32_t start = millis();
  String buffer = "";
  while (millis() - start < timeout) {
    while (simSerial.available()) {
      char c = simSerial.read();
      buffer += c;
      if (buffer.indexOf(resp) != -1) {
        Serial.println(buffer);
        return true;
      }
    }
  }
  Serial.println(buffer);
  return false;
}

void setup() {
  Serial.begin(115200);
  simSerial.begin(115200, SERIAL_8N1, SIM_RX, SIM_TX);

  Serial.println("Powering SIM7070G...");

//   pinMode(SIM_PWR, OUTPUT);
//   digitalWrite(SIM_PWR, LOW);
//   delay(1000);
//   digitalWrite(SIM_PWR, HIGH);
//   delay(2000);
//   digitalWrite(SIM_PWR, LOW);
   delay(5000); // wait for boot

  // Step 1: Basic module check
  while (!sendATCommand("AT", "OK")) {
    delay(1000);
  }

  // Step 2: Turn on GNSS power
  sendATCommand("AT+CGNSPWR=1", "OK", 1000);

  // Step 3: Set GNSS output to RMC sentences
  sendATCommand("AT+CGNSSEQ=\"RMC\"", "OK");

  // Step 4: Wait for GNSS fix
  Serial.println("Waiting for GNSS fix...");
  while (true) {
    simSerial.println("AT+CGNSINF");
    uint32_t start = millis();
    String gpsData = "";
    while (millis() - start < 2000) {
      while (simSerial.available()) {
        char c = simSerial.read();
        gpsData += c;
      }
    }
    Serial.println(gpsData);

    // Example:
    // +CGNSINF: 1,1,20230802120000.000,14.5995,120.9842,10.0,0.00,0.0,1,,1.0,1.0,0.9,,12,9,,,39,,
    if (gpsData.indexOf("+CGNSINF: 1,1") != -1) {
      int firstComma = gpsData.indexOf(",202");
      if (firstComma != -1) {
        int latStart = gpsData.indexOf(",", firstComma + 1) + 1;
        int latEnd = gpsData.indexOf(",", latStart);
        int lonStart = gpsData.indexOf(",", latEnd + 1) + 1;
        int lonEnd = gpsData.indexOf(",", lonStart);

        String lat = gpsData.substring(latStart, latEnd);
        String lon = gpsData.substring(lonStart, lonEnd);

        Serial.println("Fix acquired!");
        Serial.println("Latitude: " + lat);
        Serial.println("Longitude: " + lon);

        // Step 5: Send Google Maps link via SMS
        sendATCommand("AT+CMGF=1", "OK"); // Text mode
        sendATCommand("AT+CMGS=\"" + phoneNumber + "\"", ">", 2000);
        simSerial.print("https://maps.google.com/?q=");
        simSerial.print(lat);
        simSerial.print(",");
        simSerial.print(lon);
        simSerial.write(26); // CTRL+Z to send
        Serial.println("SMS sent!");
        return;
      }
    }
    delay(5000); // retry every 5s
  }
}

void loop() {
  // Not used in this example
}
