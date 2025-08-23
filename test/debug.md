MCU Debug

16:07:03.500 -> 🚴 Smart Bike Tracker v1.0
16:07:03.500 -> 
16:07:03.500 -> ✅ NVS initialized
16:07:03.500 -> 🔄 Normal boot
16:07:03.500 -> 🔷 BLE Device: BikeTrk_4F8C
16:07:04.029 -> E (1609) phy_init: store_cal_data_to_nvs_handle: store calibration data failed(0x1105)
16:07:04.622 -> 📍 Initial GPS history set: 7 of 29 points (25 bytes)
16:07:04.622 -> ✅ BLE Service started
16:07:04.622 -> 📍 GPS: 14.562940, 121.145820
16:07:04.716 -> LSM6DSL found at address 0x6B
16:07:05.053 -> Reference acceleration: X=0.03, Y=0.00, Z=1.01
16:07:05.053 -> ✅ LSM6DSL ready
16:07:05.053 -> 📡 SIM7070G: On-demand init
16:07:05.053 -> 📡 Ready
16:07:05.053 -> 
16:07:05.053 -> 👤 IR Sensor: User Away
16:08:05.848 -> ✅ BLE Client Connected
16:08:05.848 -> 🟢 BLE Connected - Disabling motion detection
16:08:05.914 -> LSM6DSL set to low power mode
16:08:05.915 -> LSM6DSL set to low power mode
16:08:06.872 -> 📤 Syncing GPS history to app...
16:08:06.872 ->      Reading index 22 -> actual 22: lat_22=14.5592031, lon_22=121.1355057
16:08:06.875 ->      Reading index 23 -> actual 23: lat_23=14.5589151, lon_23=121.1360855
16:08:06.875 ->      Reading index 24 -> actual 24: lat_24=14.5585518, lon_24=121.1363297
16:08:06.875 ->      Reading index 25 -> actual 25: lat_25=14.5577316, lon_25=121.1367264
16:08:06.875 ->      Reading index 26 -> actual 26: lat_26=14.5589085, lon_26=121.1400986
16:08:06.875 ->      Reading index 27 -> actual 27: lat_27=14.5633154, lon_27=121.1447449
16:08:06.898 ->      Reading index 28 -> actual 28: lat_28=14.5629396, lon_28=121.1458206
16:08:06.898 ->    Synced 7 of 29 GPS points (472 bytes) via notification
16:08:07.895 -> 📉 Power optimized
16:08:12.225 -> 📝 Command received: GPS_PAGE:0
16:08:12.225 -> 📄 Sending GPS page 0 of 6 (29 total points)
16:08:12.225 ->      Reading index 0 -> actual 0: lat_0=14.5621777, lon_0=121.1118698
16:08:12.267 ->    Point 0: lat=14.5621777, lon=121.1118698, src=2
16:08:12.267 ->      Reading index 1 -> actual 1: lat_1=14.5619478, lon_1=121.1120682
16:08:12.267 ->    Point 1: lat=14.5619478, lon=121.1120682, src=2
16:08:12.267 ->      Reading index 2 -> actual 2: lat_2=14.5619555, lon_2=121.1119995
16:08:12.267 ->    Point 2: lat=14.5619555, lon=121.1119995, src=2
16:08:12.267 ->      Reading index 3 -> actual 3: lat_3=14.5618715, lon_3=121.1120682
16:08:12.281 ->    Point 3: lat=14.5618715, lon=121.1120682, src=2
16:08:12.281 ->      Reading index 4 -> actual 4: lat_4=14.5624952, lon_4=121.1114578
16:08:12.281 ->    Point 4: lat=14.5624952, lon=121.1114578, src=2
16:08:12.281 ->    Added 5 valid points to page
16:08:12.281 ->    JSON response: page=0, totalPages=6, totalPoints=29, validPoints=5
16:08:12.281 ->    JSON metadata: {"history":[{"lat":14.5621777,"lon":121.1118698,"time":1755812006000,"src":2},{"lat":14.5619478,"lon
16:08:12.324 ->    Sent 402 bytes
16:08:12.724 -> 📝 Command received: GPS_PAGE:1
16:08:12.724 -> 📄 Sending GPS page 1 of 6 (29 total points)
16:08:12.724 ->      Reading index 5 -> actual 5: lat_5=14.5616989, lon_5=121.1121140
16:08:12.724 ->    Point 5: lat=14.5616989, lon=121.1121140, src=2
16:08:12.724 ->      Reading index 6 -> actual 6: lat_6=14.5620346, lon_6=121.1119537
16:08:12.724 ->    Point 6: lat=14.5620346, lon=121.1119537, src=2
16:08:12.728 ->      Reading index 7 -> actual 7: lat_7=14.5617790, lon_7=121.1117325
16:08:12.728 ->    Point 7: lat=14.5617790, lon=121.1117325, src=2
16:08:12.728 ->      Reading index 8 -> actual 8: lat_8=14.5618334, lon_8=121.1117477
16:08:12.728 ->    Point 8: lat=14.5618334, lon=121.1117477, src=2
16:08:12.728 ->      Reading index 9 -> actual 9: lat_9=14.5592070, lon_9=121.1136475
16:08:12.728 ->    Point 9: lat=14.5592070, lon=121.1136475, src=2
16:08:12.728 ->    Added 5 valid points to page
16:08:12.758 ->    JSON response: page=1, totalPages=6, totalPoints=29, validPoints=5
16:08:12.758 ->    JSON metadata: {"history":[{"lat":14.5616989,"lon":121.1121140,"time":1755817267000,"src":2},{"lat":14.5620346,"lon
16:08:12.758 ->    Sent 402 bytes
16:08:13.261 -> 📝 Command received: GPS_PAGE:2
16:08:13.261 -> 📄 Sending GPS page 2 of 6 (29 total points)
16:08:13.261 ->      Reading index 10 -> actual 10: lat_10=14.5549688, lon_10=121.1167831
16:08:13.261 ->    Point 10: lat=14.5549688, lon=121.1167831, src=2
16:08:13.261 ->      Reading index 11 -> actual 11: lat_11=14.5535192, lon_11=121.1177063
16:08:13.293 ->    Point 11: lat=14.5535192, lon=121.1177063, src=2
16:08:13.293 ->      Reading index 12 -> actual 12: lat_12=14.5533657, lon_12=121.1179352
16:08:13.293 ->    Point 12: lat=14.5533657, lon=121.1179352, src=2
16:08:13.293 ->      Reading index 13 -> actual 13: lat_13=14.5526648, lon_13=121.1184006
16:08:13.293 ->    Point 13: lat=14.5526648, lon=121.1184006, src=2
16:08:13.293 ->      Reading index 14 -> actual 14: lat_14=14.5506153, lon_14=121.1197281
16:08:13.339 ->    Point 14: lat=14.5506153, lon=121.1197281, src=2
16:08:13.339 ->    Added 5 valid points to page
16:08:13.339 ->    JSON response: page=2, totalPages=6, totalPoints=29, validPoints=5
16:08:13.339 ->    JSON metadata: {"history":[{"lat":14.5549688,"lon":121.1167831,"time":1755861116000,"src":2},{"lat":14.5535192,"lon
16:08:13.339 ->    Sent 402 bytes
16:08:13.647 -> 📝 Command received: GPS_PAGE:3
16:08:13.707 -> 📄 Sending GPS page 3 of 6 (29 total points)
16:08:13.707 ->      Reading index 15 -> actual 15: lat_15=14.5496979, lon_15=121.1203842
16:08:13.707 ->    Point 15: lat=14.5496979, lon=121.1203842, src=2
16:08:13.707 ->      Reading index 16 -> actual 16: lat_16=14.5497093, lon_16=121.1212463
16:08:13.707 ->    Point 16: lat=14.5497093, lon=121.1212463, src=2
16:08:13.707 ->      Reading index 17 -> actual 17: lat_17=14.5498514, lon_17=121.1212540
16:08:13.707 ->    Point 17: lat=14.5498514, lon=121.1212540, src=2
16:08:13.707 ->      Reading index 18 -> actual 18: lat_18=14.5513029, lon_18=121.1233139
16:08:13.707 ->    Point 18: lat=14.5513029, lon=121.1233139, src=2
16:08:13.707 ->      Reading index 19 -> actual 19: lat_19=14.5539064, lon_19=121.1272354
16:08:13.707 ->    Point 19: lat=14.5539064, lon=121.1272354, src=2
16:08:13.707 ->    Added 5 valid points to page
16:08:13.739 ->    JSON response: page=3, totalPages=6, totalPoints=29, validPoints=5
16:08:13.739 ->    JSON metadata: {"history":[{"lat":14.5496979,"lon":121.1203842,"time":1755861663000,"src":2},{"lat":14.5497093,"lon
16:08:13.739 ->    Sent 402 bytes
16:08:13.930 -> 📝 Command received: GPS_PAGE:4
16:08:13.930 -> 📄 Sending GPS page 4 of 6 (29 total points)
16:08:13.930 ->      Reading index 20 -> actual 20: lat_20=14.5580091, lon_20=121.1321487
16:08:13.930 ->    Point 20: lat=14.5580091, lon=121.1321487, src=2
16:08:13.961 ->      Reading index 21 -> actual 21: lat_21=14.5578022, lon_21=121.1340256
16:08:13.961 ->    Point 21: lat=14.5578022, lon=121.1340256, src=2
16:08:13.961 ->      Reading index 22 -> actual 22: lat_22=14.5592031, lon_22=121.1355057
16:08:13.961 ->    Point 22: lat=14.5592031, lon=121.1355057, src=2
16:08:13.961 ->      Reading index 23 -> actual 23: lat_23=14.5589151, lon_23=121.1360855
16:08:13.961 ->    Point 23: lat=14.5589151, lon=121.1360855, src=2
16:08:13.993 ->      Reading index 24 -> actual 24: lat_24=14.5585518, lon_24=121.1363297
16:08:13.993 ->    Point 24: lat=14.5585518, lon=121.1363297, src=2
16:08:13.993 ->    Added 5 valid points to page
16:08:13.993 ->    JSON response: page=4, totalPages=6, totalPoints=29, validPoints=5
16:08:13.993 ->    JSON metadata: {"history":[{"lat":14.5580091,"lon":121.1321487,"time":1755862191000,"src":2},{"lat":14.5578022,"lon
16:08:14.040 ->    Sent 402 bytes
16:08:14.264 -> 📝 Command received: GPS_PAGE:5
16:08:14.264 -> 📄 Sending GPS page 5 of 6 (29 total points)
16:08:14.264 ->      Reading index 25 -> actual 25: lat_25=14.5577316, lon_25=121.1367264
16:08:14.264 ->    Point 25: lat=14.5577316, lon=121.1367264, src=2
16:08:14.264 ->      Reading index 26 -> actual 26: lat_26=14.5589085, lon_26=121.1400986
16:08:14.264 ->    Point 26: lat=14.5589085, lon=121.1400986, src=2
16:08:14.264 ->      Reading index 27 -> actual 27: lat_27=14.5633154, lon_27=121.1447449
16:08:14.295 ->    Point 27: lat=14.5633154, lon=121.1447449, src=2
16:08:14.295 ->      Reading index 28 -> actual 28: lat_28=14.5629396, lon_28=121.1458206
16:08:14.295 ->    Point 28: lat=14.5629396, lon=121.1458206, src=2
16:08:14.295 ->    Added 4 valid points to page
16:08:14.295 ->    JSON response: page=5, totalPages=6, totalPoints=29, validPoints=4
16:08:14.295 ->    JSON metadata: {"history":[{"lat":14.5577316,"lon":121.1367264,"time":1755862714000,"src":2},{"lat":14.5589085,"lon
16:08:14.341 ->    Sent 336 bytes

Application debug

BLE] Bluetooth adapter state changed: BluetoothAdapterState.on
D/InputMethodManagerUtils(10932): startInputInner - Id : 0
I/InputMethodManager(10932): startInputInner - IInputMethodManagerGlobalInvoker.startInputOrWindowGainedFocus
[HomeScreen] Loaded 0 locations from storage
[BLE] Found saved device: BikeTrk_4F8C (8C:4F:00:AD:01:B2)
D/InputMethodManagerUtils(10932): startInputInner - Id : 0
I/InsetsController(10932): onStateChanged: host=com.example.smart_bike_tracker/com.example.smart_bike_tracker.MainActivity, from=android.view.ViewRootImpl$ViewRootHandler.handleMessageImpl:7211, state=InsetsState: {mDisplayFrame=Rect(0, 0 - 1080, 2408), mDisplayCutout=DisplayCutout{insets=Rect(0, 65 - 0, 0) waterfall=Insets{left=0, top=0, right=0, bottom=0} boundingRect={Bounds=[Rect(0, 0 - 0, 0), Rect(454, 0 - 626, 65), Rect(0, 0 - 0, 0), Rect(0, 0 - 0, 0)]} cutoutPathParserInfo={CutoutPathParserInfo{displayWidth=1080 displayHeight=2408 physicalDisplayWidth=1080 physicalDisplayHeight=2408 density={2.8125} cutoutSpec={M 0,0 H -30.57777777777778 V 23.11111111111111 H 30.57777777777778 V 0 H 0 Z @dp} rotation={0} scale={1.0} physicalPixelDisplaySizeRatio={1.0}}}}, mRoundedCorners=RoundedCorners{[RoundedCorner{position=TopLeft, radius=0, center=Point(0, 0)}, RoundedCorner{position=TopRight, radius=0, center=Point(0, 0)}, RoundedCorner{position=BottomRight, radius=0, center=Point(0, 0)}, RoundedCorner{position=BottomLeft, radius=0, center=Point(0, 0)}]}  mRoundedCornerFrame=Rect(0, 0 - 1080, 2408), mPrivacyIndicatorBounds=PrivacyIndicatorBounds {static bounds=Rect(964, 0 - 1080, 70) rotation=0}, mDisplayShape=DisplayShape{ spec=-311912193 displayWidth=1080 displayHeight=2408 physicalPixelDisplaySizeRatio=1.0 rotation=0 offsetX=0 offsetY=0 scale=1.0}, mSources= { InsetsSource: {3 mType=ime mFrame=[0,0][0,0] mVisible=false mFlags=[]}, InsetsSource: {27 mType=displayCutout mFrame=[0,0][1080,65] mVisible=true mFlags=[]}, InsetsSource: {1bd70000 mType=statusBars mFrame=[0,0][1080,70] mVisible=true mFlags=[]}, InsetsSource: {1bd70005 mType=mandatorySystemGestures mFrame=[0,0][1080,97] mVisible=true mFlags=[]}, InsetsSource: {1bd70006 mType=tappableElement mFrame=[0,0][1080,70] mVisible=true mFlags=[]}, InsetsSource: {35530001 mType=navigationBars mFrame=[0,2282][1080,2408] mVisible=true mFlags=[]}, InsetsSource: {35530004 mType=systemGestures mFrame=[0,0][0,0] mVisible=true mFlags=[]}, InsetsSource: {35530005 mType=mandatorySystemGestures mFrame=[0,2282][1080,2408] mVisible=true mFlags=[]}, InsetsSource: {35530006 mType=tappableElement mFrame=[0,2282][1080,2408] mVisible=true mFlags=[]}, InsetsSource: {35530024 mType=systemGestures mFrame=[0,0][0,0] mVisible=true mFlags=[]} }
I/InsetsSourceConsumer(10932): applyRequestedVisibilityToControl: visible=false, type=ime, host=com.example.smart_bike_tracker/com.example.smart_bike_tracker.MainActivity
[Permissions] Permission Permission.location: PermissionStatus.granted
[Permissions] Permission Permission.bluetoothScan: PermissionStatus.granted
[Permissions] Permission Permission.bluetoothConnect: PermissionStatus.granted
[Permissions] All permissions and services are enabled
[Permissions] All permissions granted
[BLE] Permission Permission.location: PermissionStatus.granted
[BLE] Permission Permission.bluetoothScan: PermissionStatus.granted
[BLE] Permission Permission.bluetoothConnect: PermissionStatus.granted
[BLE] Found saved device: BikeTrk_4F8C (8C:4F:00:AD:01:B2)
[BLE] Attempting auto-connect to BikeTrk_4F8C
[BLE] Starting BLE scan...
2
D/BluetoothAdapter(10932): getBleEnabledArray(): ON
D/BluetoothAdapter(10932): semIsBleEnabled(): ON
D/BluetoothAdapter(10932): getBleEnabledArray(): ON
D/BluetoothLeScanner(10932): Start Scan with callback
D/BluetoothLeScanner(10932): onScannerRegistered() - status=0 scannerId=5 mScannerId=0
[BLE] Scan results received: 0 devices
[BLE] Found 0 visible devices, 0 bike trackers
I/BluetoothAdapter(10932): BluetoothAdapter() : com.example.smart_bike_tracker
[BLE] Scan results received: 1 devices
[BLE] Device found: name="BikeTrk_4F8C", id=8C:4F:00:AD:01:B2, rssi=-69, isBikeTracker=true
[BLE] Found 1 visible devices, 1 bike trackers
[BLE] Scan results received: 2 devices
[BLE] Device found: name="BikeTrk_4F8C", id=8C:4F:00:AD:01:B2, rssi=-69, isBikeTracker=true
[BLE] Device found: name="Unknown (E2:35:B3)", id=17:22:CD:E2:35:B3, rssi=-66, isBikeTracker=false
[BLE] Found 2 visible devices, 1 bike trackers
[BLE] Scan results received: 3 devices
[BLE] Device found: name="BikeTrk_4F8C", id=8C:4F:00:AD:01:B2, rssi=-69, isBikeTracker=true
[BLE] Device found: name="Unknown (E2:35:B3)", id=17:22:CD:E2:35:B3, rssi=-66, isBikeTracker=false
[BLE] Device found: name="Unknown (39:53:51)", id=67:AB:8E:39:53:51, rssi=-88, isBikeTracker=false
[BLE] Found 3 visible devices, 1 bike trackers
[BLE] Found saved device, connecting...
2
D/BluetoothAdapter(10932): getBleEnabledArray(): ON
D/BluetoothLeScanner(10932): Stop Scan with callback
D/BluetoothAdapter(10932): getBleEnabledArray(): ON
D/CompatibilityChangeReporter(10932): Compat change id reported: 265103382; UID 10481; state: ENABLED
D/BluetoothGatt(10932): connect() - device: XX:XX:XX:XX:01:B2, auto: false
D/BluetoothGatt(10932): registerApp()
D/BluetoothGatt(10932): registerApp() - UUID=bbf29ee1-cd3d-4edd-8935-0342b4f16d0f
D/BluetoothGatt(10932): onClientRegistered() - status=0 clientIf=6
D/BluetoothAdapter(10932): getBleEnabledArray(): ON
D/BluetoothGatt(10932): onClientConnectionState() - status=0 clientIf=6 device=XX:XX:XX:XX:01:B2
[HomeScreen] _fetchMcuGpsHistory called. Connection state: BluetoothConnectionState.connected
[HomeScreen] Waiting 2 seconds for MCU to prepare data...
[HomeScreen] Syncing saved configuration to device...
[BLE-Status] Reading device status...
D/BluetoothGatt(10932): onConnectionUpdated() - Device=XX:XX:XX:XX:01:B2 interval=6 latency=0 timeout=500 status=0
D/BluetoothGatt(10932): onConnectionUpdated() - Device=XX:XX:XX:XX:01:B2 interval=36 latency=0 timeout=500 status=0
[LocationMap] Map initialized with center: LatLng(latitude:0.0, longitude:0.0)
[BLE-Config] Starting configuration send...
[BLE-Config] Connected device: BikeTrk_4F8C
[HomeScreen] Calling readAllGPSHistory for paginated data...
[BLE-GPSHistory] Starting to read all GPS history pages
[BLE-GPSPage] Requesting GPS history page 0
D/BluetoothGatt(10932): configureMTU() - device: XX:XX:XX:XX:01:B2 mtu: 512
[Location] Stopping location tracking
[Location] Starting location tracking
D/BluetoothGatt(10932): onConfigureMTU() - Device=XX:XX:XX:XX:01:B2 mtu=512 status=0
[HomeScreen] Location tracking started
[BLE] MTU negotiated: 512 bytes (DLE enabled for packets up to 251 bytes)
[BLE] DLE: Full support confirmed (MTU=512)
E/FlutterGeolocator(10932): Geolocator position updates started
D/BluetoothGatt(10932): discoverServices() - device: XX:XX:XX:XX:01:B2
D/BluetoothGatt(10932): onSearchComplete() = Device=XX:XX:XX:XX:01:B2 Status=0
D/BluetoothGatt(10932): discoverServices() - device: XX:XX:XX:XX:01:B2
D/BluetoothGatt(10932): onSearchComplete() = Device=XX:XX:XX:XX:01:B2 Status=0
D/BluetoothGatt(10932): discoverServices() - device: XX:XX:XX:XX:01:B2
D/BluetoothGatt(10932): onSearchComplete() = Device=XX:XX:XX:XX:01:B2 Status=0
D/BluetoothGatt(10932): discoverServices() - device: XX:XX:XX:XX:01:B2
D/BluetoothGatt(10932): onSearchComplete() = Device=XX:XX:XX:XX:01:B2 Status=0
2
D/BluetoothGatt(10932): setCharacteristicNotification() - uuid: 00002a05-0000-1000-8000-00805f9b34fb enable: true
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
[BLE-Config] Current MTU: 512
[BLE-Config] Full DLE support detected, using standard format
[BLE-Config] Sending config JSON: {"phone_number":"+639811932238","update_interval":60,"alert_enabled":true}
[BLE-Config] JSON length: 74 bytes
D/BluetoothGatt(10932): setCharacteristicNotification() - uuid: 00002a05-0000-1000-8000-00805f9b34fb enable: true
[BLE-Config]   Char: 2a05, Properties: CharacteristicProperties{broadcast: false, read: false, writeWithoutResponse: false, write: false, notify: false, indicate: true, authenticatedSignedWrites: false, extendedProperties: false, notifyEncryptionRequired: false, indicateEncryptionRequired: false}
[BLE-Config]   Char: 2a00, Properties: CharacteristicProperties{broadcast: false, read: true, writeWithoutResponse: false, write: false, notify: false, indicate: false, authenticatedSignedWrites: false, extendedProperties: false, notifyEncryptionRequired: false, indicateEncryptionRequired: false}
[BLE-Config]   Char: 2a01, Properties: CharacteristicProperties{broadcast: false, read: true, writeWithoutResponse: false, write: false, notify: false, indicate: false, authenticatedSignedWrites: false, extendedProperties: false, notifyEncryptionRequired: false, indicateEncryptionRequired: false}
[BLE-Config]   Char: 2aa6, Properties: CharacteristicProperties{broadcast: false, read: true, writeWithoutResponse: false, write: false, notify: false, indicate: false, authenticatedSignedWrites: false, extendedProperties: false, notifyEncryptionRequired: false, indicateEncryptionRequired: false}
[BLE-Config]   Char: 1236, Properties: CharacteristicProperties{broadcast: false, read: false, writeWithoutResponse: false, write: true, notify: false, indicate: false, authenticatedSignedWrites: false, extendedProperties: false, notifyEncryptionRequired: false, indicateEncryptionRequired: false}
[BLE-Config]   Char: 1237, Properties: CharacteristicProperties{broadcast: false, read: true, writeWithoutResponse: false, write: false, notify: true, indicate: false, authenticatedSignedWrites: false, extendedProperties: false, notifyEncryptionRequired: false, indicateEncryptionRequired: false}
[BLE-Config]   Char: 1239, Properties: CharacteristicProperties{broadcast: false, read: true, writeWithoutResponse: false, write: false, notify: true, indicate: false, authenticatedSignedWrites: false, extendedProperties: false, notifyEncryptionRequired: false, indicateEncryptionRequired: false}
[BLE-Config]   Char: 1238, Properties: CharacteristicProperties{broadcast: false, read: false, writeWithoutResponse: false, write: true, notify: false, indicate: false, authenticatedSignedWrites: false, extendedProperties: false, notifyEncryptionRequired: false, indicateEncryptionRequired: false}
D/BluetoothGatt(10932): setCharacteristicNotification() - uuid: 00002a05-0000-1000-8000-00805f9b34fb enable: true
[BLE-GPSPage] Found history characteristic
[BLE-GPSPage] Found command characteristic
[BLE] Found service: 1801
[BLE] Found service: 1800
[BLE] Found service: 1234
[BLE-Status] Subscribing to status updates...
[HomeScreen] Status update: user=false, mode=AWAY
[BLE-Status] Status read: {"ble":true,"phone_configured":false,"phone":"","interval":600,"alerts":true,"user_present":false,"mode":"AWAY","gps_valid":true,"lat":"14.562940","lon":"121.145820"}
[BLE-Config] Configuration sent successfully!
[HomeScreen] Configuration synced successfully
D/BluetoothGatt(10932): setCharacteristicNotification() - uuid: 00001239-0000-1000-8000-00805f9b34fb enable: true
D/BluetoothGatt(10932): discoverServices() - device: XX:XX:XX:XX:01:B2
[BLE-GPSPage] Subscribed to history notifications
[BLE-GPSPage] Received empty notification
D/BluetoothGatt(10932): onSearchComplete() = Device=XX:XX:XX:XX:01:B2 Status=0
[BLE-Status] Found bike tracker service for status
[BLE-Status] Found status characteristic!
[BLE-GPSPage] Sent command: GPS_PAGE:0
[BLE-GPSPage] Received page data via notification: 402 bytes
[BLE-GPSPage] Received data for page 0: totalPages=6, totalPoints=29
[BLE-GPSHistory] Page 0: totalPages=6, totalPoints=29
[BLE-GPSHistory] First GPS point from page 0: lat=14.5621777, lon=121.1118698
[BLE-GPSHistory] Added 5 points from page 0
[BLE-GPSPage] Requesting GPS history page 1
D/BluetoothGatt(10932): setCharacteristicNotification() - uuid: 00001237-0000-1000-8000-00805f9b34fb enable: true
D/BluetoothGatt(10932): discoverServices() - device: XX:XX:XX:XX:01:B2
[BLE-Status] Subscribed to status notifications
[BLE-Status] Reading device status...
D/BluetoothGatt(10932): onSearchComplete() = Device=XX:XX:XX:XX:01:B2 Status=0
[BLE-GPSPage] Found history characteristic
[BLE-GPSPage] Found command characteristic
D/BluetoothGatt(10932): discoverServices() - device: XX:XX:XX:XX:01:B2
[BLE-GPSPage] Received page data via notification: 402 bytes
D/BluetoothGatt(10932): onSearchComplete() = Device=XX:XX:XX:XX:01:B2 Status=0
[BLE-GPSPage] Sent command: GPS_PAGE:1
[BLE-Status] IR Status: user_present=false
[HomeScreen] Status update: user=false, mode=AWAY
[BLE-GPSPage] Received page data via notification: 402 bytes
[BLE-GPSPage] Received data for page 1: totalPages=6, totalPoints=29
[BLE-GPSHistory] Page 1: totalPages=6, totalPoints=29
[BLE-GPSHistory] Added 5 points from page 1
2
[HomeScreen] Status update: user=false, mode=AWAY
[BLE-Status] Status read: {"ble":true,"phone_configured":true,"phone":"+639811932238","interval":60,"alerts":true,"user_present":false,"mode":"AWAY","gps_valid":true,"lat":"14.562940","lon":"121.145820"}
[BLE-Status] IR Status: user_present=false
[HomeScreen] Status update: user=false, mode=AWAY
[BLE-GPSPage] Requesting GPS history page 2
D/BluetoothGatt(10932): discoverServices() - device: XX:XX:XX:XX:01:B2
D/BluetoothGatt(10932): onSearchComplete() = Device=XX:XX:XX:XX:01:B2 Status=0
[BLE] Saved device for auto-connect: BikeTrk_4F8C (8C:4F:00:AD:01:B2)
[BLE] Connected to BikeTrk_4F8C
[BLE-GPSPage] Found history characteristic
[BLE-GPSPage] Found command characteristic
[BLE-GPSPage] Received page data via notification: 402 bytes
[BLE-GPSPage] Sent command: GPS_PAGE:2
[BLE-GPSPage] Received page data via notification: 402 bytes
[BLE-GPSPage] Received data for page 2: totalPages=6, totalPoints=29
[BLE-GPSHistory] Page 2: totalPages=6, totalPoints=29
[BLE-GPSHistory] Added 5 points from page 2
D/BluetoothGatt(10932): discoverServices() - device: XX:XX:XX:XX:01:B2
[BLE-GPSPage] Requesting GPS history page 3
D/BluetoothGatt(10932): onSearchComplete() = Device=XX:XX:XX:XX:01:B2 Status=0
[BLE-GPSPage] Found history characteristic
[BLE-GPSPage] Found command characteristic
[BLE-GPSPage] Received page data via notification: 402 bytes
[BLE-GPSPage] Sent command: GPS_PAGE:3
[BLE-GPSPage] Received page data via notification: 402 bytes
[BLE-GPSPage] Received data for page 3: totalPages=6, totalPoints=29
[BLE-GPSHistory] Page 3: totalPages=6, totalPoints=29
[BLE-GPSHistory] Added 5 points from page 3
D/BluetoothGatt(10932): discoverServices() - device: XX:XX:XX:XX:01:B2
[BLE-GPSPage] Requesting GPS history page 4
D/BluetoothGatt(10932): onSearchComplete() = Device=XX:XX:XX:XX:01:B2 Status=0
[BLE-GPSPage] Found history characteristic
[BLE-GPSPage] Found command characteristic
[BLE-GPSPage] Received page data via notification: 402 bytes
[BLE-GPSPage] Sent command: GPS_PAGE:4
[BLE-GPSPage] Received page data via notification: 402 bytes
[BLE-GPSPage] Received data for page 4: totalPages=6, totalPoints=29
[BLE-GPSHistory] Page 4: totalPages=6, totalPoints=29
[BLE-GPSHistory] Added 5 points from page 4
[BLE-GPSPage] Requesting GPS history page 5
D/BluetoothGatt(10932): discoverServices() - device: XX:XX:XX:XX:01:B2
D/BluetoothGatt(10932): onSearchComplete() = Device=XX:XX:XX:XX:01:B2 Status=0
[BLE-GPSPage] Found history characteristic
[BLE-GPSPage] Found command characteristic
[BLE-GPSPage] Received page data via notification: 402 bytes
[BLE-GPSPage] Sent command: GPS_PAGE:5
[BLE-GPSPage] Received page data via notification: 336 bytes
[BLE-GPSPage] Received data for page 5: totalPages=6, totalPoints=29
[BLE-GPSHistory] Page 5: totalPages=6, totalPoints=29
[BLE-GPSHistory] Added 4 points from page 5
[BLE-GPSHistory] Retrieved 29 total GPS points across 6 pages
[HomeScreen] readAllGPSHistory returned: 29 points
[HomeScreen] Setting MCU GPS history with 29 points
[HomeScreen] First point: {lat: 14.5621777, lon: 121.1118698, time: 1755812006000, src: 2}
[HomeScreen] State updated. _mcuGpsHistory now has 29 points (reversed for display)
[HomeScreen] Saving GPS history locally before clearing MCU...
[HomeScreen] GPS history updated via notification: 29 points (reversed for display)
D/BluetoothGatt(10932): discoverServices() - device: XX:XX:XX:XX:01:B2
[HomeScreen] Saved 29 GPS points to local storage
[HomeScreen] Clearing MCU GPS history to free NVS space...
D/BluetoothGatt(10932): onSearchComplete() = Device=XX:XX:XX:XX:01:B2 Status=0
[BLE-ClearHistory] Command characteristic not found
[HomeScreen] Failed to clear MCU GPS history
[BLE-Status] IR Status: user_present=false
[HomeScreen] Status update: user=false, mode=AWAY
E/FlutterGeolocator(10932): Geolocator position updates stopped
E/FlutterGeolocator(10932): There is still another flutter engine connected, not stopping location service
[Location] Location error: TimeoutException after 0:00:10.000000: Time limit reached while waiting for position update.
[Location] TimeoutException (TimeoutException after 0:00:10.000000: Time limit reached while waiting for position update.)
[BLE-Status] IR Status: user_present=false
[HomeScreen] Status update: user=false, mode=AWAY
[BLE-Status] IR Status: user_present=false
[HomeScreen] Status update: user=false, mode=AWAY
[BLE-Status] IR Status: user_present=false
[HomeScreen] Status update: user=false, mode=AWAY