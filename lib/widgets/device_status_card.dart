import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../services/bluetooth_service.dart' as bike_ble;

class DeviceStatusCard extends StatefulWidget {
  const DeviceStatusCard({super.key});

  @override
  State<DeviceStatusCard> createState() => _DeviceStatusCardState();
}

class _DeviceStatusCardState extends State<DeviceStatusCard> {
  final bike_ble.BikeBluetoothService _bleService = bike_ble.BikeBluetoothService();
  StreamSubscription? _statusSubscription;
  Map<String, dynamic>? _deviceStatus;
  bool _isRefreshing = false;
  
  @override
  void initState() {
    super.initState();
    _subscribeToStatus();
    // Only do initial refresh, rely on stream for updates
    _refreshStatus();
  }
  
  void _subscribeToStatus() {
    _statusSubscription = _bleService.deviceStatus.listen((status) {
      if (mounted) {
        setState(() {
          _deviceStatus = status;
          _isRefreshing = false; // Clear refreshing state on new data
        });
      }
    });
  }
  
  Future<void> _refreshStatus() async {
    if (!mounted) return;
    
    setState(() => _isRefreshing = true);
    
    try {
      final status = await _bleService.readDeviceStatus();
      if (mounted && status != null) {
        setState(() => _deviceStatus = status);
      }
    } catch (e) {
      developer.log('Error refreshing status: $e', name: 'DeviceStatus');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }
  
  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sensors,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Device Status',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: _isRefreshing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : const Icon(Icons.refresh),
                  onPressed: _isRefreshing ? null : _refreshStatus,
                  iconSize: 20,
                ),
              ],
            ),
            const Divider(),
            
            if (_deviceStatus == null) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.sync_disabled,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No status data available',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // User Presence (IR Sensor)
              _buildStatusItem(
                icon: Icons.person_outline,
                label: 'User Presence (IR)',
                value: (_deviceStatus!['user'] ?? _deviceStatus!['user_present']) == true ? 'Detected' : 'Not Detected',
                valueColor: (_deviceStatus!['user'] ?? _deviceStatus!['user_present']) == true 
                  ? theme.colorScheme.primary 
                  : Colors.orange,
              ),
              
              // Device Mode - prominent display
              if (_deviceStatus!.containsKey('mode')) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getColorForMode(_deviceStatus!['mode']).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getColorForMode(_deviceStatus!['mode']),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getIconForMode(_deviceStatus!['mode']),
                        color: _getColorForMode(_deviceStatus!['mode']),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Status: ${_getDisplayMode(_deviceStatus!['mode'])}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: _getColorForMode(_deviceStatus!['mode']),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              
              const Divider(),
              
              // Configuration Status
              _buildStatusItem(
                icon: Icons.phone,
                label: 'Phone Config',
                value: _deviceStatus!['phone_configured'] == true 
                  ? (_deviceStatus!['phone'] ?? 'Set')
                  : 'Not Set',
                valueColor: _deviceStatus!['phone_configured'] == true
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              ),
              
              _buildStatusItem(
                icon: Icons.timer,
                label: 'Update Interval',
                value: '${_deviceStatus!['interval'] ?? 300} seconds',
              ),
              
              _buildStatusItem(
                icon: Icons.notifications,
                label: 'SMS Alerts',
                value: _deviceStatus!['alerts'] == true ? 'Enabled' : 'Disabled',
                valueColor: _deviceStatus!['alerts'] == true
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              ),
              
              // Last Config Time
              if (_deviceStatus!.containsKey('last_config_time') && 
                  _deviceStatus!['last_config_time'] != null && 
                  _deviceStatus!['last_config_time'] > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Last configured: ${_formatTimestamp(_deviceStatus!['last_config_time'])}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
  
  Color _getColorForMode(String? mode) {
    final theme = Theme.of(context);
    switch (mode) {
      case 'READY':
        return Colors.green;
      case 'AWAY':
        return Colors.orange;
      case 'DISCONNECTED':
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.onSurface;
    }
  }
  
  IconData _getIconForMode(String? mode) {
    switch (mode) {
      case 'READY':
        return Icons.check_circle;
      case 'AWAY':
        return Icons.warning;
      case 'DISCONNECTED':
        return Icons.wifi_off;
      default:
        return Icons.help_outline;
    }
  }
  
  String _getDisplayMode(String? mode) {
    switch (mode) {
      case 'READY':
        return 'Ready to Ride';
      case 'AWAY':
        return 'User Away';
      case 'DISCONNECTED':
        return 'Disconnected';
      default:
        return mode ?? 'Unknown';
    }
  }
  
  String _formatTimestamp(int timestamp) {
    // Convert milliseconds to time ago format
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - timestamp;
    
    if (diff < 60000) {
      return 'Just now';
    } else if (diff < 3600000) {
      final minutes = diff ~/ 60000;
      return '$minutes minute${minutes > 1 ? 's' : ''} ago';
    } else if (diff < 86400000) {
      final hours = diff ~/ 3600000;
      return '$hours hour${hours > 1 ? 's' : ''} ago';
    } else {
      final days = diff ~/ 86400000;
      return '$days day${days > 1 ? 's' : ''} ago';
    }
  }
  
  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }
}