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

    RelayControl::init(RELAY_PIN, true); //active low relay

    //RelayControl::startCharging(); this call writes unnecessary pins sometimes

    if (!BLEManager::savingMode) {
        RelayControl::startCharging();
    } else {
        int bat = readBatteryPercent();
        if (bat >= BLEManager::maxThreshold) {
            RelayControl::stopCharging();
        } else {
            RelayControl::startCharging(); // covers bat < min and min <= bat < max
        }
    }

    /*
     IMPORTANT  : we should inspect the battery level lecture appena lanciamo l'app
     se vediamo che legge 0%, mettiamo RelayControl::startCharging(); al posto del blocco soppra
     cosi prende il suo tempo senza clicks non necessari, e una volta il programma loaded, il Ble connected
     facciamo partire la ricarica dentro loop
     il sistema aspetta con calma che il tutto si stabili

      */

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

    if (now - RelayControl::lastControlTime >= NOTIFY_INTERVAL) {
        RelayControl::lastControlTime = now;

        if (!BLEManager::savingMode) {
            // normal charging till 100
            if (batteryPercent < 100) {
                if (!RelayControl::chargingAllowed) {
                    //if its not chargig, start charging,
                    RelayControl::startCharging();
                } //else do nothing since its already charging

            } else {
                //we hit 100 and its still charging, stop charging
                if (RelayControl::chargingAllowed) {
                    RelayControl::stopCharging();
                }
            }


        } else {
            /* 4 possible cases:
             chargin + bat<maxT (includes bat<minT) ==> else (keep charging)
             charging + bat >maxT  ==> first if (stop charging)
             not charging + bat<minT (includes bat<maxT) ==> else if (start charging)
             not charging + bat>minT  ==> else (keep not charging)
             */

            if (RelayControl::chargingAllowed && batteryPercent >= effectiveMax) {
                RelayControl::stopCharging();
            }
            else if (!RelayControl::chargingAllowed && batteryPercent <= effectiveMin) {
                RelayControl::startCharging();
            }
            else {
                //here we have the cases: charging + bat < maxT & not charging + bat > minT
                // cioè il caso tra minT e maxT
                // keep the state, do not toggle
            }
        }
    }

    /*
    bool chargeComplete = false;
    bool is_charging = false;

    if (batteryPercent > -1) {
        if (BLEManager::savingMode){
            //bat<minT
            if (batteryPercent <= effectiveMin){
                RelayControl::turnOn();
                is_charging= true;
            //charging with bat>maxT
            } else if (is_charging && batteryPercent >= effectiveMax) {
                chargeComplete = true;
                is_charging= false;
                RelayControl::turnOff();
            }

        } else {
            is_charging= true;
            RelayControl::turnOn();
        }
    } else {
        // Default to ON if no battery data yet, or keep state
        RelayControl::turnOn();
        is_charging= true;
    }
     */

    readINA219();

    if (BLEManager::isConnected() && (now - lastNotifyTime >= NOTIFY_INTERVAL)) {
        lastNotifyTime = now;
        BLEManager::pushStatus(lastVoltage_V, (int)lastCurrent_mA, lastPower_mW, RelayControl::chargingAllowed);

        Serial.printf(" V: %.2fV | I: %.1fmA | Relay: %s\n",
                       lastVoltage_V, lastCurrent_mA, RelayControl::chargingAllowed ? "Charging" : "Not Charging");
    }

    delay(20);
}