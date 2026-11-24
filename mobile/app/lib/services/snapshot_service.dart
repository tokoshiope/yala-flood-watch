import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/models/flood_snapshot.dart';

/// Phase 2 Cloud Bridge: โหลด Snapshot รวม 5 ฐานข้อมูลจาก CDN (พร้อมตรวจ manifest.json content_hash แบบ Fail-Closed)
/// เก็บแคชในเครื่อง (AppConfig.cacheSnapshotKey) พร้อม Fallback ไปยัง Bundled Offline Asset + โหลดขอบเขต GeoJSON
class SnapshotService {
  SnapshotService({
    http.Client? client,
    SharedPreferences? preferences,
    String? cdnBaseUrlOverride,
  })  : _client = client ?? http.Client(),
        // ignore: prefer_initializing_formals
        _preferences = preferences,
        // ignore: prefer_initializing_formals
        _cdnBaseUrlOverride = cdnBaseUrlOverride;

  final http.Client _client;
  final SharedPreferences? _preferences;
  final String? _cdnBaseUrlOverride;

  String get _normalizedBaseUrl {
    final base = (_cdnBaseUrlOverride ?? AppConfig.snapshotCdnBaseUrl).trim();
    return base.replaceAll(RegExp(r'/+$'), '');
  }

  String get _latestUrl {
    final base = _normalizedBaseUrl;
    return base.isEmpty ? '' : '$base/latest.json';
  }

  String get _manifestUrl {
    final base = _normalizedBaseUrl;
    return base.isEmpty ? '' : '$base/manifest.json';
  }

  /// ตรวจความสมบูรณ์ของ Snapshot แบบ Fail-Closed:
  /// - ต้องเป็น จ.ยะลา (province_code = 95) ครบทั้ง 8 อำเภอ
  /// - หากมีรายการสถานี พิกัดต้องเป็นตัวเลขและอยู่ในขอบเขต จ.ยะลา (lat 5.5–7.2, lon 100.5–101.9)
  /// - content_hash ต้องตรงกับ manifest.json
  static bool isValidYalaSnapshot(
    Map<String, dynamic> latest, {
    String? expectedManifestHash,
  }) {
    final prov = latest['province'];
    if (prov is! Map || prov['code']?.toString() != AppConfig.provinceCode) {
      return false;
    }
    final amphoes = latest['amphoes'];
    if (amphoes is! List || amphoes.length != 8) {
      return false;
    }
    final stations = latest['stations'];
    if (stations is List) {
      for (final item in stations) {
        if (item is! Map) continue;
        final rawLat = item['lat'];
        final rawLon = item['lon'];
        if (rawLat != null) {
          if (rawLat is! num) return false;
          final lat = rawLat.toDouble();
          if (lat.isNaN || lat < 5.5 || lat > 7.2) return false;
        }
        if (rawLon != null) {
          if (rawLon is! num) return false;
          final lon = rawLon.toDouble();
          if (lon.isNaN || lon < 100.5 || lon > 101.9) return false;
        }
      }
    }
    final snapHash = latest['content_hash']?.toString() ?? '';
    if (expectedManifestHash != null &&
        (expectedManifestHash.isEmpty || snapHash != expectedManifestHash)) {
      return false;
    }
    return true;
  }

  /// โหลดเฉพาะ Snapshot ในเครื่อง (Cache หรือ Bundled Asset) ทันทีโดยไม่รอเน็ต
  Future<FloodSnapshot?> loadCachedOrBundledSnapshot() async {
    final cachedRaw = _preferences?.getString(AppConfig.cacheSnapshotKey);
    if (cachedRaw != null && cachedRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(cachedRaw);
        if (decoded is Map<String, dynamic> && isValidYalaSnapshot(decoded)) {
          return FloodSnapshot.fromJson(
            decoded,
            sourceLabel: 'Cached 5-Source Snapshot',
          );
        }
      } catch (_) {
        // fail-closed: ignore corrupted cache and fallback to bundled asset
      }
    }

