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

  String get _latestUrl {
    final base = _cdnBaseUrlOverride ?? AppConfig.snapshotCdnBaseUrl;
    return base.isEmpty ? '' : '$base/latest.json';
  }

  String get _manifestUrl {
    final base = _cdnBaseUrlOverride ?? AppConfig.snapshotCdnBaseUrl;
    return base.isEmpty ? '' : '$base/manifest.json';
  }

  /// ตรวจความสมบูรณ์ของ Snapshot แบบ Fail-Closed (ต้องตรงจังหวัดยะลา 95, ครบ 8 อำเภอ และ content_hash ตรง manifest)
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
    final snapHash = latest['content_hash']?.toString() ?? '';
    if (expectedManifestHash != null &&
        (expectedManifestHash.isEmpty || snapHash != expectedManifestHash)) {
      return false;
    }
    return true;
  }

  Future<FloodSnapshot?> loadSnapshot() async {
    // 1. ถ้าตั้งค่า Supabase Storage CDN URL ไว้ ให้ดึง manifest.json + latest.json พร้อมตรวจแฮชแบบ Fail-Closed
    final latestUrl = _latestUrl;
    final manifestUrl = _manifestUrl;
    if (latestUrl.isNotEmpty && manifestUrl.isNotEmpty) {
      try {
        final manResp = await _client
            .get(Uri.parse(manifestUrl), headers: const {'accept': 'application/json'})
            .timeout(AppConfig.networkTimeout);
        final snapResp = await _client
            .get(Uri.parse(latestUrl), headers: const {'accept': 'application/json'})
            .timeout(AppConfig.networkTimeout);
        if (manResp.statusCode == 200 && snapResp.statusCode == 200) {
          final manDecoded = jsonDecode(manResp.body);
          final snapDecoded = jsonDecode(snapResp.body);
          if (manDecoded is Map<String, dynamic> &&
              snapDecoded is Map<String, dynamic>) {
            final expectedHash = manDecoded['content_hash']?.toString() ?? '';
            if (isValidYalaSnapshot(snapDecoded, expectedManifestHash: expectedHash)) {
              await _preferences?.setString(AppConfig.cacheSnapshotKey, snapResp.body);
              return FloodSnapshot.fromJson(
                snapDecoded,
                sourceLabel: 'Supabase CDN (5 Sources)',
              );
            }
          }
        }
      } on Exception {
        // Fail-closed: do not overwrite valid cached/bundled snapshot with corrupt CDN payload
      }
    }

    // 2. ลองอ่าน Snapshot ที่เคยผ่านการตรวจสอบและแคชไว้ในเครื่อง (Offline Resilience)
    final cachedRaw = _preferences?.getString(AppConfig.cacheSnapshotKey);
    if (cachedRaw != null && cachedRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(cachedRaw);
        if (decoded is Map<String, dynamic> && isValidYalaSnapshot(decoded)) {
          return FloodSnapshot.fromJson(decoded, sourceLabel: 'Cached 5-Source Snapshot');
        }
      } on Exception {
        // fallback to bundled asset
      }
    }

    // 3. Fallback ออฟไลน์ไปยัง Bundled 5-Source Snapshot ใน assets/snapshots/latest.json
    try {
      final raw = await rootBundle.loadString(AppConfig.bundledSnapshotAsset);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && isValidYalaSnapshot(decoded)) {
        return FloodSnapshot.fromJson(decoded, sourceLabel: 'Bundled 5-Source Snapshot');
      }
    } on Exception {
      return null;
    }
    return null;
  }

  Future<void> clearSnapshotCache() async {
    await _preferences?.remove(AppConfig.cacheSnapshotKey);
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
