import 'package:flutter/foundation.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/alert.dart';
import 'package:yala_flood_app/models/alert_settings.dart';
import 'package:yala_flood_app/models/flood_snapshot.dart';
import 'package:yala_flood_app/models/rain_forecast.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/sos_request.dart';
import 'package:yala_flood_app/models/station.dart';
import 'package:yala_flood_app/services/alert_engine.dart';
import 'package:yala_flood_app/services/local_store.dart';
import 'package:yala_flood_app/services/notification_service.dart';
import 'package:yala_flood_app/services/rain_forecast_service.dart';
import 'package:yala_flood_app/services/snapshot_service.dart';
import 'package:yala_flood_app/services/thai_water_service.dart';

/// ศูนย์รวม state ของแอพ: สถานี, 5-Source Snapshot, GeoJSON 8 อำเภอ, แจ้งเตือน, ภาษา 4 ภาษา และ SOS
class AlertProvider extends ChangeNotifier {
  AlertProvider({
    required ThaiWaterService waterService,
    RainForecastService? rainService,
    AlertEngine? engine,
    LocalStore? localStorage,
    NotificationService? notificationService,
    SnapshotService? snapshotService,
    // ignore: prefer_initializing_formals
  })  : _waterService = waterService,
        _rainService = rainService ?? RainForecastService(),
        _engine = engine ?? const AlertEngine(),
        _store = localStorage,
        _notifications = notificationService ?? NotificationService.instance,
        _snapshotService = snapshotService ?? SnapshotService();

  final ThaiWaterService _waterService;
  final RainForecastService _rainService;
  final AlertEngine _engine;
  final LocalStore? _store;
  final NotificationService _notifications;
  final SnapshotService _snapshotService;

  List<Station> _stations = const <Station>[];
  List<AlertItem> _alerts = const <AlertItem>[];
  List<SosRequest> _sosRequests = const <SosRequest>[];
  AlertSettings _settings = const AlertSettings();
  FloodSnapshot? _snapshot;
  List<AmphoeBoundary> _boundaries = const <AmphoeBoundary>[];
  List<SubdistrictBoundary> _subdistricts = const <SubdistrictBoundary>[];
  List<VillagePoint> _villages = const <VillagePoint>[];
  bool _gpsConsentGranted = false;

  bool _loading = false;
  bool _initialized = false;
  String? _errorTh;
  String? _noticeTh;
  DateTime? _lastUpdated;
  WaterSource _source = WaterSource.network;
  String? _selectedStationCode;

  List<Station> get stations => _stations;
  List<AlertItem> get alerts => _alerts;
  List<SosRequest> get sosRequests => _sosRequests;
  AlertSettings get settings => _settings;
  AppStrings get strings => AppStrings(_settings.languageCode);
  FloodSnapshot? get snapshot => _snapshot;
  List<AmphoeBoundary> get boundaries => _boundaries;
  List<SubdistrictBoundary> get subdistricts => _subdistricts;
  List<VillagePoint> get villages => _villages;
  bool get gpsConsentGranted => _gpsConsentGranted;
  bool get loading => _loading;
  bool get initialized => _initialized;
  String? get errorTh => _errorTh;
  String? get noticeTh => _noticeTh;
  DateTime? get lastUpdated => _lastUpdated;
  WaterSource get source => _source;
  String? get selectedStationCode => _selectedStationCode;

  bool get isOffline => _source == WaterSource.cache;
  int get unreadCount => _alerts.where((a) => !a.read).length;

  int get warningStationCount =>
      _stations.where((s) => s.riskLevel.isAtLeastWarning).length;

  int get dangerStationCount =>
      _stations.where((s) => s.riskLevel == RiskLevel.danger).length;

