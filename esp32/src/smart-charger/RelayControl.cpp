#include "RelayControl.h"

int RelayControl::_pin = -1;
bool RelayControl::_activeLow = true;
bool RelayControl::_initialized = false;
bool RelayControl::_isOn = false;

void RelayControl::init(int pin, bool activeLow) {
    _pin = pin;
    _activeLow = activeLow;
    pinMode(_pin, OUTPUT);
    _isOn = false;
    _initialized = true;
    updateOutput();
    Serial.printf("RelayControl: init pin=%d activeLow=%d\n", _pin, _activeLow);
}

void RelayControl::turnOn() {
    if (!_initialized) return;
    _isOn = true;
    updateOutput();
    Serial.println("Hardware: Relay ON");
}

void RelayControl::turnOff() {
    if (!_initialized) return;
    _isOn = false;
    updateOutput();
    Serial.println("Hardware: Relay OFF");
}

bool RelayControl::isOn() {
    return _isOn;
}

void RelayControl::updateOutput() {
    if (!_initialized) return;
    int output = _isOn ? (_activeLow ? LOW : HIGH) : (_activeLow ? HIGH : LOW);
    digitalWrite(_pin, output);
}
