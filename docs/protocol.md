## BLE Communication Protocol

**Service UUID:** `4fafc201-1fb5-459e-8fcc-c5c9c331914b`

### 1. Settings Characteristic (Write)
**UUID:** `beb5483e-36e1-4688-b7f5-ea07361b26a8`
**Format:** `manual:min:max:phoneBat`

| Field | Type | Description |
| :--- | :--- | :--- |
| `manual` | Integer (0 or 1) | 1 for Saving Mode, 0 for Normal Mode |
| `min` | Integer (0-100) | Minimum battery threshold to start charging |
| `max` | Integer (0-100) | Maximum battery threshold to stop charging |
| `phoneBat` | Integer (0-100) | Current battery level of the connected phone |

---

### 2. Status Characteristic (Notify/Read)
**UUID:** `8b11b57c-ed1a-466d-8e42-99a341f22e70`
**Format:** `extBat:temp:current`

| Field | Type | Description |
| :--- | :--- | :--- |
| `extBat` | Integer | External/Charger battery level (%) |
| `temp` | Float (1 decimal) | Temperature in Celsius |
| `current` | Integer | Current consumption in mA |
