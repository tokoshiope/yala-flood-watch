import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:yala_flood_app/models/alert.dart';
import 'package:yala_flood_app/models/risk_level.dart';

/// จัดการแจ้งเตือนในเครื่อง (flutter_local_notifications)
/// และ Push ผ่าน Firebase (ใช้ได้เมื่อตั้งค่า Firebase ให้ครบ)
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  bool get isReady => _ready;

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
      // เช่น ระบบไม่รองรับ — แอพยังใช้งานได้ แต่ไม่มีการแจ้งเตือน
      debugPrint('local notifications init failed: $error');
    }
  }

  /// เปิด Firebase ถ้ามีการตั้งค่า (ไม่มีก็ข้าม ไม่ทำให้แอพค้าง)
  Future<void> initializePush() async {
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM message: ${message.notification?.title}');
      });
      await messaging.subscribeToTopic('yala_flood');
    } catch (error) {
      // ยังไม่ได้ตั้งค่า Firebase (ไม่มี GoogleService-Info.plist / google-services.json)
      // แอพยังใช้งานได้ครบถ้วนโดยไม่มี Push
      debugPrint('push not configured, skipping: $error');
    }
  }

  Future<void> showFloodAlert(AlertItem alert, {bool quiet = false}) async {
    if (!_ready) return;
    final urgent = alert.level == RiskLevel.danger || !quiet;
    final android = AndroidNotificationDetails(
      'yala_flood_alerts',
      'แจ้งเตือนระดับน้ำ',
      channelDescription: 'แจ้งเตือนเมื่อระดับน้ำถึงเกณฑ์เตือนภัย/อันตราย',
      importance: urgent ? Importance.max : Importance.low,
      priority: urgent ? Priority.high : Priority.low,
    );
    const darwin = DarwinNotificationDetails();
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
