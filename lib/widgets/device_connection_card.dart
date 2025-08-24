import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/bike_device.dart';

/// Optimized device connection card widget
class DeviceConnectionCard extends StatelessWidget {
  final BluetoothConnectionState connectionState;
  final BikeDevice? currentDevice;
  final Map<String, dynamic>? deviceStatus;
  final bool isScanning;
  final List<BikeDevice> availableDevices;
  final Function(BikeDevice) onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onStartScan;
  final VoidCallback onStopScan;
  
  const DeviceConnectionCard({
    super.key,
    required this.connectionState,
    required this.currentDevice,
    required this.deviceStatus,
    required this.isScanning,
    required this.availableDevices,
    required this.onConnect,
    required this.onDisconnect,
    required this.onStartScan,
    required this.onStopScan,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildConnectionHeader(context),
            if (connectionState == BluetoothConnectionState.disconnected)
              _buildDeviceList(context),
            if (connectionState == BluetoothConnectionState.connected)
              _buildDeviceStatus(context),
          ],
        ),
      ),
    );
  }
  
  Widget _buildConnectionHeader(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Icon(
          _getConnectionIcon(),
          color: _getConnectionColor(theme),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getConnectionTitle(),
                style: theme.textTheme.titleMedium,
              ),
              if (currentDevice != null)
                Text(
                  currentDevice!.name,
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
        _buildActionButton(context),
      ],
    );
  }
  
  Widget _buildActionButton(BuildContext context) {
    switch (connectionState) {
      case BluetoothConnectionState.connected:
        return TextButton(
          onPressed: onDisconnect,
          child: const Text('Disconnect'),
        );
        
        
      case BluetoothConnectionState.disconnected:
        return TextButton(
          onPressed: isScanning ? onStopScan : onStartScan,
          child: Text(isScanning ? 'Stop Scan' : 'Scan'),
        );
        
      default:
        return const SizedBox.shrink();
    }
  }
  
  Widget _buildDeviceList(BuildContext context) {
    if (!isScanning && availableDevices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Press Scan to find devices'),
      );
    }
    
    if (isScanning && availableDevices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            CircularProgressIndicator.adaptive(),
            SizedBox(height: 8),
            Text('Scanning for devices...'),
          ],
        ),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: availableDevices.length,
      itemBuilder: (context, index) {
        final device = availableDevices[index];
        return ListTile(
          leading: Icon(
            Icons.bluetooth,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(device.name),
          subtitle: Text('Signal: ${device.rssi} dBm'),
          trailing: TextButton(
            onPressed: () => onConnect(device),
            child: const Text('Connect'),
          ),
        );
      },
    );
  }
  
  Widget _buildDeviceStatus(BuildContext context) {
    if (deviceStatus == null) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('Waiting for device status...'),
      );
    }
    
    final phoneConfigured = deviceStatus!['phone_configured'] ?? false;
    final alertsEnabled = deviceStatus!['alerts'] ?? false;
    final userPresent = deviceStatus!['user_present'] ?? false;
    final mode = deviceStatus!['mode'] ?? 'Unknown';
    
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _buildStatusRow('Mode', mode, _getModeIcon(mode)),
          _buildStatusRow('User', userPresent ? 'Present' : 'Away', 
              userPresent ? Icons.person : Icons.person_off),
          _buildStatusRow('SMS Alerts', 
              phoneConfigured ? (alertsEnabled ? 'Active' : 'Disabled') : 'Not Configured',
              alertsEnabled && phoneConfigured ? Icons.message : Icons.message_outlined),
        ],
      ),
    );
  }
  
  Widget _buildStatusRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text('$label: '),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  IconData _getConnectionIcon() {
    switch (connectionState) {
      case BluetoothConnectionState.connected:
        return Icons.bluetooth_connected;
      default:
        return Icons.bluetooth_disabled;
    }
  }
  
  Color _getConnectionColor(ThemeData theme) {
    switch (connectionState) {
      case BluetoothConnectionState.connected:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
  
  String _getConnectionTitle() {
    switch (connectionState) {
      case BluetoothConnectionState.connected:
        return 'Connected';
      default:
        return 'Disconnected';
    }
  }
  
  IconData _getModeIcon(String mode) {
    switch (mode.toUpperCase()) {
      case 'READY':
        return Icons.check_circle;
      case 'AWAY':
        return Icons.directions_walk;
      case 'DISCONNECTED':
        return Icons.link_off;
      default:
        return Icons.help_outline;
    }
  }
}