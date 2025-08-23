21:13:03.477 -> 🚴 Smart Bike Tracker v1.0
21:13:03.477 -> 
21:13:03.521 -> ✅ NVS initialized
21:13:03.521 -> 🔄 Normal boot
21:13:03.521 -> 📱 Config: +639811932238, 300s
21:13:03.521 -> 🔷 BLE Device: BikeTrk_4F8C
21:13:04.153 -> 📍 Initial GPS history set: 7 of 8 points (24 bytes)
21:13:04.153 -> ✅ BLE Service started
21:13:04.153 -> 📍 GPS: 14.563259, 121.145845
21:13:04.266 -> LSM6DSL found at address 0x6B
21:13:04.571 -> Reference acceleration: X=0.03, Y=-0.01, Z=1.02
21:13:04.571 -> ✅ LSM6DSL ready
21:13:04.571 -> 🎚️ Motion: High sensitivity (Low threshold: 0.50g)
21:13:04.571 -> Motion threshold set to 0.50g (register: 0x10)
21:13:04.608 -> 📡 SIM7070G: On-demand init
21:13:04.608 -> 📡 Ready
21:13:04.608 -> 
21:13:04.608 -> ⏱️ 30s grace period for BLE
21:13:04.608 -> 👤 IR Sensor: User Away
21:13:07.439 -> ⏳ BLE wait: 27s
21:13:12.437 -> ⏳ BLE wait: 22s
21:13:17.454 -> ⏳ BLE wait: 17s
21:13:22.453 -> ⏳ BLE wait: 12s
21:13:27.451 -> ⏳ BLE wait: 7s
21:13:32.469 -> ⏳ BLE wait: 2s
21:13:34.635 -> ⏱️ Grace period expired
21:13:34.641 -> 😴 No motion for 10 seconds - Preparing for sleep...
21:13:34.641 -> 🔍 First disconnect - configuring wake on motion only
21:13:34.641 -> Configuring LSM6DSL for wake-on-motion...
21:13:34.668 -> Cleared interrupts - Wake: 0x00, Status: 0x04
21:13:34.779 -> Cleared interrupts - Wake: 0x00, Status: 0x05
21:13:34.779 -> Wake interrupts configured - MD1: 0x20, MD2: 0x20
21:13:34.889 -> Cleared interrupts - Wake: 0x00, Status: 0x05
21:13:35.002 -> 💤 Entering light sleep...
21:13:35.002 -> Will wake on: Motion detection
21:13:45.618 -> 🚨 Wake interrupt triggered
21:13:45.678 -> Cleared interrupts - Wake: 0x09, Status: 0x05
21:13:46.044 -> ❌ False wake - no real motion detected
21:13:49.065 -> Motion detected! Delta: 1.697g
21:13:49.065 -> 🚨 Motion detected - Waking from sleep
21:13:49.097 -> Cleared interrupts - Wake: 0x0F, Status: 0x04
21:13:49.097 -> 
21:13:49.097 -> 📱 Motion detected after disconnect - Sending initial SMS...
21:13:49.134 -> 🛰️ Disabling GPS...
21:13:54.134 -> ❌ Failed to power off GPS
21:13:54.625 -> 📡 Enabling RF (AT+CFUN=1)...
21:14:04.632 -> ❌ Failed to enable RF
21:14:07.139 -> ❌ Module not responding
21:14:07.139 -> 📡 Disabling RF after SMS...
21:14:07.139 -> 📡 Disabling RF (AT+CFUN=0)...
21:14:12.114 -> ❌ Failed to disable RF
21:14:12.114 -> ❌ Failed to send location SMS
21:14:12.163 -> 😴 No motion for 10 seconds - Preparing for sleep...
21:14:12.163 -> Configuring LSM6DSL for wake-on-motion...
21:14:12.189 -> Cleared interrupts - Wake: 0x00, Status: 0x04
21:14:12.291 -> Cleared interrupts - Wake: 0x00, Status: 0x05
21:14:12.291 -> Wake interrupts configured - MD1: 0x20, MD2: 0x20
21:14:12.425 -> Cleared interrupts - Wake: 0x00, Status: 0x05
21:14:12.527 -> 💤 Entering light sleep...
21:14:12.527 -> Will wake on: Motion detection