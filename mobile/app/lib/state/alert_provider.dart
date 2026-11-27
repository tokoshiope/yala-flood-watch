import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/alert.dart';
import 'package:yala_flood_app/models/alert_settings.dart';
import 'package:yala_flood_app/models/flood_snapshot.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/station.dart';
import 'package:yala_flood_app/services/alert_engine.dart';
import 'package:yala_flood_app/services/local_store.dart';
import 'package:yala_flood_app/services/notification_service.dart';
import 'package:yala_flood_app/services/snapshot_service.dart';
import 'package:yala_flood_app/services/thai_water_service.dart';

/// ศูนย์รวม state ของแอป: สถานี 14 แห่ง, 5-Source Snapshot, ขอบเขต 3 ระดับ (8 อำเภอ/58 ตำบล/449 หมู่บ้าน),
/// แจ้งเตือน v5, Layer 2 Terrain Exposure (Zone A/B/C) และภาษา 4 ภาษา (0% UGC · 0% Server PII)
class AlertProvider extends ChangeNotifier {
  AlertProvider({
    required ThaiWaterService waterService,
    AlertEngine? engine,
    LocalStore? localStorage,
    NotificationService? notificationService,
    SnapshotService? snapshotService,
    // ignore: prefer_initializing_formals
  })  : _waterService = waterService,
        _engine = engine ?? const AlertEngine(),
        _store = localStorage,
        _notifications = notificationService ?? NotificationService.instance,
        _snapshotService = snapshotService ?? SnapshotService();

  final ThaiWaterService _waterService;
  final AlertEngine _engine;
  final LocalStore? _store;
  final NotificationService _notifications;
  final SnapshotService _snapshotService;

  List<Station> _stations = const <Station>[];
  List<AlertItem> _alerts = const <AlertItem>[];
  AlertSettings _settings = const AlertSettings();
  FloodSnapshot? _snapshot;
  List<AmphoeBoundary> _boundaries = const <AmphoeBoundary>[];
  List<SubdistrictBoundary> _subdistricts = const <SubdistrictBoundary>[];
  List<VillagePoint> _villages = const <VillagePoint>[];
  List<VillageZoneBoundary> _villageZones = const <VillageZoneBoundary>[];
  List<ElevationBandZone> _elevationZones = const <ElevationBandZone>[];
  DemElevationGrid? _demGrid;
  ({double lat, double lng, bool isGps})? _pinnedCoords;
  bool _gpsConsentGranted = false;
  int _dataResetVersion = 0;
  final Map<String, List<WaterLevelPoint>> _stationHistory7d =
      <String, List<WaterLevelPoint>>{};
  final Set<String> _loadingHistoryCodes = <String>{};

