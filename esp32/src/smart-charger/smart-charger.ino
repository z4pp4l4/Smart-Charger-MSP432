#include "BLEManager.h"
#include "RelayControl.h"

#define RELAY_PIN 23

// Simulated telemetry data
int mockBat = 75;
float mockTemp = 28.5;
int mockCurr = 850;

unsigned long lastNotifyTime = 0;
const unsigned long notifyInterval = 5000; // Push to app every 5s

void setup() {
    Serial.begin(115200);

    // 1. Initialize modular components
    RelayControl::init(RELAY_PIN);
    BLEManager::init("ESP32_SMART_CHARGER");
}

void loop() {
    unsigned long now = millis();

    // 1. Handle live status updates to the app
    if (BLEManager::isConnected() && (now - lastNotifyTime >= notifyInterval)) {
        lastNotifyTime = now;

        // Mock updates for testing
        mockTemp += 0.1;
        if (mockBat > 1) mockBat--;

        BLEManager::pushStatus(mockBat, mockTemp, mockCurr);
        Serial.printf("Pushed Status -> Bat: %d, Temp: %.1f\n", mockBat, mockTemp);
    }

    // 2. The core charging logic (Smart Mode)
    // This only runs if the user hasn't turned on "Manual Override" in the app
    if (!BLEManager::manualOverride) {
        // If phone battery is below min, start charging
        if (BLEManager::phoneBattery > 0 && BLEManager::phoneBattery < BLEManager::minThreshold) {
            RelayControl::turnOn();
        }
        // If phone battery reaches max, stop charging
        else if (BLEManager::phoneBattery >= BLEManager::maxThreshold) {
            RelayControl::turnOff();
        }
    }

    delay(10); // Small stability delay
}
