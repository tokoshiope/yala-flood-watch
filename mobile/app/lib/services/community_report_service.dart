import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/services/local_store.dart';
import 'package:yala_flood_app/services/sos_dispatch_service.dart';

/// ประเภทเหตุการณ์รายงานชุมชนที่อนุญาตใน Supabase Schema (0001_initial_yala_flood_schema.sql)
const List<String> kCommunityReportTypes = [
  'water_rising',
  'road_flooded',
  'flash_flood',
  'landslide',
  'shelter_full',
];

/// รายงานสถานการณ์น้ำจากชุมชน (Tier C · ไม่ระบุตัวตน · พิกัดปัดเศษ ~110 ม. · ลบอัตโนมัติ 90 วัน)
class CommunityReport {
  const CommunityReport({
    required this.id,
    required this.createdAt,
    required this.amphoeTh,
    required this.reportType,
    required this.lat,
    required this.lng,
    this.waterDepthCm,
    this.noteTh,
    this.trustScore = 1,
  });

  final String id;
  final DateTime createdAt;
  final String amphoeTh;
  final String reportType;
  final double lat;
  final double lng;
  final int? waterDepthCm;
  final String? noteTh;
  final int trustScore;

  static CommunityReport? tryFromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final amphoe = json['amphoe_th']?.toString() ?? '';
    final type = json['report_type']?.toString() ?? '';
    final rawLat = json['lat'];
    final rawLon = json['lon'];
    if (id.isEmpty ||
        !AppConfig.riskAmphoeTh.contains(amphoe) ||
        !kCommunityReportTypes.contains(type) ||
        rawLat is! num ||
        rawLon is! num) {
      return null;
    }
    final lat = rawLat.toDouble();
    final lon = rawLon.toDouble();
    if (!lat.isFinite || !lon.isFinite || lat < 5.5 || lat > 7.2 || lon < 100.5 || lon > 101.9) {
      return null;
    }
    final created = DateTime.tryParse(json['created_at']?.toString() ?? '');
    if (created == null) return null;
    final rawDepth = json['water_depth_cm'];
    final depth = rawDepth is num ? rawDepth.toInt() : null;
    final rawTrust = json['trust_score'];
    final trust = rawTrust is num ? rawTrust.toInt() : 1;
    final note = json['note_th']?.toString().trim();

    return CommunityReport(
      id: id,
      createdAt: created,
      amphoeTh: amphoe,
      reportType: type,
      lat: lat,
      lng: lon,
      waterDepthCm: (depth != null && depth >= 0 && depth <= 1000) ? depth : null,
      noteTh: (note != null && note.isNotEmpty) ? note : null,
      trustScore: trust.clamp(1, 5),
    );
  }
}

enum CommunitySubmitStatus {
  success,
  notConfigured,
  invalidInput,
  outsideYala,
  rateLimited,
  networkError,
}

class CommunitySubmitResult {
  const CommunitySubmitResult({
    required this.status,
    this.reportId,
    this.detail,
  });

  final CommunitySubmitStatus status;
  final String? reportId;
  final String? detail;

  bool get ok => status == CommunitySubmitStatus.success;
}

/// บริการส่งและอ่านรายงานสถานการณ์น้ำชุมชน (Tier C) ผ่าน Supabase RLS RPC แบบ Zero-PII
class CommunityReportService {
  CommunityReportService({
    http.Client? client,
    String? supabaseBaseUrlOverride,
    String? anonKeyOverride,
  })  : _client = client ?? http.Client(),
        // ignore: prefer_initializing_formals
        _supabaseBaseUrlOverride = supabaseBaseUrlOverride,
        // ignore: prefer_initializing_formals
        _anonKeyOverride = anonKeyOverride;

  final http.Client _client;
  final String? _supabaseBaseUrlOverride;
  final String? _anonKeyOverride;

  String get _baseUrl {
    final raw = (_supabaseBaseUrlOverride ?? AppConfig.effectiveSupabaseBaseUrl)
        .trim()
        .replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return '';
    return '${uri.scheme}://${uri.authority}';
  }

  String get _anonKey => (_anonKeyOverride ?? AppConfig.supabaseAnonKey).trim();

  /// พร้อมเชื่อมต่อ Supabase จริงเมื่อมีทั้ง HTTPS URL และ Public Anon Key
  bool get isConfigured => _baseUrl.isNotEmpty && _anonKey.isNotEmpty;

  /// ปัดเศษพิกัดเหลือ 3 ตำแหน่งทศนิยม (~110 ม.) เพื่อคุ้มครองความเป็นส่วนตัวตาม PDPA
  static double roundCoordinatePdpa(double value) =>
      (value * 1000.0).round() / 1000.0;

  static bool isWithinYalaBbox(double lat, double lng) =>
      lat.isFinite &&
      lng.isFinite &&
      lat >= 5.5 &&
      lat <= 7.2 &&
      lng >= 100.5 &&
      lng <= 101.9;