  bool _loading = false;
  bool _initialized = false;
  bool _disposed = false;
  String? _errorTh;
  String? _noticeTh;
  DateTime? _lastUpdated;
  WaterSource _source = WaterSource.network;
  String? _selectedStationCode;

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _waterService.close();
    _snapshotService.close();
    super.dispose();
  }

  List<Station> get stations => _stations;
  List<AlertItem> get alerts => _alerts;
  AlertSettings get settings => _settings;
  AppStrings get strings => AppStrings(_settings.languageCode);
  FloodSnapshot? get snapshot => _snapshot;
  List<AmphoeBoundary> get boundaries => _boundaries;
  List<SubdistrictBoundary> get subdistricts => _subdistricts;
  List<VillagePoint> get villages => _villages;
  List<VillageZoneBoundary> get villageZones => _villageZones;
  List<ElevationBandZone> get elevationZones => _elevationZones;
  DemElevationGrid? get demGrid => _demGrid;
  bool get gpsConsentGranted => _gpsConsentGranted;
  int get dataResetVersion => _dataResetVersion;
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
      _stations.where((s) => s.riskLevel.isHighOrDanger).length;

  /// ระดับแจ้งเตือน 1–5 ของแต่ละอำเภอ (Layer 1 Basin Hazard)
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

  /// ค้นหาชื่อตำบลภาษาอังกฤษจากขอบเขต 58 ตำบลเพื่อแสดงผลครบ 4 ภาษา
  String? tumbonEnOf(String? amphoeTh, String tumbonTh) {
    for (final s in _subdistricts) {
      if (s.tumbonTh == tumbonTh && (amphoeTh == null || s.amphoeTh == amphoeTh)) {
        if (s.tumbonEn.trim().isNotEmpty) return s.tumbonEn.trim();
      }
    }
    return null;
  }

  List<VillagePoint> villagesOf(String amphoeTh, String tumbonTh) => _villages
      .where((v) => v.amphoeTh == amphoeTh && v.tumbonTh == tumbonTh)
      .toList();

  /// รายชื่อหมู่บ้านและตำบลพื้นที่เฝ้าระวังสำคัญในอำเภอ (เรียงจาก Zone A ลุ่มต่ำ/ระดับเสี่ยงสูงสุดก่อน)
  List<({VillagePoint village, ElevationFloodResult eval})> watchVillagesForAmphoe(
    String amphoeTh, {
    int limit = 12,
  }) {
    final matching = _villages.where((v) => v.amphoeTh == amphoeTh).toList();
    if (matching.isEmpty) {
      final snapWatch =
          _snapshot?.byAmphoe(amphoeTh)?.watchAreas ?? const <WatchAreaInfo>[];
      return snapWatch.take(limit).map((w) {
        final vp = VillagePoint(
          code: '',
          moo: w.moo,
          nameTh: w.nameTh,
          nameEn: w.nameEn,
          amphoeTh: amphoeTh,
          tumbonTh: w.tumbonTh,
          lat: AppConfig.defaultLat,
          lon: AppConfig.defaultLng,
          elevationMsl: w.elevationMsl,
          exposureZone: w.exposureZone,
        );
        return (
          village: vp,
          eval: elevationFloodLevel(
            w.elevationMsl,
            amphoeTh,
            exposureZone: w.exposureZone,
          ),
        );
      }).toList();
    }

    final scored = <({
      VillagePoint village,
      ElevationFloodResult eval,
      int zoneOrder,
      double sortKey,
    })>[];
    for (final v in matching) {
      final ev = elevationFloodLevel(
        v.elevationMsl,
        amphoeTh,
        exposureZone: v.exposureZone,
        relHeightM: v.relHeightM,
      );
      final zOrder = v.exposureZone == 'A'
          ? 0
          : (v.exposureZone == 'B' ? 1 : 2);
      final key = ev.marginMeters ?? v.elevationMsl ?? 9999.0;
      scored.add((village: v, eval: ev, zoneOrder: zOrder, sortKey: key));
    }
    scored.sort((a, b) {
      final byLv = b.eval.level.compareTo(a.eval.level);
      if (byLv != 0) return byLv;
      final byZone = a.zoneOrder.compareTo(b.zoneOrder);
      if (byZone != 0) return byZone;
      final byMargin = a.sortKey.compareTo(b.sortKey);
      if (byMargin != 0) return byMargin;
      return a.village.nameTh.compareTo(b.village.nameTh);
    });
    return scored
        .take(limit)
        .map((e) => (village: e.village, eval: e.eval))
        .toList();
  }

  /// รายชื่อหมู่บ้านและตำบลในพื้นที่รอบสถานีวัดระดับน้ำ
  List<({VillagePoint village, ElevationFloodResult eval, double distKm})>
      watchVillagesNearStation(Station station, {int limit = 6}) {
    final amp = station.amphoeTh ?? '';
    if (amp.isEmpty || _villages.isEmpty) return const [];
    final sLat = station.lat;
    final sLng = station.lng;
    final refWater = station.displayLevel ?? referenceWaterMslForAmphoe(amp);
    final candidates = _villages.where((v) => v.amphoeTh == amp).toList();
    if (candidates.isEmpty) return const [];

    final scored = <({
      VillagePoint village,
      ElevationFloodResult eval,
      double distKm,
      bool sameTumbon,
      int zoneOrder,
      double sortMargin,
    })>[];
    for (final v in candidates) {
      final dist = (sLat != null && sLng != null)
          ? _haversineKm(sLat, sLng, v.lat, v.lon)
          : 99.0;
      final ev = elevationFloodLevel(
        v.elevationMsl,
        amp,
        exposureZone: v.exposureZone,
        relHeightM: v.relHeightM,
      );
      final margin = (v.elevationMsl != null && refWater != null)
          ? (v.elevationMsl! - refWater)
          : (ev.marginMeters ?? v.elevationMsl ?? 999.0);
      final zOrder = v.exposureZone == 'A'
          ? 0
          : (v.exposureZone == 'B' ? 1 : 2);
      scored.add((
        village: v,
        eval: ev,
        distKm: dist,
        sameTumbon: station.tumbonTh != null && v.tumbonTh == station.tumbonTh,
        zoneOrder: zOrder,
        sortMargin: margin,
      ));
    }
    final near = scored.where((e) => e.sameTumbon || e.distKm <= 12.0).toList();
    final pool = near.isNotEmpty ? near : scored;
    pool.sort((a, b) {
      final byLv = b.eval.level.compareTo(a.eval.level);
      if (byLv != 0) return byLv;
      final byZone = a.zoneOrder.compareTo(b.zoneOrder);
      if (byZone != 0) return byZone;
      final byMargin = a.sortMargin.compareTo(b.sortMargin);
      if (byMargin != 0) return byMargin;
      return a.distKm.compareTo(b.distKm);
    });
    return pool
        .take(limit)
        .map((e) => (village: e.village, eval: e.eval, distKm: e.distKm))
        .toList();
  }

  /// กราฟระดับน้ำย้อนหลัง 7 วันของสถานี (คืนข้อมูลความละเอียดสูงที่โหลดแล้ว หรือ Snapshot สำรองทันที)
  List<WaterLevelPoint> stationHistory7d(String stationCode) {
    final live = _stationHistory7d[stationCode];
    if (live != null && live.isNotEmpty) return live;
    return _snapshot?.stationHistory7dByCode[stationCode] ??
        const <WaterLevelPoint>[];
  }

  bool isStationHistoryLoading(String stationCode) =>
      _loadingHistoryCodes.contains(stationCode);

  /// โหลดข้อมูลระดับน้ำย้อนหลัง 7 วันความละเอียดเต็มจาก ThaiWater `waterlevel_graph`
  Future<List<WaterLevelPoint>> loadStationHistory7d(
    Station station, {
    bool forceRefresh = false,
  }) async {
    final code = station.code;
    if (_loadingHistoryCodes.contains(code)) {
      return stationHistory7d(code);
    }
    _loadingHistoryCodes.add(code);
    notifyListeners();
    try {
      final teleId = station.stationId ?? _snapshot?.stationTeleIdByCode[code];
      final fetched = await _waterService.fetchStationHistory7d(
        station,
        teleStationIdOverride: teleId,
        days: 7,
        forceRefresh: forceRefresh,
      );
      if (fetched.isNotEmpty) {
        _stationHistory7d[code] = fetched;
      }
      return stationHistory7d(code);
    } finally {
      _loadingHistoryCodes.remove(code);
      notifyListeners();
    }
  }

  List<VillageZoneBoundary> villageZonesOf(String amphoeTh, String tumbonTh) =>
      _villageZones
          .where((v) => v.amphoeTh == amphoeTh && v.tumbonTh == tumbonTh)
          .toList();

  List<ElevationBandZone> elevationZonesOf(String? amphoeTh) => amphoeTh == null
      ? _elevationZones
      : _elevationZones.where((z) => z.amphoeTh == amphoeTh).toList();

  /// สีไล่ระดับแผนที่ตาม Layer 2 Unified Basin Hazard × Terrain Exposure Matrix (Zone A/B/C)
  /// - เมื่อ Basin Level == 1: ทุกโซนแสดงเฉดเขียวภูมิประเทศสงบ (ไม่มีสีแดง/ส้ม/เหลืองลวงในวันแดดออก)
  /// - เมื่อ Basin Level 2–5: Zone A เปลี่ยนสีตามระดับภัย 1:1, Zone B ตามหลัง 1 ขั้น, Zone C คงสีเขียวปลอดภัย
  Color elevationGradientColor(
    double elevMsl,
    String amphoeTh, {
    String? exposureZone,
    double? relHeightM,
  }) {
    final ampLv = amphoeAlertLevel(amphoeTh).value;
    final zone = (exposureZone ?? _inferExposureZoneForElev(elevMsl, amphoeTh))
        .toUpperCase();

    if (ampLv <= 1) {
      // สถานการณ์ปกติ: เฉดสีเขียวภูมิประเทศจริง (ลุ่มต่ำสีเขียวอ่อน -> ที่สูงสีเขียวเข้ม)
      if (zone == 'A') return const Color(0xFF9CCC65);
      if (zone == 'B') return const Color(0xFF66BB6A);
      if (elevMsl < 120) return const Color(0xFF43A047);
      if (elevMsl < 280) return const Color(0xFF2E7D32);
      return const Color(0xFF1B5E20);
    }

    final overflowDepth = _amphoeOverflowDepthM(amphoeTh);
    final effectiveLv = AlertEngine.evaluateTerrainExposureLevel(
      basinLevel: ampLv,
      exposureZone: zone,
      overflowDepthM: overflowDepth,
      relHeightM: relHeightM,
    );

    if (effectiveLv >= 2) {
      return AlertLevel.fromValue(effectiveLv).color;
    }

    // Effective Level == 1 (เช่น Zone C พื้นที่สูง หรือ Zone B ในระดับเฝ้าระวัง) -> เฉดเขียวปลอดภัย
    if (zone == 'B') return const Color(0xFF66BB6A);
    if (elevMsl < 120) return const Color(0xFF43A047);
    if (elevMsl < 280) return const Color(0xFF2E7D32);
    return const Color(0xFF1B5E20);
  }

  String _inferExposureZoneForElev(double elevMsl, String amphoeTh) {
    final bank = _referenceBankMslForAmphoe(amphoeTh);
    if (bank != null) {
      if (elevMsl <= bank + 1.5) return 'A';
      if (elevMsl <= bank + 5.0) return 'B';
      return 'C';
    }
    final floor = _minElevForAmphoe(amphoeTh) ?? 20.0;
    final rel = elevMsl - floor;
    if (rel <= 5.0) return 'A';
    if (rel <= 15.0) return 'B';
    return 'C';
  }

  /// ประเมินพิกัด GPS หรือหมุดที่ผู้ใช้ปักไว้บนแผนที่แบบ Hyper-Local (Zone A/B/C × Basin Hazard)
  UserPinAssessment? get userPinAssessment {
    final pin = _pinnedCoords;
    if (pin == null) return null;
    return evaluateCoordinates(pin.lat, pin.lng, isGps: pin.isGps);
  }

  /// ประเมินพิกัดใด ๆ ในจังหวัดยะลาแบบออฟไลน์ (Layer 2 Unified Matrix + Zone C Advisory)
  UserPinAssessment evaluateCoordinates(
    double lat,
    double lng, {
    bool isGps = true,
  }) {
    final pt = LatLng(lat, lng);

    String? matchedAmphoe;
    for (final b in _boundaries) {
      if (SnapshotService.pointInRings(pt, b.rings)) {
        matchedAmphoe = b.amphoeTh;
        break;
      }
    }

    String? matchedTumbon;
    String? matchedTumbonEn;
    double? matchedTumbonFloor;
    for (final s in _subdistricts) {
      if (matchedAmphoe != null && s.amphoeTh != matchedAmphoe) continue;
      if (SnapshotService.pointInRings(pt, s.rings)) {
        matchedTumbon = s.tumbonTh;
        matchedTumbonEn = s.tumbonEn;
        matchedTumbonFloor = s.minElevationMsl;
        matchedAmphoe ??= s.amphoeTh;
        break;
      }
    }

    // ความสูงภูมิประเทศจริงจาก Copernicus DEM grid (ออฟไลน์) หรือ fallback หมู่บ้านใกล้สุด
    double? elevMsl = _demGrid?.elevationAt(lat, lng);
    if (elevMsl == null && _villages.isNotEmpty) {
      VillagePoint? nearestV;
      var bestDist = double.infinity;
      for (final v in _villages) {
        if (v.elevationMsl == null) continue;
        final d = _haversineKm(lat, lng, v.lat, v.lon);
        if (d < bestDist) {
          bestDist = d;
          nearestV = v;
        }
      }
      if (nearestV != null && bestDist <= 10.0) {
        elevMsl = nearestV.elevationMsl;
      }
    }

    // หาสถานีวัดระดับน้ำใกล้ที่สุด (ทั้งหมด + สถานีที่ยืนยันฐานตลิ่งแล้วในอำเภอเดียวกัน)
    Station? nearestSt;
    var nearestDist = double.infinity;
    Station? nearestVerifiedSameAmp;
    var nearestVerifiedDist = double.infinity;
    final amphoeHint = matchedAmphoe;
    for (final st in _stations) {
      if (!st.hasCoordinate) continue;
      final d = _haversineKm(lat, lng, st.lat!, st.lng!);
      if (d < nearestDist) {
        nearestDist = d;
        nearestSt = st;
      }
      if (st.hasBank &&
          (amphoeHint == null || st.amphoeTh == amphoeHint) &&
          d < nearestVerifiedDist) {
        nearestVerifiedDist = d;
        nearestVerifiedSameAmp = st;
      }
    }

    final amphoeForEval = matchedAmphoe ?? nearestSt?.amphoeTh ?? 'เมืองยะลา';

    // จำแนก Zone A / B / C ตาม spec-unified-impact-early-warning-v5.md §3.1
    String zone = 'A';
    double? relHeight;
    if (elevMsl != null) {
      if (nearestVerifiedSameAmp != null &&
          nearestVerifiedDist <= 5.0 &&
          nearestVerifiedSameAmp.criticalLevel != null) {
        final bank = nearestVerifiedSameAmp.criticalLevel!;
        relHeight = double.parse((elevMsl - bank).toStringAsFixed(2));
        if (elevMsl <= bank + 1.5) {
          zone = 'A';
        } else if (elevMsl <= bank + 5.0) {
          zone = 'B';
        } else {
          zone = 'C';
        }
      } else {
        final floor =
            matchedTumbonFloor ?? _minElevForAmphoe(amphoeForEval) ?? elevMsl;
        relHeight = double.parse((elevMsl - floor).toStringAsFixed(2));
        if (relHeight <= 5.0) {
          zone = 'A';
        } else if (relHeight <= 15.0) {
          zone = 'B';
        } else {
          zone = 'C';
        }
      }
    }

    final elevEval = elevationFloodLevel(
      elevMsl,
      amphoeForEval,
      exposureZone: zone,
      relHeightM: relHeight,
    );

    return UserPinAssessment(
      lat: lat,
      lng: lng,
      isGps: isGps,
      level: elevEval.level,
      amphoeTh: matchedAmphoe,
      tumbonTh: matchedTumbon,
      tumbonEn: matchedTumbonEn,
      elevationMsl: elevMsl,
      refWaterMsl: elevEval.refWaterMsl ?? nearestSt?.displayLevel,
      marginMeters: elevEval.marginMeters,
      nearestStationCode: nearestSt?.code,
      nearestStationDistKm: nearestSt != null ? nearestDist : null,
      exposureZone: elevEval.exposureZone,
      advisoryNote: elevEval.advisoryNote,
    );
  }

  Future<void> setPinnedLocation(double lat, double lng, {bool isGps = false}) async {
    _pinnedCoords = (lat: lat, lng: lng, isGps: isGps);
    await _store?.savePinnedLocation(lat, lng, isGps: isGps);
    notifyListeners();
  }

  Future<void> clearPinnedLocation() async {
    _pinnedCoords = null;
    await _store?.clearPinnedLocation();
    notifyListeners();
  }

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final p1 = lat1 * math.pi / 180.0;
    final p2 = lat2 * math.pi / 180.0;
    final dp = (lat2 - lat1) * math.pi / 180.0;
    final dl = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dp / 2) * math.sin(dp / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return 2 * r * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
  }

  /// ระดับน้ำแม่น้ำอ้างอิงในอำเภอ (เลือกสถานีที่ยืนยันฐานตลิ่งแล้วและใกล้ตลิ่งที่สุด)
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

  double? _referenceBankMslForAmphoe(String amphoeTh) {
    final matching = _stations
        .where((s) => s.amphoeTh == amphoeTh && s.hasBank && s.criticalLevel != null)
        .toList();
    if (matching.isEmpty) return null;
    matching.sort(
      (a, b) => (a.remainingToBank ?? 99.0).compareTo(b.remainingToBank ?? 99.0),
    );
    return matching.first.criticalLevel;
  }

  double _amphoeOverflowDepthM(String amphoeTh) {
    var maxOverflow = 0.0;
    for (final s in _stations) {
      if (s.amphoeTh != amphoeTh || !s.hasBank) continue;
      final rem = s.remainingToBank;
      if (rem != null && rem < 0 && -rem > maxOverflow) {
        maxOverflow = -rem;
      }
    }
    return maxOverflow;
  }

  double? _minElevForAmphoe(String amphoeTh) {
    double? best;
    for (final v in _villages) {
      if (v.amphoeTh != amphoeTh || v.elevationMsl == null) continue;
      if (best == null || v.elevationMsl! < best) {
        best = v.elevationMsl;
      }
    }
    return best;
  }

  /// ประเมินระดับผลกระทบเฉพาะจุดตาม Layer 2 Unified Basin Hazard × Terrain Exposure Matrix (Zone A/B/C)
  ElevationFloodResult elevationFloodLevel(
    double? elevMsl,
    String amphoeTh, {
    String? exposureZone,
    double? relHeightM,
  }) {
    final ampLv = amphoeAlertLevel(amphoeTh).value;
    final refWater = referenceWaterMslForAmphoe(amphoeTh);

    if (elevMsl == null) {
      return ElevationFloodResult(
        level: ampLv,
        summaryTh: AlertLevel.fromValue(ampLv).labelTh,
        refWaterMsl: refWater,
        exposureZone: exposureZone ?? 'A',
      );
    }

    final zone = (exposureZone ?? _inferExposureZoneForElev(elevMsl, amphoeTh))
        .toUpperCase();
    final overflowDepth = _amphoeOverflowDepthM(amphoeTh);
    final effectiveLv = AlertEngine.evaluateTerrainExposureLevel(
      basinLevel: ampLv,
      exposureZone: zone,
      overflowDepthM: overflowDepth,
      relHeightM: relHeightM,
    );

    String? advisory;
    if (zone == 'C' && ampLv >= 3) {
      final isMountainFlash = AppConfig.flashFloodAmphoes.contains(amphoeTh);
      if (ampLv >= 5) {
        advisory = strings.get('zone_c_advisory_lv5');
      } else if (ampLv >= 4 && isMountainFlash) {
        advisory = strings.get('zone_c_advisory_flash_lv4');
      } else if (ampLv >= 4) {
        advisory = strings.get('zone_c_advisory_lv4');
      } else {
        advisory = strings.get('zone_c_advisory_lv3');
      }
    }

    if (refWater != null) {
      final margin = double.parse((elevMsl - refWater).toStringAsFixed(1));
      final txt = margin <= 0
          ? 'ต่ำกว่าระดับน้ำ ${margin.abs().toStringAsFixed(1)} ม.'
          : 'สูงกว่าระดับน้ำ +${margin.toStringAsFixed(1)} ม.';
      return ElevationFloodResult(
        level: effectiveLv,
        summaryTh: txt,
        marginMeters: margin,
        refWaterMsl: refWater,
        exposureZone: zone,
        advisoryNote: advisory,
      );
    }

    return ElevationFloodResult(
      level: effectiveLv,
      summaryTh: 'สูง ${elevMsl.toStringAsFixed(0)} ม.รทก.',
      exposureZone: zone,
      advisoryNote: advisory,
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
      _gpsConsentGranted = store.loadGpsConsent();
      _pinnedCoords = store.loadPinnedLocation();
    }
    // โหลดขอบเขตแผนที่ทั้ง 3 ระดับ, ชั้นความสูง DEM และแคชในเครื่องแบบขนานเพื่อให้เปิดหน้าจอได้ทันที
    final results = await Future.wait<dynamic>([
      _snapshotService.loadYalaBoundaries(),
      _snapshotService.loadYalaSubdistricts(),
      _snapshotService.loadYalaVillages(),
      _snapshotService.loadVillageZones(),
      _snapshotService.loadElevationZones(),
      _snapshotService.loadDemGrid(),
      _snapshotService.loadCachedOrBundledSnapshot(),
    ]);
    _boundaries = results[0] as List<AmphoeBoundary>;
    _subdistricts = results[1] as List<SubdistrictBoundary>;
    _villages = results[2] as List<VillagePoint>;
    _villageZones = results[3] as List<VillageZoneBoundary>;
    _elevationZones = results[4] as List<ElevationBandZone>;
    _demGrid = results[5] as DemElevationGrid?;
    _snapshot = results[6] as FloodSnapshot?;
    _initialized = true;
    notifyListeners();

    await _notifications.syncTopicSubscription(
      pushEnabled: _settings.pushEnabled,
      selectedAmphoeTh: _settings.selectedAmphoeTh,
    );
    await refresh();
  }

  /// รีเฟรชอัตโนมัติเมื่อผู้ใช้กลับมาเปิดแอปและข้อมูลเก่าเกินค่าที่ตั้งไว้ใน settings.refreshMinutes
  Future<void> refreshIfStale() async {
    if (_loading) return;
    final last = _lastUpdated;
    if (last == null ||
        DateTime.now().difference(last) >=
            Duration(minutes: _settings.refreshMinutes)) {
      await refresh();
    }
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
      if (_villageZones.isEmpty) {
        _villageZones = await _snapshotService.loadVillageZones();
      }
      if (_elevationZones.isEmpty) {
        _elevationZones = await _snapshotService.loadElevationZones();
      }
      _demGrid ??= await _snapshotService.loadDemGrid();
      final snapFuture = _snapshotService.loadSnapshot();
      final result = await _waterService.fetch(forceRefresh: force);
      _stations = result.stations;
      _lastUpdated = result.updatedAt;
      _source = result.source;
      _noticeTh = result.messageTh;
      _snapshot = await snapFuture ?? _snapshot;

      final newAlerts = _engine.evaluate(
        stations: _stations,
        settings: _settings,
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
    _notifications.syncTopicSubscription(
      pushEnabled: next.pushEnabled,
      selectedAmphoeTh: next.selectedAmphoeTh,
    );
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

  void setSelectedStation(String? code) {
    _selectedStationCode = code;
    notifyListeners();
  }

  Future<void> clearCache() async {
    _stationHistory7d.clear();
    await _waterService.clearCache();
    await _snapshotService.clearSnapshotCache();
    notifyListeners();
  }

  Future<void> deleteAllUserData() async {
    _alerts = const <AlertItem>[];
    _settings = const AlertSettings();
    _gpsConsentGranted = false;
    _pinnedCoords = null;
    _dataResetVersion++;
    await _store?.deleteAllUserData();
    await _waterService.clearCache();
    await _snapshotService.clearSnapshotCache();
    await _notifications.syncTopicSubscription(
      pushEnabled: _settings.pushEnabled,
      selectedAmphoeTh: _settings.selectedAmphoeTh,
    );
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