    try {
      final raw = await rootBundle.loadString(AppConfig.bundledSnapshotAsset);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && isValidYalaSnapshot(decoded)) {
        return FloodSnapshot.fromJson(
          decoded,
          sourceLabel: 'Bundled 5-Source Snapshot',
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<FloodSnapshot?> loadSnapshot() async {
    // 1. ถ้าตั้งค่า Supabase Storage CDN URL (HTTPS เท่านั้น) ให้ดึง manifest.json + latest.json พร้อมกันแบบขนาน + Fail-Closed
    final latestUrl = _latestUrl;
    final manifestUrl = _manifestUrl;
    if (latestUrl.isNotEmpty && manifestUrl.isNotEmpty) {
      final manifestUri = Uri.tryParse(manifestUrl);
      final latestUri = Uri.tryParse(latestUrl);
      if (manifestUri != null &&
          latestUri != null &&
          manifestUri.scheme == 'https' &&
          latestUri.scheme == 'https') {
        try {
          const headers = {'accept': 'application/json'};
          final responses = await Future.wait<http.Response>([
            _client
                .get(manifestUri, headers: headers)
                .timeout(AppConfig.networkTimeout),
            _client
                .get(latestUri, headers: headers)
                .timeout(AppConfig.networkTimeout),
          ]);
          final manResp = responses[0];
          final snapResp = responses[1];
          if (manResp.statusCode == 200 && snapResp.statusCode == 200) {
            final manText = utf8.decode(manResp.bodyBytes);
            final snapText = utf8.decode(snapResp.bodyBytes);
            final manDecoded = jsonDecode(manText);
            final snapDecoded = jsonDecode(snapText);
            if (manDecoded is Map<String, dynamic> &&
                snapDecoded is Map<String, dynamic>) {
              final expectedHash = manDecoded['content_hash']?.toString() ?? '';
              if (isValidYalaSnapshot(
                snapDecoded,
                expectedManifestHash: expectedHash,
              )) {
                await _preferences?.setString(
                  AppConfig.cacheSnapshotKey,
                  snapText,
                );
                return FloodSnapshot.fromJson(
                  snapDecoded,
                  sourceLabel: 'Supabase CDN (5 Sources)',
                );
              }
            }
          }
        } catch (_) {
          // Fail-closed: do not overwrite valid cached/bundled snapshot with corrupt CDN payload
        }
      }
    }

    // 2. Fallback ไปยัง Snapshot ที่แคชไว้ในเครื่องหรือ Bundled Asset (Offline Resilience)
    return loadCachedOrBundledSnapshot();
  }

  Future<void> clearSnapshotCache() async {
    await _preferences?.remove(AppConfig.cacheSnapshotKey);
  }

  void close() {
    _client.close();
  }

  /// โหลดขอบเขต GeoJSON จริงของทั้ง 8 อำเภอ จ.ยะลา เพื่อระบายสีระดับแจ้งเตือนบนแผนที่
  Future<List<AmphoeBoundary>> loadYalaBoundaries() async {
    try {
      final raw = await rootBundle.loadString(AppConfig.bundledGeoJsonAsset);
      return parseGeoJsonBoundaries(raw);
    } on Exception {
      return const <AmphoeBoundary>[];
    }
  }

  /// โหลดขอบเขต GeoJSON จริงของทั้ง 58 ตำบล จ.ยะลา พร้อมความสูงภูมิประเทศ (MSL)
  Future<List<SubdistrictBoundary>> loadYalaSubdistricts() async {
    try {
      final raw = await rootBundle.loadString(AppConfig.bundledSubdistrictsAsset);
      return parseGeoJsonSubdistricts(raw);
    } on Exception {
      return const <SubdistrictBoundary>[];
    }
  }

  /// โหลดข้อมูล 449 หมู่บ้านจริง จ.ยะลา (DOPA + Open-Meteo Copernicus DEM MSL)
  Future<List<VillagePoint>> loadYalaVillages() async {
    try {
      final raw = await rootBundle.loadString(AppConfig.bundledVillagesAsset);
      return parseVillagesJson(raw);
    } on Exception {
      return const <VillagePoint>[];
    }
  }

  /// โหลดแถบความสูงภูมิประเทศจริง Copernicus DEM สำหรับไล่ระดับสีบนแผนที่
  Future<List<ElevationBandZone>> loadElevationZones() async {
    try {
      final raw = await rootBundle.loadString(AppConfig.bundledElevationZonesAsset);
      return parseElevationZones(raw);
    } on Exception {
      return const <ElevationBandZone>[];
    }
  }

  /// โหลดขอบเขตโซนหมู่บ้านแบบเว้าโค้งภายในขอบเขตตำบลจริง
  Future<List<VillageZoneBoundary>> loadVillageZones() async {
    try {
      final raw = await rootBundle.loadString(AppConfig.bundledVillageZonesAsset);
      return parseVillageZones(raw);
    } on Exception {
      return const <VillageZoneBoundary>[];
    }
  }

  /// โหลดตาราง DEM ออฟไลน์สำหรับคำนวณ ม.รทก. ณ จุด GPS หรือหมุดผู้ใช้
  Future<DemElevationGrid?> loadDemGrid() async {
    try {
      final raw = await rootBundle.loadString(AppConfig.bundledDemGridAsset);
      return parseDemGrid(raw);
    } on Exception {
      return null;
    }
  }

  static List<ElevationBandZone> parseElevationZones(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) return const <ElevationBandZone>[];
    final features = decoded['features'];
    if (features is! List) return const <ElevationBandZone>[];

    final out = <ElevationBandZone>[];
    for (final f in features) {
      if (f is! Map) continue;
      final props = (f['properties'] as Map?)?.cast<String, dynamic>() ?? const {};
      final geom = (f['geometry'] as Map?)?.cast<String, dynamic>() ?? const {};
      final coords = geom['coordinates'];
      if (geom['type'] != 'Polygon' || coords is! List || coords.isEmpty) continue;
      final ring = _parseRing(coords.first);
      if (ring.length < 3) continue;
      final amphoeTh = props['amphoe_th']?.toString() ?? '';
      if (amphoeTh.isEmpty) continue;
      out.add(
        ElevationBandZone(
          amphoeTh: amphoeTh,
          band: props['band']?.toString() ?? '',
          elevMin: (props['elev_min'] as num?)?.toDouble() ?? 0.0,
          elevMax: (props['elev_max'] as num?)?.toDouble() ?? 0.0,
          elevMid: (props['elev_mid'] as num?)?.toDouble() ?? 0.0,
          ring: ring,
        ),
      );
    }
    return out;
  }

  static List<VillageZoneBoundary> parseVillageZones(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) return const <VillageZoneBoundary>[];
    final features = decoded['features'];
    if (features is! List) return const <VillageZoneBoundary>[];

    final out = <VillageZoneBoundary>[];
    for (final f in features) {
      if (f is! Map) continue;
      final props = (f['properties'] as Map?)?.cast<String, dynamic>() ?? const {};
      final geom = (f['geometry'] as Map?)?.cast<String, dynamic>() ?? const {};
      final coords = geom['coordinates'];
      if (geom['type'] != 'Polygon' || coords is! List || coords.isEmpty) continue;
      final ring = _parseRing(coords.first);
      if (ring.length < 3) continue;
      out.add(
        VillageZoneBoundary(
          code: props['code']?.toString() ?? '',
          moo: (props['moo'] as num?)?.toInt() ?? 0,
          nameTh: props['name_th']?.toString() ?? '',
          nameEn: props['name_en']?.toString() ?? '',
          amphoeTh: props['amphoe_th']?.toString() ?? '',
          tumbonTh: props['tumbon_th']?.toString() ?? '',
          ring: ring,
          elevationMsl: (props['elevation_msl'] as num?)?.toDouble(),
        ),
      );
    }
    return out;
  }

