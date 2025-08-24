import 'package:flutter/material.dart';
import '../models/location_data.dart';

/// Optimized GPS history list view
class GpsHistoryView extends StatelessWidget {
  final String title;
  final List<LocationData>? locations;
  final List<Map<String, dynamic>>? mcuHistory;
  final bool isPhone;
  final Function(LocationData) onLocationTap;
  final VoidCallback? onClear;
  final VoidCallback? onRefresh;
  
  const GpsHistoryView({
    super.key,
    required this.title,
    this.locations,
    this.mcuHistory,
    required this.isPhone,
    required this.onLocationTap,
    this.onClear,
    this.onRefresh,
  });
  
  @override
  Widget build(BuildContext context) {
    final itemCount = isPhone 
        ? (locations?.length ?? 0)
        : (mcuHistory?.length ?? 0);
    
    if (itemCount == 0) {
      return _buildEmptyState(context);
    }
    
    return Column(
      children: [
        _buildHeader(context, itemCount),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              onRefresh?.call();
            },
            child: ListView.builder(
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (isPhone) {
                  return _buildPhoneLocationTile(context, locations![index]);
                } else {
                  return _buildMcuLocationTile(context, mcuHistory![index]);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off,
            size: 64,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No GPS history available',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (onRefresh != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Text(
            '$title ($count points)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          if (onClear != null && count > 0)
            IconButton(
              onPressed: () => _confirmClear(context),
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear History',
            ),
          if (onRefresh != null)
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
        ],
      ),
    );
  }
  
  Widget _buildPhoneLocationTile(BuildContext context, LocationData location) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.phone_android, color: Colors.white),
        ),
        title: Text(
          '${location.latitude.toStringAsFixed(6)}, '
          '${location.longitude.toStringAsFixed(6)}',
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Accuracy: ±${location.accuracy.toStringAsFixed(1)}m'),
            Text(_formatTimestamp(location.timestamp.millisecondsSinceEpoch ~/ 1000)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.map),
          onPressed: () => onLocationTap(location),
        ),
      ),
    );
  }
  
  Widget _buildMcuLocationTile(BuildContext context, Map<String, dynamic> location) {
    final lat = location['lat']?.toDouble() ?? 0.0;
    final lng = location['lng']?.toDouble() ?? location['lon']?.toDouble() ?? 0.0;
    final timestamp = location['time'] ?? location['timestamp'] ?? 0;
    final source = location['src'] ?? location['source'] ?? 0;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getSourceColor(source),
          child: Icon(
            _getSourceIcon(source),
            color: Colors.white,
          ),
        ),
        title: Text(
          '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Source: ${_getSourceName(source)}'),
            Text(_formatTimestamp(timestamp)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.map),
          onPressed: () {
            final locationData = LocationData(
              latitude: lat,
              longitude: lng,
              accuracy: 10.0,
              timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
              source: _getSourceName(source),
            );
            onLocationTap(locationData);
          },
        ),
      ),
    );
  }
  
  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: Text('Are you sure you want to clear all $title?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onClear?.call();
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
  
  String _formatTimestamp(int timestamp) {
    if (timestamp == 0) return 'Unknown time';
    
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    
    return '${date.day}/${date.month}/${date.year}';
  }
  
  Color _getSourceColor(int source) {
    switch (source) {
      case 0: return Colors.blue;      // Phone GPS
      case 1: return Colors.orange;    // SIM7070G Direct
      case 2: return Colors.green;     // SIM7070G Periodic
      default: return Colors.grey;
    }
  }
  
  IconData _getSourceIcon(int source) {
    switch (source) {
      case 0: return Icons.phone_android;
      case 1: return Icons.gps_fixed;
      case 2: return Icons.timer;
      default: return Icons.location_on;
    }
  }
  
  String _getSourceName(int source) {
    switch (source) {
      case 0: return 'Phone GPS';
      case 1: return 'SIM7070G';
      case 2: return 'Periodic Update';
      default: return 'Unknown';
    }
  }
}