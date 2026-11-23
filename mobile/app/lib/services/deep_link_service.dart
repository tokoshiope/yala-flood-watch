import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'package:yala_flood_app/config/app_config.dart';

/// แปลง deep link yalaflood://... เป็นชื่อหน้าจอ + อาร์กิวเมนต์
///
/// รูปแบบที่รองรับ:
///   yalaflood://station/PAT002   → หน้ารายละเอียดสถานี
///   yalaflood://alerts           → หน้าแจ้งเตือน
///   yalaflood://sos              → หน้า SOS
///   yalaflood://shelters         → หน้าจุดอพยพ
///   yalaflood://settings         → หน้าตั้งค่า
class DeepLinkTarget {
  const DeepLinkTarget(this.route, [this.argument]);

  final String route;
  final String? argument;
}

class DeepLinkService {
  DeepLinkService({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;
  StreamSubscription<Uri>? _subscription;

  /// เริ่มรับ deep link ตั้งแต่ต้น (ไม่บังคับให้แอพถูกเปิดจากลิงก์)
  void start(void Function(DeepLinkTarget target) onTarget) {
    _subscription?.cancel();
    _subscription = _appLinks.uriLinkStream.listen(
      (uri) {
        final target = parse(uri);
        if (target != null) onTarget(target);
      },
      onError: (Object error) {
        debugPrint('deep link stream error: $error');
      },
    );
    _readInitialLink(onTarget);
  }

  Future<void> _readInitialLink(
    void Function(DeepLinkTarget target) onTarget,
  ) async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        final target = parse(uri);
        if (target != null) onTarget(target);
      }
    } on Exception catch (error) {
      debugPrint('initial deep link unavailable: $error');
    }
  }

  /// แปลง URI เป็นเป้าหมาย คืน null ถ้าไม่ใช่ลิงก์ของเรา
  static DeepLinkTarget? parse(Uri uri) {
    if (uri.scheme != AppConfig.deepLinkScheme) return null;
    // yalaflood://station/PAT002 → host = station, pathSegments = [PAT002]
    final segments = uri.pathSegments;
    final host = uri.host.isNotEmpty ? uri.host : (segments.isNotEmpty ? segments.first : '');
    final argument = segments.isNotEmpty ? segments.last : null;

    switch (host) {
      case AppConfig.deepLinkHostStation:
        return DeepLinkTarget('/station', argument);
      case AppConfig.deepLinkHostAlerts:
        return const DeepLinkTarget('/alerts');
      case AppConfig.deepLinkHostSos:
        return const DeepLinkTarget('/sos');
      case AppConfig.deepLinkHostShelters:
        return const DeepLinkTarget('/shelters');
      case AppConfig.deepLinkHostSettings:
        return const DeepLinkTarget('/settings');
      default:
        return const DeepLinkTarget('/');
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
