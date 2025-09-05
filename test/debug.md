MCU DEBUG PRINT

12:56:59.077 -> 
12:56:59.077 -> ========================================
12:56:59.110 -> 🚀 MCU STARTUP
12:56:59.110 -> ⏰ Wake reason: NORMAL BOOT (power on/reset)
12:56:59.110 -> ========================================
12:56:59.110 -> 
12:56:59.873 -> LSM6DSL found at address 0x6B
12:57:00.198 -> Reference acceleration: X=0.05, Y=0.02, Z=1.01
12:57:00.198 -> Motion threshold set to 1.00g (register: 0x20)
12:57:02.171 -> 📡 Initializing SIM7070G module...
12:57:02.206 -> ✅ SIM7070G module detected
12:57:02.799 ->      Reading index 0 -> actual 0: lat_0=14.5629663, lon_0=121.1458511
12:57:02.799 ->      Reading index 1 -> actual 1: lat_1=14.5630541, lon_1=121.1457520
12:57:03.241 -> ✅ SIM7070G initialization complete
12:57:03.283 -> 📡 Disabling RF (AT+CFUN=0)...
12:57:03.658 -> ✅ RF disabled - minimum power mode
12:57:04.652 -> LSM6DSL set to low power mode
12:57:10.849 ->      Reading index 0 -> actual 0: lat_0=14.5629663, lon_0=121.1458511
12:57:10.901 ->    Point 0: lat=14.5629663, lon=121.1458511, src=2
12:57:10.901 ->      Reading index 1 -> actual 1: lat_1=14.5630541, lon_1=121.1457520
12:57:10.901 ->    Point 1: lat=14.5630541, lon=121.1457520, src=2
12:57:10.901 ->    Added 2 valid points to page
12:57:10.901 ->    JSON response: page=0, totalPages=1, totalPoints=2, validPoints=2

Application Debug Print

