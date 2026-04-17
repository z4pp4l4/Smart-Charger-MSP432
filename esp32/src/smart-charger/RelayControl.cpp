#include "RelayControl.h"

//int RelayControl::_pin = 23;

void RelayControl::init(int pin) {
    //_pin = pin;
    //pinMode(_pin, OUTPUT);
    //digitalWrite(_pin, HIGH); // Off initially (Active Low)
}

void RelayControl::turnOn() {
    //digitalWrite(_pin, LOW);
    //Serial.println("Hardware: Relay ON");
}

void RelayControl::turnOff() {
    //digitalWrite(_pin, HIGH);
    //Serial.println("Hardware: Relay OFF");
}
