import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../services/bluetooth_service.dart' as bike_ble;
import '../models/bike_device.dart';

class DeviceScanScreen extends StatefulWidget {
  const DeviceScanScreen({super.key});

  @override
  State<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends State<DeviceScanScreen> {
  final bike_ble.BikeBluetoothService _bleService = bike_ble.BikeBluetoothService();
  bool _isScanning = false;
  bool _bluetoothAvailable = false;
  List<BikeDevice> _devices = [];
  String? _connectingDeviceId;
  
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _adapterStateSubscription;
  
  @override
  void initState() {
    super.initState();
    _initBluetooth();
    _setupListeners();
  }
  
  Future<void> _initBluetooth() async {
    final available = await _bleService.checkBluetoothAvailability();
    setState(() {
      _bluetoothAvailable = available;
    });
    
    if (available) {
      _startScan();
    }
    
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      setState(() {
        _bluetoothAvailable = state == BluetoothAdapterState.on;
      });
      
      if (state == BluetoothAdapterState.on && !_isScanning) {
        _startScan();
      }
    });
  }
  
  void _setupListeners() {
    _scanSubscription = _bleService.scanResults.listen((devices) {
      setState(() {
        _devices = devices;
      });
    });
    
    _connectionSubscription = _bleService.connectionState.listen((state) {
      if (state == BluetoothConnectionState.connected) {
        setState(() {
          _connectingDeviceId = null;
        });
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else if (state == BluetoothConnectionState.disconnected) {
        setState(() {
          _connectingDeviceId = null;
        });
      }
    });
  }
  
  Future<void> _startScan() async {
    if (!_bluetoothAvailable || _isScanning) return;
    
    setState(() {
      _isScanning = true;
      _devices = [];
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
      developer.log('Error starting scan: $e', name: 'DeviceScan');
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start scan: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to connect to device'),
        ),
      );
    }
  }
  
  Widget _buildDeviceTile(BikeDevice device) {
    final isConnecting = _connectingDeviceId == device.id;
    final theme = Theme.of(context);
    
    return Card(
      elevation: device.isBikeTracker ? 3 : 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              device.isBikeTracker ? Icons.directions_bike : Icons.bluetooth,
              color: device.isBikeTracker 
                ? theme.colorScheme.primary 
                : theme.colorScheme.onSurfaceVariant,
              size: 32,
            ),
            if (isConnecting)
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        title: Text(
          device.name,
          style: TextStyle(
            fontWeight: device.isBikeTracker ? FontWeight.bold : FontWeight.normal,
            color: device.isBikeTracker 
              ? theme.colorScheme.primary 
              : theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              device.id,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildSignalStrength(device.signalStrength),
                const SizedBox(width: 8),
                Text(
                  '${device.rssi} dBm',
                  style: theme.textTheme.bodySmall,
                ),
                if (device.isBikeTracker) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Bike Tracker',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: device.isBikeTracker 
          ? ElevatedButton(
              onPressed: isConnecting ? null : () => _connectToDevice(device),
              child: isConnecting 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Connect'),
            )
          : null,
        onTap: device.isBikeTracker && !isConnecting 
          ? () => _connectToDevice(device) 
          : null,
      ),
    );
  }
  
  Widget _buildSignalStrength(int strength) {
    return Row(
      children: List.generate(4, (index) {
        return Icon(
          Icons.signal_cellular_4_bar,
          size: 12,
          color: index < strength 
            ? Theme.of(context).colorScheme.primary 
            : Theme.of(context).colorScheme.outlineVariant,
        );
      }),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Your Bike Tracker'),
        actions: [
          if (_bluetoothAvailable)
            IconButton(
              icon: _isScanning 
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : const Icon(Icons.refresh),
              onPressed: _isScanning ? null : _startScan,
            ),
        ],
      ),
      body: !_bluetoothAvailable
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bluetooth_disabled,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Bluetooth is disabled',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please enable Bluetooth to scan for devices',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    await FlutterBluePlus.turnOn();
                  },
                  child: const Text('Enable Bluetooth'),
                ),
              ],
            ),
          )
        : _devices.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isScanning) ...[
                    const CircularProgressIndicator(strokeWidth: 3),
                    const SizedBox(height: 24),
                    Text(
                      'Scanning for devices...',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Make sure your bike tracker is powered on',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    Icon(
                      Icons.bluetooth_searching,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No devices found',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap refresh to scan again',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _startScan,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Scan Again'),
                    ),
                  ],
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _startScan,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _devices.length + (_isScanning ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isScanning && index == 0) {
                    return Container(
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
                            'Scanning...',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  }
                  
                  final deviceIndex = _isScanning ? index - 1 : index;
                  return _buildDeviceTile(_devices[deviceIndex]);
                },
              ),
            ),
    );
  }
  
  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _bleService.stopScan();
    super.dispose();
  }
}