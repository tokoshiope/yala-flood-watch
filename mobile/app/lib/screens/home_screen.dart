import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/flood_snapshot.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/saved_place.dart';
import 'package:yala_flood_app/models/station.dart';
import 'package:yala_flood_app/screens/guide_screen.dart';
import 'package:yala_flood_app/screens/station_detail_screen.dart';
import 'package:yala_flood_app/services/caching_tile_provider.dart';
import 'package:yala_flood_app/state/alert_provider.dart';
import 'package:yala_flood_app/widgets/family_watch_strip.dart';
import 'package:yala_flood_app/widgets/risk_badge.dart';
import 'package:yala_flood_app/widgets/share_status_sheet.dart';
import 'package:yala_flood_app/widgets/station_marker.dart';

/// แถบที่ 1 "แผนที่":
/// - รองรับ iOS Light Mode & Dark Mode ชัดเจนทุกตัวอักษรและป้ายแผนที่
/// - ระบายสีไล่ระดับจริงตามความสูงภูมิประเทศจากระดับน้ำทะเล (Copernicus DEM ม.รทก.)
/// - เส้นขอบเว้าโค้งตามพื้นที่อ้างอิงจริง 3 ระดับ (8 อำเภอ → 58 ตำบล → โซนหมู่บ้าน)
/// - ป้ายสถานีแสดงชื่อสถานีจริง (เช่น บ้านปายอยือนิ) รองรับ 4 ภาษาเต็มรูปแบบ
/// - ปุ่มระบุพิกัด GPS เครื่องผู้ใช้ (PDPA) และปักหมุดบนแผนที่เพื่อเทียบความสูงและระดับแจ้งเตือน
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final CachingTileProvider _tileProvider = CachingTileProvider();
  String? _selectedCode;
  String? _drillAmphoe;
  String? _drillTumbon;
  bool _pinDropMode = false;
  bool _locatingGps = false;

  // Memoized map polygons so unrelated notifyListeners() calls don't reallocate 400+ polygons
  String? _cachedPolyKey;
  List<Polygon> _cachedPolygons = const <Polygon>[];

  static final LatLngBounds _yalaBounds = LatLngBounds(
    const LatLng(5.55, 100.78),
    const LatLng(6.76, 101.68),
  );

  static const List<LatLng> _outerWorldMask = [
    LatLng(-20, 60),
    LatLng(-20, 140),
    LatLng(35, 140),
    LatLng(35, 60),
  ];

  @override
  void dispose() {
    _mapController.dispose();
    _tileProvider.dispose();
    super.dispose();
  }

  void _drillToProvince() {
    setState(() {
      _drillAmphoe = null;
      _drillTumbon = null;
      _selectedCode = null;
    });
    _mapController.move(
      const LatLng(AppConfig.defaultLat, AppConfig.defaultLng),
      AppConfig.defaultZoom,
    );
  }

  void _drillToAmphoe(AlertProvider provider, String amphoeTh) {
    setState(() {
      _drillAmphoe = amphoeTh;
      _drillTumbon = null;
    });
    for (final b in provider.boundaries) {
      if (b.amphoeTh == amphoeTh) {
        _mapController.move(b.centroid, 10.6);
        break;
      }
    }
  }

  void _drillToTumbon(AlertProvider provider, String amphoeTh, String tumbonTh) {
    setState(() {
      _drillAmphoe = amphoeTh;
      _drillTumbon = tumbonTh;
    });
    for (final sub in provider.subdistrictsOf(amphoeTh)) {
      if (sub.tumbonTh == tumbonTh) {
        _mapController.move(sub.centroid, 12.2);
        break;
      }
    }
  }

  Future<void> _locateUserOnMap(AlertProvider provider) async {
    final strings = provider.strings;
    if (!provider.gpsConsentGranted) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(strings.get('gps_consent_title')),
          content: Text(strings.get('gps_consent_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.get('gps_decline')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(strings.get('gps_accept')),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
      await provider.setGpsConsent(true);
    }

    setState(() => _locatingGps = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.get('gps_permission_denied'))),
          );
        }
        return;
      }
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.get('gps_service_disabled'))),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final inYala = pos.latitude >= 5.5 &&
          pos.latitude <= 7.2 &&
          pos.longitude >= 100.5 &&
          pos.longitude <= 101.9;
      if (!inYala) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.get('outside_yala_notice'))),
        );
        return;
      }
      await provider.setPinnedLocation(pos.latitude, pos.longitude, isGps: true);
      if (mounted) {
        setState(() => _pinDropMode = false);
        _mapController.move(LatLng(pos.latitude, pos.longitude), 12.2);
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.get('gps_permission_denied'))),
        );
      }
    } finally {
      if (mounted) setState(() => _locatingGps = false);
    }
  }

  Future<void> _dropPinAt(AlertProvider provider, LatLng pt) async {
    final strings = provider.strings;
    final inYala = pt.latitude >= 5.5 &&
        pt.latitude <= 7.2 &&
        pt.longitude >= 100.5 &&
        pt.longitude <= 101.9;
    if (!inYala) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.get('outside_yala_notice'))),
      );
      return;
    }
    await provider.setPinnedLocation(pt.latitude, pt.longitude, isGps: false);
    if (mounted) {
      setState(() => _pinDropMode = false);
    }
  }

  void _openDetail(Station station) {
    context.read<AlertProvider>().setSelectedStation(station.code);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StationDetailScreen(stationCode: station.code),
      ),
    );
  }

  Future<void> _showStationSheet(Station station, AppStrings strings) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.stationFullName(station),
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                  ),
                  RiskBadge(level: station.riskLevel, strings: strings),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                strings.stationLocation(station),
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Text(_stationSummary(station, strings)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _openDetail(station);
                  },
                  icon: const Icon(Icons.insights_outlined),
                  label: Text(strings.get('view_station_detail')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _stationSummary(Station station, AppStrings strings) {
    final level = station.displayLevel;
    final buffer = StringBuffer();
    if (level != null) {
      buffer.write(
        '${strings.get('latest_water_level')} ${level.toStringAsFixed(2)} ${strings.get('unit_msl')}',
      );
    } else {
      buffer.write(strings.get('no_water_reading'));
    }
    final remaining = station.remainingToBank;
    if (remaining != null) {
      buffer.write(' · ${strings.remainingToBankText(remaining)}');
    }
    if (station.trend != WaterTrend.unknown) {
      buffer.write(' · ${strings.waterTrendLabel(station.trend)}');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final strings = provider.strings;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.get('app_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            if (provider.lastUpdated != null)
              Text(
                strings.formatTime(provider.lastUpdated!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: strings.get('share_status_btn'),
            onPressed: () {
              final targetAmp = _drillAmphoe ??
                  provider.settings.selectedAmphoeTh ??
                  'เมืองยะลา';
              final lv = provider.amphoeAlertLevel(targetAmp).value;
              showShareStatusSheet(
                context,
                provider: provider,
                placeLabel: strings.amphoe(targetAmp),
                amphoeTh: targetAmp,
                level: lv,
              );
            },
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: strings.get('guide_title'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const GuideScreen()),
            ),
            icon: const Icon(Icons.menu_book_outlined),
          ),
          IconButton(
            tooltip: strings.get('refresh_tooltip'),
            onPressed: provider.loading
                ? null
                : () => provider.refresh(force: true),
            icon: provider.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _buildBody(context, provider),
    );
  }

  Widget _buildBody(BuildContext context, AlertProvider provider) {
    final strings = provider.strings;
    if (provider.loading && provider.stations.isEmpty) {
      return _LoadingView(strings: strings);
    }
    if (provider.stations.isEmpty) {
      return _ErrorView(
        strings: strings,
        message: strings.lang == 'th'
            ? (provider.errorTh ?? strings.get('no_station_data'))
            : strings.get('no_station_data'),
        onRetry: () => provider.refresh(force: true),
      );
    }

    final dam = provider.snapshot?.bangLangDam;
    final pinAssessment = provider.userPinAssessment;

    return Column(
      children: [
        if (provider.isOffline || provider.noticeTh != null)
          _OfflineBanner(strings: strings, messageTh: provider.noticeTh),
        if (dam != null) _BangLangDamCard(dam: dam, strings: strings),
        FamilyWatchStrip(
          provider: provider,
          onFocusPoint: (pt, amphoeTh) {
            setState(() {
              _drillAmphoe = amphoeTh;
              _drillTumbon = null;
            });
            _mapController.move(pt, 12.0);
          },
        ),
        _DrillBreadcrumbBar(
          drillAmphoe: _drillAmphoe,
          drillTumbon: _drillTumbon,
          provider: provider,
          onBackProvince: _drillToProvince,
          onBackAmphoe: _drillAmphoe == null
              ? null
              : () => _drillToAmphoe(provider, _drillAmphoe!),
        ),
        if (_pinDropMode)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                Icon(
                  Icons.push_pin,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.get('pin_mode_hint'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => setState(() => _pinDropMode = false),
                  child: Text(strings.get('cancel')),
                ),
              ],
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              _buildMap(context, provider),
              // ปุ่มควบคุมตำแหน่ง GPS และปักหมุดบนแผนที่
              Positioned(
                right: 10,
                top: 10,
                child: Column(
                  children: [
                    _MapActionFab(
                      icon: _locatingGps ? Icons.gps_not_fixed : Icons.my_location,
                      tooltip: strings.get('my_location_btn'),
                      active: pinAssessment?.isGps == true,
                      loading: _locatingGps,
                      onPressed: _locatingGps ? null : () => _locateUserOnMap(provider),
                    ),
                    const SizedBox(height: 8),
                    _MapActionFab(
                      icon: _pinDropMode ? Icons.close : Icons.add_location_alt,
                      tooltip: strings.get('pin_mode_btn'),
                      active: _pinDropMode || (pinAssessment != null && !pinAssessment.isGps),
                      onPressed: () => setState(() => _pinDropMode = !_pinDropMode),
                    ),
                  ],
                ),
              ),
              // คำอธิบายแถบสีไล่ระดับตามความสูงจากระดับน้ำทะเล (ม.รทก.)
              Positioned(
                left: 10,
                bottom: pinAssessment != null ? 102 : 10,
                child: _ElevationLegendChip(strings: strings),
              ),
              // การ์ดสรุปพิกัดของผู้ใช้ / หมุดปักเทียบระดับน้ำและระดับแจ้งเตือน
              if (pinAssessment != null)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: _UserPinCard(
                    assessment: pinAssessment,
                    provider: provider,
                    onClear: () => provider.clearPinnedLocation(),
                    onFocus: () => _mapController.move(pinAssessment.point, 13.0),
                  ),
                ),
            ],
          ),
        ),
        _DrillListStrip(
          provider: provider,
          drillAmphoe: _drillAmphoe,
          drillTumbon: _drillTumbon,
          onSelectAmphoe: (amp) => _drillToAmphoe(provider, amp),
          onSelectTumbon: (amp, tam) => _drillToTumbon(provider, amp, tam),
          onSelectVillage: (v) => _mapController.move(v.point, 14.0),
        ),
      ],
    );
  }

  List<Polygon> _buildMemoizedPolygons(
    AlertProvider provider,
    bool isDark,
  ) {
    final stSig = provider.stations
        .map((s) => '${s.code}:${s.riskLevel.severity}:${s.displayLevel?.toStringAsFixed(2) ?? ''}')
        .join(',');
    final polyKey = '${_drillAmphoe ?? ''}|${_drillTumbon ?? ''}|'
        '${isDark ? 1 : 0}|${provider.snapshot?.contentHash ?? ''}|'
        '${provider.boundaries.length}|${provider.subdistricts.length}|'
        '${provider.elevationZones.length}|${provider.villageZones.length}|$stSig';
    if (_cachedPolyKey == polyKey) {
      return _cachedPolygons;
    }

    final maskHoles = <List<LatLng>>[
      for (final b in provider.boundaries) ...b.rings,
    ];
    final polygons = <Polygon>[];
    if (maskHoles.isNotEmpty) {
      polygons.add(
        Polygon(
          points: _outerWorldMask,
          holePointsList: maskHoles,
          color: const Color(0xD90F172A),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
        ),
      );
    }

    final elevZones = provider.elevationZonesOf(_drillAmphoe);
    if (_drillTumbon == null && elevZones.isNotEmpty) {
      for (final ez in elevZones) {
        final gradColor = provider.elevationGradientColor(
          ez.elevMid,
          ez.amphoeTh,
          exposureZone: ez.exposureZone,
        );
        polygons.add(
          Polygon(
            points: ez.ring,
            color: gradColor.withValues(alpha: _drillAmphoe == null ? 0.44 : 0.36),
            borderColor: Colors.transparent,
            borderStrokeWidth: 0,
          ),
        );
      }
    }

    if (_drillAmphoe == null) {
      for (final boundary in provider.boundaries) {
        final level = provider.amphoeAlertLevel(boundary.amphoeTh);
        for (final ring in boundary.rings) {
          polygons.add(
            Polygon(
              points: ring,
              color: elevZones.isEmpty
                  ? level.color.withValues(alpha: 0.34)
                  : Colors.transparent,
              borderColor: isDark ? const Color(0xE6FFFFFF) : const Color(0xFF0F172A),
              borderStrokeWidth: 1.6,
            ),
          );
        }
      }
    } else if (_drillTumbon == null) {
      final subs = provider.subdistrictsOf(_drillAmphoe!);
      for (final sub in subs) {
        final elev = provider.elevationFloodLevel(
          sub.minElevationMsl ?? sub.elevationMsl,
          sub.amphoeTh,
        );
        final lv = AlertLevel.fromValue(elev.level);
        for (final ring in sub.rings) {
          polygons.add(
            Polygon(
              points: ring,
              color: elevZones.isEmpty
                  ? lv.color.withValues(alpha: 0.42)
                  : lv.color.withValues(alpha: 0.12),
              borderColor: isDark ? Colors.white : const Color(0xFF1E293B),
              borderStrokeWidth: 1.5,
            ),
          );
        }
      }
    } else {
      final vZones = provider.villageZonesOf(_drillAmphoe!, _drillTumbon!);
      for (final vz in vZones) {
        final gradColor = vz.elevationMsl != null
            ? provider.elevationGradientColor(
                vz.elevationMsl!,
                vz.amphoeTh,
                exposureZone: vz.exposureZone,
                relHeightM: vz.relHeightM,
              )
            : provider.amphoeAlertLevel(vz.amphoeTh).color;
        for (final ring in vz.rings) {
          polygons.add(
            Polygon(
              points: ring,
              color: gradColor.withValues(alpha: 0.34),
              borderColor: isDark ? Colors.white70 : const Color(0xAA0F172A),
              borderStrokeWidth: 1.1,
            ),
          );
        }
      }
      final subs = provider.subdistrictsOf(_drillAmphoe!);
      for (final sub in subs) {
        final isTarget = sub.tumbonTh == _drillTumbon;
        for (final ring in sub.rings) {
          polygons.add(
            Polygon(
              points: ring,
              color: isTarget ? Colors.transparent : const Color(0x401E293B),
              borderColor: isTarget
                  ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF0E5FA6))
                  : Colors.white54,
              borderStrokeWidth: isTarget ? 2.4 : 1.0,
            ),
          );
        }
      }
    }

    _cachedPolyKey = polyKey;
    _cachedPolygons = polygons;
    return polygons;
  }

  Widget _buildMap(BuildContext context, AlertProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = provider.strings;

    final pillBg = isDark ? const Color(0xF00F172A) : const Color(0xF5FFFFFF);
    final pillFg = isDark ? Colors.white : const Color(0xFF0F172A);

    final polygons = _buildMemoizedPolygons(provider, isDark);
    final areaMarkers = <Marker>[];

    if (_drillAmphoe == null) {
      for (final boundary in provider.boundaries) {
        final level = provider.amphoeAlertLevel(boundary.amphoeTh);
        final borderColor = level.colorFor(Theme.of(context).brightness);
        areaMarkers.add(
          Marker(
            point: boundary.centroid,
            width: 126,
            height: 28,
            child: GestureDetector(
              onTap: () => _drillToAmphoe(provider, boundary.amphoeTh),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor, width: 1.6),
                    boxShadow: const [
                      BoxShadow(color: Color(0x44000000), blurRadius: 3),
                    ],
                  ),
                  child: Text(
                    strings.amphoe(boundary.amphoeTh),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: pillFg,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    } else if (_drillTumbon == null) {
      final subs = provider.subdistrictsOf(_drillAmphoe!);
      for (final sub in subs) {
        final elev = provider.elevationFloodLevel(
          sub.minElevationMsl ?? sub.elevationMsl,
          sub.amphoeTh,
        );
        final lv = AlertLevel.fromValue(elev.level);
        final borderColor = lv.colorFor(Theme.of(context).brightness);
        areaMarkers.add(
          Marker(
            point: sub.centroid,
            width: 128,
            height: 28,
            child: GestureDetector(
              onTap: () => _drillToTumbon(provider, sub.amphoeTh, sub.tumbonTh),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: borderColor, width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Color(0x44000000), blurRadius: 3),
                    ],
                  ),
                  child: Text(
                    strings.tumbonName(sub.tumbonTh, sub.tumbonEn),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: pillFg,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    } else {
      final villages = provider.villagesOf(_drillAmphoe!, _drillTumbon!);
      for (final v in villages) {
        final elev = provider.elevationFloodLevel(
          v.elevationMsl,
          v.amphoeTh,
          exposureZone: v.exposureZone,
          relHeightM: v.relHeightM,
        );
        final lv = AlertLevel.fromValue(elev.level);
        areaMarkers.add(
          Marker(
            point: v.point,
            width: 132,
            height: 38,
            child: GestureDetector(
              onTap: () => _showVillageSheet(v, elev, lv, strings),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: lv.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: lv.colorFor(Theme.of(context).brightness),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      strings.villageName(v.moo, v.nameTh, v.nameEn),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: pillFg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    // หมุดสถานีวัดระดับน้ำ แสดงชื่อสถานีจริง (เช่น บ้านปายอยือนิ)
    final stationMarkers = <Marker>[];
    if (_drillTumbon == null) {
      for (final station in provider.stations) {
        final lat = station.lat;
        final lng = station.lng;
        if (lat == null || lng == null) continue;
        if (_drillAmphoe != null && station.amphoeTh != _drillAmphoe) continue;
        stationMarkers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 138,
            height: 60,
            alignment: Alignment.topCenter,
            child: StationMarker(
              station: station,
              strings: strings,
              selected: _selectedCode == station.code,
              onTap: () {
                setState(() => _selectedCode = station.code);
                _mapController.move(LatLng(lat, lng), 12.0);
                _showStationSheet(station, strings);
              },
            ),
          ),
        );
      }
    }

    // หมุดตำแหน่ง GPS หรือจุดปักหมุดของผู้ใช้
    final userMarkers = <Marker>[];
    final pin = provider.userPinAssessment;
    if (pin != null) {
      final pinLv = AlertLevel.fromValue(pin.level);
      userMarkers.add(
        Marker(
          point: pin.point,
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2563EB), width: 2),
            ),
            child: Center(
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: pin.isGps ? const Color(0xFF2563EB) : pinLv.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66000000), blurRadius: 6),
                  ],
                ),
                child: Icon(
                  pin.isGps ? Icons.my_location : Icons.push_pin,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(AppConfig.defaultLat, AppConfig.defaultLng),
        initialZoom: AppConfig.defaultZoom,
        minZoom: 8.5,
        maxZoom: 16,
        cameraConstraint: CameraConstraint.contain(bounds: _yalaBounds),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom |
              InteractiveFlag.drag |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.scrollWheelZoom,
        ),
        onTap: (_, pt) {
          if (_pinDropMode) {
            _dropPinAt(provider, pt);
          } else {
            setState(() => _selectedCode = null);
          }
        },
        onLongPress: (_, pt) => _dropPinAt(provider, pt),
      ),
      children: [
        TileLayer(
          urlTemplate: AppConfig.mapTileUrl(isDark: isDark),
          tileProvider: _tileProvider,
          userAgentPackageName: AppConfig.packageName,
          maxZoom: 18,
        ),
        if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
        if (areaMarkers.isNotEmpty) MarkerLayer(markers: areaMarkers),
        if (stationMarkers.isNotEmpty) MarkerLayer(markers: stationMarkers),
        if (userMarkers.isNotEmpty) MarkerLayer(markers: userMarkers),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              AppConfig.mapTileAttribution,
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showVillageSheet(
    VillagePoint v,
    ElevationFloodResult elev,
    AlertLevel lv,
    AppStrings strings,
  ) async {
    final elevSummary = elev.marginMeters != null
        ? strings.elevationMarginText(elev.marginMeters!)
        : strings.alertLevelLabel(elev.level);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.villageName(v.moo, v.nameTh, v.nameEn),
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: lv.color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      strings.alertLevelLabel(lv.value),
                      style: TextStyle(
                        color: lv.onSolidColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${strings.tumbonName(v.tumbonTh, context.read<AlertProvider>().tumbonEnOf(v.amphoeTh, v.tumbonTh))} · ${strings.amphoePrefixed(v.amphoeTh)} · ${strings.get('yala_province')}',
              ),
              const SizedBox(height: 8),
              Text(
                '${strings.get('ground_elevation')}: ${v.elevationMsl?.toStringAsFixed(0) ?? '-'} ${strings.get('unit_msl')} · $elevSummary',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (elev.refWaterMsl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${strings.get('ref_river_level')}: ${elev.refWaterMsl!.toStringAsFixed(2)} ${strings.get('unit_msl')}',
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                ),
              if (elev.advisoryNote != null && elev.advisoryNote!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Text(
                      elev.advisoryNote!,
                      style: const TextStyle(fontSize: 12.5, height: 1.4),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapActionFab extends StatelessWidget {
  const _MapActionFab({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    this.loading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = active
        ? const Color(0xFF0E5FA6)
        : (isDark ? const Color(0xEE0F172A) : const Color(0xF5FFFFFF));
    final fg = active
        ? Colors.white
        : (isDark ? Colors.white : const Color(0xFF0F172A));

    return Material(
      color: bg,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: active
              ? Colors.white
              : (isDark ? Colors.white24 : const Color(0x33000000)),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                    )
                  : Icon(icon, size: 21, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

class _ElevationLegendChip extends StatelessWidget {
  const _ElevationLegendChip({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xEB0F172A) : const Color(0xF0FFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white24 : const Color(0x28000000),
        ),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            strings.get('elev_legend_title'),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 158,
            height: 7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFB71C1C),
                  Color(0xFFEF6C00),
                  Color(0xFFF9A825),
                  Color(0xFF66BB6A),
                  Color(0xFF1B5E20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: 158,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    strings.get('elev_low_risk'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    strings.get('elev_high_safe'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserPinCard extends StatelessWidget {
  const _UserPinCard({
    required this.assessment,
    required this.provider,
    required this.onClear,
    required this.onFocus,
  });

  final UserPinAssessment assessment;
  final AlertProvider provider;
  final VoidCallback onClear;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = provider.strings;
    final lv = AlertLevel.fromValue(assessment.level);
    final nearestSt = provider.stationByCode(assessment.nearestStationCode);
    final areaParts = <String>[
      if (assessment.tumbonTh != null)
        strings.tumbonName(assessment.tumbonTh!, assessment.tumbonEn),
      if (assessment.amphoeTh != null) strings.amphoePrefixed(assessment.amphoeTh!),
    ];

    return Material(
      color: isDark ? const Color(0xF50F172A) : const Color(0xFAFFFFFF),
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onFocus,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: lv.colorFor(Theme.of(context).brightness),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    assessment.isGps ? Icons.my_location : Icons.push_pin,
                    size: 16,
                    color: lv.colorFor(Theme.of(context).brightness),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${assessment.isGps ? strings.get('gps_point_title') : strings.get('pinned_point_title')}'
                      '${areaParts.isNotEmpty ? ' · ${areaParts.join(' ')}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: lv.color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      strings.alertLevelLabel(lv.value),
                      style: TextStyle(
                        color: lv.onSolidColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: onClear,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${strings.get('ground_elevation')}: '
                '${assessment.elevationMsl != null ? '${assessment.elevationMsl!.toStringAsFixed(1)} ${strings.get('unit_msl')}' : '—'}'
                '${assessment.marginMeters != null ? ' · ${strings.elevationMarginText(assessment.marginMeters!)}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                ),
              ),
              if (nearestSt != null)
                Text(
                  '${strings.get('nearest_station')}: ${strings.stationShortName(nearestSt)}'
                  '${assessment.nearestStationDistKm != null ? ' (${assessment.nearestStationDistKm!.toStringAsFixed(1)} ${strings.get('unit_km')})' : ''}'
                  '${nearestSt.displayLevel != null ? ' · ${nearestSt.displayLevel!.toStringAsFixed(2)} ${strings.get('unit_msl')}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
              if (assessment.advisoryNote != null &&
                  assessment.advisoryNote!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    assessment.advisoryNote!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFFCD34D)
                          : const Color(0xFFB45309),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (provider.savedPlaces.length < SavedPlace.maxSavedPlaces &&
                      assessment.amphoeTh != null)
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.bookmark_add_outlined, size: 14),
                      label: Text(
                        strings.get('family_save_pin_btn'),
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                      ),
                      onPressed: () {
                        final label = assessment.tumbonTh != null
                            ? strings.tumbonName(
                                assessment.tumbonTh!,
                                assessment.tumbonEn,
                              )
                            : strings.amphoe(assessment.amphoeTh!);
                        provider.addSavedPlace(
                          label: label,
                          amphoeTh: assessment.amphoeTh!,
                          tumbonTh: assessment.tumbonTh,
                          lat: assessment.lat,
                          lng: assessment.lng,
                          isGps: assessment.isGps,
                        );
                      },
                    ),
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.share_outlined, size: 14),
                    label: Text(
                      strings.get('share_status_btn'),
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => showShareStatusSheet(
                      context,
                      provider: provider,
                      placeLabel: assessment.tumbonTh != null
                          ? strings.tumbonName(
                              assessment.tumbonTh!,
                              assessment.tumbonEn,
                            )
                          : strings.amphoe(assessment.amphoeTh ?? 'เมืองยะลา'),
                      amphoeTh: assessment.amphoeTh ?? 'เมืองยะลา',
                      level: assessment.level,
                      exposureZone: assessment.exposureZone,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// กรอบสถานะเขื่อนบางลาง ด้านบนต่อจากแถบหัวเรื่อง
class _BangLangDamCard extends StatelessWidget {
  const _BangLangDamCard({required this.dam, required this.strings});

  final BangLangDamStatus dam;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final spill = dam.spillwayActive;
    final bgStart = spill ? const Color(0xFF991B1B) : const Color(0xFF0B3B75);
    final bgEnd = spill ? const Color(0xFFDC2626) : const Color(0xFF145DA0);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [bgStart, bgEnd]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water, color: Colors.white, size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  strings.get('dam_title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: spill ? Colors.amber : Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  spill ? strings.get('dam_spillway_alert') : strings.get('dam_normal'),
                  style: TextStyle(
                    color: spill ? const Color(0xFF111827) : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _metric(
                strings.get('dam_storage_pct'),
                dam.storagePercent != null
                    ? '${dam.storagePercent!.toStringAsFixed(1)}%'
                    : '—',
              ),
              const SizedBox(width: 8),
              _metric(
                strings.get('dam_volume'),
                dam.storageMcm != null
                    ? '${dam.storageMcm!.toStringAsFixed(0)} ${strings.get('unit_mcm')}'
                    : '—',
              ),
              const SizedBox(width: 8),
              _metric(
                strings.get('dam_release_day'),
                dam.releasedDailyMcm != null
                    ? '${dam.releasedDailyMcm!.toStringAsFixed(2)} ${strings.get('unit_mcm')}'
                    : '—',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrillBreadcrumbBar extends StatelessWidget {
  const _DrillBreadcrumbBar({
    required this.drillAmphoe,
    required this.drillTumbon,
    required this.provider,
    required this.onBackProvince,
    required this.onBackAmphoe,
  });

  final String? drillAmphoe;
  final String? drillTumbon;
  final AlertProvider provider;
  final VoidCallback onBackProvince;
  final VoidCallback? onBackAmphoe;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final strings = provider.strings;

    String? tumbonEn;
    if (drillAmphoe != null && drillTumbon != null) {
      for (final s in provider.subdistrictsOf(drillAmphoe!)) {
        if (s.tumbonTh == drillTumbon) {
          tumbonEn = s.tumbonEn;
          break;
        }
      }
    }

    final path = drillAmphoe == null
        ? strings.get('map_province_hint')
        : drillTumbon == null
            ? '${strings.get('yala_province')} › ${strings.amphoePrefixed(drillAmphoe!)} (${provider.subdistrictsOf(drillAmphoe!).length} ${strings.get('subdistricts_unit')})'
            : '${strings.amphoePrefixed(drillAmphoe!)} › ${strings.tumbonName(drillTumbon!, tumbonEn)} (${provider.villagesOf(drillAmphoe!, drillTumbon!).length} ${strings.get('villages_unit')})';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      color: cs.surfaceContainerHighest,
      child: Row(
        children: [
          Icon(Icons.layers_outlined, size: 15, color: cs.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
          if (drillTumbon != null && onBackAmphoe != null)
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              onPressed: onBackAmphoe,
              child: Text(
                strings.get('map_back_tumbon'),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          if (drillAmphoe != null)
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              onPressed: onBackProvince,
              child: Text(
                strings.get('map_back_province'),
                style: const TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

class _DrillListStrip extends StatelessWidget {
  const _DrillListStrip({
    required this.provider,
    required this.drillAmphoe,
    required this.drillTumbon,
    required this.onSelectAmphoe,
    required this.onSelectTumbon,
    required this.onSelectVillage,
  });

  final AlertProvider provider;
  final String? drillAmphoe;
  final String? drillTumbon;
  final ValueChanged<String> onSelectAmphoe;
  final void Function(String amphoe, String tumbon) onSelectTumbon;
  final ValueChanged<VillagePoint> onSelectVillage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: _buildItems(provider.strings),
    );
  }

  Widget _buildItems(AppStrings strings) {
    if (drillAmphoe == null) {
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        itemCount: AppConfig.riskAmphoeTh.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final amp = AppConfig.riskAmphoeTh[i];
          final lv = provider.amphoeAlertLevel(amp);
          return ActionChip(
            avatar: CircleAvatar(backgroundColor: lv.color, radius: 6),
            label: Text(strings.amphoe(amp), style: const TextStyle(fontSize: 12)),
            onPressed: () => onSelectAmphoe(amp),
          );
        },
      );
    }

    if (drillTumbon == null) {
      final subs = provider.subdistrictsOf(drillAmphoe!);
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        itemCount: subs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final sub = subs[i];
          final elev = provider.elevationFloodLevel(
            sub.minElevationMsl ?? sub.elevationMsl,
            sub.amphoeTh,
          );
          final lv = AlertLevel.fromValue(elev.level);
          return ActionChip(
            avatar: CircleAvatar(backgroundColor: lv.color, radius: 6),
            label: Text(
              '${strings.tumbonName(sub.tumbonTh, sub.tumbonEn)} (${sub.minElevationMsl?.toStringAsFixed(0) ?? '-'} ${strings.get('unit_msl')})',
              style: const TextStyle(fontSize: 11.5),
            ),
            onPressed: () => onSelectTumbon(sub.amphoeTh, sub.tumbonTh),
          );
        },
      );
    }

    final villages = provider.villagesOf(drillAmphoe!, drillTumbon!);
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      itemCount: villages.length,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (_, i) {
        final v = villages[i];
        final elev = provider.elevationFloodLevel(
          v.elevationMsl,
          v.amphoeTh,
          exposureZone: v.exposureZone,
          relHeightM: v.relHeightM,
        );
        final lv = AlertLevel.fromValue(elev.level);
        return ActionChip(
          avatar: CircleAvatar(backgroundColor: lv.color, radius: 6),
          label: Text(
            '${strings.villageName(v.moo, v.nameTh, v.nameEn)} (${v.elevationMsl?.toStringAsFixed(0) ?? '-'} ${strings.get('unit_m')})',
            style: const TextStyle(fontSize: 11.5),
          ),
          onPressed: () => onSelectVillage(v),
        );
      },
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.strings, this.messageTh});

  final AppStrings strings;
  final String? messageTh;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF3E2723) : const Color(0xFFFFF3E0);
    final fg = isDark ? const Color(0xFFFFCC80) : const Color(0xFF6D4C00);
    final iconColor = isDark ? const Color(0xFFFFB74D) : const Color(0xFFEF6C00);
    final text = strings.lang == 'th'
        ? (messageTh ?? strings.get('offline_cached_notice'))
        : strings.get('offline_cached_notice');

    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: fg)),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(strings.get('loading_yala'), style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.strings,
    required this.message,
    required this.onRetry,
  });

  final AppStrings strings;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.water_damage_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              strings.get('load_failed'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(strings.get('retry')),
            ),
          ],
        ),
      ),
    );
  }
}
