import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 100% Offline Voice Briefing Service (ประกาศเสียงสั้นสำหรับผู้สูงอายุและสถานการณ์เร่งด่วน)
/// เรียกใช้ Native AVSpeechSynthesizer บน iOS/macOS ผ่าน MethodChannel โดยไม่เพิ่ม External Plugin
/// รองรับภาษาไทย (`th-TH`), มลายู (`ms-MY`), อังกฤษ (`en-US`) และจีน (`zh-CN`)
class VoiceBriefingService {
  VoiceBriefingService._() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDone') {
        isSpeaking.value = false;
      }
    });
  }
  static final VoiceBriefingService instance = VoiceBriefingService._();

  static const MethodChannel _channel = MethodChannel('net.yala.floodapp/speech');

  final ValueNotifier<bool> isSpeaking = ValueNotifier<bool>(false);

  static String bcp47ForLang(String langCode) {
    return switch (langCode) {
      'en' => 'en-US',
      'zh' => 'zh-CN',
      'ms' => 'ms-MY',
      _ => 'th-TH',
    };
  }

  /// อ่านประกาศเตือนภัยเสียงออกลำโพงเครื่องแบบออฟไลน์ 100%
  Future<bool> speak({
    required String text,
    required String langCode,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return false;
    isSpeaking.value = true;
    try {
      final result = await _channel.invokeMethod<bool>('speak', <String, dynamic>{
        'text': clean,
        'locale': bcp47ForLang(langCode),
      });
      if (result != true) {
        isSpeaking.value = false;
      }
      return result == true;
    } on MissingPluginException {
      isSpeaking.value = false;
      return false;
    } on PlatformException {
      isSpeaking.value = false;
      return false;
    } catch (_) {
      isSpeaking.value = false;
      return false;
    }
  }

  Future<void> stop() async {
    isSpeaking.value = false;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {
      // Safe no-op in headless/test environments
    }
  }
}
