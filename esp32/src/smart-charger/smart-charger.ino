#include "BLEManager.h"
#include "RelayControl.h"

#define RELAY_PIN 23
#define NOTIFY_INTERVAL 5000

// Simulated telemetry data for initial testing
int mockBat = 75;
float mockTemp = 28.5;
int mockCurr = 850;

unsigned long lastNotifyTime = 0;

int readBatteryPercent() {
    if (BLEManager::phoneBattery > 0) {
        return BLEManager::phoneBattery;
    }

    // Fallback for test mode if no phone battery value has been synced yet
    return mockBat;
}

float readBatteryTemperature() {
    return mockTemp;
}

int readChargeCurrent() {
    return mockCurr;
}

void updateMockTelemetry() {
    mockTemp += 0.1;
    if (mockBat > 1) {
        mockBat--;
    }
}

void setup() {
    Serial.begin(115200);

    RelayControl::init(RELAY_PIN, true);
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

    bool chargeComplete = false;

    if (batteryPercent > 0) {
        if (batteryPercent < effectiveMax) {
            RelayControl::turnOn();
        } else {
            RelayControl::turnOff();
            chargeComplete = true;
        }
    } else {
        RelayControl::turnOff();
    }

    bool relayState = RelayControl::isOn();

    if (BLEManager::isConnected() && (now - lastNotifyTime >= NOTIFY_INTERVAL)) {
        lastNotifyTime = now;
        updateMockTelemetry();

        BLEManager::pushStatus(batteryPercent, readBatteryTemperature(), readChargeCurrent(), relayState);
        Serial.printf("Pushed Status -> Bat: %d%% Temp: %.1f°C Curr: %dmA Relay: %s\n",
            batteryPercent,
            readBatteryTemperature(),
            readChargeCurrent(),
            relayState ? "ON" : "OFF");

        if (chargeComplete) {
            Serial.println("Charge completed: relay turned OFF and current is stopped.");
        }
    }

    delay(10);
}
