import 'dart:io';
import 'dart:math' as math;
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:latlong2/latlong.dart';

class MapDownloadService {
  static const int _minZoom = 10;
  static const int _maxZoom = 16;
  
  final Dio _dio = Dio();
  bool _isDownloading = false;
  int _totalTiles = 0;
  int _downloadedTiles = 0;
  CancelToken? _cancelToken;
  
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _totalTiles > 0 ? _downloadedTiles / _totalTiles : 0.0;
  
  Future<String> get _cacheDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final mapCacheDir = Directory('${appDir.path}/offline_maps');
    if (!await mapCacheDir.exists()) {
      await mapCacheDir.create(recursive: true);
    }
    return mapCacheDir.path;
  }
  
  Future<int> calculateTileCount(LatLng center, double radiusKm) async {
    int totalTiles = 0;
    
    for (int zoom = _minZoom; zoom <= _maxZoom; zoom++) {
      final bounds = _getBoundsForRadius(center, radiusKm, zoom);
      final tileCount = (bounds['maxX']! - bounds['minX']! + 1) * 
                       (bounds['maxY']! - bounds['minY']! + 1);
      totalTiles += tileCount;
    }
    
    return totalTiles;
  }
  
  Future<void> downloadMapArea({
    required LatLng center,
    required double radiusKm,
    required String tileUrl,
    required Function(double) onProgress,
    required Function() onComplete,
    required Function(String) onError,
  }) async {
    if (_isDownloading) {
      onError('Download already in progress');
      return;
    }
    
    _isDownloading = true;
    _downloadedTiles = 0;
    _totalTiles = await calculateTileCount(center, radiusKm);
    _cancelToken = CancelToken();
    
    developer.log('Starting download of $_totalTiles tiles for center: ${center.latitude}, ${center.longitude}', name: 'MapDownload');
    
    try {
      final cacheDir = await _cacheDirectory;
      
      for (int zoom = _minZoom; zoom <= _maxZoom; zoom++) {
        if (_cancelToken?.isCancelled ?? false) break;
        
        final bounds = _getBoundsForRadius(center, radiusKm, zoom);
        developer.log('Zoom $zoom bounds: X[${bounds['minX']}-${bounds['maxX']}], Y[${bounds['minY']}-${bounds['maxY']}]', 
                     name: 'MapDownload');
        
        for (int x = bounds['minX']!; x <= bounds['maxX']!; x++) {
          for (int y = bounds['minY']!; y <= bounds['maxY']!; y++) {
            if (_cancelToken?.isCancelled ?? false) break;
            
            final url = tileUrl
                .replaceAll('{z}', zoom.toString())
                .replaceAll('{x}', x.toString())
                .replaceAll('{y}', y.toString());
            
            final tilePath = '$cacheDir/$zoom/$x/$y.png';
            final tileFile = File(tilePath);
            
            // Skip if already exists
            if (await tileFile.exists()) {
              _downloadedTiles++;
              onProgress(downloadProgress);
              continue;
            }
            
            // Create directory structure
            await tileFile.parent.create(recursive: true);
            
            // Download tile
            try {
              final response = await _dio.get(
                url,
                options: Options(
                  responseType: ResponseType.bytes,
                  headers: {
                    'User-Agent': 'SmartBikeTracker/1.0',
                  },
                  validateStatus: (status) {
                    return status != null && status < 500;
                  },
                ),
                cancelToken: _cancelToken,
              );
              
              if (response.statusCode == 200 && response.data != null) {
                await tileFile.writeAsBytes(response.data);
                _downloadedTiles++;
                onProgress(downloadProgress);
              } else {
                developer.log('Tile $x,$y at zoom $zoom returned status ${response.statusCode}', 
                            name: 'MapDownload');
                _downloadedTiles++; // Count as processed even if failed
                onProgress(downloadProgress);
              }
              
              // Small delay to avoid overwhelming the server
              await Future.delayed(const Duration(milliseconds: 50));
            } catch (e) {
              developer.log('Error downloading tile $zoom/$x/$y from $url: $e', 
                          name: 'MapDownload');
              _downloadedTiles++; // Count as processed even if failed
              onProgress(downloadProgress);
            }
          }
        }
      }
      
      if (!(_cancelToken?.isCancelled ?? false)) {
        onComplete();
      }
    } catch (e) {
      onError('Download failed: $e');
      developer.log('Download error: $e', name: 'MapDownload');
    } finally {
      _isDownloading = false;
      _cancelToken = null;
    }
  }
  
  void cancelDownload() {
    _cancelToken?.cancel('User cancelled');
    _isDownloading = false;
  }
  
  Future<Map<String, dynamic>> getOfflineMapInfo() async {
    final cacheDir = await _cacheDirectory;
    final dir = Directory(cacheDir);
    
    if (!await dir.exists()) {
      return {'exists': false, 'tileCount': 0, 'sizeInMB': 0.0};
    }
    
    int tileCount = 0;
    int totalSize = 0;
    
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.png')) {
        tileCount++;
        totalSize += await entity.length();
      }
    }
    
    return {
      'exists': tileCount > 0,
      'tileCount': tileCount,
      'sizeInMB': totalSize / (1024 * 1024),
    };
  }
  
  Future<void> clearOfflineCache() async {
    final cacheDir = await _cacheDirectory;
    final dir = Directory(cacheDir);
    
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      developer.log('Offline cache cleared', name: 'MapDownload');
    }
  }
  
  Map<String, int> _getBoundsForRadius(LatLng center, double radiusKm, int zoom) {
    // Calculate tile bounds for given radius
    final lat = center.latitude;
    final lng = center.longitude;
    
    // Approximate degrees per km
    const kmPerDegreeLat = 111.0;
    final kmPerDegreeLng = kmPerDegreeLat * math.cos(lat * (math.pi / 180));
    
    final latDelta = radiusKm / kmPerDegreeLat;
    final lngDelta = radiusKm / kmPerDegreeLng;
    
    final minLat = lat - latDelta;
    final maxLat = lat + latDelta;
    final minLng = lng - lngDelta;
    final maxLng = lng + lngDelta;
    
    // Convert to tile coordinates
    final minX = _lngToTileX(minLng, zoom);
    final maxX = _lngToTileX(maxLng, zoom);
    final minY = _latToTileY(maxLat, zoom); // Note: Y is inverted
    final maxY = _latToTileY(minLat, zoom);
    
    // Ensure bounds are within valid tile ranges
    final maxTileIndex = math.pow(2, zoom).toInt() - 1;
    
    return {
      'minX': math.max(0, minX),
      'maxX': math.min(maxTileIndex, maxX),
      'minY': math.max(0, minY),
      'maxY': math.min(maxTileIndex, maxY),
    };
  }
  
  int _lngToTileX(double lng, int zoom) {
    // Ensure longitude is within valid range
    lng = lng.clamp(-180, 180);
    return ((lng + 180.0) / 360.0 * math.pow(2, zoom)).floor();
  }
  
  int _latToTileY(double lat, int zoom) {
    // Ensure latitude is within valid Web Mercator range
    lat = lat.clamp(-85.05112878, 85.05112878);
    final latRad = lat * math.pi / 180.0;
    return ((1.0 - math.log(math.tan(latRad) + (1 / math.cos(latRad))) / math.pi) / 2.0 * math.pow(2, zoom)).floor();
  }
}