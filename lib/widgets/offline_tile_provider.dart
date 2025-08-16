import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;

class OfflineTileProvider extends TileProvider {
  final String fallbackUrl;
  String? _cacheDirectory;
  
  OfflineTileProvider({required this.fallbackUrl});
  
  Future<String> get cacheDirectory async {
    if (_cacheDirectory != null) return _cacheDirectory!;
    
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDirectory = '${appDir.path}/offline_maps';
    return _cacheDirectory!;
  }
  
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return OfflineImageProvider(
      coordinates: coordinates,
      cacheDirectoryFuture: cacheDirectory,
      fallbackUrl: fallbackUrl
        .replaceAll('{z}', coordinates.z.toString())
        .replaceAll('{x}', coordinates.x.toString())
        .replaceAll('{y}', coordinates.y.toString()),
    );
  }
}

class OfflineImageProvider extends ImageProvider<OfflineImageProvider> {
  final TileCoordinates coordinates;
  final Future<String> cacheDirectoryFuture;
  final String fallbackUrl;
  
  const OfflineImageProvider({
    required this.coordinates,
    required this.cacheDirectoryFuture,
    required this.fallbackUrl,
  });
  
  @override
  Future<OfflineImageProvider> obtainKey(ImageConfiguration configuration) {
    return Future.value(this);
  }
  
  @override
  ImageStreamCompleter loadImage(OfflineImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
    );
  }
  
  Future<ui.Codec> _loadAsync(OfflineImageProvider key, ImageDecoderCallback decode) async {
    try {
      // Try to load from offline cache first
      final cacheDir = await cacheDirectoryFuture;
      final tilePath = '$cacheDir/${coordinates.z}/${coordinates.x}/${coordinates.y}.png';
      final tileFile = File(tilePath);
      
      if (await tileFile.exists()) {
        final bytes = await tileFile.readAsBytes();
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        return decode(buffer);
      }
    } catch (e) {
      developer.log('Failed to load offline tile: $e', name: 'OfflineTileProvider');
    }
    
    // Fallback to network if offline tile not found
    try {
      final HttpClient httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(fallbackUrl));
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    } catch (e) {
      developer.log('Failed to load network tile: $e', name: 'OfflineTileProvider');
      // Return a transparent image as fallback
      final transparentPixel = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
      ]);
      final buffer = await ui.ImmutableBuffer.fromUint8List(transparentPixel);
      return decode(buffer);
    }
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! OfflineImageProvider) return false;
    return coordinates == other.coordinates && fallbackUrl == other.fallbackUrl;
  }
  
  @override
  int get hashCode => Object.hash(coordinates, fallbackUrl);
}