#ifndef BLE_MANAGER_H
#define BLE_MANAGER_H

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include "RelayControl.h"

// Professional 128-bit UUIDs
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define SETTINGS_CHAR_UUID  "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define STATUS_CHAR_UUID    "8b11b57c-ed1a-466d-8e42-99a341f22e70"

class BLEManager {
public:
    static void init(const char* deviceName);
    static void pushStatus(int bat, float temp, int curr);
    static bool isConnected();

    static bool savingMode;
    static int minThreshold;
    static int maxThreshold;
    static int phoneBattery;

private:
    static BLECharacteristic *pSettingsChar;
    static BLECharacteristic *pStatusChar;
    static bool _connected;

    class ServerCallbacks : public BLEServerCallbacks {
        void onConnect(BLEServer* pServer) override;
        void onDisconnect(BLEServer* pServer) override;
    };

    class SettingsCallbacks : public BLECharacteristicCallbacks {
        void onWrite(BLECharacteristic *pCharacteristic) override;
    };
};

#endif