  /// ระดับแจ้งเตือน 1–5 ของแต่ละอำเภอ (ใช้ระบายสี Polygon บนแผนที่ Google Maps)
  AlertLevel amphoeAlertLevel(String amphoeTh) {
    final fromSnap = _snapshot?.byAmphoe(amphoeTh);
    if (fromSnap != null) return AlertLevel.fromValue(fromSnap.level);
    var maxLv = 1;
    for (final s in _stations) {
      if (s.amphoeTh == amphoeTh) {
        final sev = s.riskLevel.severity;
        if (sev > maxLv) maxLv = sev;
      }
    }
    return AlertLevel.fromValue(maxLv);
  }

  List<SubdistrictBoundary> subdistrictsOf(String amphoeTh) =>
      _subdistricts.where((s) => s.amphoeTh == amphoeTh).toList();

  List<VillagePoint> villagesOf(String amphoeTh, String tumbonTh) => _villages
      .where((v) => v.amphoeTh == amphoeTh && v.tumbonTh == tumbonTh)
      .toList();

  /// ระดับน้ำแม่น้ำอ้างอิงในอำเภอ (เลือกสถานีที่ใกล้ตลิ่งที่สุด)
  double? referenceWaterMslForAmphoe(String amphoeTh) {
    final matching = _stations
        .where((s) => s.amphoeTh == amphoeTh && s.displayLevel != null && s.hasBank)
        .toList();
    if (matching.isEmpty) return null;
    matching.sort(
      (a, b) => (a.remainingToBank ?? 99.0).compareTo(b.remainingToBank ?? 99.0),
    );
    return matching.first.displayLevel;
  }

  /// ประเมินระดับสีความเสี่ยงน้ำท่วมถึงจากความสูงจากระดับน้ำทะเล (MSL) เทียบระดับน้ำแม่น้ำ
  /// ตรงตามสูตรใน Interactive iOS Preview 100%
  ElevationFloodResult elevationFloodLevel(double? elevMsl, String amphoeTh) {
    final ampLv = amphoeAlertLevel(amphoeTh).value;
    final refWater = referenceWaterMslForAmphoe(amphoeTh);

    if (elevMsl == null) {
      return ElevationFloodResult(
        level: ampLv,
        summaryTh: AlertLevel.fromValue(ampLv).labelTh,
        refWaterMsl: refWater,
      );
    }

    if (refWater != null) {
      final margin = double.parse((elevMsl - refWater).toStringAsFixed(1));
      var lv = 1;
      if (margin <= 0.5) {
        lv = 5;
      } else if (margin <= 2.5) {
        lv = 4;
      } else if (margin <= 6.0) {
        lv = 3;
      } else if (margin <= 12.0) {
        lv = 2;
      } else {
        lv = 1;
      }

      if (ampLv == 1 && lv >= 4) lv = 2;
      if (ampLv == 2 && lv == 5) lv = 3;
      if (ampLv >= 5 && margin <= 5.0) {
        lv = 5;
      } else if (ampLv >= 4 && margin <= 3.5 && lv < 4) {
        lv = 4;
      }

      final txt = margin <= 0
          ? 'ต่ำกว่าระดับน้ำ ${margin.abs().toStringAsFixed(1)} ม.'
          : 'สูงกว่าระดับน้ำ +${margin.toStringAsFixed(1)} ม.';
      return ElevationFloodResult(
        level: lv,
        summaryTh: txt,
        marginMeters: margin,
        refWaterMsl: refWater,
      );
    }

    // อำเภอไม่มีสถานีวัดน้ำ (เช่น อ.กาบัง)
    var lv = ampLv;
    if (elevMsl >= 120 && lv > 2) lv = lv - 1;
    return ElevationFloodResult(
      level: lv,
      summaryTh: 'สูง ${elevMsl.toStringAsFixed(0)} ม.รทก.',
    );
  }

  /// แจ้งเตือนที่กำลังมีผลอยู่ ณ ขณะนี้ (ไม่ใช้ Cooldown มาซ่อนสถานะเตือนภัยที่ยังไม่คลี่คลาย)
  List<AlertItem> get activeAlerts {
    if (_stations.isEmpty) return const <AlertItem>[];
    return _engine.evaluate(
      stations: _stations,
      settings: _settings,
      previous: const <AlertItem>[],
    );
  }

