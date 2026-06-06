#include "BLEManager.h"
#include "RelayControl.h"

#include <Wire.h>
#include <Adafruit_INA219.h>

#define RELAY_PIN 6
#define NOTIFY_INTERVAL 5000

// Your ESP32 board I2C pins
#define I2C_SDA_PIN 8
#define I2C_SCL_PIN 9

Adafruit_INA219 ina219;
bool ina219Ok = false;

unsigned long lastNotifyTime = 0;
bool chargingStarted = false;

bool cappedAtMax = false;   // true once we've hit max and are waiting for min
int  lastMaxSeen   = -1;    // to detect when the user raises the cap

float lastVoltage_V = 0.0;
float lastCurrent_mA = 0.0;
float lastPower_mW = 0.0;

// No temperature sensor for now
float readBatteryTemperature() {
    return 0.0;
}

int readBatteryPercent() {
    if (BLEManager::phoneBattery > 0) {
        return BLEManager::phoneBattery;
    }

    // If the phone has not sent battery value yet
    return 0;
}

void readINA219() {
    if (!ina219Ok) {
        lastVoltage_V = 0.0;
        lastCurrent_mA = 0.0;
        lastPower_mW = 0.0;
        return;
    }

    lastVoltage_V = ina219.getBusVoltage_V();
    lastCurrent_mA = ina219.getCurrent_mA();
    lastPower_mW = ina219.getPower_mW();

    // Remove small negative noise around zero
    if (lastCurrent_mA < 0 && lastCurrent_mA > -2.0) {
        lastCurrent_mA = 0.0;
    }

    if (lastPower_mW < 0 && lastPower_mW > -5.0) {
        lastPower_mW = 0.0;
    }
}

void setup() {
    Serial.begin(115200);
    delay(1000);

    Serial.println("=== ESP32 Smart Charger ===");

    RelayControl::init(RELAY_PIN, true);
    RelayControl::turnOff();

    Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);

    Serial.println("Searching INA219...");
    if (ina219.begin()) {
        ina219Ok = true;
        Serial.println("INA219 found.");
    } else {
        ina219Ok = false;
        Serial.println("INA219 not found. Voltage/current/power will be 0.");
    }

    BLEManager::init("ESP32_SMART_CHARGER");
}

void loop() {
    unsigned long now = millis();
    
    int batteryPercent = readBatteryPercent();

    int effectiveMin = 0;
    int effectiveMax = 100;
    if (BLEManager::savingMode) {
        effectiveMin = BLEManager::minThreshold;
        effectiveMax = BLEManager::maxThreshold;
    }

    // If the user RAISED the cap, re-arm so we charge toward the new max
    // even if we were parked between min and max.
    if (BLEManager::maxThreshold > lastMaxSeen) {
        cappedAtMax = false;
    }
    lastMaxSeen = BLEManager::maxThreshold;

    bool chargeComplete = false;

    if (batteryPercent > 0) {
        if (BLEManager::savingMode) {
            if (batteryPercent >= effectiveMax) {
                // Reached the cap -> stop and latch
                if (chargingStarted) chargeComplete = true;
                chargingStarted = false;
                cappedAtMax = true;
                RelayControl::turnOff();
            } else if (batteryPercent <= effectiveMin) {
                // Dropped to the floor -> resume
                chargingStarted = true;
                cappedAtMax = false;
                RelayControl::turnOn();
            } else {
                // Between min and max
                if (cappedAtMax) {
                    // Already hit max this cycle -> wait until min
                    chargingStarted = false;
                    RelayControl::turnOff();
                } else {
                    // Fresh start, or cap was just raised -> charge toward max
                    chargingStarted = true;
                    RelayControl::turnOn();
                }
            }
        } else {
            cappedAtMax = false;
            chargingStarted = true;
            RelayControl::turnOn();
        }
    } else {
        chargingStarted = true;
        RelayControl::turnOn();
    }
  

    bool relayState = RelayControl::isOn();

    readINA219();

    if (BLEManager::isConnected() && (now - lastNotifyTime >= NOTIFY_INTERVAL)) {
        lastNotifyTime = now;

        // For now, we send current through the old current field.
        // UI can later be updated to display voltage and power too.
        BLEManager::pushStatus(
                batteryPercent,
                lastVoltage_V,
                (int)lastCurrent_mA,
                lastPower_mW,
                relayState
        );

        Serial.printf(
                "Status -> Bat: %d%% | V: %.2f V | I: %.2f mA | P: %.2f mW | Relay: %s\n",
                batteryPercent,
                lastVoltage_V,
                lastCurrent_mA,
                lastPower_mW,
                relayState ? "ON" : "OFF"
        );

        if (!ina219Ok) {
            Serial.println("Warning: INA219 not available.");
        }

        if (chargeComplete) {
            Serial.println("Charge completed: relay turned OFF.");
        }
    }

    delay(10);
}
