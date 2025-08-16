import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../services/bluetooth_service.dart' as bike_ble;
import '../services/location_service.dart';
import '../services/location_storage_service.dart';
import '../models/bike_device.dart';
import '../models/location_data.dart';
import '../widgets/location_map.dart';
import '../widgets/device_status_card.dart';
import '../widgets/map_download_dialog.dart';
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
  
  // Tab controller for map/list view
  late TabController _tabController;
  
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _locationSubscription;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to show/hide clear button
    });
    _setupListeners();
    _loadLocationHistory();
    _initializeAndAutoConnect();
  }
  
  Future<void> _loadLocationHistory() async {
    final history = await _storageService.loadLocationHistory();
    setState(() {
      _locationHistory = history;
    });
    developer.log('Loaded ${history.length} locations from storage', name: 'HomeScreen');
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
        } else if (state == BluetoothConnectionState.disconnected) {
          _connectingDeviceId = null;
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
  
  Future<void> _initializeAndAutoConnect() async {
    // Load saved device info
    _savedDevice = await _bleService.getLastConnectedDevice();
    _autoConnectEnabled = await _bleService.isAutoConnectEnabled();
    
    setState(() {});
    
    // Check Bluetooth availability
    final available = await _bleService.checkBluetoothAvailability();
    if (!available) return;
    
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
    final available = await _bleService.checkBluetoothAvailability();
    if (available && _connectionState != BluetoothConnectionState.connected) {
      _startScan();
    }
  }
  
  Future<void> _startScan() async {
    if (_isScanning || _connectionState == BluetoothConnectionState.connected) return;
    
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
      setState(() {
        _isScanning = false;
      });
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect')),
      );
    }
  }
  
  Future<void> _disconnect() async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disconnected from device')),
        );
      }
    }
  }
  
  Widget _buildConnectionStatus() {
    final theme = Theme.of(context);
    
    String statusText;
    IconData statusIcon;
    Color statusColor;
    
    if (_isAutoConnecting) {
      statusText = 'Auto-connecting...';
      statusIcon = Icons.bluetooth_searching;
      statusColor = theme.colorScheme.secondary;
    } else {
      switch (_connectionState) {
        case BluetoothConnectionState.connected:
          statusText = 'Connected';
          statusIcon = Icons.bluetooth_connected;
          statusColor = theme.colorScheme.primary;
          break;
        default:
          statusText = 'Disconnected';
          statusIcon = Icons.bluetooth_disabled;
          statusColor = theme.colorScheme.error;
      }
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
                              Text(
                                _isTrackingLocation ? 'Location Tracking Active' : 'Location Tracking Inactive',
                                style: theme.textTheme.titleMedium,
                              ),
                              const Spacer(),
                              // Show clear button when in list view
                              if (_tabController.index == 1 && _locationHistory.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear_all),
                                  color: theme.colorScheme.error,
                                  onPressed: _clearLocationHistory,
                                  tooltip: 'Clear History',
                                ),
                              // Show download button when in map view
                              if (_tabController.index == 0 && _locationHistory.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.download),
                                  onPressed: () => _showMapDownloadDialog(),
                                  tooltip: 'Download Map',
                                ),
                              if (_locationHistory.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_locationHistory.length} logs',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Tab bar for map/list view
                        TabBar(
                          controller: _tabController,
                          tabs: const [
                            Tab(
                              icon: Icon(Icons.map),
                              text: 'Map',
                            ),
                            Tab(
                              icon: Icon(Icons.list),
                              text: 'List',
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
                          : RawScrollbar(
                            thumbVisibility: true, // Always show scrollbar
                            thickness: 8.0,
                            radius: const Radius.circular(4),
                            thumbColor: theme.colorScheme.primary.withOpacity(0.6),
                            interactive: true, // Allow dragging the scrollbar
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _locationHistory.length,
                              itemBuilder: (context, index) {
                                final location = _locationHistory[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    onTap: () => _copyLocationToClipboard(location),
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
                                  ],
                                ),
                                trailing: index == 0
                                  ? Container(
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
                                    )
                                  : null,
                              ),
                                );
                              },
                            ),
                          ),
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
  
  void _copyLocationToClipboard(LocationData location) {
    final coordinates = '${location.latitude}, ${location.longitude}';
    Clipboard.setData(ClipboardData(text: coordinates));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $coordinates'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Open Maps',
          onPressed: () {
            // Could launch maps app with coordinates if needed
            developer.log('Open maps with: $coordinates', name: 'HomeScreen');
          },
        ),
      ),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location history cleared')),
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
    _locationService.dispose();
    super.dispose();
  }
}