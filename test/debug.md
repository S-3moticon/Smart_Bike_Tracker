=== ESP32-C3 LSM6DSL Motion System ===
🔌 POWER-ON RESET / FIRST BOOT
Found LSM6DSL at 0x6B (ID: 0x6A)
LSM6DSL ready - calibrating...
Calibrating... Keep device still
Calibration complete: X=0.786 Y=-0.210 Z=0.605
Motion threshold: 0.050g (HIGH SENSITIVITY)

=== INITIAL DEEP SLEEP TEST ===
⚠️  USB will disconnect! Press RESET after 5 sec to see output.
Testing 5-second timer wake...

=== ESP32-C3 LSM6DSL Motion System ===
⏰ WAKE FROM TIMER! (30s backup) Count: 1
Found LSM6DSL at 0x6B (ID: 0x6A)
LSM6DSL ready - calibrating...
Calibrating... Keep device still
Calibration complete: X=0.786 Y=-0.209 Z=0.605
Motion threshold: 0.050g (HIGH SENSITIVITY)


>>> MOTION DETECTED <<<
Event #1
X=+0.849 Y=-0.069 Z=+0.571 | Change: 0.158g
X=+0.819 Y=-0.191 Z=+0.564 | Change: 0.058g
X=+0.758 Y=-0.130 Z=+0.625 | Change: 0.205g
X=+0.751 Y=-0.226 Z=+0.645 | Change: 0.070g
X=+0.747 Y=-0.265 Z=+0.619 | Change: 0.055g
X=+0.776 Y=-0.217 Z=+0.617 | Change: 0.166g
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
Configuring LSM6DSL for wake-on-motion...
LSM6DSL config: MD1=0x20 MD2=0x20 CTRL1_XL=0x20
Wake-on-motion interrupts configured (52Hz, latched)
Cleared wake source: 0x0D
Testing interrupt generation...
Shake device NOW for 2 seconds...
✓ INT detected! INT1=HIGH INT2=HIGH
✓ LSM6DSL interrupt generation working!
Cleared wake source: 0x0A
Configuring GPIO wake sources...
GPIO wake enable results: INT1=0 INT2=0 Enable=0
Timer wake enable result: 0
Pin states before sleep: INT1=LOW INT2=LOW
⚠️  ENTERING DEEP SLEEP - USB WILL DISCONNECT!
Device will wake on motion or after 5 seconds.
Press RESET button after wake to see output.
Use BOOT+RESET to recover if stuck.

=== ESP32-C3 LSM6DSL Motion System ===
🔔 WAKE FROM MOTION! (GPIO) Count: 2
   INT1: HIGH, INT2: HIGH
Found LSM6DSL at 0x6B (ID: 0x6A)
   LSM6DSL wake source: 0x00
LSM6DSL ready - calibrating...
Calibrating... Keep device still
Calibration complete: X=0.783 Y=-0.221 Z=0.592
Motion threshold: 0.050g (HIGH SENSITIVITY)
>>> MOTION DETECTED <<<
Event #2
X=+0.968 Y=-0.479 Z=+0.312 | Change: 0.565g
X=+0.964 Y=-0.293 Z=+0.370 | Change: 0.457g
X=+0.822 Y=+0.230 Z=+0.654 | Change: 0.895g
X=+0.695 Y=+0.156 Z=+0.804 | Change: 0.794g
X=+0.645 Y=-0.718 Z=+0.607 | Change: 1.209g
X=+0.594 Y=-0.776 Z=+0.790 | Change: 0.954g
X=+0.897 Y=-0.456 Z=+0.574 | Change: 0.354g
X=+0.956 Y=+0.217 Z=+0.433 | Change: 0.847g
X=+0.873 Y=+0.235 Z=+0.638 | Change: 0.430g
X=+0.557 Y=-0.169 Z=+0.881 | Change: 0.671g
X=+0.814 Y=-0.210 Z=+0.587 | Change: 0.051g
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
Total: 2 motions, 2 wakes
Configuring LSM6DSL for wake-on-motion...
LSM6DSL config: MD1=0x20 MD2=0x20 CTRL1_XL=0x20
Wake-on-motion interrupts configured (52Hz, latched)
Cleared wake source: 0x00
Testing interrupt generation...
Shake device NOW for 2 seconds...
✓ INT detected! INT1=HIGH INT2=HIGH
✓ LSM6DSL interrupt generation working!
Cleared wake source: 0x0F
Configuring GPIO wake sources...
GPIO wake enable results: INT1=0 INT2=0 Enable=0
Timer wake enable result: 0
Pin states before sleep: INT1=LOW INT2=LOW
⚠️  ENTERING DEEP SLEEP - USB WILL DISCONNECT!
Device will wake on motion or after 5 seconds.
Press RESET button after wake to see output.
Use BOOT+RESET to recover if stuck.

=== ESP32-C3 LSM6DSL Motion System ===
🔔 WAKE FROM MOTION! (GPIO) Count: 3
   INT1: HIGH, INT2: HIGH
Found LSM6DSL at 0x6B (ID: 0x6A)
   LSM6DSL wake source: 0x00
LSM6DSL ready - calibrating...
Calibrating... Keep device still
Calibration complete: X=0.766 Y=-0.223 Z=0.603
Motion threshold: 0.050g (HIGH SENSITIVITY)
