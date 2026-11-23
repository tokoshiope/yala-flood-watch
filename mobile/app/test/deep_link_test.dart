import 'package:flutter_test/flutter_test.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/main.dart';
import 'package:yala_flood_app/services/deep_link_service.dart';

void main() {
  test('deep link yalaflood://station/PAT002 → หน้ารายละเอียดสถานี', () {
    final target = DeepLinkService.parse(
      Uri.parse('yalaflood://station/PAT002'),
    );
    expect(target, isNotNull);
    expect(target!.route, '/station');
    expect(target.argument, 'PAT002');
  });

  test('deep link อื่น ๆ  map ถูกต้อง', () {
    expect(
      DeepLinkService.parse(Uri.parse('yalaflood://alerts'))!.route,
      '/alerts',
    );
    expect(
      DeepLinkService.parse(Uri.parse('yalaflood://sos'))!.route,
      '/sos',
    );
    expect(
      DeepLinkService.parse(Uri.parse('yalaflood://shelters'))!.route,
      '/shelters',
    );
    expect(
      DeepLinkService.parse(Uri.parse('yalaflood://settings'))!.route,
      '/settings',
    );
  });

  test('ลิงก์ของคนอื่นถูกปฏิเสธ', () {
    expect(DeepLinkService.parse(Uri.parse('https://example.com/x')), isNull);
    expect(DeepLinkService.parse(Uri.parse('other://station/PAT002')), isNull);
  });

  test('URL API เป็นของ จ.ยะลา (รหัส 95) เท่านั้น', () {
    expect(AppConfig.provinceCode, '95');
    expect(AppConfig.waterLevelUrl, contains('province_code=95'));
    expect(AppConfig.waterLevelUrl, startsWith('https://api-v3.thaiwater.net'));
  });

  test('main.dart compile ผ่าน (navigatorKey พร้อมใช้)', () {
    expect(navigatorKey, isNotNull);
  });
}
