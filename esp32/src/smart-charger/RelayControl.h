#ifndef RELAY_CONTROL_H
#define RELAY_CONTROL_H

#include <Arduino.h>

class RelayControl {
public:
    static void init(int pin, bool activeLow = true);
    static void turnOn();
    static void turnOff();
    static bool isOn();

private:
    static int _pin;
    static bool _activeLow;
    static bool _initialized;
    static bool _isOn;
    static void updateOutput();
};

#endif
