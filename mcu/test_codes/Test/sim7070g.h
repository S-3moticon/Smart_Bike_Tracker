/*
 * sim7070g.h
 * 
 * Header file for SIM7070G GPS/SMS module interface
 * Provides AT command communication and module control
 */

#ifndef SIM7070G_H
#define SIM7070G_H

#include <Arduino.h>
#include <HardwareSerial.h>

// Pin definitions for UART communication
#define SIM_TX_PIN 4
#define SIM_RX_PIN 5

// Timeout values
#define DEFAULT_TIMEOUT 2000
#define NETWORK_TIMEOUT 5000
#define SMS_TIMEOUT 30000
#define GPS_TIMEOUT 10000

// External serial object (defined in .cpp)
extern HardwareSerial simSerial;

// Module initialization and control
bool initializeSIM7070G();
bool isSIM7070GInitialized();
bool sendATCommand(const String& cmd, const String& expectedResp, uint32_t timeout = DEFAULT_TIMEOUT);
bool checkNetworkRegistration();
bool isModuleReady();
bool resetModule();

// Power management
bool enableGNSSPower();
bool disableGNSSPower();
bool disableRF();  // Turn off RF with AT+CFUN=0
bool enableRF();   // Turn on RF with AT+CFUN=1

// Utility functions
void clearSerialBuffer();
String readResponse(uint32_t timeout = DEFAULT_TIMEOUT);

#endif // SIM7070G_H