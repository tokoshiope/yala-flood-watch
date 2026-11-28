import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

import 'package:yala_flood_app/services/disk_cache_stub.dart'
    if (dart.library.io) 'package:yala_flood_app/services/disk_cache_io.dart' as disk;

/// 1x1 transparent PNG used as graceful offline fallback when a tile is uncached and network is unavailable.
/// Keeps Yala's offline GeoJSON elevation zones, rivers, and administrative boundaries crisp without red errors.
final Uint8List _kTransparentTilePng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Verifies PNG, JPEG, or WebP magic bytes so captive-portal HTML 200 responses are never cached/decoded.
bool isValidTileImageBytes(Uint8List data) {
  if (data.length < 16) return false;
  // PNG: 89 50 4E 47
  if (data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47) {
    return true;
  }
  // JPEG: FF D8 FF
  if (data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF) {
    return true;
  }
  // WebP: RIFF....WEBP
  if (data[0] == 0x52 &&
      data[1] == 0x49 &&
      data[2] == 0x46 &&
      data[3] == 0x46 &&
      data[8] == 0x57 &&
      data[9] == 0x45 &&
      data[10] == 0x42 &&
      data[11] == 0x50) {
    return true;
  }
  return false;
}

/// Cross-platform Disk-caching TileProvider for CARTO/OSM tiles (iOS/macOS/Android disk cache + Web HTTPS).
/// - Validates image magic bytes + atomic write (.tmp -> rename)
/// - Guards decode() with automatic corrupt-file eviction + transparent fallback
/// - Async throttled eviction (every 25 writes; zero synchronous listSync() on main thread)
class CachingTileProvider extends TileProvider {
  CachingTileProvider({
    this.cacheSubdir = 'yala_map_tiles_v1',
    this.maxCachedTiles = 500,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String cacheSubdir;
  final int maxCachedTiles;
  final http.Client _client;
  int _writesSinceEvict = 0;
  bool _evicting = false;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    final styleTag = url.contains('dark_all') ? 'dark' : 'light';
    final cacheKey = '${styleTag}_${coordinates.z}_${coordinates.x}_${coordinates.y}.png';
    return _DiskCachedTileImage(
      url: url,
      cacheSubdir: cacheSubdir,
      cacheFilename: cacheKey,
      client: _client,
      headers: headers,
      onTileWritten: _maybeEvictAsync,
    );
  }

  void _maybeEvictAsync() {
    _writesSinceEvict++;
    if (_writesSinceEvict < 25 || _evicting || kIsWeb) return;
    _writesSinceEvict = 0;
    _evicting = true;
    unawaited(
      disk.evictTileCacheOverflow(cacheSubdir, maxCachedTiles).whenComplete(() {
        _evicting = false;
      }),
    );
  }

  /// Clear cached map tiles on disk (called by Settings → Clear Cache / PDPA wipe).
  static Future<void> clearDiskCache({String cacheSubdir = 'yala_map_tiles_v1'}) async {
    if (kIsWeb) return;
    await disk.clearTileCacheDir(cacheSubdir);
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

class _DiskCachedTileImage extends ImageProvider<_DiskCachedTileImage> {
  const _DiskCachedTileImage({
    required this.url,
    required this.cacheSubdir,
    required this.cacheFilename,
    required this.client,
    required this.headers,
    required this.onTileWritten,
  });

  final String url;
  final String cacheSubdir;
  final String cacheFilename;
  final http.Client client;
  final Map<String, String> headers;
  final VoidCallback onTileWritten;

  @override
  Future<_DiskCachedTileImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_DiskCachedTileImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _DiskCachedTileImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(decode),
      scale: 1.0,
      debugLabel: url,
    );
  }

  Future<ui.Codec> _decodeFallback(ImageDecoderCallback decode) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(_kTransparentTilePng);
    return decode(buffer);
  }

  Future<ui.Codec> _loadAsync(ImageDecoderCallback decode) async {
    Uint8List? bytes;
    var fromCache = false;

    // 1. Try local disk cache first on native platforms (instant offline rendering)
    if (!kIsWeb) {
      final cached = await disk.readTileFile(cacheSubdir, cacheFilename);
      if (cached != null) {
        if (isValidTileImageBytes(cached)) {
          bytes = cached;
          fromCache = true;
        } else {
          await disk.deleteTileFile(cacheSubdir, cacheFilename);
        }
      }
    }

    // 2. Fetch over HTTPS if not cached
    if (bytes == null) {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.scheme == 'https') {
        try {
          final resp = await client
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 8));
          if (resp.statusCode == 200 && isValidTileImageBytes(resp.bodyBytes)) {
            bytes = resp.bodyBytes;
            if (!kIsWeb) {
              unawaited(
                disk.writeTileFile(cacheSubdir, cacheFilename, bytes).then((ok) {
                  if (ok) onTileWritten();
                }),
              );
            }
          }
        } catch (_) {
          // Offline / timeout -> fall through to transparent tile
        }
      }
    }

    if (bytes == null) {
      return _decodeFallback(decode);
    }

    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return await decode(buffer);
    } catch (_) {
      if (fromCache && !kIsWeb) {
        await disk.deleteTileFile(cacheSubdir, cacheFilename);
      }
      return _decodeFallback(decode);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _DiskCachedTileImage && other.url == url);

  @override
  int get hashCode => url.hashCode;
}