  static DemElevationGrid? parseDemGrid(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) return null;
    final latMin = (decoded['lat_min'] as num?)?.toDouble();
    final lonMin = (decoded['lon_min'] as num?)?.toDouble();
    final step = (decoded['step'] as num?)?.toDouble();
    final rows = (decoded['rows'] as num?)?.toInt();
    final cols = (decoded['cols'] as num?)?.toInt();
    final rawVals = decoded['values'];
    if (latMin == null ||
        lonMin == null ||
        step == null ||
        rows == null ||
        cols == null ||
        rawVals is! List) {
      return null;
    }
    final grid = <List<int?>>[];
    for (final row in rawVals) {
      if (row is! List) return null;
      grid.add(row.map((e) => (e as num?)?.round()).toList());
    }
    return DemElevationGrid(
      latMin: latMin,
      lonMin: lonMin,
      step: step,
      rows: rows,
      cols: cols,
      values: grid,
    );
  }

  /// ตรวจว่าจุด (lat, lng) อยู่ในรูปหลายเหลี่ยม (Ray Casting)
  static bool pointInRing(LatLng pt, List<LatLng> ring) {
    var inside = false;
    final n = ring.length;
    if (n < 3) return false;
    var j = n - 1;
    for (var i = 0; i < n; i++) {
      final xi = ring[i].longitude;
      final yi = ring[i].latitude;
      final xj = ring[j].longitude;
      final yj = ring[j].latitude;
      final intersect = ((yi > pt.latitude) != (yj > pt.latitude)) &&
          (pt.longitude < (xj - xi) * (pt.latitude - yi) / (yj - yi + 1e-15) + xi);
      if (intersect) inside = !inside;
      j = i;
    }
    return inside;
  }

  static bool pointInRings(LatLng pt, List<List<LatLng>> rings) {
    for (final ring in rings) {
      if (pointInRing(pt, ring)) return true;
    }
    return false;
  }

  static List<SubdistrictBoundary> parseGeoJsonSubdistricts(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) return const <SubdistrictBoundary>[];
    final features = decoded['features'];
    if (features is! List) return const <SubdistrictBoundary>[];

    final out = <SubdistrictBoundary>[];
    for (final f in features) {
      if (f is! Map) continue;
      final props = (f['properties'] as Map?)?.cast<String, dynamic>() ?? const {};
      final geom = (f['geometry'] as Map?)?.cast<String, dynamic>() ?? const {};
      final amphoeTh = props['amphoe_th']?.toString() ?? '';
      final tumbonTh = props['tumbon_th']?.toString() ?? '';
      final tumbonEn = props['tumbon_en']?.toString() ?? '';
      final tumbonCode = props['tumbon_code']?.toString() ?? '';
      final type = geom['type']?.toString() ?? '';
      final coords = geom['coordinates'];
      final rings = <List<LatLng>>[];

      if (type == 'Polygon' && coords is List && coords.isNotEmpty) {
        final ring = _parseRing(coords.first);
        if (ring.isNotEmpty) rings.add(ring);
      } else if (type == 'MultiPolygon' && coords is List) {
        for (final poly in coords) {
          if (poly is List && poly.isNotEmpty) {
            final ring = _parseRing(poly.first);
            if (ring.isNotEmpty) rings.add(ring);
          }
        }
      }
      if (amphoeTh.isEmpty || tumbonTh.isEmpty || rings.isEmpty) continue;
      final lat = (props['lat'] as num?)?.toDouble();
      final lon = (props['lon'] as num?)?.toDouble();
      final centroid = (lat != null && lon != null)
          ? LatLng(lat, lon)
          : _computeCentroid(rings.first);
      out.add(
        SubdistrictBoundary(
          amphoeTh: amphoeTh,
          tumbonTh: tumbonTh,
          tumbonEn: tumbonEn,
          tumbonCode: tumbonCode,
          rings: rings,
          centroid: centroid,
          elevationMsl: (props['elevation_msl'] as num?)?.toDouble(),
          minElevationMsl: (props['min_elevation_msl'] as num?)?.toDouble(),
          maxElevationMsl: (props['max_elevation_msl'] as num?)?.toDouble(),
          villageCount: (props['village_count'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    return out;
  }

  static List<VillagePoint> parseVillagesJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) return const <VillagePoint>[];
    final items = decoded['villages'];
    if (items is! List) return const <VillagePoint>[];
    return items
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => VillagePoint.fromJson(e.cast<String, dynamic>()))
        .where((v) => v.nameTh.isNotEmpty && v.amphoeTh.isNotEmpty)
        .toList();
  }

  static List<AmphoeBoundary> parseGeoJsonBoundaries(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) return const <AmphoeBoundary>[];
    final features = decoded['features'];
    if (features is! List) return const <AmphoeBoundary>[];

    final boundaries = <AmphoeBoundary>[];
    for (final f in features) {
      if (f is! Map) continue;
      final props = (f['properties'] as Map?)?.cast<String, dynamic>() ?? const {};
      final geom = (f['geometry'] as Map?)?.cast<String, dynamic>() ?? const {};
      final amphoeTh = props['amphoe_th']?.toString() ?? '';
      final amphoeEn = props['amphoe_en']?.toString() ?? '';
      final type = geom['type']?.toString() ?? '';
      final coords = geom['coordinates'];
      final rings = <List<LatLng>>[];

      if (type == 'Polygon' && coords is List && coords.isNotEmpty) {
        final ring = _parseRing(coords.first);
        if (ring.isNotEmpty) rings.add(ring);
      } else if (type == 'MultiPolygon' && coords is List) {
        for (final poly in coords) {
          if (poly is List && poly.isNotEmpty) {
            final ring = _parseRing(poly.first);
            if (ring.isNotEmpty) rings.add(ring);
          }
        }
      }
      if (amphoeTh.isEmpty || rings.isEmpty) continue;
      final centroid = _computeCentroid(rings.first);
      boundaries.add(
        AmphoeBoundary(
          amphoeTh: amphoeTh,
          amphoeEn: amphoeEn,
          rings: rings,
          centroid: centroid,
        ),
      );
    }
    return boundaries;
  }

  static List<LatLng> _parseRing(dynamic rawRing) {
    if (rawRing is! List) return const <LatLng>[];
    final out = <LatLng>[];
    for (final pt in rawRing) {
      if (pt is List && pt.length >= 2) {
        final lon = (pt[0] as num?)?.toDouble();
        final lat = (pt[1] as num?)?.toDouble();
        if (lat != null && lon != null) {
          out.add(LatLng(lat, lon));
        }
      }
    }
    return out;
  }

  static LatLng _computeCentroid(List<LatLng> pts) {
    var sumLat = 0.0;
    var sumLng = 0.0;
    for (final p in pts) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    return LatLng(sumLat / pts.length, sumLng / pts.length);
  }
}
