=== ESP32-C3 LSM6DSL Motion System ===
🔌 POWER-ON RESET / FIRST BOOT
Found LSM6DSL at 0x6B (ID: 0x6A)
LSM6DSL ready - calibrating...
Calibrating... Keep device still
Calibration complete: X=0.786 Y=-0.213 Z=0.604
Motion threshold: 0.050g (HIGH SENSITIVITY)

=== INITIAL DEEP SLEEP TEST ===
⚠️  USB will disconnect! Press RESET after 5 sec to see output.
Testing 5-second timer wake...

=== ESP32-C3 LSM6DSL Motion System ===
⏰ WAKE FROM TIMER! (Periodic) Count: 1
Found LSM6DSL at 0x6B (ID: 0x6A)
LSM6DSL ready - calibrating...
Calibrating... Keep device still
Calibration complete: X=0.786 Y=-0.213 Z=0.605
Motion threshold: 0.050g (HIGH SENSITIVITY)


=== NO CHANGE DETECTED - SLEEP COUNTDOWN ===
6...
5...
4...
3...

>>> MOTION DETECTED <<<
Event #1
X=+0.998 Y=+0.185 Z=+0.497 | Change: 0.463g
Countdown cancelled

X=+0.765 Y=-0.515 Z=+0.554 | Change: 0.309g
X=+0.733 Y=-0.302 Z=+0.649 | Change: 0.351g
Motion stopped


=== NO CHANGE DETECTED - SLEEP COUNTDOWN ===
6...
5...
4...
3...
2...
1...
4294968...

=== ENTERING SLEEP ===
Total: 1 motions, 1 wakes
Phase: First Motion (Light Sleep)
Configuring LSM6DSL for wake-on-motion...
LSM6DSL config: MD1=0x20 MD2=0x20 CTRL1_XL=0x20
Wake-on-motion interrupts configured (52Hz, latched)
Cleared wake source: 0x0D
Testing interrupt generation...
Shake device NOW for 2 seconds...
⚠️ WARNING: No interrupt detected!
Configuring GPIO wake sources...
GPIO wake enable: INT1=0 INT2=0 Enable=0
Pin states: INT1=LOW INT2=LOW
⚠️ ENTERING LIGHT SLEEP
Will wake ONLY on motion (no timer backup)