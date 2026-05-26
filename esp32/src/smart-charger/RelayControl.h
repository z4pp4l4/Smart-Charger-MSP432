#ifndef RELAY_CONTROL_H
#define RELAY_CONTROL_H

#include <Arduino.h>

class RelayControl {
public:
    static void init(int pin, bool activeLow = true);
    static bool isOn();
    static bool chargingAllowed;
    static unsigned long lastControlTime;
    static void startCharging();
    static void stopCharging();

private:
    static int _pin;
    static bool _activeLow;
    static bool _initialized;
    static bool _circuitOpen;
    static void updateOutput();
};

#endif
