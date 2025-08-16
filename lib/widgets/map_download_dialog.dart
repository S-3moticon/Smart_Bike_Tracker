import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/map_download_service.dart';
import 'dart:developer' as developer;

class MapDownloadDialog extends StatefulWidget {
  final LatLng? currentLocation;
  final String tileUrl;
  
  const MapDownloadDialog({
    super.key,
    this.currentLocation,
    required this.tileUrl,
  });
  
  @override
  State<MapDownloadDialog> createState() => _MapDownloadDialogState();
}

class _MapDownloadDialogState extends State<MapDownloadDialog> {
  final MapDownloadService _downloadService = MapDownloadService();
  double _radiusKm = 5.0;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusMessage = '';
  Map<String, dynamic>? _offlineMapInfo;
  
  @override
  void initState() {
    super.initState();
    _loadOfflineMapInfo();
  }
  
  Future<void> _loadOfflineMapInfo() async {
    final info = await _downloadService.getOfflineMapInfo();
    setState(() {
      _offlineMapInfo = info;
    });
  }
  
  Future<void> _startDownload() async {
    if (widget.currentLocation == null) {
      _showError('No location available. Please wait for GPS fix.');
      return;
    }
    
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusMessage = 'Calculating tiles...';
    });
    
    final tileCount = await _downloadService.calculateTileCount(
      widget.currentLocation!,
      _radiusKm,
    );
    
    setState(() {
      _statusMessage = 'Downloading $tileCount tiles...';
    });
    
    await _downloadService.downloadMapArea(
      center: widget.currentLocation!,
      radiusKm: _radiusKm,
      tileUrl: widget.tileUrl,
      onProgress: (progress) {
        setState(() {
          _downloadProgress = progress;
          _statusMessage = 'Downloading: ${(progress * 100).toStringAsFixed(1)}%';
        });
      },
      onComplete: () async {
        await _loadOfflineMapInfo();
        setState(() {
          _isDownloading = false;
          _statusMessage = 'Download complete!';
        });
        developer.log('Map download completed', name: 'MapDownload');
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline map downloaded successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      onError: (error) {
        setState(() {
          _isDownloading = false;
          _statusMessage = 'Error: $error';
        });
        _showError(error);
      },
    );
  }
  
  void _cancelDownload() {
    _downloadService.cancelDownload();
    setState(() {
      _isDownloading = false;
      _statusMessage = 'Download cancelled';
    });
  }
  
  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Offline Maps'),
        content: const Text('This will delete all downloaded offline map tiles. Continue?'),
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
      await _downloadService.clearOfflineCache();
      await _loadOfflineMapInfo();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline cache cleared')),
        );
      }
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLocation = widget.currentLocation != null;
    
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.download_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Download Offline Maps'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current offline map info
            if (_offlineMapInfo != null && _offlineMapInfo!['exists']) ...[
              Card(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Offline maps available',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_offlineMapInfo!['tileCount']} tiles, '
                              '${_offlineMapInfo!['sizeInMB'].toStringAsFixed(1)} MB',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Location status
            if (!hasLocation) ...[
              Card(
                color: theme.colorScheme.errorContainer.withOpacity(0.3),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_off,
                        color: theme.colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Waiting for location...',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Card(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Download center',
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              'Lat: ${widget.currentLocation!.latitude.toStringAsFixed(4)}, '
                              'Lng: ${widget.currentLocation!.longitude.toStringAsFixed(4)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Radius selector
            Text(
              'Download radius: ${_radiusKm.toStringAsFixed(0)} km',
              style: theme.textTheme.bodyMedium,
            ),
            Slider(
              value: _radiusKm,
              min: 1,
              max: 20,
              divisions: 19,
              label: '${_radiusKm.toStringAsFixed(0)} km',
              onChanged: _isDownloading ? null : (value) {
                setState(() {
                  _radiusKm = value;
                });
              },
            ),
            
            Text(
              'Larger radius = more storage space required',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            
            // Download progress
            if (_isDownloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                style: theme.textTheme.bodySmall,
              ),
            ] else if (_statusMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _statusMessage.startsWith('Error') 
                    ? theme.colorScheme.error 
                    : theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        // Clear cache button
        if (_offlineMapInfo != null && _offlineMapInfo!['exists'] && !_isDownloading)
          TextButton.icon(
            onPressed: _clearCache,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Clear'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
          ),
        
        // Cancel/Close button
        TextButton(
          onPressed: _isDownloading ? _cancelDownload : () => Navigator.pop(context),
          child: Text(_isDownloading ? 'Cancel' : 'Close'),
        ),
        
        // Download button
        if (!_isDownloading)
          ElevatedButton.icon(
            onPressed: hasLocation ? _startDownload : null,
            icon: const Icon(Icons.download),
            label: const Text('Download'),
          ),
      ],
    );
  }
}