  Station? stationByCode(String? code) {
    if (code == null) return null;
    for (final station in _stations) {
      if (station.code == code) return station;
    }
    return null;
  }

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

  Future<void> hydrate() async {
    final store = _store;
    if (store != null) {
      _alerts = store.loadAlerts();
      _settings = store.loadSettings();
      _sosRequests = store.loadSosRequests();
      _gpsConsentGranted = store.loadGpsConsent();
    }
    _boundaries = await _snapshotService.loadYalaBoundaries();
    _subdistricts = await _snapshotService.loadYalaSubdistricts();
    _villages = await _snapshotService.loadYalaVillages();
    _snapshot = await _snapshotService.loadSnapshot();
    _initialized = true;
    await refresh();
  }

  Future<void> refresh({bool force = false}) async {
    if (_loading) return;
    _loading = true;
    _errorTh = null;
    notifyListeners();

    try {
      if (_boundaries.isEmpty) {
        _boundaries = await _snapshotService.loadYalaBoundaries();
      }
      if (_subdistricts.isEmpty) {
        _subdistricts = await _snapshotService.loadYalaSubdistricts();
      }
      if (_villages.isEmpty) {
        _villages = await _snapshotService.loadYalaVillages();
      }
      final snapFuture = _snapshotService.loadSnapshot();
      final result = await _waterService.fetch(forceRefresh: force);
      _stations = result.stations;
      _lastUpdated = result.updatedAt;
      _source = result.source;
      _noticeTh = result.messageTh;
      _snapshot = await snapFuture ?? _snapshot;

      final rain = await _loadRain();
      final newAlerts = _engine.evaluate(
        stations: _stations,
        settings: _settings,
        rain: rain,
        previous: _alerts,
      );
      if (newAlerts.isNotEmpty) {
        _alerts = _mergeAlerts(_alerts, newAlerts);
        await _dispatchLocalNotifications(newAlerts);
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

  Future<void> _dispatchLocalNotifications(List<AlertItem> freshAlerts) async {
    if (!_settings.pushEnabled || !_notifications.isReady) return;
    for (final alert in freshAlerts) {
      if (alert.pushed) {
        await _notifications.showFloodAlert(alert, quiet: _settings.quietMode);
      }
    }
  }

  Future<RainForecast?> _loadRain() async {
    if (AppConfig.rainForecastEndpoint.isEmpty) return null;
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

  void updateSettings(AlertSettings next) {
    _settings = next;
    notifyListeners();
    _store?.saveSettings(next);
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

  Future<void> setGpsConsent(bool granted) async {
    _gpsConsentGranted = granted;
    await _store?.saveGpsConsent(granted);
    notifyListeners();
  }

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

  Future<void> clearCache() async {
    await _waterService.clearCache();
    notifyListeners();
  }

  Future<void> deleteAllUserData() async {
    _alerts = const <AlertItem>[];
    _sosRequests = const <SosRequest>[];
    _settings = const AlertSettings();
    _gpsConsentGranted = false;
    await _store?.deleteAllUserData();
    await _waterService.clearCache();
    notifyListeners();
  }

  String get statusLineTh {
    if (_stations.isEmpty) {
      return _errorTh ?? 'กำลังโหลดข้อมูล…';
    }
    final buffer = StringBuffer(
      'สถานี ${_stations.length} แห่ง · เตือนภัย $warningStationCount · อันตราย $dangerStationCount',
    );
    if (_lastUpdated != null) {
      buffer.write(' · ${AppStrings.formatThailandTime(_lastUpdated!)}');
    }
    if (isOffline) buffer.write(' · ใช้ข้อมูลสำรอง');
    return buffer.toString();
  }
}
