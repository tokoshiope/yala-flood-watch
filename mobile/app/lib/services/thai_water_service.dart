import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/models/station.dart';

/// แหล่งข้อมูลที่ใช้แสดงผล
enum WaterSource {
  /// ดึงจากเน็ตสำเร็จ
  network,

  /// เน็ตมีปัญหา ตัวเลขมาจากแคชของเครื่อง
  cache,
}

/// ผลลัพธ์การดึงข้อมูลสถานี
class StationFetchResult {
  const StationFetchResult({
    required this.stations,
    required this.source,
    this.updatedAt,
    this.messageTh,
  });

  final List<Station> stations;
  final WaterSource source;
  final DateTime? updatedAt;
  final String? messageTh;

  bool get isOffline => source == WaterSource.cache;
  bool get isEmpty => stations.isEmpty;
}

/// ข้อผิดพลาดที่แปลงเป็นภาษาไทยแล้ว ให้ UI แสดงได้ทันที
class ThaiWaterException implements Exception {
  ThaiWaterException({required this.messageTh, this.cause});

  final String messageTh;
  final Object? cause;

  @override
  String toString() => 'ThaiWaterException: $messageTh';
}

/// เรียก ThaiWater API จริง พร้อม timeout, retry และ fallback ไปแคช
///
/// ใช้ [SharedPreferences] เก็บผลล่าสุดเสมอ เพื่อให้แอพเปิดใช้ได้แม้ไม่มีสัญญาณ
class ThaiWaterService {
  ThaiWaterService({
    http.Client? client,
    SharedPreferences? preferences,
    this.cacheTtl = AppConfig.cacheTtl,
  })  : _client = client ?? http.Client(),
        _prefs = preferences;

  final http.Client _client;
  final SharedPreferences? _prefs;
  final Duration cacheTtl;

  /// ดึงข้อมูลล่าสุด ถ้าเน็ตใช้ไม่ได้จะคืนค่าจากแคช
  Future<StationFetchResult> fetch({bool forceRefresh = false}) async {
    try {
      final stations = await _fetchFromNetwork();
      await _writeCache(stations);
      return StationFetchResult(
        stations: stations,
        source: WaterSource.network,
        updatedAt: DateTime.now(),
      );
    } on Exception catch (error) {
      final cached = await readCache();
      if (cached != null && cached.isNotEmpty) {
        final updated = await _readCacheTime();
        return StationFetchResult(
          stations: cached,
          source: WaterSource.cache,
          updatedAt: updated,
          messageTh: 'ไม่มีสัญญาณเน็ต กำลังแสดงข้อมูลล่าสุดที่บันทึกไว้',
        );
      }
      throw ThaiWaterException(
        messageTh: 'ยังไม่สามารถโหลดข้อมูลได้ โปรดลองอีกครั้งในภายหลัง',
        cause: error,
      );
    }
  }

  Future<List<Station>> _fetchFromNetwork() async {
    Object? lastError;

    for (var attempt = 0; attempt <= AppConfig.maxRetries; attempt++) {
      try {
        final response = await _client
            .get(
              Uri.parse(AppConfig.waterLevelUrl),
              headers: const {
                'accept': 'application/json',
                'user-agent': 'yala-flood-app/${AppConfig.appVersion}',
              },
            )
            .timeout(AppConfig.networkTimeout);

        if (response.statusCode != 200) {
          throw http.ClientException(
            'ThaiWater ตอบ ${response.statusCode}',
          );
        }
        return _parse(response.body);
      } on Exception catch (error) {
        lastError = error;
        if (attempt < AppConfig.maxRetries) {
          await Future<void>.delayed(
            AppConfig.retryDelay * (attempt + 1),
          );
        }
      }
    }

    throw ThaiWaterException(
      messageTh: 'โหลดข้อมูลจากเซิร์ฟเวอร์ไม่สำเร็จ',
      cause: lastError,
    );
  }

  /// แปลง JSON ของ ThaiWater เป็น [Station]
  /// คัดเฉพาะสถานีที่เป็นของ จ.ยะลา (province_code 95) เท่านั้น
  List<Station> _parse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('รูปแบบข้อมูลไม่ถูกต้อง');
    }
    if (decoded['result'] != null &&
        decoded['result'].toString().toUpperCase() != 'OK') {
      throw const FormatException('ThaiWater แจ้งว่าข้อมูลไม่พร้อมใช้งาน');
    }
    final data = decoded['data'];
    if (data is! List) return const <Station>[];

    final stations = <Station>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final geocode = item['geocode'];
      final provinceCode = geocode is Map ? geocode['province_code'] : null;
      if (provinceCode != null &&
          provinceCode.toString() != AppConfig.provinceCode) {
        continue; // ไม่เอาข้อมูลจังหวัดอื่นมาแสดง
      }
      stations.add(Station.fromThaiWaterJson(item));
    }
    stations.sort((a, b) => b.riskLevel.severity.compareTo(a.riskLevel.severity));
    return stations;
  }

  // ── แคช ────────────────────────────────────────────────────────────────
  Future<List<Station>?> readCache() async {
    final prefs = _prefs;
    if (prefs == null) return null;
    final raw = prefs.getString(AppConfig.cacheStationsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw);
      if (list is! List) return null;
      return list
          .whereType<Map<String, dynamic>>()
          .map(Station.fromJson)
          .toList();
    } on FormatException {
      return null;
    }
  }

  Future<void> _writeCache(List<Station> stations) async {
    final prefs = _prefs;
    if (prefs == null || stations.isEmpty) return;
    final payload = jsonEncode(stations.map((s) => s.toJson()).toList());
    await prefs.setString(AppConfig.cacheStationsKey, payload);
    await prefs.setInt(
      AppConfig.cacheUpdatedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<DateTime?> _readCacheTime() async {
    final prefs = _prefs;
    if (prefs == null) return null;
    final millis = prefs.getInt(AppConfig.cacheUpdatedAtKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// คืน true ถ้าแคชยังสดอยู่ภายใน [cacheTtl]
  Future<bool> isCacheFresh() async {
    final updated = await _readCacheTime();
    if (updated == null) return false;
    return DateTime.now().difference(updated) < cacheTtl;
  }

  Future<void> clearCache() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.remove(AppConfig.cacheStationsKey);
    await prefs.remove(AppConfig.cacheUpdatedAtKey);
  }
}
