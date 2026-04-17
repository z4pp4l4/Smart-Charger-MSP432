#ifndef RELAY_CONTROL_H
#define RELAY_CONTROL_H

#include <Arduino.h>

class RelayControl {
public:
    static void init(int pin);
    static void turnOn();
    static void turnOff();
private:
    static int _pin;
};

#endif
