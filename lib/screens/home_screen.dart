import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import '../services/bluetooth_service.dart' as bike_ble;
import '../services/location_service.dart';
import '../services/location_storage_service.dart';
import '../models/bike_device.dart';
import '../models/location_data.dart';
import '../widgets/location_map.dart';
import '../widgets/device_status_card.dart';
import '../widgets/map_download_dialog.dart';
import '../utils/ui_helpers.dart';
import '../utils/permission_helper.dart';
import '../constants/app_constants.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final bike_ble.BikeBluetoothService _bleService = bike_ble.BikeBluetoothService();
  final LocationService _locationService = LocationService();
  final LocationStorageService _storageService = LocationStorageService();
  
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  bool _isScanning = false;
  bool _isAutoConnecting = false;
  List<BikeDevice> _availableDevices = [];
  String? _connectingDeviceId;
  Map<String, String>? _savedDevice;
  bool _autoConnectEnabled = true;
  
  // Location tracking
  List<LocationData> _locationHistory = [];
  bool _isTrackingLocation = false;
  LocationData? _currentLocation;
  
  // Tracker GPS History
  List<Map<String, dynamic>> _mcuGpsHistory = [];
  bool _isLoadingMcuHistory = false;
  
  // Device status tracking
  Map<String, dynamic>? _currentDeviceStatus;
  
  // Selected location for map navigation
  LatLng? _selectedMapLocation;
  
  // Clicked GPS history locations that should be shown on map
  final Set<LatLng> _clickedPhoneLocations = {};
  final Set<LatLng> _clickedMcuLocations = {};
  
  // Tab controller for map/list/mcu view
  late TabController _tabController;
  
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _locationSubscription;
  StreamSubscription? _bluetoothStateSubscription;
  StreamSubscription? _gpsHistorySubscription;
  
  BluetoothAdapterState _bluetoothState = BluetoothAdapterState.unknown;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to show/hide clear button
    });
    _initializeApp();
  }
  
  Future<void> _initializeApp() async {
    // Initialize Bluetooth monitoring
    _bleService.initializeBluetoothMonitoring();
    
    // Get initial Bluetooth state
    _bluetoothState = await _bleService.getCurrentBluetoothState();
    
    _setupListeners();
    await _loadLocationHistory();
    
    // Load saved GPS history from backup
    await _loadGpsHistoryBackup();
    
    // Check if Bluetooth is off and prompt user
    if (_bluetoothState == BluetoothAdapterState.off) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showBluetoothOffDialog();
      });
    } else {
      await _initializeAndAutoConnect();
    }
  }
  
  Future<void> _loadLocationHistory() async {
    final history = await _storageService.loadLocationHistory();
    setState(() {
      _locationHistory = history;
    });
    developer.log('Loaded ${history.length} locations from storage', name: 'HomeScreen');
  }
  
  Future<void> _saveGpsHistoryLocally(List<Map<String, dynamic>> history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Convert history to JSON string
      final historyJson = json.encode(history);
      await prefs.setString('mcu_gps_history_backup', historyJson);
      await prefs.setString('mcu_gps_history_backup_date', DateTime.now().toIso8601String());
      developer.log('Saved ${history.length} GPS points to local storage', name: 'HomeScreen');
    } catch (e) {
      developer.log('Error saving GPS history locally: $e', name: 'HomeScreen', error: e);
    }
  }
  
  Future<void> _loadGpsHistoryBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('mcu_gps_history_backup');
      
      if (historyJson != null && historyJson.isNotEmpty) {
        final List<dynamic> decodedHistory = json.decode(historyJson);
        final List<Map<String, dynamic>> history = decodedHistory.map((item) {
          return Map<String, dynamic>.from(item);
        }).toList();
        
        if (mounted) {
          setState(() {
            _mcuGpsHistory = history.reversed.toList(); // Reverse for display (newest first)
          });
        }
        
        final backupDate = prefs.getString('mcu_gps_history_backup_date') ?? 'Unknown';
        developer.log('Loaded ${history.length} GPS points from backup (saved: $backupDate)', name: 'HomeScreen');
      } else {
        developer.log('No GPS history backup found', name: 'HomeScreen');
      }
    } catch (e) {
      developer.log('Error loading GPS history backup: $e', name: 'HomeScreen', error: e);
    }
  }
  
  void _mergeGpsHistory(List<Map<String, dynamic>> newHistory) {
    if (newHistory.isEmpty && _mcuGpsHistory.isNotEmpty) {
      // If MCU returns empty but we have saved history, keep the saved history
      developer.log('MCU returned 0 points, keeping existing ${_mcuGpsHistory.length} saved points', name: 'HomeScreen');
      return;
    }
    
    // Create a map to track unique points by timestamp
    Map<int, Map<String, dynamic>> uniquePoints = {};
    
    // Add existing saved points (already reversed, so un-reverse for processing)
    List<Map<String, dynamic>> currentHistory = _mcuGpsHistory.reversed.toList();
    for (var point in currentHistory) {
      final timestamp = point['time'] ?? point['timestamp'] ?? 0;
      uniquePoints[timestamp] = point;
    }
    
    // Add new points from MCU (will overwrite duplicates with latest data)
    for (var point in newHistory) {
      final timestamp = point['time'] ?? point['timestamp'] ?? 0;
      uniquePoints[timestamp] = point;
    }
    
    // Convert back to list and sort by timestamp (newest first)
    List<Map<String, dynamic>> mergedHistory = uniquePoints.values.toList();
    mergedHistory.sort((a, b) {
      final timeA = a['time'] ?? a['timestamp'] ?? 0;
      final timeB = b['time'] ?? b['timestamp'] ?? 0;
      return timeB.compareTo(timeA); // Descending order (newest first)
    });
    
    developer.log('Merged history: ${currentHistory.length} saved + ${newHistory.length} new = ${mergedHistory.length} unique points', name: 'HomeScreen');
    
    // Update UI
    setState(() {
      _mcuGpsHistory = mergedHistory;
    });
    
    // Save the merged history
    _saveGpsHistoryLocally(mergedHistory.reversed.toList()); // Save in original order
  }
  
  Future<void> _fetchMcuGpsHistory() async {
    developer.log('_fetchMcuGpsHistory called. Connection state: $_connectionState', name: 'HomeScreen');
    
    if (_connectionState != BluetoothConnectionState.connected) {
      developer.log('Not connected, skipping GPS history fetch', name: 'HomeScreen');
      return;
    }
    
    setState(() {
      _isLoadingMcuHistory = true;
    });
    
    // Add delay to allow MCU to prepare data after connection
    developer.log('Waiting 2 seconds for MCU to prepare data...', name: 'HomeScreen');
    await Future.delayed(const Duration(seconds: 2));
    
    try {
      developer.log('Calling readAllGPSHistory for paginated data...', name: 'HomeScreen');
      final history = await _bleService.readAllGPSHistory();
      
      developer.log('readAllGPSHistory returned: ${history?.length ?? "null"} points', name: 'HomeScreen');
      
      if (mounted && history != null) {
        developer.log('Received ${history.length} points from MCU', name: 'HomeScreen');
        if (history.isNotEmpty) {
          developer.log('First point: ${history.first}', name: 'HomeScreen');
        }
        
        // Use merge logic instead of replacing
        _mergeGpsHistory(history);
        setState(() {
          _isLoadingMcuHistory = false;
        });
        
        developer.log('After merge: _mcuGpsHistory has ${_mcuGpsHistory.length} points', name: 'HomeScreen');
        
        // Clear MCU GPS history after successful sync to free NVS space
        if (history.length >= 25) { // Only clear if we got substantial data
          developer.log('Clearing MCU GPS history to free NVS space...', name: 'HomeScreen');
          // Note: History is already saved in _mergeGpsHistory()
          final cleared = await _bleService.clearMCUGPSHistory();
          if (cleared) {
            developer.log('MCU GPS history cleared successfully', name: 'HomeScreen');
            if (mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('GPS history synced (${history.length} points) and MCU memory cleared'),
                  duration: const Duration(seconds: 3),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            developer.log('Failed to clear MCU GPS history', name: 'HomeScreen');
            if (mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('GPS history synced but failed to clear MCU memory'),
                  duration: Duration(seconds: 3),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        } else {
          developer.log('Only ${history.length} points received, not clearing MCU (threshold: 25)', name: 'HomeScreen');
        }
      } else {
        developer.log('History is null or component not mounted', name: 'HomeScreen');
        setState(() {
          _mcuGpsHistory = [];
          _isLoadingMcuHistory = false;
        });
      }
    } catch (e, stack) {
      developer.log('Error fetching MCU GPS history: $e', name: 'HomeScreen', error: e);
      developer.log('Stack trace: $stack', name: 'HomeScreen');
      if (mounted) {
        setState(() {
          _isLoadingMcuHistory = false;
        });
      }
    }
  }
  
  void _setupListeners() {
    _connectionSubscription = _bleService.connectionState.listen((state) {
      setState(() {
        _connectionState = state;
        _isAutoConnecting = false;
        if (state == BluetoothConnectionState.connected) {
          _connectingDeviceId = null;
          _availableDevices.clear();
          // Start location tracking when connected
          _startLocationTracking();
          // Sync saved configuration to device
          _syncSavedConfiguration();
          // Fetch MCU GPS history
          _fetchMcuGpsHistory();
        } else if (state == BluetoothConnectionState.disconnected) {
          _connectingDeviceId = null;
          // Clear MCU history on disconnect
          _mcuGpsHistory = [];
          // Clear clicked history locations on disconnect
          _clickedPhoneLocations.clear();
          _clickedMcuLocations.clear();
          // Stop location tracking when disconnected
          _stopLocationTracking();
          _checkBluetoothAndScan();
        }
      });
    });
    
    _scanSubscription = _bleService.scanResults.listen((devices) {
      setState(() {
        _availableDevices = devices.where((d) => d.isBikeTracker).toList();
      });
    });
    
    // Subscribe to GPS history stream for real-time updates
    _gpsHistorySubscription = _bleService.gpsHistoryStream.listen((history) {
      if (mounted) {
        setState(() {
          // Reverse the history so newest points are first
          _mcuGpsHistory = history.reversed.toList();
          _isLoadingMcuHistory = false;
        });
        developer.log('GPS history updated via notification: ${history.length} points (reversed for display)', name: 'HomeScreen');
      }
    });
    
    // Device status listener - track configuration state
    _bleService.deviceStatus.listen((status) {
      setState(() {
        _currentDeviceStatus = status;
      });
      developer.log('Status update: user=${status['user'] ?? status['user_present']}, mode=${status['mode']}', name: 'HomeScreen');
    });
    
    // Listen to Bluetooth adapter state changes
    _bluetoothStateSubscription = _bleService.bluetoothState.listen((state) {
      setState(() {
        _bluetoothState = state;
      });
      
      if (state == BluetoothAdapterState.off) {
        // Stop scanning if Bluetooth is turned off
        _isScanning = false;
        _availableDevices.clear();
        // Show dialog to prompt user to turn on Bluetooth
        _showBluetoothOffDialog();
      } else if (state == BluetoothAdapterState.on) {
        // Bluetooth turned on, start scanning if not connected
        if (_connectionState != BluetoothConnectionState.connected) {
          _checkBluetoothAndScan();
        }
      }
    });
    
    // Location updates listener
    _locationSubscription = _locationService.locationStream.listen((location) async {
      setState(() {
        _currentLocation = location;
        _locationHistory.insert(0, location); // Add to beginning for newest first
        // Keep only last 500 locations in memory
        if (_locationHistory.length > 500) {
          _locationHistory.removeLast();
        }
      });
      // Save to persistent storage
      await _storageService.addLocation(location);
    });
  }
  
  Future<void> _startLocationTracking() async {
    setState(() {
      _isTrackingLocation = true;
    });
    await _locationService.startLocationTracking();
    developer.log('Location tracking started', name: 'HomeScreen');
  }
  
  Future<void> _stopLocationTracking() async {
    setState(() {
      _isTrackingLocation = false;
    });
    await _locationService.stopLocationTracking();
    developer.log('Location tracking stopped', name: 'HomeScreen');
  }
  
  Future<void> _refreshLocation() async {
    developer.log('Manually refreshing GPS location', name: 'HomeScreen');
    
    // Show loading indicator
    if (mounted) {
      UIHelpers.showInfo(context, 'Getting GPS location...');
    }
    
    // Get current location immediately
    final location = await _locationService.getCurrentLocation();
    
    if (location != null && mounted) {
      setState(() {
        _currentLocation = location;
        _locationHistory.insert(0, location);
      });
      
      // Save to storage
      await _storageService.saveLocationHistory(_locationHistory);
      
      UIHelpers.showInfo(context, 'Location refreshed');
      developer.log('Location refreshed: ${location.formattedCoordinates}', name: 'HomeScreen');
    } else if (mounted) {
      UIHelpers.showError(context, 'Could not get GPS location');
    }
  }
  
  Future<void> _initializeAndAutoConnect() async {
    // Load saved device info
    _savedDevice = await _bleService.getLastConnectedDevice();
    _autoConnectEnabled = await _bleService.isAutoConnectEnabled();
    
    setState(() {});
    
    // Check permissions and location services first
    bool permissionsReady = await PermissionHelper.checkAndRequestPermissions(context);
    if (!permissionsReady) {
      developer.log('Permissions not ready for auto-connect', name: 'HomeScreen');
      return;
    }
    
    // Check Bluetooth availability
    if (!await _bleService.checkBluetoothAvailability()) {
      developer.log('Bluetooth not available for auto-connect', name: 'HomeScreen');
      return;
    }
    
    // Try auto-connect if enabled and has saved device
    if (_autoConnectEnabled && _savedDevice != null) {
      setState(() {
        _isAutoConnecting = true;
      });
      
      final connected = await _bleService.tryAutoConnect();
      
      if (!connected && mounted) {
        setState(() {
          _isAutoConnecting = false;
        });
        // If auto-connect failed, start regular scan
        _startScan();
      }
    } else {
      // No auto-connect, start regular scan
      _startScan();
    }
  }
  
  Future<void> _checkBluetoothAndScan() async {
    if (await _bleService.checkBluetoothAvailability() && 
        _connectionState != BluetoothConnectionState.connected) {
      _startScan();
    }
  }
  
  Future<void> _startScan() async {
    if (_isScanning || _connectionState == BluetoothConnectionState.connected) return;
    
    // Check permissions and location services first
    bool permissionsReady = await PermissionHelper.checkAndRequestPermissions(context);
    if (!permissionsReady) {
      developer.log('Permissions not ready, cannot start scan', name: 'HomeScreen');
      if (mounted) {
        UIHelpers.showError(context, 'Location services must be enabled to scan for devices');
      }
      return;
    }
    
    setState(() {
      _isScanning = true;
      _availableDevices.clear();
    });
    
    try {
      await _bleService.startScan();
      
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
        }
      });
    } catch (e) {
      developer.log('Error scanning: $e', name: 'HomeScreen');
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        
        // Check if error is due to location services
        if (e.toString().contains('Location services')) {
          bool userAction = await PermissionHelper.requestLocationServices(context);
          if (userAction) {
            // User went to settings, wait a bit and retry
            await Future.delayed(const Duration(seconds: 2));
            // Check if location is now enabled
            bool locationEnabled = await PermissionHelper.isLocationServiceEnabled();
            if (locationEnabled) {
              // Retry scanning
              _startScan();
            }
          }
        } else {
          UIHelpers.showError(context, 'Failed to start scanning: ${e.toString()}');
        }
      }
    }
  }
  
  Future<void> _connectToDevice(BikeDevice device) async {
    setState(() {
      _connectingDeviceId = device.id;
    });
    
    final success = await _bleService.connectToDevice(device);
    
    if (!success && mounted) {
      setState(() {
        _connectingDeviceId = null;
      });
      
      UIHelpers.showError(context, 'Failed to connect');
    }
  }
  
  Future<void> _disconnect() async {
    // Check device configuration status first
    bool phoneConfigured = _currentDeviceStatus?['phone_configured'] ?? false;
    bool alertsEnabled = _currentDeviceStatus?['alerts'] ?? false;
    
    // If either phone is not configured or alerts are disabled, show warning
    if (!phoneConfigured || !alertsEnabled) {
      final proceedWithDisconnect = await _showConfigurationWarning(
        phoneConfigured: phoneConfigured,
        alertsEnabled: alertsEnabled,
      );
      
      if (!proceedWithDisconnect) {
        return; // User cancelled or went to settings
      }
    }
    
    // Show normal disconnect confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Device'),
        content: const Text('Are you sure you want to disconnect from the bike tracker?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await _bleService.disconnect();
      if (mounted) {
        UIHelpers.showInfo(context, 'Disconnected from device');
      }
    }
  }
  
  Future<bool> _showConfigurationWarning({
    required bool phoneConfigured,
    required bool alertsEnabled,
  }) async {
    // Determine the warning message based on what's missing
    String title;
    String message;
    
    if (!phoneConfigured && !alertsEnabled) {
      // Both issues
      title = '⚠️ Protection Not Active';
      message = 'SMS alerts are disabled and no phone number is configured.\n\n'
                'Your bike will have NO theft protection while disconnected.\n\n'
                'Configure protection settings before disconnecting?';
    } else if (!phoneConfigured) {
      // No phone number
      title = '⚠️ No SMS Alerts Configured';
      message = 'No phone number is configured for SMS alerts.\n\n'
                'You won\'t receive notifications if your bike is moved while disconnected.\n\n'
                'Add a phone number before disconnecting?';
    } else {
      // Alerts disabled
      title = '⚠️ SMS Alerts Disabled';
      message = 'SMS alerts are currently disabled.\n\n'
                'You won\'t receive notifications even though a phone number is configured.\n\n'
                'Enable alerts before disconnecting?';
    }
    
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, 
                   color: Colors.orange,
                   size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('disconnect'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Disconnect Anyway'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('configure'),
              child: Text(
                !phoneConfigured ? 'Configure Now' : 'Enable Alerts',
              ),
            ),
          ],
        );
      },
    );
    
    if (result == 'configure') {
      // Navigate to settings screen
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SettingsScreen(),
          ),
        );
      }
      return false; // Don't disconnect after going to settings
    } else if (result == 'disconnect') {
      return true; // Proceed with disconnect
    } else {
      return false; // Cancelled
    }
  }
  
  void _showBluetoothOffDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User must take action
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bluetooth_disabled, color: Colors.red),
            SizedBox(width: 12),
            Text('Bluetooth is Off'),
          ],
        ),
        content: const Text(
          'Bluetooth is required to connect to your bike tracker. '
          'Please turn on Bluetooth to use this app.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Try to open Bluetooth settings (platform specific)
              if (Theme.of(context).platform == TargetPlatform.android) {
                // For Android, we can try to prompt the user
                FlutterBluePlus.turnOn();
              }
            },
            child: const Text('Turn On Bluetooth'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _syncSavedConfiguration() async {
    try {
      // Load saved configuration from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final phoneNumber = prefs.getString('config_phone');
      final updateInterval = prefs.getInt('config_interval');
      final alertsEnabled = prefs.getBool('config_alerts');
      
      // Check if we have saved configuration
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        developer.log('Syncing saved configuration to device...', name: 'HomeScreen');
        
        // Wait a moment for the connection to stabilize
        await Future.delayed(AppConstants.connectionStabilizationDelay);
        
        // Send configuration to device
        final success = await _bleService.sendConfiguration(
          phoneNumber: phoneNumber,
          updateInterval: updateInterval ?? 300,
          alertEnabled: alertsEnabled ?? true,
        );
        
        if (success) {
          developer.log('Configuration synced successfully', name: 'HomeScreen');
          if (mounted) {
            UIHelpers.showSuccess(context, 'Configuration synced to device');
          }
        } else {
          developer.log('Failed to sync configuration', name: 'HomeScreen');
          if (mounted) {
            UIHelpers.showWarning(context, 'Failed to sync configuration');
          }
        }
      } else {
        developer.log('No saved configuration found to sync', name: 'HomeScreen');
      }
    } catch (e) {
      developer.log('Error syncing configuration: $e', name: 'HomeScreen', error: e);
    }
  }
  
  Widget _buildConnectionStatus() {
    final theme = Theme.of(context);
    
    // Check Bluetooth state first
    if (_bluetoothState == BluetoothAdapterState.off) {
      return Card(
        color: theme.colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bluetooth_disabled,
                    color: theme.colorScheme.error,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bluetooth is Off',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                        Text(
                          'Turn on Bluetooth to connect',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => FlutterBluePlus.turnOn(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    ),
                    child: const Text('Enable'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    
    late final String statusText;
    late final IconData statusIcon;
    late final Color statusColor;
    
    if (_isAutoConnecting) {
      statusText = 'Auto-connecting...';
      statusIcon = Icons.bluetooth_searching;
      statusColor = theme.colorScheme.secondary;
    } else if (_connectionState == BluetoothConnectionState.connected) {
      statusText = 'Connected';
      statusIcon = Icons.bluetooth_connected;
      statusColor = theme.colorScheme.primary;
    } else {
      statusText = 'Disconnected';
      statusIcon = Icons.bluetooth_disabled;
      statusColor = theme.colorScheme.error;
    }
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (_isAutoConnecting)
              const CircularProgressIndicator()
            else
              Icon(
                statusIcon,
                size: 64,
                color: statusColor,
              ),
            const SizedBox(height: 16),
            Text(
              statusText,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_isAutoConnecting && _savedDevice != null) ...[
              const SizedBox(height: 8),
              Text(
                'Searching for ${_savedDevice!['name']}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (_connectionState == BluetoothConnectionState.connected && _bleService.connectedDevice != null) ...[
              const SizedBox(height: 8),
              Text(
                'Device: ${_bleService.connectedDevice!.platformName}',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                _bleService.connectedDevice!.remoteId.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (!_isAutoConnecting && _connectionState != BluetoothConnectionState.connected) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Auto-connect',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _autoConnectEnabled,
                    onChanged: (value) async {
                      await _bleService.setAutoConnectEnabled(value);
                      setState(() {
                        _autoConnectEnabled = value;
                      });
                    },
                  ),
                ],
              ),
              if (_savedDevice != null && _autoConnectEnabled) ...[
                Text(
                  'Will auto-connect to: ${_savedDevice!['name']}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await _bleService.clearLastConnectedDevice();
                    setState(() {
                      _savedDevice = null;
                    });
                  },
                  child: Text(
                    'Forget Device',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildDeviceList() {
    final theme = Theme.of(context);
    
    if (_availableDevices.isEmpty && !_isScanning) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No bike trackers found',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Make sure your tracker is powered on',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return Column(
      children: [
        if (_isScanning)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Scanning for devices...',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ..._availableDevices.map((device) {
          final isConnecting = _connectingDeviceId == device.id;
          
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: Icon(
                Icons.directions_bike,
                color: theme.colorScheme.primary,
              ),
              title: Text(device.name),
              subtitle: Text('Signal: ${device.rssi} dBm'),
              trailing: ElevatedButton(
                onPressed: isConnecting ? null : () => _connectToDevice(device),
                child: isConnecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Connect'),
              ),
            ),
          );
        }),
      ],
    );
  }
  
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_connectionState == BluetoothConnectionState.connected) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _disconnect,
                icon: const Icon(Icons.bluetooth_disabled),
                label: const Text('Disconnect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isScanning ? null : _startScan,
                icon: const Icon(Icons.search),
                label: Text(_isScanning ? 'Scanning...' : 'Scan for Devices'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Bike Tracker'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildConnectionStatus(),
          if (_connectionState != BluetoothConnectionState.connected) ...[
            Expanded(
              child: SingleChildScrollView(
                child: _buildDeviceList(),
              ),
            ),
          ] else ...[
            // Scrollable content when connected
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Device status card
                    const DeviceStatusCard(),
                  // Location tracking status with tabs - reduced padding
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                _isTrackingLocation ? Icons.location_on : Icons.location_off,
                                color: _isTrackingLocation ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _isTrackingLocation ? 'Location Tracking Active' : 'Location Tracking Inactive',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              // Refresh location button
                              IconButton(
                                icon: Icon(
                                  Icons.refresh,
                                  color: theme.colorScheme.primary,
                                ),
                                onPressed: _refreshLocation,
                                tooltip: 'Refresh GPS Location',
                              ),
                              // Show clear button when in Phone list view
                              if (_tabController.index == 1 && _locationHistory.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear_all),
                                  color: theme.colorScheme.error,
                                  onPressed: _clearLocationHistory,
                                  tooltip: 'Clear Phone History',
                                ),
                              // Show clear button when in GPS view
                              if (_tabController.index == 2 && _mcuGpsHistory.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear_all),
                                  color: theme.colorScheme.error,
                                  onPressed: _clearMcuGpsHistory,
                                  tooltip: 'Clear GPS History',
                                ),
                              // Show download button when in map view
                              if (_tabController.index == 0 && _locationHistory.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.download),
                                  onPressed: () => _showMapDownloadDialog(),
                                  tooltip: 'Download Map',
                                ),
                              // Show count badge based on current tab
                              if ((_tabController.index == 1 && _locationHistory.isNotEmpty) ||
                                  (_tabController.index == 2 && _mcuGpsHistory.isNotEmpty))
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _tabController.index == 1 
                                      ? theme.colorScheme.primaryContainer
                                      : theme.colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _tabController.index == 1
                                      ? '${_locationHistory.length} logs'
                                      : '${_mcuGpsHistory.length} points',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: _tabController.index == 1
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Tab bar for map/list/mcu view
                        TabBar(
                          controller: _tabController,
                          tabs: const [
                            Tab(
                              icon: Icon(Icons.map),
                              text: 'Map',
                            ),
                            Tab(
                              icon: Icon(Icons.list),
                              text: 'Phone',
                            ),
                            Tab(
                              icon: Icon(Icons.satellite_alt),
                              text: 'GPS',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Tab view for map and list - fixed height
                  SizedBox(
                    height: 500, // Fixed height for map/list view
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Map View
                        LocationMap(
                          locationHistory: _locationHistory,
                          currentLocation: _currentLocation,
                          isTracking: _isTrackingLocation,
                          mcuGpsPoints: _mcuGpsHistory,
                          selectedLocation: _selectedMapLocation,
                          clickedPhoneLocations: _clickedPhoneLocations,
                          clickedMcuLocations: _clickedMcuLocations,
                          onLocationSelected: () {
                            // Clear the selected location after navigating
                            setState(() {
                              _selectedMapLocation = null;
                            });
                          },
                          onClearMarkers: _clearMapMarkers,
                        ),
                        // List View - wrapped in builder to maintain state
                        Builder(
                          builder: (context) => _locationHistory.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.location_searching,
                                    size: 64,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Waiting for location data...',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Location logs will appear here',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : NotificationListener<OverscrollNotification>(
                            onNotification: (notification) {
                              // When overscrolling at the bottom, let parent handle it
                              if (notification.overscroll > 0 && notification.metrics.pixels >= notification.metrics.maxScrollExtent) {
                                // Find the parent ScrollController and scroll it
                                final scrollController = PrimaryScrollController.of(context);
                                if (scrollController.hasClients) {
                                  scrollController.animateTo(
                                    scrollController.offset + notification.overscroll,
                                    duration: const Duration(milliseconds: 100),
                                    curve: Curves.easeOut,
                                  );
                                }
                                return true;
                              }
                              return false;
                            },
                            child: RawScrollbar(
                              thumbVisibility: true, // Always show scrollbar
                              thickness: 8.0,
                              radius: const Radius.circular(4),
                              thumbColor: theme.colorScheme.primary.withValues(alpha: 0.6),
                              interactive: true, // Allow dragging the scrollbar
                              child: ListView.builder(
                                physics: const BouncingScrollPhysics(), // Use bouncing for better feel
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: _locationHistory.length,
                                itemBuilder: (context, index) {
                                final location = _locationHistory[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  elevation: 2,
                                  child: InkWell(
                                    onTap: () => _navigateToLocationOnMap(location),
                                    borderRadius: BorderRadius.circular(12),
                                    child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: theme.colorScheme.primaryContainer,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: theme.colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${location.formattedDate} ${location.formattedTimestamp}',
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Lat: ${location.latitude.toStringAsFixed(6)}',
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        const SizedBox(width: 18),
                                        Expanded(
                                          child: Text(
                                            'Lng: ${location.longitude.toStringAsFixed(6)}',
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Display speed
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.speed,
                                          size: 14,
                                          color: theme.colorScheme.tertiary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Speed: ${location.speed.toStringAsFixed(1)} km/h',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.map,
                                      color: theme.colorScheme.primary.withValues(alpha: 0.7),
                                      size: 20,
                                    ),
                                    if (index == 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Latest',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                          ),
                        // Tracker GPS History View
                        Builder(
                          builder: (context) {
                            if (!_bleService.isConnected) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.bluetooth_disabled,
                                      size: 64,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Connect to device to view tracker GPS history',
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else if (_isLoadingMcuHistory) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            } else if (_mcuGpsHistory.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.location_off,
                                      size: 64,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No GPS history available from MCU',
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: _fetchMcuGpsHistory,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Refresh'),
                                    ),
                                  ],
                                ),
                              );
                            }
                            
                            return RefreshIndicator(
                              onRefresh: _fetchMcuGpsHistory,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: _mcuGpsHistory.length,
                                itemBuilder: (context, index) {
                                  final point = _mcuGpsHistory[index];
                                  final timestamp = point['time'] ?? point['timestamp'] ?? 0;
                                  // MCU sends timestamp in milliseconds already
                                  final date = timestamp > 0 
                                    ? DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal() // Convert to local time
                                    : DateTime.now();
                                  
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    elevation: 2,
                                    child: InkWell(
                                      onTap: () => _navigateToGpsPointOnMap(point),
                                      borderRadius: BorderRadius.circular(12),
                                      child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: theme.colorScheme.secondaryContainer,
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: theme.colorScheme.onSecondaryContainer,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      title: Row(
                                        children: [
                                          Icon(
                                            Icons.satellite_alt,
                                            size: 16,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'GPS Point #${index + 1}',
                                            style: theme.textTheme.bodyLarge?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          if (timestamp > 0)
                                            Text(
                                              '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.location_on,
                                                size: 14,
                                                color: theme.colorScheme.secondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  'Lat: ${(point['lat'] ?? point['latitude'] ?? 0).toStringAsFixed(6)}',
                                                  style: theme.textTheme.bodyMedium,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              const SizedBox(width: 18),
                                              Expanded(
                                                child: Text(
                                                  'Lng: ${(point['lon'] ?? point['longitude'] ?? 0).toStringAsFixed(6)}',
                                                  style: theme.textTheme.bodyMedium,
                                                ),
                                              ),
                                            ],
                                          ),
                                          // Display speed (including 0.0 values)
                                          if (point['speed'] != null) ...[
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.speed,
                                                  size: 14,
                                                  color: theme.colorScheme.tertiary,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Speed: ${(point['speed'] ?? 0.0).toStringAsFixed(1)} km/h',
                                                  style: theme.textTheme.bodyMedium,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.map,
                                            color: theme.colorScheme.primary.withValues(alpha: 0.7),
                                            size: 20,
                                          ),
                                          if (index == 0) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.secondary,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'Latest',
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: theme.colorScheme.onSecondary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  // No buttons below the list - removed for better UX
                ],
                ),
              ),
            ),
          ],
          _buildActionButtons(),
        ],
      ),
    );
  }
  
  void _navigateToLocationOnMap(LocationData location) {
    // Switch to map tab
    _tabController.animateTo(0);
    
    final locationLatLng = LatLng(location.latitude, location.longitude);
    
    // Add this location to clicked phone locations set
    setState(() {
      _selectedMapLocation = locationLatLng;
      _clickedPhoneLocations.add(locationLatLng);
    });
    
    // Hide any existing snackbar first
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    // Show a snackbar with location details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Showing location from ${location.formattedDate} ${location.formattedTimestamp}'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.down,
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () {
            final coordinates = '${location.latitude}, ${location.longitude}';
            Clipboard.setData(ClipboardData(text: coordinates));
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied: $coordinates'),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ),
    );
  }
  
  void _navigateToGpsPointOnMap(Map<String, dynamic> point) {
    // Extract coordinates - handle both key formats
    final lat = (point['lat'] ?? point['latitude'] ?? 0).toDouble();
    final lng = (point['lon'] ?? point['longitude'] ?? 0).toDouble();
    final timestamp = point['time'] ?? point['timestamp'] ?? 0;
    
    // Switch to map tab
    _tabController.animateTo(0);
    
    final locationLatLng = LatLng(lat, lng);
    
    // Add this GPS point to clicked MCU locations set
    setState(() {
      _selectedMapLocation = locationLatLng;
      _clickedMcuLocations.add(locationLatLng);
    });
    
    // Format timestamp for display
    final date = timestamp > 0 
      ? DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal() // Convert to local time
      : DateTime.now();
    final formattedDate = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final formattedTime = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
    
    // Hide any existing snackbar first
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    // Show a snackbar with GPS point details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Showing GPS point from $formattedDate $formattedTime'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.down,
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () {
            final coordinates = '$lat, $lng';
            Clipboard.setData(ClipboardData(text: coordinates));
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied: $coordinates'),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ),
    );
  }
  
  Future<void> _clearMapMarkers() async {
    // Check if there are any markers to clear
    if (_clickedPhoneLocations.isEmpty && _clickedMcuLocations.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No markers to clear'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Map Markers'),
        content: Text(
          'Clear ${_clickedPhoneLocations.length + _clickedMcuLocations.length} markers from the map?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() {
        _clickedPhoneLocations.clear();
        _clickedMcuLocations.clear();
        _selectedMapLocation = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Map markers cleared'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }
  
  Future<void> _clearLocationHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Location History'),
        content: const Text('This will permanently delete all saved location history. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await _storageService.clearLocationHistory();
      setState(() {
        _locationHistory.clear();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location history cleared')),
        );
      }
    }
  }
  
  Future<void> _clearMcuGpsHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear GPS History'),
        content: const Text('This will permanently delete all saved GPS history from the tracker. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      // Clear local backup first
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('mcu_gps_history_backup');
        await prefs.remove('mcu_gps_history_backup_date');
        developer.log('Cleared local GPS history backup', name: 'HomeScreen');
      } catch (e) {
        developer.log('Error clearing local GPS backup: $e', name: 'HomeScreen', error: e);
      }
      
      // Clear the displayed history
      setState(() {
        _mcuGpsHistory.clear();
        // Also clear any clicked MCU locations from the map
        _clickedMcuLocations.clear();
      });
      
      // If connected, also try to clear MCU's internal GPS history
      if (_bleService.isConnected) {
        try {
          final cleared = await _bleService.clearMCUGPSHistory();
          if (cleared) {
            developer.log('MCU GPS history cleared successfully', name: 'HomeScreen');
          } else {
            developer.log('Failed to clear MCU GPS history', name: 'HomeScreen');
          }
        } catch (e) {
          developer.log('Error clearing MCU GPS history: $e', name: 'HomeScreen', error: e);
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS history cleared')),
        );
      }
    }
  }
  
  void _showMapDownloadDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MapDownloadDialog(
        currentLocation: _currentLocation != null 
          ? LatLng(_currentLocation!.latitude, _currentLocation!.longitude)
          : null,
        tileUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      ),
    );
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _connectionSubscription?.cancel();
    _scanSubscription?.cancel();
    _locationSubscription?.cancel();
    _bluetoothStateSubscription?.cancel();
    _gpsHistorySubscription?.cancel();
    _locationService.dispose();
    super.dispose();
  }
}