import 'package:flutter/foundation.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/models/alert.dart';
import 'package:yala_flood_app/models/alert_settings.dart';
import 'package:yala_flood_app/models/rain_forecast.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/sos_request.dart';
import 'package:yala_flood_app/services/alert_engine.dart';
import 'package:yala_flood_app/services/local_store.dart';
import 'package:yala_flood_app/services/rain_forecast_service.dart';
import 'package:yala_flood_app/services/thai_water_service.dart';
import 'package:yala_flood_app/models/station.dart';

/// ศูนย์รวม state ของแอพ: สถานี, แจ้งเตือน, การตั้งค่า และคำขอ SOS
///
/// ทำให้ทุกหน้าจออ่านข้อมูลจากที่เดียว และ cache ถูกใช้อัตโนมัติเมื่อเน็ตขาด
class AlertProvider extends ChangeNotifier {
  AlertProvider({
    required ThaiWaterService waterService,
    RainForecastService? rainService,
    AlertEngine? engine,
    LocalStore? localStorage,
    // ignore: prefer_initializing_formals — พารามิเตอร์ต้องเป็นชื่อสาธารณะ
  })  : _waterService = waterService,
        _rainService = rainService ?? RainForecastService(),
        _engine = engine ?? const AlertEngine(),
        _store = localStorage;

  final ThaiWaterService _waterService;
  final RainForecastService _rainService;
  final AlertEngine _engine;
  final LocalStore? _store;

  // ── ข้อมูลที่แสดง ──────────────────────────────────────────────────────
  List<Station> _stations = const <Station>[];
  List<AlertItem> _alerts = const <AlertItem>[];
  List<SosRequest> _sosRequests = const <SosRequest>[];
  AlertSettings _settings = const AlertSettings();

  bool _loading = false;
  bool _initialized = false;
  String? _errorTh;
  String? _noticeTh;
  DateTime? _lastUpdated;
  WaterSource _source = WaterSource.network;

  /// สถานีที่ผู้ใช้เปิดดูรายละเอียดอยู่ (ใช้โหลดค่าฝนเฉพาะจุดนั้น)
  String? _selectedStationCode;

  // ── getter ─────────────────────────────────────────────────────────────
  List<Station> get stations => _stations;
  List<AlertItem> get alerts => _alerts;
  List<SosRequest> get sosRequests => _sosRequests;
  AlertSettings get settings => _settings;
  bool get loading => _loading;
  bool get initialized => _initialized;
  String? get errorTh => _errorTh;
  String? get noticeTh => _noticeTh;
  DateTime? get lastUpdated => _lastUpdated;
  WaterSource get source => _source;
  String? get selectedStationCode => _selectedStationCode;

  bool get isOffline => _source == WaterSource.cache;

  /// แจ้งเตือนที่ยังไม่ได้อ่าน
  int get unreadCount => _alerts.where((a) => !a.read).length;

  /// จำนวนสถานีที่ถึงเกณฑ์เตือนภัยขึ้นไป
  int get warningStationCount =>
      _stations.where((s) => s.riskLevel.isAtLeastWarning).length;

  int get dangerStationCount =>
      _stations.where((s) => s.riskLevel == RiskLevel.danger).length;

  /// แจ้งเตือนที่กำลังมีผล (สถานียังอยู่ในระดับนั้น)
  List<AlertItem> get activeAlerts {
    if (_stations.isEmpty) return const <AlertItem>[];
    final current = _engine.evaluate(
      stations: _stations,
      settings: _settings,
      previous: _alerts,
    );
    if (current.isEmpty) return const <AlertItem>[];
    return current;
  }

  Station? stationByCode(String? code) {
    if (code == null) return null;
    for (final station in _stations) {
      if (station.code == code) return station;
    }
    return null;
  }