BLE] Bluetooth adapter state changed: BluetoothAdapterState.on
I/ViewRootImpl@ee46c63[MainActivity](18883): handleWindowFocusChanged: 1 0 call from android.view.ViewRootImpl.-$$Nest$mhandleWindowFocusChanged:0
D/ViewRootImpl@ee46c63[MainActivity](18883): mThreadedRenderer.initializeIfNeeded()#2 mSurface={isValid=true 0xe1d11c00}
D/InputMethodManagerUtils(18883): startInputInner - Id : 0
I/InputMethodManager(18883): startInputInner - IInputMethodManagerGlobalInvoker.startInputOrWindowGainedFocus
D/InputMethodManagerUtils(18883): startInputInner - Id : 0
[HomeScreen] Loaded 284 locations from storage
[HomeScreen] Loaded 2 GPS points from backup (saved: 2025-09-05T12:46:48.583473)
[BLE] Found saved device: BikeTrk_4F8C (8C:4F:00:AD:01:B2)
I/InsetsController(18883): onStateChanged: host=com.example.smart_bike_tracker/com.example.smart_bike_tracker.MainActivity, from=android.view.ViewRootImpl$ViewRootHandler.handleMessageImpl:7211, state=InsetsState: {mDisplayFrame=Rect(0, 0 - 1080, 2408), mDisplayCutout=DisplayCutout{insets=Rect(0, 65 - 0, 0) waterfall=Insets{left=0, top=0, right=0, bottom=0} boundingRect={Bounds=[Rect(0, 0 - 0, 0), Rect(454, 0 - 626, 65), Rect(0, 0 - 0, 0), Rect(0, 0 - 0, 0)]} cutoutPathParserInfo={CutoutPathParserInfo{displayWidth=1080 displayHeight=2408 physicalDisplayWidth=1080 physicalDisplayHeight=2408 density={2.8125} cutoutSpec={M 0,0 H -30.57777777777778 V 23.11111111111111 H 30.57777777777778 V 0 H 0 Z @dp} rotation={0} scale={1.0} physicalPixelDisplaySizeRatio={1.0}}}}, mRoundedCorners=RoundedCorners{[RoundedCorner{position=TopLeft, radius=0, center=Point(0, 0)}, RoundedCorner{position=TopRight, radius=0, center=Point(0, 0)}, RoundedCorner{position=BottomRight, radius=0, center=Point(0, 0)}, RoundedCorner{position=BottomLeft, radius=0, center=Point(0, 0)}]}  mRoundedCornerFrame=Rect(0, 0 - 1080, 2408), mPrivacyIndicatorBounds=PrivacyIndicatorBounds {static bounds=Rect(964, 0 - 1080, 70) rotation=0}, mDisplayShape=DisplayShape{ spec=-311912193 displayWidth=1080 displayHeight=2408 physicalPixelDisplaySizeRatio=1.0 rotation=0 offsetX=0 offsetY=0 scale=1.0}, mSources= { InsetsSource: {ed8a0000 mType=statusBars mFrame=[0,0][1080,70] mVisible=true mFlags=[]}, InsetsSource: {ed8a0005 mType=mandatorySystemGestures mFrame=[0,0][1080,97] mVisible=true mFlags=[]}, InsetsSource: {ed8a0006 mType=tappableElement mFrame=[0,0][1080,70] mVisible=true mFlags=[]}, InsetsSource: {3 mType=ime mFrame=[0,0][0,0] mVisible=false mFlags=[]}, InsetsSource: {27 mType=displayCutout mFrame=[0,0][1080,65] mVisible=true mFlags=[]}, InsetsSource: {208c0001 mType=navigationBars mFrame=[0,2282][1080,2408] mVisible=true mFlags=[]}, InsetsSource: {208c0004 mType=systemGestures mFrame=[0,0][0,0] mVisible=true mFlags=[]}, InsetsSource: {208c0005 mType=mandatorySystemGestures mFrame=[0,2282][1080,2408] mVisible=true mFlags=[]}, InsetsSource: {208c0006 mType=tappableElement mFrame=[0,2282][1080,2408] mVisible=true mFlags=[]}, InsetsSource: {208c0024 mType=systemGestures mFrame=[0,0][0,0] mVisible=true mFlags=[]} }
I/InsetsSourceConsumer(18883): applyRequestedVisibilityToControl: visible=false, type=ime, host=com.example.smart_bike_tracker/com.example.smart_bike_tracker.MainActivity
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
2
D/BluetoothAdapter(18883): getBleEnabledArray(): ON
D/BluetoothAdapter(18883): semIsBleEnabled(): ON
D/BluetoothAdapter(18883): getBleEnabledArray(): ON
D/BluetoothLeScanner(18883): Start Scan with callback
D/BluetoothLeScanner(18883): onScannerRegistered() - status=0 scannerId=2 mScannerId=0
[BLE] Starting BLE scan...
I/BluetoothAdapter(18883): BluetoothAdapter() : com.example.smart_bike_tracker
[BLE] Scan results received: 0 devices
[BLE] Found 0 visible devices, 0 bike trackers
[BLE] Scan results received: 1 devices
[BLE] Device found: name="Unknown (62:F4:8C)", id=4B:F5:C8:62:F4:8C, rssi=-69, isBikeTracker=false
[BLE] Found 1 visible devices, 0 bike trackers
[BLE] Scan results received: 2 devices
[BLE] Device found: name="Unknown (62:F4:8C)", id=4B:F5:C8:62:F4:8C, rssi=-69, isBikeTracker=false
[BLE] Device found: name="Unknown (3C:76:75)", id=13:9E:FF:3C:76:75, rssi=-62, isBikeTracker=false
[BLE] Found 2 visible devices, 0 bike trackers
[BLE] Scan results received: 3 devices
[BLE] Device found: name="Unknown (62:F4:8C)", id=4B:F5:C8:62:F4:8C, rssi=-69, isBikeTracker=false
[BLE] Device found: name="Unknown (3C:76:75)", id=13:9E:FF:3C:76:75, rssi=-62, isBikeTracker=false
[BLE] Device found: name="Unknown (FC:4A:D5)", id=15:D3:51:FC:4A:D5, rssi=-87, isBikeTracker=false
[BLE] Found 3 visible devices, 0 bike trackers
[BLE] Scan results received: 4 devices
[BLE] Device found: name="Unknown (62:F4:8C)", id=4B:F5:C8:62:F4:8C, rssi=-69, isBikeTracker=false
[BLE] Device found: name="Unknown (3C:76:75)", id=13:9E:FF:3C:76:75, rssi=-62, isBikeTracker=false
[BLE] Device found: name="Unknown (FC:4A:D5)", id=15:D3:51:FC:4A:D5, rssi=-87, isBikeTracker=false
[BLE] Device found: name="BikeTrk_4F8C", id=8C:4F:00:AD:01:B2, rssi=-73, isBikeTracker=true
[BLE] Found 4 visible devices, 1 bike trackers
[BLE] Found saved device, connecting...
2
D/BluetoothAdapter(18883): getBleEnabledArray(): ON
D/BluetoothLeScanner(18883): Stop Scan with callback
D/BluetoothAdapter(18883): getBleEnabledArray(): ON
D/CompatibilityChangeReporter(18883): Compat change id reported: 265103382; UID 10501; state: ENABLED
D/BluetoothGatt(18883): connect() - device: XX:XX:XX:XX:01:B2, auto: false
D/BluetoothGatt(18883): registerApp()
D/BluetoothGatt(18883): registerApp() - UUID=24e0124f-a143-493b-9595-28ae665b4303
D/BluetoothGatt(18883): onClientRegistered() - status=0 clientIf=6
D/BluetoothAdapter(18883): getBleEnabledArray(): ON
D/BluetoothGatt(18883): onClientConnectionState() - status=0 clientIf=6 device=XX:XX:XX:XX:01:B2
[HomeScreen] _fetchMcuGpsHistory called. Connection state: BluetoothConnectionState.connected
[HomeScreen] Waiting 2 seconds for MCU to prepare data...
[HomeScreen] Syncing saved configuration to device...
[BLE-Status] Reading device status...
D/BluetoothGatt(18883): onConnectionUpdated() - Device=XX:XX:XX:XX:01:B2 interval=6 latency=0 timeout=500 status=0
D/BluetoothGatt(18883): onConnectionUpdated() - Device=XX:XX:XX:XX:01:B2 interval=36 latency=0 timeout=500 status=0
[LocationMap] Map initialized with center: LatLng(latitude:14.56287, longitude:121.145908)
[LocationMap] Trail points: 248
[BLE-Config] Starting configuration send...
[BLE-Config] Connected device: BikeTrk_4F8C
[HomeScreen] Calling readAllGPSHistory for paginated data...
[BLE-GPSHistory] Starting to read all GPS history pages
[BLE-GPSPage] Requesting GPS history page 0
D/BluetoothGatt(18883): configureMTU() - device: XX:XX:XX:XX:01:B2 mtu: 512
[LocationMap] Trail points: 248
D/BluetoothGatt(18883): onConfigureMTU() - Device=XX:XX:XX:XX:01:B2 mtu=512 status=0
I/Choreographer(18883): Skipped 62 frames!  The application may be doing too much work on its main thread.
[Location] Stopping location tracking
D/BluetoothGatt(18883): discoverServices() - device: XX:XX:XX:XX:01:B2
[Location] Starting location tracking
[BLE] MTU negotiated: 512 bytes (DLE enabled for packets up to 251 bytes)
[BLE] DLE: Full support confirmed (MTU=512)
D/BluetoothGatt(18883): onSearchComplete() = Device=XX:XX:XX:XX:01:B2 Status=0
[Location] Using last known position (201s old)
[HomeScreen] Location tracking started
[LocationMap] Auto-centered map to new location
[LocationMap] Trail points: 249
E/FlutterGeolocator(18883): Geolocator position updates started
[LocationStorage] Saved 285 locations to storage
D/BluetoothGatt(18883): discoverServices() - device: XX:XX:XX:XX:01:B2
D/BluetoothGatt(18883): onSearchComplete() = Device=XX:XX:XX:XX:01:B2 Status=0
D/BluetoothGatt(18883): discoverServices() - device: XX:XX:XX:XX:01:B2
D/BluetoothGatt(18883): onSearchComplete() = Device=XX:XX:XX:XX:01:B2 Status=0
D/BluetoothGatt(18883): discoverServices() - device: XX:XX:XX:XX:01:B2
D/BluetoothGatt(18883): onSearchComplete() = Device=XX:XX:XX:XX:01:B2 Status=0
2
D/BluetoothGatt(18883): setCharacteristicNotification() - uuid: 00002a05-0000-1000-8000-00805f9b34fb enable: true
[BLE-Config] Discovered 3 services
[BLE-Config] Service: 1801
[BLE-Config] Service: 1800
[BLE-Config] Service: 1234
D/BluetoothGatt(18883): setCharacteristicNotification() - uuid: 00002a05-0000-1000-8000-00805f9b34fb enable: true
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
[BLE-Config]   Char: 2a05, Properties: CharacteristicProperties{broadcast: false, read: false, writeWithoutResponse: false, write: false, notify: false, indicate: true, authenticatedSignedWrites: false, extendedProperties: false, notifyEncryptionRequired: false, indicateEncryptionRequired: false}
[BLE-Config]   Char: 2a00, Properties: CharacteristicProperties{broadcast: false, read: true, writeWithoutResponse: false, write: false, notify: false, indicate: false, authenticatedSignedWrites: false, extendedProperties: false, notifyEncryptionRequired: false, indicateEncryptionRequired: false}
[BLE-Config]   Char: 2a01, Properties: CharacteristicProperties{broadcast: false, read: true, writeWithoutResponse: false, write: false, notify: false, indicate: false, authenticatedSignedWrites: false, extendedProperties: false, notifyEncryptionRequired: false, indicateEncryptionRequired: false}
[BLE-Config]   Char: 2aa6, Properties: CharacteristicProperties{broadcast: false, read: true, writeWithoutResponse: false, write: false, notify: false, indicate: false, authenticatedSignedWrites: false, extendedProperties: false, notifyEncryptionRequired: false, indicateEncryptionRequired: false}
[BLE-Config]   Char: 1236, Properties: CharacteristicProperties{broadcast: false, read: false, writeWithoutResponse: false, write: true, notify: false, indicate: false, authenticatedSignedWrites: false, extendedProperties: false, notifyEncryptionRequired: false, indicateEncryptionRequired: false}
[BLE-GPSPage] Found history characteristic
[BLE-GPSPage] Found command characteristic
[BLE-Config]   Char: 1237, Properties: CharacteristicProperties{broadcast: false, read: true, writeWithoutResponse: false, write: false, notify: true, indicate: false, authenticatedSignedWrites: false, extendedProperties: false, notifyEncryptionRequired: false, indicateEncryptionRequired: false}
D/BluetoothGatt(18883): setCharacteristicNotification() - uuid: 00002a05-0000-1000-8000-00805f9b34fb enable: true
[BLE-Config]   Char: 1239, Properties: CharacteristicProperties{broadcast: false, read: true, writeWithoutResponse: false, write: false, notify: true, indicate: false, authenticatedSignedWrites: false, extendedProperties: false, notifyEncryptionRequired: false, indicateEncryptionRequired: false}
[BLE-Config]   Char: 1238, Properties: CharacteristicProperties{broadcast: false, read: false, writeWithoutResponse: false, write: true, notify: false, indicate: false, authenticatedSignedWrites: false, extendedProperties: false, notifyEncryptionRequired: false, indicateEncryptionRequired: false}
[BLE] Found service: 1801
[BLE] Found service: 1800
[BLE] Found service: 1234
[BLE-Status] Subscribing to status updates...
[HomeScreen] Status update: user=false, mode=DISCONNECTED
[BLE-Status] Status read: {"ble":true,"phone_configured":true,"phone":"+639811932238","interval":60,"alerts":true,"user_present":false,"mode":"DISCONNECTED","gps_valid":true,"lat":"14.563054","lon":"121.145749"}
[LocationMap] Trail points: 249
[BLE-Config] Configuration sent successfully!
[HomeScreen] Configuration synced successfully
D/BluetoothGatt(18883): setCharacteristicNotification() - uuid: 00001239-0000-1000-8000-00805f9b34fb enable: true
[BLE-GPSPage] Subscribed to history notifications
[BLE-GPSPage] Received empty notification
D/BluetoothGatt(18883): discoverServices() - device: XX:XX:XX:XX:01:B2
D/BluetoothGatt(18883): onSearchComplete() = Device=XX:XX:XX:XX:01:B2 Status=0
[Location] Location update: 14.563004, 121.145901
[BLE-Status] Found bike tracker service for status
[BLE-Status] Found status characteristic!
[LocationMap] Auto-centered map to new location
[LocationMap] Trail points: 250
[LocationStorage] Saved 286 locations to storage
[BLE-GPSPage] Sent command: GPS_PAGE:0
[BLE-GPSPage] Received page data via notification: 227 bytes
[BLE-GPSPage] Received data for page 0: totalPages=1, totalPoints=2
[BLE-GPSHistory] Page 0: totalPages=1, totalPoints=2
[BLE-GPSHistory] First GPS point from page 0: lat=14.5629663, lon=121.1458511
[BLE-GPSHistory] Added 2 points from page 0
[BLE-GPSHistory] Retrieved 2 total GPS points across 1 pages
[HomeScreen] readAllGPSHistory returned: 2 points
[HomeScreen] Received 2 points from MCU
[HomeScreen] First point: {lat: 14.5629663, lon: 121.1458511, speed: 0.0, time: 1757045934000, src: 2}
[HomeScreen] Merged history: 2 saved + 2 new = 2 unique points
[HomeScreen] After merge: _mcuGpsHistory has 2 points
[HomeScreen] Only 2 points received, not clearing MCU (threshold: 25)
[HomeScreen] GPS history updated via notification: 2 points (reversed for display)
D/BluetoothGatt(18883): setCharacteristicNotification() - uuid: 00001237-0000-1000-8000-00805f9b34fb enable: true
[LocationMap] Trail points: 250
[HomeScreen] Saved 2 GPS points to local storage
[BLE-Status] Subscribed to status notifications
[BLE-Status] Reading device status...
D/BluetoothGatt(18883): discoverServices() - device: XX:XX:XX:XX:01:B2
D/BluetoothGatt(18883): onSearchComplete() = Device=XX:XX:XX:XX:01:B2 Status=0
[BLE-Status] IR Status: user_present=false
3
[HomeScreen] Status update: user=false, mode=DISCONNECTED
[BLE-Status] Status read: {"ble":true,"phone_configured":true,"phone":"+639811932238","interval":60,"alerts":true,"user_present":false,"mode":"DISCONNECTED","gps_valid":true,"lat":"14.563054","lon":"121.145749"}
[BLE] Saved device for auto-connect: BikeTrk_4F8C (8C:4F:00:AD:01:B2)
[BLE] Connected to BikeTrk_4F8C
[LocationMap] Trail points: 250
[BLE-Status] IR Status: user_present=false
[HomeScreen] Status update: user=false, mode=DISCONNECTED
[LocationMap] Trail points: 250
[Location] Location update: 14.563057, 121.145933
[LocationMap] Auto-centered map to new location
[LocationMap] Trail points: 251
[LocationStorage] Saved 287 locations to storage
[LocationMap] Trail points: 251
[BLE-Status] IR Status: user_present=false
[HomeScreen] Status update: user=false, mode=DISCONNECTED
[LocationMap] Trail points: 251
[Location] Location update: 14.563013, 121.145897
[LocationStorage] Saved 288 locations to storage
[LocationMap] Auto-centered map to new location
[LocationMap] Trail points: 252
[BLE-Status] IR Status: user_present=false
[HomeScreen] Status update: user=false, mode=DISCONNECTED
[LocationMap] Trail points: 252
[BLE-Status] IR Status: user_present=false
[HomeScreen] Status update: user=false, mode=DISCONNECTED
[LocationMap] Trail points: 252
[BLE-Status] IR Status: user_present=false
[HomeScreen] Status update: user=false, mode=DISCONNECTED
[LocationMap] Trail points: 252
[BLE-Status] IR Status: user_present=false
[HomeScreen] Status update: user=false, mode=DISCONNECTED
[LocationMap] Trail points: 252
[BLE-Status] IR Status: user_present=false
[HomeScreen] Status update: user=false, mode=DISCONNECTED
[LocationMap] Trail points: 252
[BLE-Status] IR Status: user_present=false
[HomeScreen] Status update: user=false, mode=DISCONNECTED
[LocationMap] Trail points: 252
[BLE-Status] IR Status: user_present=false
[HomeScreen] Status update: user=false, mode=DISCONNECTED
[LocationMap] Trail points: 252
[BLE-Status] IR Status: user_present=false
[HomeScreen] Status update: user=false, mode=DISCONNECTED
[LocationMap] Trail points: 252
[BLE-Status] IR Status: user_present=false
[HomeScreen] Status update: user=false, mode=DISCONNECTED
[LocationMap] Trail points: 252