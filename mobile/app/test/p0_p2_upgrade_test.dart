import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/flood_snapshot.dart';
import 'package:yala_flood_app/models/saved_place.dart';
import 'package:yala_flood_app/models/shelter.dart';
import 'package:yala_flood_app/screens/shelters_screen.dart';
import 'package:yala_flood_app/services/caching_tile_provider.dart';
import 'package:yala_flood_app/services/local_store.dart';
import 'package:yala_flood_app/services/notification_service.dart';
import 'package:yala_flood_app/services/snapshot_service.dart';
import 'package:yala_flood_app/services/thai_water_service.dart';
import 'package:yala_flood_app/services/voice_briefing_service.dart';
import 'package:yala_flood_app/state/alert_provider.dart';
import 'package:yala_flood_app/widgets/family_watch_strip.dart';
import 'package:yala_flood_app/widgets/onboarding_sheet.dart';
import 'package:yala_flood_app/widgets/share_status_sheet.dart';

Map<String, dynamic> _buildValidSnapshotJson({DateTime? generatedAt}) {
  final raw = File('assets/snapshots/latest.json').readAsStringSync();
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  if (generatedAt != null) {
    decoded['generated_at'] = generatedAt.toIso8601String();
  }
  return decoded;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P0.1 — CDN-First Architecture & Outage Resilience', () {
    test('loads stations + shelters from fresh CDN snapshot with ZERO direct ThaiWater API calls', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final snapJson = _buildValidSnapshotJson(generatedAt: DateTime.now());
      final hash = snapJson['content_hash'].toString();
      final manifestJson = {'content_hash': hash};

      var thaiWaterHits = 0;
      final waterClient = MockClient((req) async {
        thaiWaterHits++;
        return http.Response('{"result":"ERR"}', 500);
      });
      final cdnClient = MockClient((req) async {
        if (req.url.path.endsWith('/manifest.json')) {
          return http.Response(jsonEncode(manifestJson), 200);
        }
        return http.Response(
          jsonEncode(snapJson),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final provider = AlertProvider(
        waterService: ThaiWaterService(client: waterClient, preferences: prefs),
        localStorage: LocalStore(prefs),
        snapshotService: SnapshotService(
          client: cdnClient,
          preferences: prefs,
          cdnBaseUrlOverride: 'https://cdn.example.com/snapshots',
          useDiskCache: false,
        ),
      );

      await provider.refresh();

      expect(thaiWaterHits, 0, reason: 'CDN-First must not hammer ThaiWater when CDN snapshot is fresh');
      expect(provider.stations.length, 14);
      expect(provider.isOffline, isFalse);
      expect(provider.hasOtaShelters, isTrue);
      expect(provider.shelters.length, greaterThanOrEqualTo(12));
    });

    test('falls back to cached/bundled snapshot stations when BOTH CDN and ThaiWater fail', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final failClient = MockClient((_) async => http.Response('down', 503));
      final provider = AlertProvider(
        waterService: ThaiWaterService(client: failClient, preferences: prefs),
        localStorage: LocalStore(prefs),
        snapshotService: SnapshotService(
          client: failClient,
          preferences: prefs,
          cdnBaseUrlOverride: 'https://cdn.example.com/snapshots',
          useDiskCache: false,
        ),
      );

      await provider.refresh();

      expect(provider.stations, isNotEmpty, reason: 'Bundled snapshot stations must keep app alive offline');
      expect(provider.isOffline, isTrue);
      expect(provider.errorTh, isNull);
    });
  });

  group('P0.2 & P0.3 — Compliant Basemap, Multi-Topic FCM & Push Navigation', () {
    test('map tile URL uses compliant CARTO Light/Dark tiles (never mt1.google.com)', () {
      final light = AppConfig.mapTileUrl(isDark: false);
      final dark = AppConfig.mapTileUrl(isDark: true);
      expect(light, startsWith('https://'));
      expect(dark, startsWith('https://'));
      expect(light, contains('cartocdn.com'));
      expect(dark, contains('dark_all'));
      expect(light, isNot(contains('mt1.google.com')));
      expect(dark, isNot(contains('mt1.google.com')));
    });

    test('Multi-topic builder deduplicates primary + family amphoes and defaults to yala_flood_all', () {
      final empty = NotificationService.topicsForAmphoes();
      expect(empty, {NotificationService.topicAllYala});

      final family = NotificationService.topicsForAmphoes(
        primaryAmphoeTh: 'เมืองยะลา',
        extraAmphoes: const ['รามัน', 'เมืองยะลา', 'บันนังสตา'],
      );
      expect(family, {
        'yala_flood_mueang_yala',
        'yala_flood_raman',
        'yala_flood_bannang_sata',
      });
    });

    test('VoiceBriefingService maps all 4 locales cleanly to BCP-47', () {
      expect(VoiceBriefingService.bcp47ForLang('th'), 'th-TH');
      expect(VoiceBriefingService.bcp47ForLang('ms'), 'ms-MY');
      expect(VoiceBriefingService.bcp47ForLang('en'), 'en-US');
      expect(VoiceBriefingService.bcp47ForLang('zh'), 'zh-CN');
    });
  });

  group('P1 — Multi-Pin Family Watchlist, Onboarding, OTA Shelters & PDPA Wipe', () {
    test('SavedPlace CRUD enforces max 5, Yala bbox, and full PDPA wipe', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LocalStore(prefs);
      final provider = AlertProvider(
        waterService: ThaiWaterService(preferences: prefs),
        localStorage: store,
        snapshotService: SnapshotService(preferences: prefs, useDiskCache: false),
      );

      // Reject out-of-Yala coordinates (e.g., Bangkok)
      final rejected = await provider.addSavedPlace(
        label: 'Bangkok',
        amphoeTh: 'เมืองยะลา',
        lat: 13.75,
        lng: 100.5,
      );
      expect(rejected, isFalse);

      // Onboarding creates primary Home place
      await provider.completeOnboarding(
        languageCode: 'th',
        homeAmphoeTh: 'เมืองยะลา',
        homeLabel: 'บ้านของฉัน',
      );
      expect(provider.onboardingDone, isTrue);
      expect(provider.settings.selectedAmphoeTh, 'เมืองยะลา');
      expect(provider.savedPlaces.length, 1);

      // Add 4 more family places up to limit 5
      for (final amp in const ['รามัน', 'ยะหา', 'บันนังสตา', 'เบตง']) {
        final ok = await provider.addSavedPlace(label: 'ครอบครัว $amp', amphoeTh: amp);
        expect(ok, isTrue);
      }
      expect(provider.savedPlaces.length, SavedPlace.maxSavedPlaces);

      // 6th place rejected cleanly
      final sixth = await provider.addSavedPlace(label: 'เกินโควต้า', amphoeTh: 'กาบัง');
      expect(sixth, isFalse);

      // PDPA full wipe clears savedPlaces, onboardingDone, and subscribedTopics
      await provider.deleteAllUserData();
      expect(provider.savedPlaces, isEmpty);
      expect(provider.onboardingDone, isFalse);
      expect(prefs.getString(AppConfig.savedPlacesPrefsKey), isNull);
      expect(prefs.getBool(AppConfig.onboardingDonePrefsKey), isNull);
      expect(prefs.getStringList(AppConfig.subscribedTopicsPrefsKey), isNull);
    });

    test('Shelter.fromJson validates Yala bbox and parses valid OTA shelters', () {
      expect(
        Shelter.fromJson({'name': 'Bad', 'amphoe': 'เมืองยะลา', 'lat': 13.7, 'lon': 100.5}),
        isNull,
      );
      final ok = Shelter.fromJson({
        'id': 'sh_test',
        'name': 'ศูนย์พักพิงทดสอบ',
        'amphoe': 'เมืองยะลา',
        'address': 'ต.สะเตง',
        'lat': 6.54,
        'lon': 101.28,
        'phone': '073-212345',
        'is_historical_unconfirmed': false,
      });
      expect(ok, isNotNull);
      expect(ok!.nameTh, 'ศูนย์พักพิงทดสอบ');
    });

    test('All new P0-P2 l10n keys, Share text & Voice briefing (with leadTime) have zero raw keys and zero Thai leakage in en/zh/ms', () async {
      final thaiRegex = RegExp(r'[\u0E00-\u0E7F]');
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = AlertProvider(
        waterService: ThaiWaterService(preferences: prefs),
        localStorage: LocalStore(prefs),
        snapshotService: SnapshotService(preferences: prefs, useDiskCache: false),
      );
      await provider.refresh();

      const newKeys = [
        'onboarding_banner_title',
        'onboarding_banner_sub',
        'onboarding_start_btn',
        'onboarding_skip_btn',
        'onboarding_sheet_title',
        'onboarding_step_lang',
        'onboarding_step_amphoe',
        'onboarding_done_btn',
        'family_watch_title',
        'family_add_btn',
        'family_add_dialog_title',
        'family_label_hint',
        'family_save_btn',
        'family_limit_note',
        'family_save_pin_btn',
        'place_preset_home',
        'place_preset_parents',
        'place_preset_school',
        'share_status_btn',
        'share_sheet_title',
        'share_line_btn',
        'share_copy_btn',
        'share_copied_snack',
        'voice_listen_btn',
        'voice_stop_btn',
        'voice_unavailable_snack',
        'shelters_nearest_badge',
        'shelters_ota_badge',
        'push_clarity_note',
        'exposure_zone_label',
        'zone_short_prefix',
        'share_level_prefix',
        'share_lead_time_label',
        'share_emergency_line',
        'remove_place_title',
        'remove_place_confirm',
      ];
      for (final lang in const ['en', 'zh', 'ms']) {
        final s = AppStrings(lang);
        for (final key in newKeys) {
          final val = s.get(key);
          expect(val, isNot(equals(key)), reason: 'Missing $key for $lang');
          expect(thaiRegex.hasMatch(val), isFalse, reason: 'Thai leaked in $key ($lang): $val');
        }
        final voice = s.voiceBriefingText(
          placeLabel: 'Home',
          amphoeTh: 'เมืองยะลา',
          level: 3,
          damPercent: 62.0,
          leadTime: '6–12 ชม.',
        );
        expect(thaiRegex.hasMatch(voice), isFalse, reason: 'Thai leaked in voiceBriefing ($lang): $voice');

        final shareText = buildFloodShareText(
          strings: s,
          provider: provider,
          placeLabel: 'Home',
          amphoeTh: 'เมืองยะลา',
          level: 3,
          exposureZone: 'A',
        );
        expect(shareText, isNot(contains('banglang_dam')));
        expect(shareText, isNot(contains('exposure_zone_label')));
        expect(thaiRegex.hasMatch(shareText), isFalse, reason: 'Thai leaked in shareText ($lang): $shareText');
      }

      // Thai share text also must never leak raw l10n keys
      final thShare = buildFloodShareText(
        strings: const AppStrings('th'),
        provider: provider,
        placeLabel: 'บ้านของฉัน',
        amphoeTh: 'เมืองยะลา',
        level: 2,
        exposureZone: 'A',
      );
      expect(thShare, isNot(contains('banglang_dam')));
      expect(thShare, isNot(contains('exposure_zone_label')));
      expect(thShare, contains('โซน A'));
    });

    test('CachingTileProvider magic-byte validator rejects captive-portal HTML and accepts PNG/JPEG/WebP', () {
      final htmlBytes = Uint8List.fromList(utf8.encode('<html><body>Captive Portal Login Page</body></html>'));
      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, ...List.filled(20, 0)]);
      final jpgBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(20, 0)]);
      final webpBytes = Uint8List.fromList([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 0, 0, 0, 0]);
      expect(isValidTileImageBytes(htmlBytes), isFalse);
      expect(isValidTileImageBytes(pngBytes), isTrue);
      expect(isValidTileImageBytes(jpgBytes), isTrue);
      expect(isValidTileImageBytes(webpBytes), isTrue);
    });
  });

  group('Accessibility & Layout Regression (375pt · 1.35x · Light & Dark)', () {
    for (final brightness in Brightness.values) {
      testWidgets('FamilyWatchStrip, Onboarding, ShareSheet & SheltersScreen render with 0 overflow ($brightness)', (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final snapJson = _buildValidSnapshotJson(generatedAt: DateTime.now());
        final provider = AlertProvider(
          waterService: ThaiWaterService(preferences: prefs),
          localStorage: LocalStore(prefs),
          snapshotService: SnapshotService(preferences: prefs, useDiskCache: false),
        );
        // Seed snapshot + 2 family places
        final snap = FloodSnapshot.fromJson(snapJson);
        await provider.completeOnboarding(
          languageCode: 'th',
          homeAmphoeTh: 'เมืองยะลา',
          homeLabel: 'บ้านของฉัน',
        );
        await provider.addSavedPlace(label: 'บ้านพ่อแม่', amphoeTh: 'รามัน');

        final theme = ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(AppConfig.colorPrimary),
            brightness: brightness,
          ),
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<AlertProvider>.value(
            value: provider,
            child: MaterialApp(
              theme: theme,
              builder: (ctx, child) => MediaQuery(
                data: MediaQuery.of(ctx).copyWith(
                  textScaler: const TextScaler.linear(1.35),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: Column(
                  children: [
                    FamilyWatchStrip(
                      provider: provider,
                      onFocusPoint: (_, _) {},
                    ),
                    const Expanded(child: SheltersScreen()),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('บ้านของฉัน'), findsOneWidget);
        expect(find.textContaining('บ้านพ่อแม่'), findsOneWidget);
        expect(snap.shelters.length, greaterThanOrEqualTo(12));

        // Open Share Status Sheet at 375pt / 1.35x
        final ctx = tester.element(find.byType(FamilyWatchStrip));
        unawaited(
          showShareStatusSheet(
            ctx,
            provider: provider,
            placeLabel: 'บ้านของฉัน',
            amphoeTh: 'เมืองยะลา',
            level: 2,
            exposureZone: 'A',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('แชร์เข้า LINE'), findsOneWidget);
        Navigator.of(ctx).pop();
        await tester.pumpAndSettle();

        // Open Onboarding Sheet at 375pt / 1.35x
        unawaited(showOnboardingSheet(ctx, provider));
        await tester.pumpAndSettle();
        expect(find.text('เริ่มติดตามสถานการณ์'), findsOneWidget);
        Navigator.of(ctx).pop();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  });
}