  /// อำเภอทั้งหมดที่มีสถานี (กรองเฉพาะจ.ยะลา)
  List<String> get amphoes {
    final set = _stations
        .map((s) => s.amphoeTh ?? '')
        .where((a) => a.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return set;
  }

  List<String> get tumbonsInSelectedAmphoe {
    final amphoe = _settings.selectedAmphoeTh;
    return _stations
        .where((s) => amphoe == null || s.amphoeTh == amphoe)
        .map((s) => s.tumbonTh ?? '')
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  // ── เริ่มต้น + รีเฟรช ───────────────────────────────────────────────────
  /// โหลดข้อมูลที่เก็บไว้ในเครื่องก่อน แล้วค่อยพยายามดึงจากเน็ต
  Future<void> hydrate() async {
    final store = _store;
    if (store != null) {
      _alerts = store.loadAlerts();
      _settings = store.loadSettings();
      _sosRequests = store.loadSosRequests();
    }
    _initialized = true;
    await refresh();
  }

  Future<void> refresh({bool force = false}) async {
    if (_loading) return;
    _loading = true;
    _errorTh = null;
    notifyListeners();

    try {
      final result = await _waterService.fetch(forceRefresh: force);
      _stations = result.stations;
      _lastUpdated = result.updatedAt;
      _source = result.source;
      _noticeTh = result.messageTh;

      // โหลดค่าฝนเฉพาะสถานีที่เลือก หรือสถานีที่รุนแรงสุด (ไม่เรียกทุกสถานี)
      final rain = await _loadRain();
      final newAlerts = _engine.evaluate(
        stations: _stations,
        settings: _settings,
        rain: rain,
        previous: _alerts,
      );
      if (newAlerts.isNotEmpty) {
        _alerts = _mergeAlerts(_alerts, newAlerts);
      }
      _initialized = true;
      await _store?.saveAlerts(_alerts);
    } on ThaiWaterException catch (error) {
      _errorTh = error.messageTh;
    } catch (error) {
      _errorTh = 'เกิดข้อผิดพลาดที่ไม่คาดคิด โปรดลองอีกครั้ง';
      debugPrint('refresh failed: $error');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<RainForecast?> _loadRain() async {
    if (!AppConfig.rainForecastEndpoint.isNotEmpty) return null;
    final code = _selectedStationCode ??
        (_stations.isEmpty ? null : _stations.first.code);
    if (code == null) return null;
    return _rainService.current(code);
  }

  List<AlertItem> _mergeAlerts(List<AlertItem> existing, List<AlertItem> fresh) {
    final byId = {for (final a in existing) a.id: a};
    for (final a in fresh) {
      byId[a.id] = a;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (merged.length > AppConfig.maxStoredAlerts) {
      merged.removeRange(AppConfig.maxStoredAlerts, merged.length);
    }
    return merged;
  }

  // ── การตั้งค่า ─────────────────────────────────────────────────────────
  void updateSettings(AlertSettings next) {
    _settings = next;
    notifyListeners();
    _store?.saveSettings(next);
    // คำนวณแจ้งเตือนใหม่ทันทีถ้าเปลี่ยนเกณฑ์
    final newAlerts = _engine.evaluate(
      stations: _stations,
      settings: _settings,
      previous: _alerts,
    );
    if (newAlerts.isNotEmpty) {
      _alerts = _mergeAlerts(_alerts, newAlerts);
      _store?.saveAlerts(_alerts);
      notifyListeners();
    }
  }

  // ── แจ้งเตือน ──────────────────────────────────────────────────────────
  void markAllAlertsRead() {
    if (_alerts.every((a) => a.read)) return;
    _alerts = _alerts.map((a) => a.copyWith(read: true)).toList();
    _store?.saveAlerts(_alerts);
    notifyListeners();
  }

  void markAlertRead(String id) {
    _alerts = _alerts
        .map((a) => a.id == id ? a.copyWith(read: true) : a)
        .toList();
    _store?.saveAlerts(_alerts);
    notifyListeners();
  }

  void clearAlerts() {
    _alerts = const <AlertItem>[];
    _store?.saveAlerts(_alerts);
    notifyListeners();
  }

  // ── SOS ────────────────────────────────────────────────────────────────
  void addSosRequest(SosRequest request) {
    _sosRequests = [request, ..._sosRequests];
    if (_sosRequests.length > AppConfig.maxStoredSosRequests) {
      _sosRequests.removeRange(
        AppConfig.maxStoredSosRequests,
        _sosRequests.length,
      );
    }
    _store?.saveSosRequests(_sosRequests);
    notifyListeners();
  }

  void advanceSosStatus(String id) {
    _sosRequests = _sosRequests.map((request) {
      if (request.id != id) return request;
      final next = request.status.next;
      if (next == null) return request;
      return request.copyWith(
        status: next,
        statusHistory: [...request.statusHistory, next],
      );
    }).toList();
    _store?.saveSosRequests(_sosRequests);
    notifyListeners();
  }

  void setSelectedStation(String? code) {
    _selectedStationCode = code;
    notifyListeners();
  }

  /// ล้างแคชระดับน้ำที่เก็บไว้ในเครื่อง
  Future<void> clearCache() async {
    await _waterService.clearCache();
    notifyListeners();
  }

  /// ข้อความสถานะแบบสั้นสำหรับแสดงบนแผนที่
  String get statusLineTh {
    if (_stations.isEmpty) {
      return _errorTh ?? 'กำลังโหลดข้อมูล…';
    }
    final buffer = StringBuffer(
      'สถานี ${_stations.length} แห่ง · เตือนภัย $warningStationCount · อันตราย $dangerStationCount',
    );
    if (_lastUpdated != null) {
      buffer.write(' · ข้อมูลล่าสุด ${thaiRelativeTime(_lastUpdated!)}');
    }
    if (isOffline) buffer.write(' · ใช้ข้อมูลสำรอง');
    return buffer.toString();
  }
}
