import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/sos_request.dart';
import 'package:yala_flood_app/models/station.dart';
import 'package:yala_flood_app/screens/settings_screen.dart';
import 'package:yala_flood_app/screens/shelters_screen.dart';
import 'package:yala_flood_app/services/alert_engine.dart';
import 'package:yala_flood_app/services/local_store.dart';
import 'package:yala_flood_app/services/snapshot_service.dart';
import 'package:yala_flood_app/services/thai_water_service.dart';
import 'package:yala_flood_app/state/alert_provider.dart';
import 'package:yala_flood_app/widgets/station_marker.dart';

void main() {
  const engine = AlertEngine();

  group('Formula v3 Python <-> Dart 100% Parity Test Vectors (TV3-1..TV3-10)', () {
    test('TV3-1: normal', () {
      final r = engine.assessV3(
        levelMsl: 14.2,
        previousMsl: 14.2,
        bankM: 16.5,
        watchM: 15.5,
        criticalM: 16.5,
        situationLevel: 1,
        rain1hMm: 3.0,
        forecast24hMm: 11.0,
      );
      expect(r.score, 5.1);
      expect(r.level, AlertLevel.normal);
      expect(r.shouldPush, isFalse);
      expect(r.floodMechanism, 'monitoring');
      expect(r.confidence, 'high');
    });

    test('TV3-2: Nov 2025 X.40A overflow +1.24m with null situation_level -> Lv 5', () {
      final r = engine.assessV3(
        levelMsl: 17.74,
        previousMsl: 17.50,
        bankM: 16.5,
        watchM: 15.5,
        criticalM: 16.5,
        rain1hMm: 5.0,
        rain24hMm: 20.0,
        isUrbanBasin: true,
      );
      expect(r.score, 40.9);
      expect(r.level, AlertLevel.danger);
      expect(r.shouldPush, isTrue);
      expect(r.floodMechanism, 'riverine_overflow');
      expect(r.confidence, 'high');
    });

    test('TV3-3: Nov 2025 Mueang Yala 3-day 333.8mm urban flood with low dam -> Lv 3 urban_pluvial', () {
      final r = engine.assessV3(
        levelMsl: 14.5,
        previousMsl: 14.4,
        bankM: 16.5,
        watchM: 15.5,
        criticalM: 16.5,
        rain24hMm: 155.0,
        rain72hMm: 333.8,
        api7dMm: 140.0,
        forecast6hMm: 35.0,
        damSignal: 0.0,
        isUrbanBasin: true,
      );
      expect(r.score, 45.1);
      expect(r.level, AlertLevel.warning);
      expect(r.shouldPush, isTrue);
      expect(r.floodMechanism, 'urban_pluvial');
    });

    test('TV3-4: Nov 2024 X.40A 18.97m + Bang Lang inflow surge + GloFAS -> Lv 5', () {
      final r = engine.assessV3(
        levelMsl: 18.97,
        previousMsl: 18.50,
        bankM: 16.5,
        watchM: 15.5,
        criticalM: 16.5,
        situationLevel: 4,
        rain24hMm: 180.0,
        rain72hMm: 320.0,
        api7dMm: 200.0,
        forecast24hMm: 120.0,
        glofasPeakRatio: 3.5,
        damSignal: 0.75,
        leadTimeHours: '6–12 ชม.',
      );
      expect(r.score, 89.5);
      expect(r.level, AlertLevel.danger);
      expect(r.shouldPush, isTrue);
      expect(r.floodMechanism, 'dam_release');
    });

    test('TV3-5: X.77 RID8 39.70m critical override -> Lv 4', () {
      final r = engine.assessV3(
        levelMsl: 39.75,
        previousMsl: 39.65,
        bankM: 40.3,
        watchM: 38.0,
        criticalM: 39.7,
        isFlashFlood: true,
      );
      expect(r.score, 38.0);
      expect(r.level, AlertLevel.high);
      expect(r.shouldPush, isTrue);
    });

    test('TV3-6: Moderate rain only without soil/water confirmation -> Lv 1 no push', () {
      final r = engine.assessV3(
        levelMsl: 12.0,
        previousMsl: 12.0,
        bankM: 16.5,
        watchM: 15.5,
        criticalM: 16.5,
        rain1hMm: 40.0,
        forecast24hMm: 33.0,
        isUrbanBasin: true,
      );
      expect(r.score, 18.3);
      expect(r.level, AlertLevel.normal);
      expect(r.shouldPush, isFalse);
    });

    test('TV3-7: Kabang 0-gauge saturated soil + heavy rain -> Lv 4 flash_flood', () {
      final r = engine.assessV3(
        rain1hMm: 48.0,
        api7dMm: 140.0,
        forecast24hMm: 66.0,
        isFlashFlood: true,
        hasWaterGauge: false,
      );
      expect(r.score, 32.6);
      expect(r.level, AlertLevel.high);
      expect(r.shouldPush, isTrue);
      expect(r.floodMechanism, 'flash_flood');
      expect(r.confidence, 'medium');
    });

    test('TV3-8: Bang Lang spillway early warning -> Lv 3 dam_release', () {
      final r = engine.assessV3(
        levelMsl: 14.0,
        previousMsl: 14.0,
        bankM: 16.5,
        watchM: 15.5,
        criticalM: 16.5,
        situationLevel: 1,
        rain1hMm: 12.0,
        forecast24hMm: 22.0,
        damSignal: 1.0,
        damSpillwayActive: true,
        leadTimeHours: '6–12 ชม.',
      );
      expect(r.score, 16.8);
      expect(r.level, AlertLevel.warning);
      expect(r.shouldPush, isTrue);
      expect(r.floodMechanism, 'dam_release');
    });

    test('TV3-9: Watch + rapid rise override -> Lv 3', () {
      final r = engine.assessV3(
        levelMsl: 15.60,
        previousMsl: 15.40,
        bankM: 16.5,
        watchM: 15.5,
        criticalM: 16.5,
      );
      expect(r.score, 25.7);
      expect(r.level, AlertLevel.warning);
      expect(r.shouldPush, isTrue);
    });

    test('TV3-10: Raman sensor gap lowers confidence to medium while preserving Lv 5 bank overflow', () {
      final r = engine.assessV3(
        levelMsl: 17.67,
        previousMsl: 17.50,
        bankM: 16.5,
        watchM: 15.0,
        criticalM: 16.5,
        rain24hMm: 90.0,
        rainSensorGap: true,
        isUrbanBasin: true,
      );
      expect(r.score, 51.2);
      expect(r.level, AlertLevel.danger);
      expect(r.shouldPush, isTrue);
      expect(r.confidence, 'medium');
    });
  });

  group('Curved GIS, Real DEM Grid, Elevation Zones & Village Zones', () {
    test('Parses high-res curved boundaries, DEM grid, elevation zones & village zones', () {
      final dem = SnapshotService.parseDemGrid(
        File('assets/geo/yala_dem_grid.json').readAsStringSync(),
      );
      expect(dem, isNotNull);
      // Mueang Yala city floodplain (~15-30m MSL) vs Betong highland (>200m MSL)
      final yalaElev = dem!.elevationAt(6.5415, 101.2812);
      final betongElev = dem.elevationAt(5.7853, 101.0587);
      expect(yalaElev, isNotNull);
      expect(betongElev, isNotNull);
      expect(yalaElev!, lessThan(60.0));
      expect(betongElev!, greaterThan(150.0));

      final ez = SnapshotService.parseElevationZones(
        File('assets/geo/yala_elevation_zones.geojson').readAsStringSync(),
      );
      expect(ez.length, greaterThanOrEqualTo(100));
      expect(ez.map((e) => e.amphoeTh).toSet(), containsAll(AppConfig.riskAmphoeTh));

      final vz = SnapshotService.parseVillageZones(
        File('assets/geo/yala_village_zones.geojson').readAsStringSync(),
      );
      expect(vz.length, greaterThanOrEqualTo(400));
    });
  });

  group('Real Station Names, Complete 4-Language Coverage & Dark Mode UI', () {
    testWidgets('StationMarker shows real station name บ้านปายอยือนิ (not X.273) & adapts to Dark Mode', (tester) async {
      const x273 = Station(
        id: 273,
        code: 'X.273',
        nameTh: 'บ้านปายอยือนิ',
        lat: 6.47977,
        lng: 101.44474,
        waterLevelMsl: 12.37,
        leftBank: 16.5,
        amphoeTh: 'รามัน',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: Center(
              child: StationMarker(
                station: x273,
                strings: const AppStrings('th'),
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('บ้านปายอยือนิ'), findsOneWidget);
      expect(find.text('X.273'), findsNothing);

      // Verify English mode shows localized station name
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: Center(
              child: StationMarker(
                station: x273,
                strings: const AppStrings('en'),
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Ban Payo Yuni'), findsOneWidget);
    });

    test('All 4 languages (th/en/zh/ms) have zero Thai leakage in non-Thai modes', () {
      final thaiRegex = RegExp(r'[\u0E00-\u0E7F]');
      for (final lang in const ['en', 'zh', 'ms']) {
        final s = AppStrings(lang);
        for (var lv = 1; lv <= 5; lv++) {
          expect(thaiRegex.hasMatch(s.alertLevelLabel(lv)), isFalse, reason: '$lang lv$lv label');
          expect(thaiRegex.hasMatch(s.alertLevelDesc(lv)), isFalse, reason: '$lang lv$lv desc');
          expect(thaiRegex.hasMatch(s.alertLevelAction(lv)), isFalse, reason: '$lang lv$lv action');
        }
        for (final sh in kYalaShelters) {
          expect(thaiRegex.hasMatch(s.shelterName(sh.nameTh)), isFalse, reason: '$lang shelter ${sh.nameTh}');
        }
        for (final amp in AppConfig.riskAmphoeTh) {
          expect(thaiRegex.hasMatch(s.amphoe(amp)), isFalse, reason: '$lang amphoe $amp');
        }
      }
    });

    testWidgets('SettingsScreen displays 5-level alert guide in Dark Mode & switches to English/Chinese/Malay', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = AlertProvider(
        waterService: ThaiWaterService(preferences: prefs),
        localStorage: LocalStore(prefs),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            themeMode: ThemeMode.dark,
            darkTheme: ThemeData.dark(useMaterial3: true),
            home: const SettingsScreen(),
          ),
        ),
      );

      expect(find.text('คำอธิบายระดับการแจ้งเตือน (1–5)'), findsOneWidget);
      expect(find.text('ปกติ'), findsOneWidget);
      expect(find.text('อันตราย'), findsOneWidget);

      provider.updateSettings(provider.settings.copyWith(languageCode: 'en'));
      await tester.pump();
      expect(find.text('Alert Level Guide (Levels 1–5)'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Danger / Evacuate'), findsOneWidget);

      provider.updateSettings(provider.settings.copyWith(languageCode: 'ms'));
      await tester.pump();
      expect(find.text('Panduan Tahap Amaran (Tahap 1–5)'), findsOneWidget);
    });

    test('User pinned location persists locally and is completely erased by PDPA deleteAllUserData', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LocalStore(prefs);
      final provider = AlertProvider(
        waterService: ThaiWaterService(preferences: prefs),
        localStorage: store,
      );

      await provider.setPinnedLocation(6.5415, 101.2812, isGps: false);
      expect(provider.userPinAssessment, isNotNull);
      expect(store.loadPinnedLocation(), isNotNull);

      await provider.deleteAllUserData();
      expect(provider.userPinAssessment, isNull);
      expect(store.loadPinnedLocation(), isNull);
      expect(prefs.getString(AppConfig.pinnedLocationPrefsKey), isNull);
    });

    test('QA MEDIUM-2/3/5 regressions: X.77 RID8 evaluate override, NaN fail-closed, Dark Mode & watch contrast', () {
      // MEDIUM-2: X.77 at 39.75m (RID8 critical 39.70m < leftBank 40.30m) with null situation_level
      // MUST produce an on-device alert via assessV3 in evaluate()!
      const x77 = Station(
        id: 77,
        code: 'X.77',
        nameTh: 'บ้านหัวสะพาน',
        lat: 6.1525,
        lng: 101.0809,
        waterLevelMsl: 39.75,
        waterLevelMslPrev: 39.65,
        leftBank: 40.30,
        amphoeTh: 'ธารโต',
      );
      final alerts = engine.evaluate(stations: const [x77]);
      expect(alerts, isNotEmpty);
      expect(alerts.first.stationCode, 'X.77');
      expect(alerts.first.level, RiskLevel.danger);

      // MEDIUM-3: watch solid pill uses dark ink, and WaterTrend/SosStatus adapt for Dark Mode
      expect(AlertLevel.watch.onSolidColor, const Color(0xFF111827));
      expect(RiskLevel.watch.onColor, const Color(0xFF111827));
      expect(WaterTrend.steady.colorFor(Brightness.dark), isNot(WaterTrend.steady.color));
      expect(SosStatus.accepted.colorFor(Brightness.dark), isNot(SosStatus.accepted.color));

      // MEDIUM-5: Non-finite NaN/Infinity strings in ThaiWater JSON safely parse as null (no throw)
      final nanStation = Station.fromThaiWaterJson({
        'id': 999,
        'waterlevel_msl': 'NaN',
        'waterlevel_msl_previous': 'Infinity',
        'station': {
          'tele_station_oldcode': 'X.40A',
          'tele_station_name': {'th': 'บ้านท่าสาป'},
          'left_bank': double.nan,
        },
      });
      expect(nanStation.waterLevelMsl, isNull);
      expect(nanStation.waterLevelMslPrev, isNull);
      expect(nanStation.leftBank, isNull);
    });
  });
}