  /// ส่งรายงานชุมชนแบบไม่ระบุตัวตน (ไม่ส่งชื่อ/เบอร์โทร · จำกัด 1 ครั้ง/เครื่อง/ชม.)
  Future<CommunitySubmitResult> submitReport({
    required String amphoeTh,
    required String reportType,
    required double lat,
    required double lng,
    required LocalStore? store,
    int? waterDepthCm,
    String? noteTh,
  }) async {
    if (!isConfigured) {
      return const CommunitySubmitResult(
        status: CommunitySubmitStatus.notConfigured,
      );
    }
    if (!AppConfig.riskAmphoeTh.contains(amphoeTh) ||
        !kCommunityReportTypes.contains(reportType)) {
      return const CommunitySubmitResult(
        status: CommunitySubmitStatus.invalidInput,
      );
    }
    if (!isWithinYalaBbox(lat, lng)) {
      return const CommunitySubmitResult(
        status: CommunitySubmitStatus.outsideYala,
      );
    }
    if (waterDepthCm != null && (waterDepthCm < 0 || waterDepthCm > 1000)) {
      return const CommunitySubmitResult(
        status: CommunitySubmitStatus.invalidInput,
      );
    }

    final cleanNote = (noteTh ?? '').trim();
    final safeNote = cleanNote.isEmpty
        ? null
        : (cleanNote.runes.length > 280
            ? String.fromCharCodes(cleanNote.runes.take(280))
            : cleanNote);

    final salt = store != null
        ? await store.loadOrCreateCommunitySalt()
        : 'ephemeral-${DateTime.now().microsecondsSinceEpoch}';
    final deviceHash = SosDispatchService.sha256Hex('yala-flood-c-v1:$salt');

    final roundedLat = roundCoordinatePdpa(lat);
    final roundedLng = roundCoordinatePdpa(lng);

    final uri = Uri.parse('$_baseUrl/rest/v1/rpc/submit_community_report');
    final payload = <String, dynamic>{
      'p_amphoe_th': amphoeTh,
      'p_report_type': reportType,
      'p_lat': roundedLat,
      'p_lon': roundedLng,
      'p_device_hash': deviceHash,
      'p_water_depth_cm': waterDepthCm,
      'p_note_th': safeNote,
    };

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'apikey': _anonKey,
              'Authorization': 'Bearer $_anonKey',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(AppConfig.networkTimeout);

      final bodyText = utf8.decode(response.bodyBytes, allowMalformed: true);
      if (response.statusCode == 200 || response.statusCode == 201) {
        String? reportId;
        try {
          final decoded = jsonDecode(bodyText);
          if (decoded is String && decoded.isNotEmpty) {
            reportId = decoded;
          }
        } catch (_) {
          // ignore non-JSON body
        }
        await store?.saveCommunityLastReportAt(DateTime.now());
        return CommunitySubmitResult(
          status: CommunitySubmitStatus.success,
          reportId: reportId,
        );
      }

      if (bodyText.toLowerCase().contains('rate limit')) {
        return CommunitySubmitResult(
          status: CommunitySubmitStatus.rateLimited,
          detail: bodyText,
        );
      }
      if (bodyText.toLowerCase().contains('outside yala')) {
        return CommunitySubmitResult(
          status: CommunitySubmitStatus.outsideYala,
          detail: bodyText,
        );
      }
      return CommunitySubmitResult(
        status: CommunitySubmitStatus.networkError,
        detail: 'HTTP ${response.statusCode}',
      );
    } catch (_) {
      return const CommunitySubmitResult(
        status: CommunitySubmitStatus.networkError,
      );
    }
  }

  /// ดึงรายงานชุมชนล่าสุดจากวิวไม่ระบุตัวตน `public_community_reports` (ไม่เปิดเผย device_hash)
  Future<List<CommunityReport>> fetchRecentReports({int limit = 20}) async {
    if (!isConfigured) return const <CommunityReport>[];
    final safeLimit = limit.clamp(1, 50);
    final uri = Uri.parse(
      '$_baseUrl/rest/v1/public_community_reports'
      '?select=id,created_at,amphoe_th,report_type,lat,lon,water_depth_cm,note_th,trust_score'
      '&order=created_at.desc&limit=$safeLimit',
    );
    try {
      final response = await _client
          .get(
            uri,
            headers: {
              'apikey': _anonKey,
              'Authorization': 'Bearer $_anonKey',
              'Accept': 'application/json',
            },
          )
          .timeout(AppConfig.networkTimeout);
      if (response.statusCode != 200) return const <CommunityReport>[];
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) return const <CommunityReport>[];
      final out = <CommunityReport>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final parsed = CommunityReport.tryFromJson(item);
          if (parsed != null) out.add(parsed);
        } else if (item is Map) {
          final parsed = CommunityReport.tryFromJson(item.cast<String, dynamic>());
          if (parsed != null) out.add(parsed);
        }
      }
      return out;
    } catch (_) {
      return const <CommunityReport>[];
    }
  }

  void close() {
    _client.close();
  }
}
