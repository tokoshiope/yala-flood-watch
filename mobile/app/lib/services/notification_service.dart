import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/models/alert.dart';

/// จัดการแจ้งเตือนในเครื่อง (flutter_local_notifications)
/// และ Push รายอำเภอหลายจุดพร้อมกัน (Multi-Topic Family Watchlist) ผ่าน Firebase Cloud Messaging (APNs/FCM)
/// รวมถึงเชื่อม Push Tap Navigation พาผู้ใช้ตรงไปยังหน้าสถานการณ์/สถานีทันทีเมื่อแตะแจ้งเตือน
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String topicAllYala = 'yala_flood_all';

  static const Map<String, String> amphoeTopicMap = {
    'เมืองยะลา': 'yala_flood_mueang_yala',
    'รามัน': 'yala_flood_raman',
    'ยะหา': 'yala_flood_yaha',
    'กรงปินัง': 'yala_flood_krong_pinang',
    'เบตง': 'yala_flood_betong',
    'บันนังสตา': 'yala_flood_bannang_sata',
    'ธารโต': 'yala_flood_than_to',
    'กาบัง': 'yala_flood_kabang',
  };

  /// แปลงชื่ออำเภอภาษาไทยเป็นชื่อ FCM Topic มาตรฐาน (ASCII)
  static String topicForAmphoe(String? amphoeTh) {
    if (amphoeTh == null || amphoeTh.isEmpty) return topicAllYala;
    return amphoeTopicMap[amphoeTh] ?? topicAllYala;
  }

  /// แปลงรายการอำเภอที่ติดตามทั้งหมด (อำเภอหลัก + จุดครอบครัว) เป็นชุด FCM Topic ที่ไม่ซ้ำกัน
  static Set<String> topicsForAmphoes({
    String? primaryAmphoeTh,
    Iterable<String> extraAmphoes = const <String>[],
  }) {
    final out = <String>{};
    if (primaryAmphoeTh != null && primaryAmphoeTh.isNotEmpty) {
      out.add(topicForAmphoe(primaryAmphoeTh));
    }
    for (final a in extraAmphoes) {
      if (a.isNotEmpty) out.add(topicForAmphoe(a));
    }
    if (out.isEmpty) {
      out.add(topicAllYala);
    }
    return out;
  }

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  bool _pushConfigured = false;
  Set<String> _activeTopics = <String>{};
  bool _desiredPushEnabled = true;
  Set<String> _desiredTopics = <String>{topicAllYala};
  SharedPreferences? _prefs;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedAppSub;
  StreamSubscription<String>? _onTokenRefreshSub;

  /// Callback พาผู้ใช้ไปยังหน้าเป้าหมายเมื่อแตะ Push/Local Notification (เช่น `/alerts` หรือ `/station`)
  void Function(String route, String? amphoeOrCode)? onNavigateRoute;
  ({String route, String? arg})? _pendingNavigation;

  bool get isReady => _ready;
  bool get isPushConfigured => _pushConfigured;
  Set<String> get activeTopics => Set<String>.unmodifiable(_activeTopics);

  /// ลงทะเบียนตัวนำทางจาก main.dart และระบาย pending navigation ทันทีหากแอปถูกเปิดจากการแตะ Push
  void registerNavigationHandler(
    void Function(String route, String? amphoeOrCode) handler,
  ) {
    onNavigateRoute = handler;
    final pending = _pendingNavigation;
    if (pending != null) {
      _pendingNavigation = null;
      handler(pending.route, pending.arg);
    }
  }

  void _dispatchNavigation(String route, String? arg) {
    final normalized = _sanitizeRoute(route);
    final handler = onNavigateRoute;
    if (handler != null) {
      handler(normalized, arg);
    } else {
      _pendingNavigation = (route: normalized, arg: arg);
    }
  }

  static String _sanitizeRoute(String raw) {
    return switch (raw.trim()) {
      '/alerts' => '/alerts',
      '/station' => '/station',
      '/shelters' => '/shelters',
      '/sos' => '/sos',
      '/settings' => '/settings',
      _ => '/alerts',
    };
  }

  Future<void> initialize() async {
    if (_ready || kIsWeb) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          ),
          macOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          ),
        ),
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      _ready = true;
    } on Exception catch (error) {
      debugPrint('local notifications init failed: $error');
    }
  }

  Set<String> _loadStoredTopics() {
    final multi = _prefs?.getStringList(AppConfig.subscribedTopicsPrefsKey);
    if (multi != null && multi.isNotEmpty) {
      return multi.where((t) => t.isNotEmpty).toSet();
    }
    final legacy = _prefs?.getString(AppConfig.subscribedTopicPrefsKey);
    if (legacy != null && legacy.isNotEmpty) {
      return <String>{legacy};
    }
    return <String>{};
  }

  Future<void> _persistTopics(Set<String> topics) async {
    if (topics.isEmpty) {
      await _prefs?.remove(AppConfig.subscribedTopicsPrefsKey);
      await _prefs?.remove(AppConfig.subscribedTopicPrefsKey);
      return;
    }
    final sorted = topics.toList()..sort();
    await _prefs?.setStringList(AppConfig.subscribedTopicsPrefsKey, sorted);
    await _prefs?.setString(AppConfig.subscribedTopicPrefsKey, sorted.first);
  }

  /// เปิด Firebase/APNs ถ้ามีการตั้งค่า `GoogleService-Info.plist` (ไม่มีก็ข้าม ไม่ทำให้แอพค้าง)
  /// รองรับการแตะ Push ทั้งตอนเปิดค้างและตอน Cold Start (`onMessageOpenedApp` / `getInitialMessage`)
  Future<void> initializePush({
    bool pushEnabled = true,
    String? selectedAmphoeTh,
    Iterable<String> extraAmphoes = const <String>[],
    SharedPreferences? preferences,
  }) async {
    if (kIsWeb) return;
    _prefs ??= preferences;
    _desiredPushEnabled = pushEnabled;
    _desiredTopics = topicsForAmphoes(
      primaryAmphoeTh: selectedAmphoeTh,
      extraAmphoes: extraAmphoes,
    );
    if (_activeTopics.isEmpty) {
      _activeTopics = _loadStoredTopics();
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _onMessageSub ??= FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM message received: ${message.messageId ?? "unknown"}');
      });

      _onOpenedAppSub ??= FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessageOpen);

      final initialMsg = await messaging.getInitialMessage();
      if (initialMsg != null) {
        _handleRemoteMessageOpen(initialMsg);
      }

      _onTokenRefreshSub ??= messaging.onRegistered.listen((_) {
        unawaited(
          syncTopics(
            pushEnabled: _desiredPushEnabled,
            topics: _desiredTopics,
            forceResync: true,
          ),
        );
      });

      await _waitForAppleApnsTokenIfNeeded(messaging);
      _pushConfigured = true;
      await syncTopics(
        pushEnabled: _desiredPushEnabled,
        topics: _desiredTopics,
      );
    } catch (error) {
      _pushConfigured = false;
      debugPrint('push not configured, skipping: $error');
    }
  }

  void _handleRemoteMessageOpen(RemoteMessage message) {
    final route = message.data['route']?.toString() ?? '/alerts';
    final arg = message.data['station']?.toString() ?? message.data['amphoe']?.toString();
    _dispatchNavigation(route, arg);
  }

  Future<void> _waitForAppleApnsTokenIfNeeded(
    FirebaseMessaging messaging,
  ) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }
    for (var attempt = 0; attempt < 12; attempt++) {
      try {
        final apnsToken = await messaging.getAPNSToken();
        if (apnsToken != null && apnsToken.isNotEmpty) return;
      } catch (_) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  /// Backward-compatible single-amphoe wrapper (ยังคงรองรับโค้ด/เทสต์เดิม)
  Future<void> syncTopicSubscription({
    required bool pushEnabled,
    String? selectedAmphoeTh,
    Iterable<String> extraAmphoes = const <String>[],
    bool forceResync = false,
  }) =>
      syncTopics(
        pushEnabled: pushEnabled,
        topics: topicsForAmphoes(
          primaryAmphoeTh: selectedAmphoeTh,
          extraAmphoes: extraAmphoes,
        ),
        forceResync: forceResync,
      );

  /// ซิงค์การติดตามชุดหัวข้อ Push ทั้งหมด (รองรับ Multi-Pin ครอบครัวสูงสุด 5 อำเภอแบบ Lean)
  Future<void> syncTopics({
    required bool pushEnabled,
    required Set<String> topics,
    bool forceResync = false,
  }) async {
    _desiredPushEnabled = pushEnabled;
    _desiredTopics = topics.isEmpty ? <String>{topicAllYala} : Set<String>.from(topics);
    if (!_pushConfigured) return;

    try {
      final messaging = FirebaseMessaging.instance;
      final previous = _activeTopics.isNotEmpty ? _activeTopics : _loadStoredTopics();

      if (!pushEnabled) {
        for (final t in previous) {
          await messaging.unsubscribeFromTopic(t);
        }
        _activeTopics = <String>{};
        await _persistTopics(_activeTopics);
        return;
      }

      if (!forceResync &&
          previous.length == _desiredTopics.length &&
          previous.containsAll(_desiredTopics)) {
        _activeTopics = Set<String>.from(_desiredTopics);
        return;
      }

      for (final oldTopic in previous.difference(_desiredTopics)) {
        await messaging.unsubscribeFromTopic(oldTopic);
      }
      final toSubscribe = forceResync
          ? _desiredTopics
          : _desiredTopics.difference(previous);
      for (final newTopic in toSubscribe) {
        await messaging.subscribeToTopic(newTopic);
      }
      _activeTopics = Set<String>.from(_desiredTopics);
      await _persistTopics(_activeTopics);
    } catch (error) {
      debugPrint('syncTopics failed: $error');
    }
  }

  Future<void> showFloodAlert(AlertItem alert, {bool quiet = false}) async {
    if (!_ready) return;
    final playSound = !quiet;
    final highPriority = alert.level.isHighOrDanger || playSound;
    final android = AndroidNotificationDetails(
      'yala_flood_alerts',
      'แจ้งเตือนระดับน้ำ',
      channelDescription: 'แจ้งเตือนเมื่อระดับน้ำถึงเกณฑ์เตือนภัย/อันตราย',
      importance: highPriority ? Importance.max : Importance.low,
      priority: highPriority ? Priority.high : Priority.low,
      playSound: playSound,
    );
    final darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
    );
    final payload = jsonEncode(<String, dynamic>{
      'route': alert.stationCode.isNotEmpty ? '/station' : '/alerts',
      'arg': alert.stationCode.isNotEmpty ? alert.stationCode : alert.amphoeTh,
    });
    try {
      await _plugin.show(
        id: alert.id.hashCode,
        title: alert.title,
        body: alert.message,
        payload: payload,
        notificationDetails: NotificationDetails(
          android: android,
          iOS: darwin,
          macOS: darwin,
        ),
      );
    } on Exception catch (error) {
      debugPrint('showFloodAlert failed: $error');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) {
      _dispatchNavigation('/alerts', null);
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _dispatchNavigation(
          decoded['route']?.toString() ?? '/alerts',
          decoded['arg']?.toString(),
        );
        return;
      }
    } catch (_) {
      // Fallback to /alerts
    }
    _dispatchNavigation('/alerts', null);
  }
}
