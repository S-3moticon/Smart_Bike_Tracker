#ifndef BLE_PROTOCOL_H
#define BLE_PROTOCOL_H

#define SERVICE_UUID "00001234-0000-1000-8000-00805f9b34fb"
#define LOCATION_CHAR_UUID "00001235-0000-1000-8000-00805f9b34fb"
#define CONFIG_CHAR_UUID "00001236-0000-1000-8000-00805f9b34fb"
#define STATUS_CHAR_UUID "00001237-0000-1000-8000-00805f9b34fb"
#define COMMAND_CHAR_UUID "00001238-0000-1000-8000-00805f9b34fb"
#define HISTORY_CHAR_UUID "00001239-0000-1000-8000-00805f9b34fb"

#define DEVICE_NAME_PREFIX "BikeTrk_"

enum DeviceMode {
  MODE_IDLE,
  MODE_TRACKING,
  MODE_ALERT,
  MODE_SLEEP
};

struct LocationData {
  float lat;
  float lng;
  unsigned long timestamp;
  float speed;
  int satellites;
  int battery;
};

struct ConfigData {
  char phoneNumber[16];
  int updateInterval;
  bool alertEnabled;
};

struct StatusData {
  bool bleConnected;
  bool motionDetected;
  bool userPresent;
  DeviceMode mode;
};

#endif