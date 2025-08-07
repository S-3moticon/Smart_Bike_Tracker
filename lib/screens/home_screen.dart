import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/bluetooth_service.dart' as bike_ble;
import '../services/location_service.dart';
import '../models/location_data.dart';
import '../models/device_status.dart';
import '../models/tracker_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final bike_ble.BikeBluetoothService _bleService = bike_ble.BikeBluetoothService();
  final LocationService _locationService = LocationService();
  final TextEditingController _phoneController = TextEditingController();
  
  LocationData? _currentLocation;
  DeviceStatus? _deviceStatus;
  BluetoothConnectionState _connectionState = BluetoothConnectionState.connected;
  int _updateInterval = 30;
  bool _alertEnabled = true;
  bool _isUpdatingConfig = false;
  
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  bool _isMapReady = false;
  
  StreamSubscription? _locationSubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _phoneLocationSubscription;
  
  @override
  void initState() {
    super.initState();
    _setupListeners();
    _requestInitialData();
    _initializeLocationService();
  }
  
  Future<void> _initializeLocationService() async {
    await _locationService.initialize();
    
    _phoneLocationSubscription = _locationService.locationStream.listen((location) {
      if (mounted) {
        setState(() {
          _currentLocation = location;
          _updateMapMarker(location);
        });
      }
    });
  }
  
  void _setupListeners() {
    _locationSubscription = _bleService.locationData.listen((location) {
      setState(() {
        _currentLocation = location;
      });
      developer.log('Location updated: ${location.formattedCoordinates}', name: 'HomeScreen');
    });
    
    _statusSubscription = _bleService.deviceStatus.listen((status) {
      setState(() {
        _deviceStatus = status;
      });
      developer.log('Status updated: ${status.mode.value}', name: 'HomeScreen');
    });
    
    _connectionSubscription = _bleService.connectionState.listen((state) {
      setState(() {
        _connectionState = state;
      });
      
      if (state == BluetoothConnectionState.disconnected && mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    });
  }
  
  Future<void> _requestInitialData() async {
    final location = await _bleService.requestLocation();
    final status = await _bleService.requestStatus();
    
    if (mounted) {
      setState(() {
        _currentLocation = location;
        _deviceStatus = status;
      });
    }
  }
  
  Future<void> _updateConfiguration() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }
    
    setState(() {
      _isUpdatingConfig = true;
    });
    
    final config = TrackerConfig(
      phoneNumber: _phoneController.text,
      updateInterval: _updateInterval,
      alertEnabled: _alertEnabled,
    );
    
    final success = await _bleService.writeConfig(config);
    
    if (mounted) {
      setState(() {
        _isUpdatingConfig = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Configuration updated' : 'Failed to update configuration'),
          backgroundColor: success ? Colors.green : Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
  
  Future<void> _requestLocationUpdate() async {
    final location = await _bleService.requestLocation();
    if (location != null && mounted) {
      setState(() {
        _currentLocation = location;
      });
    }
  }
  
  Widget _buildStatusCard() {
    final theme = Theme.of(context);
    final status = _deviceStatus ?? DeviceStatus.initial();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  status.isTheftDetected ? Icons.warning : Icons.shield,
                  color: status.isTheftDetected 
                    ? theme.colorScheme.error 
                    : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Device Status',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusRow('Mode', status.mode.value, 
              status.isTheftDetected ? theme.colorScheme.error : null),
            _buildStatusRow('Motion', status.motionDetected ? 'Detected' : 'None'),
            _buildStatusRow('User Present', status.userPresent ? 'Yes' : 'No'),
            _buildStatusRow('BLE', status.bleConnected ? 'Connected' : 'Disconnected'),
            const SizedBox(height: 8),
            Text(
              status.statusMessage,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: status.isTheftDetected 
                  ? theme.colorScheme.error 
                  : theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
  
  void _updateMapMarker(LocationData location) {
    _markers.clear();
    
    final markerIcon = location.source == LocationSource.phone
        ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)
        : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    
    _markers.add(
      Marker(
        markerId: const MarkerId('bike_location'),
        position: LatLng(location.latitude, location.longitude),
        icon: markerIcon,
        infoWindow: InfoWindow(
          title: 'Bike Location',
          snippet: 'Source: ${location.source.name}\nSpeed: ${location.formattedSpeed}',
        ),
      ),
    );
    
    if (_mapController != null && _isMapReady) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(location.latitude, location.longitude),
        ),
      );
    }
  }
  
  Widget _buildLocationCard() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Location',
                  style: theme.textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _requestLocationUpdate,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_currentLocation != null && _currentLocation!.isValid) ...[
              _buildStatusRow('Coordinates', _currentLocation!.formattedCoordinates),
              _buildStatusRow('Speed', _currentLocation!.formattedSpeed),
              _buildStatusRow('Satellites', _currentLocation!.satellites.toString()),
              _buildStatusRow('Battery', '${_currentLocation!.battery}%'),
              _buildStatusRow('Source', _currentLocation!.source.name.toUpperCase()),
              _buildStatusRow('Last Update', _currentLocation!.formattedTime),
            ] else ...[
              const Center(
                child: Text('No location data available'),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildMapCard() {
    final theme = Theme.of(context);
    final initialPosition = _currentLocation != null && _currentLocation!.isValid
        ? LatLng(_currentLocation!.latitude, _currentLocation!.longitude)
        : const LatLng(37.7749, -122.4194);
    
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.map, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Live Map',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 300,
            child: GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
                setState(() {
                  _isMapReady = true;
                });
              },
              initialCameraPosition: CameraPosition(
                target: initialPosition,
                zoom: 16.0,
              ),
              markers: _markers,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              mapType: MapType.normal,
              compassEnabled: true,
              zoomControlsEnabled: true,
              style: '''[
                {
                  "elementType": "geometry",
                  "stylers": [{"color": "#212121"}]
                },
                {
                  "elementType": "labels.text.fill",
                  "stylers": [{"color": "#757575"}]
                },
                {
                  "elementType": "labels.text.stroke",
                  "stylers": [{"color": "#212121"}]
                },
                {
                  "featureType": "road",
                  "elementType": "geometry",
                  "stylers": [{"color": "#2c2c2c"}]
                },
                {
                  "featureType": "water",
                  "elementType": "geometry",
                  "stylers": [{"color": "#000000"}]
                }
              ]''',
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildConfigurationCard() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Configuration',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Emergency Phone Number',
                hintText: '+1234567890',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Update Interval:'),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    value: _updateInterval.toDouble(),
                    min: 10,
                    max: 300,
                    divisions: 29,
                    label: '$_updateInterval seconds',
                    onChanged: (value) {
                      setState(() {
                        _updateInterval = value.round();
                      });
                    },
                  ),
                ),
                Text('${_updateInterval}s'),
              ],
            ),
            SwitchListTile(
              title: const Text('SMS Alerts'),
              subtitle: const Text('Send SMS when theft is detected'),
              value: _alertEnabled,
              onChanged: (value) {
                setState(() {
                  _alertEnabled = value;
                });
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUpdatingConfig ? null : _updateConfiguration,
                child: _isUpdatingConfig
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update Configuration'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Bike Tracker'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _connectionState == BluetoothConnectionState.connected
                ? Colors.green.withValues(alpha: 0.2)
                : Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.bluetooth_connected,
                  size: 16,
                  color: _connectionState == BluetoothConnectionState.connected
                    ? Colors.green
                    : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  _connectionState == BluetoothConnectionState.connected
                    ? 'Connected'
                    : 'Connecting...',
                  style: TextStyle(
                    fontSize: 12,
                    color: _connectionState == BluetoothConnectionState.connected
                      ? Colors.green
                      : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled),
            onPressed: () async {
              await _bleService.disconnect();
              if (!context.mounted) return;
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            _buildStatusCard(),
            _buildLocationCard(),
            _buildMapCard(),
            _buildConfigurationCard(),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _phoneController.dispose();
    _locationSubscription?.cancel();
    _statusSubscription?.cancel();
    _connectionSubscription?.cancel();
    _phoneLocationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}