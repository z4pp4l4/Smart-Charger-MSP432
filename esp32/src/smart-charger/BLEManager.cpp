#include "BLEManager.h"

// Define static variables
BLECharacteristic* BLEManager::pSettingsChar = nullptr;
BLECharacteristic* BLEManager::pStatusChar = nullptr;
bool BLEManager::_connected = false;
bool BLEManager::savingMode = false;
int BLEManager::minThreshold = 20;
int BLEManager::maxThreshold = 80;
int BLEManager::phoneBattery = 0;

void BLEManager::init(const char* deviceName) {
    BLEDevice::init(deviceName);
    BLEServer *pServer = BLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks());

    // Use 128-bit UUIDs for stability
    BLEService *pService = pServer->createService(SERVICE_UUID);

    pSettingsChar = pService->createCharacteristic(
                        SETTINGS_CHAR_UUID,
                        BLECharacteristic::PROPERTY_WRITE
                    );
    pSettingsChar->setCallbacks(new SettingsCallbacks());

    pStatusChar = pService->createCharacteristic(
                      STATUS_CHAR_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_NOTIFY
                  );

    pService->start();

    // Fix: Explicitly add service UUID to advertising and set scan response
    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);
    pAdvertising->setMinPreferred(0x12);
    BLEDevice::startAdvertising();

    Serial.println("BLE Manager Initialized with Advertising.");
}

void BLEManager::pushStatus(int bat, float voltage, int curr, float power, bool relayOn) {
    if (_connected) {
        char payload[64];

        // Format: battery:voltage:current:power:relay
        snprintf(payload, sizeof(payload), "%d:%.2f:%d:%.1f:%d",
                 bat,
                 voltage,
                 curr,
                 power,
                 relayOn ? 0 : 1);

        pStatusChar->setValue(payload);
        pStatusChar->notify();

        Serial.print("BLE Status Sent -> ");
        Serial.println(payload);
    }
}

bool BLEManager::isConnected() {
    return _connected;
}

void BLEManager::ServerCallbacks::onConnect(BLEServer* pServer) {
    _connected = true;
    Serial.println("BLE: Connected");
}

void BLEManager::ServerCallbacks::onDisconnect(BLEServer* pServer) {
    _connected = false;
    Serial.println("BLE: Disconnected");
    BLEDevice::startAdvertising();
}

void BLEManager::SettingsCallbacks::onWrite(BLECharacteristic *pCharacteristic) {
    String value = pCharacteristic->getValue();
    if (value.length() > 0) {
        int c1 = value.indexOf(':');
        int c2 = value.indexOf(':', c1 + 1);
        int c3 = value.indexOf(':', c2 + 1);

        if (c1 != -1 && c2 != -1 && c3 != -1) {
            savingMode = (value.substring(0, c1) == "1");
            minThreshold = value.substring(c1 + 1, c2).toInt();
            maxThreshold = value.substring(c2 + 1, c3).toInt();
            phoneBattery = value.substring(c3 + 1).toInt();

            Serial.printf("Sync Received -> Mode: %s, Min: %d, Max: %d, Phone: %d%%\n",
                savingMode ? "SAVING" : "NORMAL", minThreshold, maxThreshold, phoneBattery);
        }
    }
}
