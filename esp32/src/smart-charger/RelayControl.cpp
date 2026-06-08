#include "RelayControl.h"

int RelayControl::_pin = -1;
bool RelayControl::_activeLow = true;
bool RelayControl::_initialized = false;
bool RelayControl::_circuitOpen = false;

bool RelayControl::chargingAllowed = true;
unsigned long RelayControl::lastControlTime = 0;


void RelayControl::init(int pin, bool activeLow) {
    _pin = pin;
    _activeLow = activeLow;
    pinMode(_pin, OUTPUT);
    _circuitOpen = false;
    _initialized = true;
    updateOutput();
    Serial.printf("RelayControl: init pin=%d activeLow=%d\n", _pin, _activeLow);
}

bool RelayControl::circuitOpen() {
    return _circuitOpen;
}

void RelayControl::updateOutput() {
    if (!_initialized) return;
    int output = _activeLow
        ? (_circuitOpen ? LOW : HIGH)
        : (_circuitOpen ? HIGH : LOW);
    digitalWrite(_pin, output);

    // if active low is true and circuitOpen is true, set output to LOW
    //    if (_activeLow) {
    //        if (_circuitOpen) {
    //            output = LOW;
    //        } else {
    //            output = HIGH;
    //        }
    //    } else {
    //        if (_circuitOpen) {
    //            output = HIGH;
    //        } else {
    //            output = LOW;
    //        }
    //    }
    //
    //    digitalWrite(_pin, output);
    //}
}

void RelayControl::startCharging() {
    if (!_initialized) return;
    _circuitOpen = false; // relay OFF = NC closed = charging ON
    chargingAllowed = true;
    updateOutput();
}

void RelayControl::stopCharging() {
    if (!_initialized) return;
    _circuitOpen = true; // relay ON = NC open = charging OFF
    chargingAllowed = false;
    updateOutput();
}
