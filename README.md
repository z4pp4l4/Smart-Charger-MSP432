# ***SMART CHARGER***


## Features

###  Flutter Mobile Application
* **Smart Range Configuration:** Set custom minimum (e.g., 20%) and maximum (e.g., 80%) thresholds to maintain optimal battery health.
* **Saving Mode Toggle:** Enable intelligent automation or fallback to a standard passive charge pass-through.
* **Real-time Telemetry Analytics:** Dashboard showing:
  *  **Voltage** (V)
  *  **Current** (A)
  *  **Power Consumption** (W)
* **Historical Micro-Charts:** Smooth time-series graphs to observe charging curves and power delivery performance.
* **BLE Connect:** Discovery and handshake with the FeatherS3 Bluetooth adapter.

###  Hardware & Firmware
* **USB-C High-Speed Pass-Through:** Preserves USB-C data and fast-charging power delivery profiles.
* **Fail-Safe Design:** Uses a normally-closed relay configuration so that if the application or micro-controller loses power, the circuit defaults to letting current pass safely.

---

## How the Charging Logic Works

The **Saving Mode** logic regulates the state of the relay based on the configuration sent from the Flutter app:

| Saving Mode | App Configured? | Current Battery Level | Relay Pin State | Charging Behavior |
| :---: | :---: | :---: | :---: | :---: |
| **OFF** | Any | Any | **LOW (Deactivated)** | **CHARGING:** Current passes freely. |
| **ON** | **YES** | `< Minimum Level` | **LOW (Deactivated)** | **CHARGING:** Reaches minimum floor, initiates charge. |
| **ON** | **YES** | `> Maximum Level` | **HIGH (Activated)** | **STOPPED:** Reaches maximum ceiling, cuts power. |
| **ON** | **YES** | `Min <= Level <= Max` | *Retains Previous State* | **MAINTAINING:** Keeps previous state. |

---

## Hardware Requirements & Components

1. **Microcontroller:** [Unexpected Maker FeatherS3](https://feathers3.io/) (ESP32-S3 development board).
2. **Relay Module:** 5V low-level trigger relay.
3. **Power Sensing:** INA219.
4. **Connectors:** 2x USB-C cables (Input from power source, Output to target device).
5. **Enclosure:** 3D-printed custom housing.

---

##  Getting Started

### 1. Hardware Setup & Wiring
* Connect the VBUS line of the input USB-C connector through the Relay common and input terminals and the Normally Closed (NC) port to the VBUS line of the output USB-C connector.
* Share the Ground (GND) across both USB-C breakouts, FeatherS3, Relay and INA219.
* Connect the FeatherS3 Out Pin (e.g., `Pin 6`) to the Signal pin of the Relay driver.
* Wire your voltage/current monitoring sensor across the output line and bridge it to the ESP32 via I2C (`SDA`/`SCL`).

### 2. Flashing the Firmware
1. Open the `/esp32/src/smart-charger` directory in **VS Code** with the **PlatformIO** extension installed (or use the Arduino IDE).
2. Install dependencies: `ESP32 BLE Arduino` and sensor libraries (e.g., `Adafruit_INA219`).
3. Build and upload the code to your FeatherS3 via USB-C.

### 3. Setting Up the Flutter App
1. Ensure you have the Flutter SDK installed (`flutter doctor`).
2. Ensure you have the Android Studio IDE installed and open it.
3. Flash the newest version of the application and flash it to your device.
4. Open and use the App!:
