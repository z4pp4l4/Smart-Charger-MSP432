#include "BLEManager.h"
#include "RelayControl.h"

#include <Wire.h>
#include <Adafruit_INA219.h>

// WARNING: If using a standard ESP32, pins 6, 8, 9 are usually reserved for internal flash.
// If it still fails to boot, try changing these to: RELAY: 18, SDA: 21, SCL: 22
#define RELAY_PIN 5
#define I2C_SDA_PIN 8
#define I2C_SCL_PIN 9

#define NOTIFY_INTERVAL 5000

Adafruit_INA219 ina219;
bool ina219Ok = false;

unsigned long lastNotifyTime = 0;
bool chargingStarted = false;

float lastVoltage_V = 0.0;
float lastCurrent_mA = 0.0;
float lastPower_mW = 0.0;

float readBatteryTemperature() { return 0.0; }

int readBatteryPercent() {
    return (BLEManager::phoneBattery > 0) ? BLEManager::phoneBattery : 0;
}

void readINA219() {
    // If it wasn't found at setup, try to initialize it now
    if (!ina219Ok) {
        if (ina219.begin()) {
            ina219Ok = true;
            Serial.println("INA219 recovered and connected!");
        } else {
            lastVoltage_V = 0.0;
            lastCurrent_mA = 0.0;
            lastPower_mW = 0.0;
            return;
        }
    }

    lastVoltage_V = ina219.getBusVoltage_V();
    lastCurrent_mA = ina219.getCurrent_mA();
    lastPower_mW = ina219.getPower_mW();

    if (lastCurrent_mA < 0 && lastCurrent_mA > -2.0) lastCurrent_mA = 0.0;
    if (lastPower_mW < 0 && lastPower_mW > -5.0) lastPower_mW = 0.0;
}

void setup() {
    Serial.begin(115200);

    // Give time for power to stabilize and for user to open Serial Monitor
    for(int i = 0; i < 3; i++) {
        Serial.print(".");
        delay(500);
    }
    Serial.println("\n=== ESP32 Smart Charger Booting ===");

    RelayControl::init(RELAY_PIN, true);
    RelayControl::turnOff();

    Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);
    delay(500);

    Serial.println("Searching INA219...");
    ina219Ok = false;

    for (int i = 0; i < 5; i++) {
        if (ina219.begin()) {
            ina219Ok = true;
            Serial.println("INA219 found.");
            break;
        }
        Serial.println("INA219 not found, retrying...");
        delay(500);
    }

    if (!ina219Ok) {
        Serial.println("INA219 not found after retries.");
    }

    Serial.println("Starting BLE...");
    BLEManager::init("ESP32_SMART_CHARGER");
    Serial.println("System Ready.");
}

void loop() {
    unsigned long now = millis();
    int batteryPercent = readBatteryPercent();

    int effectiveMin = BLEManager::savingMode ? BLEManager::minThreshold : 0;
    int effectiveMax = BLEManager::savingMode ? BLEManager::maxThreshold : 100;

    bool chargeComplete = false;

    if (batteryPercent > -1) {
        if (BLEManager::savingMode){
            if (batteryPercent <= effectiveMin){
                RelayControl::turnOn();
                chargingStarted = true;
            } else if (chargingStarted && batteryPercent > effectiveMax) {
                chargeComplete = true;
                chargingStarted = false;
                RelayControl::turnOff();
            }
        } else {
            chargingStarted = true;
            RelayControl::turnOn();
        }
    } else {
        // Default to ON if no battery data yet, or keep state
        RelayControl::turnOn();
        chargingStarted = true;
    }

    readINA219();

    if (BLEManager::isConnected() && (now - lastNotifyTime >= NOTIFY_INTERVAL)) {
        lastNotifyTime = now;
        BLEManager::pushStatus(lastVoltage_V, (int)lastCurrent_mA, lastPower_mW, RelayControl::isOn());

        Serial.printf("V: %.2fV | I: %.1fmA | Relay: %s\n",
                      lastVoltage_V, lastCurrent_mA, RelayControl::isOn() ? "ON" : "OFF");
    }

    delay(20);
}