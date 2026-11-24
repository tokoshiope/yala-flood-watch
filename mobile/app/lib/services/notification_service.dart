import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/models/alert.dart';
import 'package:yala_flood_app/models/risk_level.dart';

/// จัดการแจ้งเตือนในเครื่อง (flutter_local_notifications)
/// และ Push รายอำเภอผ่าน Firebase Cloud Messaging (APNs/FCM)
/// ใช้รหัสหัวข้อ ASCII ที่ถูกต้องตามข้อกำหนด FCM (`[a-zA-Z0-9-_.~%]`) ตรงกับ `backend/notify_fcm.py`
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

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  bool _pushConfigured = false;
  String? _activeTopic;
  bool _desiredPushEnabled = true;
  String? _desiredAmphoeTh;
  SharedPreferences? _prefs;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<String>? _onTokenRefreshSub;

  bool get isReady => _ready;
  bool get isPushConfigured => _pushConfigured;

  Future<void> initialize() async {
    if (_ready) return;
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

  /// เปิด Firebase/APNs ถ้ามีการตั้งค่า `GoogleService-Info.plist` (ไม่มีก็ข้าม ไม่ทำให้แอพค้าง)
  /// รองรับการรอ APNs Token บน iPhone จริงและซิงค์ใหม่อัตโนมัติเมื่อ Token รีเฟรช
  Future<void> initializePush({
    bool pushEnabled = true,
    String? selectedAmphoeTh,
    SharedPreferences? preferences,
  }) async {
    _prefs ??= preferences;
    _desiredPushEnabled = pushEnabled;
    _desiredAmphoeTh = selectedAmphoeTh;
    _activeTopic ??= _prefs?.getString(AppConfig.subscribedTopicPrefsKey);

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

      _onTokenRefreshSub ??= messaging.onRegistered.listen((_) {
        unawaited(
          syncTopicSubscription(
            pushEnabled: _desiredPushEnabled,
            selectedAmphoeTh: _desiredAmphoeTh,
            forceResync: true,
          ),
        );
      });

      await _waitForAppleApnsTokenIfNeeded(messaging);
      _pushConfigured = true;
      await syncTopicSubscription(
        pushEnabled: _desiredPushEnabled,
        selectedAmphoeTh: _desiredAmphoeTh,
      );
    } catch (error) {
      _pushConfigured = false;
      debugPrint('push not configured, skipping: $error');
    }
  }

  /// บน iOS/macOS จริง Apple จะส่ง APNs token กลับมาแบบ async หลังขอสิทธิ์
  /// รอแบบมีเพดานสูงสุด ~6 วินาที เพื่อลดโอกาสเกิด `apns-token-not-set`
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

  /// ซิงค์การติดตามหัวข้อ Push ตามอำเภอที่ผู้ใช้เลือกแบบ Lean (ลดการยิง API ซ้ำซ้อน)
  Future<void> syncTopicSubscription({
    required bool pushEnabled,
    String? selectedAmphoeTh,
    bool forceResync = false,
  }) async {
    _desiredPushEnabled = pushEnabled;
    _desiredAmphoeTh = selectedAmphoeTh;
    if (!_pushConfigured) return;

    try {
      final messaging = FirebaseMessaging.instance;
      final previous =
          _activeTopic ?? _prefs?.getString(AppConfig.subscribedTopicPrefsKey);

      if (!pushEnabled) {
        if (previous != null && previous.isNotEmpty) {
          await messaging.unsubscribeFromTopic(previous);
        }
        _activeTopic = null;
        await _prefs?.remove(AppConfig.subscribedTopicPrefsKey);
        return;
      }

      final desired = topicForAmphoe(selectedAmphoeTh);
      if (!forceResync && previous == desired) {
        _activeTopic = desired;
        return;
      }

      if (previous != null && previous.isNotEmpty && previous != desired) {
        await messaging.unsubscribeFromTopic(previous);
      }
      await messaging.subscribeToTopic(desired);
      _activeTopic = desired;
      await _prefs?.setString(AppConfig.subscribedTopicPrefsKey, desired);
    } catch (error) {
      debugPrint('syncTopicSubscription failed: $error');
    }
  }

  Future<void> showFloodAlert(AlertItem alert, {bool quiet = false}) async {
    if (!_ready) return;
    final playSound = !quiet;
    final highPriority = alert.level == RiskLevel.danger || playSound;
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
    try {
      await _plugin.show(
        id: alert.id.hashCode,
        title: alert.title,
        body: alert.message,
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
    debugPrint('notification tapped: ${response.payload}');
  }
}
