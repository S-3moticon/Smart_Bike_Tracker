[Settings] Settings saved to preferences
[BLE-Config] Starting configuration send...
[BLE-Config] Connected device: BikeTrk_4B00
D/BluetoothGatt(19565): discoverServices() - device: XX:XX:XX:XX:6E:06
D/BluetoothGatt(19565): onSearchComplete() = Device=XX:XX:XX:XX:6E:06 Status=0
[BLE-Config] Discovered 3 services
[BLE-Config] Service: 1801
[BLE-Config] Service: 1800
[BLE-Config] Service: 1234
[BLE-Config] Checking service: 1801 against 00001234-0000-1000-8000-00805f9b34fb (short: 1234)
[BLE-Config] Checking service: 1800 against 00001234-0000-1000-8000-00805f9b34fb (short: 1234)
[BLE-Config] Checking service: 1234 against 00001234-0000-1000-8000-00805f9b34fb (short: 1234)
[BLE-Config] Found bike tracker service!
[BLE-Config] Checking char: 1236 against 00001236-0000-1000-8000-00805f9b34fb (short: 1236)
[BLE-Config] Found config characteristic!
[BLE-Config] Sending config JSON: {"phone_number":"+639811932238","update_interval":3600,"alert_enabled":true}
[BLE-Config] JSON length: 76 bytes
[BLE-Config]   Char: 2a05, Properties: CharacteristicProperties{broadcast: false, read: false, writeWithoutResponse: false, write: false, notify: false, indicate: true, authenticatedSignedWrites: false, extendedProperties: false, notifyEncryptionRequired: false, indicateEncryptionRequired: false}
[BLE-Config]   Char: 2a00, Properties: CharacteristicProperties{broadcast: false, read: true, writeWithoutResponse: false, write: false, notify: false, indicate: false, authenticatedSignedWrites: false, extendedProperties: false, notifyEncryptionRequired: false, indicateEncryptionRequired: false}
[BLE-Config]   Char: 2a01, Properties: CharacteristicProperties{broadcast: false, read: true, writeWithoutResponse: false, write: false, notify: false, indicate: false, authenticatedSignedWrites: false, extendedProperties: false, notifyEncryptionRequired: false, indicateEncryptionRequired: false}
[BLE-Config]   Char: 2aa6, Properties: CharacteristicProperties{broadcast: false, read: true, writeWithoutResponse: false, write: false, notify: false, indicate: false, authenticatedSignedWrites: false, extendedProperties: false, notifyEncryptionRequired: false, indicateEncryptionRequired: false}
[BLE-Config]   Char: 1236, Properties: CharacteristicProperties{broadcast: false, read: false, writeWithoutResponse: false, write: true, notify: false, indicate: false, authenticatedSignedWrites: false, extendedProperties: false, notifyEncryptionRequired: false, indicateEncryptionRequired: false}
[BLE-Config]   Char: 1237, Properties: CharacteristicProperties{broadcast: false, read: true, writeWithoutResponse: false, write: false, notify: true, indicate: false, authenticatedSignedWrites: false, extendedProperties: false, notifyEncryptionRequired: false, indicateEncryptionRequired: false}
[BLE-Config] Write failed both ways: PlatformException(writeCharacteristic, The WRITE_NO_RESPONSE property is not supported by this BLE characteristic, null, null)
[BLE-Config] Write error: PlatformException(writeCharacteristic, data longer than allowed. dataLen: 76 > max: 20 (withResponse, noLongWrite), null, null)
[BLE-Config] PlatformException (PlatformException(writeCharacteristic, data longer than allowed. dataLen: 76 > max: 20 (withResponse, noLongWrite), null, null))