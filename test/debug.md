19:10:03.978 -> 
19:10:03.978 -> === ESP32-C3 LSM6DSL Motion System ===
19:10:03.978 -> 🔌 POWER-ON RESET / FIRST BOOT
19:10:04.045 -> Found LSM6DSL at 0x6B (ID: 0x6A)
19:10:04.402 -> LSM6DSL ready - calibrating...
19:10:04.402 -> Calibrating... Keep device still
19:10:05.617 -> Calibration complete: X=0.790 Y=-0.187 Z=0.608
19:10:05.617 -> Motion threshold: 0.050g (HIGH SENSITIVITY)
19:10:05.617 -> 
19:10:16.350 -> 
19:10:16.350 -> === NO CHANGE DETECTED - SLEEP COUNTDOWN ===
19:10:16.350 -> 6...
19:10:16.452 -> 5...
19:10:17.434 -> 4...
19:10:18.350 -> 3...
19:10:19.333 -> 2...
19:10:20.333 -> 1...
19:10:21.333 -> 4294968...
19:10:21.333 -> 
19:10:21.333 -> === ENTERING SLEEP ===
19:10:21.333 -> Total: 0 motions, 0 wakes
19:10:21.333 -> Phase: First Motion (Light Sleep)
19:10:21.449 -> Configuring LSM6DSL for wake-on-motion...
19:10:21.651 -> LSM6DSL config: MD1=0x20 MD2=0x20 CTRL1_XL=0x20
19:10:21.651 -> Wake-on-motion interrupts configured (52Hz, latched)
19:10:21.697 -> Cleared wake source: 0x00
19:10:21.800 -> Waiting for motion detection...
19:10:21.800 -> (Move device when ready to sleep)
19:10:28.582 -> ✓ Motion detected! INT1=HIGH INT2=HIGH
19:10:28.582 -> ✓ LSM6DSL interrupt working!
19:10:28.583 -> Cleared wake source: 0x0A
19:10:28.713 -> Configuring GPIO wake sources (ESP32-C3 deep sleep)...
19:10:28.713 -> Deep sleep GPIO wake configured: result=0
19:10:28.713 -> GPIO mask: 0x3 (INT1=0, INT2=1)
19:10:28.713 -> Pin states: INT1=LOW INT2=LOW
19:10:28.713 -> ⚠️ ENTERING DEEP SLEEP (Phase 1)
19:10:28.713 -> Will wake ONLY on motion (no timer backup)
19:10:33.925 -> 
19:10:33.925 -> === ESP32-C3 LSM6DSL Motion System ===
19:10:33.925 -> 🔔 WAKE FROM MOTION! (GPIO) Count: 1
19:10:33.925 ->    INT1: HIGH, INT2: HIGH
19:10:34.049 -> Found LSM6DSL at 0x6B (ID: 0x6A)
19:10:34.363 ->    LSM6DSL wake source: 0x00
19:10:34.363 -> LSM6DSL ready - calibrating...
19:10:34.363 -> Calibrating... Keep device still
19:10:35.582 -> Calibration complete: X=0.790 Y=-0.187 Z=0.607
19:10:35.582 -> Motion threshold: 0.050g (HIGH SENSITIVITY)
19:10:35.582 -> 
19:10:40.714 -> 
19:10:40.714 -> === NO CHANGE DETECTED - SLEEP COUNTDOWN ===
19:10:40.714 -> 6...
19:10:40.817 -> 5...
19:10:41.696 -> 4...
19:10:42.714 -> 3...
19:10:43.697 -> 2...
19:10:44.697 -> 1...
19:10:45.697 -> 4294968...
19:10:45.697 -> 
19:10:45.697 -> === ENTERING SLEEP ===
19:10:45.697 -> Total: 0 motions, 1 wakes
19:10:45.697 -> Phase: Periodic (Deep Sleep)
19:10:45.812 -> First motion already detected - using periodic deep sleep
19:10:45.812 -> Timer wake enable: 0
19:10:45.812 -> ⚠️ ENTERING DEEP SLEEP - USB WILL DISCONNECT!
19:10:45.812 -> Will wake after 10 seconds (periodic check)
19:10:45.812 -> Press RESET button after wake to see output.
19:10:56.657 -> 
19:10:56.657 -> === ESP32-C3 LSM6DSL Motion System ===
19:10:56.657 -> ⏰ WAKE FROM TIMER! (Periodic) Count: 2
19:10:56.728 -> Found LSM6DSL at 0x6B (ID: 0x6A)
19:10:57.079 -> LSM6DSL ready - calibrating...
19:10:57.079 -> Calibrating... Keep device still
19:10:58.312 -> Calibration complete: X=0.791 Y=-0.187 Z=0.607
19:10:58.312 -> Motion threshold: 0.050g (HIGH SENSITIVITY)
19:10:58.312 -> 
19:11:00.511 -> 
19:11:00.511 -> >>> MOTION DETECTED <<<
19:11:00.511 -> Event #1
19:11:00.511 -> X=+0.860 Y=-0.128 Z=+0.248 | Change: 0.370g
19:11:02.711 -> Motion stopped
19:11:02.711 -> 