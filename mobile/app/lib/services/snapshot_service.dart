import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/models/flood_snapshot.dart';

/// Phase 2 Cloud Bridge: โหลด Snapshot รวม 5 ฐานข้อมูลจาก CDN (ถ้าตั้งค่าไว้)
/// พร้อม Fallback ไปยัง Bundled Offline Asset + โหลดขอบเขต GeoJSON 8 อำเภอ จ.ยะลา
class SnapshotService {
  SnapshotService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<FloodSnapshot?> loadSnapshot() async {
    // 1. ถ้าตั้งค่า Supabase Storage CDN URL ไว้ ให้ดึงจาก CDN ก่อน
    final cdnUrl = AppConfig.snapshotLatestUrl;
    if (cdnUrl.isNotEmpty) {
      try {
        final resp = await _client
            .get(Uri.parse(cdnUrl), headers: const {'accept': 'application/json'})
            .timeout(AppConfig.networkTimeout);
        if (resp.statusCode == 200) {
          final decoded = jsonDecode(resp.body);
          if (decoded is Map<String, dynamic>) {
            return FloodSnapshot.fromJson(decoded, sourceLabel: 'Supabase CDN (5 Sources)');
          }
        }
      } on Exception {
        // fallback gracefully to bundled offline snapshot
      }
    }

    // 2. Fallback ออฟไลน์ไปยัง Bundled 5-Source Snapshot ใน assets/snapshots/latest.json
    try {
      final raw = await rootBundle.loadString(AppConfig.bundledSnapshotAsset);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return FloodSnapshot.fromJson(decoded, sourceLabel: 'Bundled 5-Source Snapshot');
      }
    } on Exception {
      return null;
    }
    return null;
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
