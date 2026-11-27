import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/station.dart';

void main() {
  group('Station.fromThaiWaterJson (ข้อมูลจริงจาก ThaiWater)', () {
    final fixture = jsonDecode(
      File('test/fixtures/yala_water_sample.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final records = (fixture['data'] as List)
        .whereType<Map<String, dynamic>>()
        .toList();

    test('มีสถานียะลา 14 แห่งตามข้อมูลจริง', () {
      expect(records.length, 14);
      final stations = records.map(Station.fromThaiWaterJson).toList();
      expect(stations.length, 14);
      expect(
        stations.map((s) => s.code).toSet(),
        containsAll(<String>['PAT002', 'PAT001', 'BLGTD03', 'BLGTU05']),
      );
    });

    test('แปลงสถานี PAT002 เมืองยะลา ถูกต้อง', () {
      final station = Station.fromThaiWaterJson(records.first);
      expect(station.code, 'PAT002');
      expect(station.nameTh, 'เมืองยะลา');
      expect(station.amphoeTh, 'เมืองยะลา');
      expect(station.tumbonTh, 'ตาเซะ');
      expect(station.lat, closeTo(6.67525, 0.00001));
      expect(station.lng, closeTo(101.286354, 0.00001));
      expect(station.waterLevelMsl, 13.00);
      expect(station.leftBank, 13.85);
      expect(station.situationLevel, 4);
      // formula_version = 5 (DEC-022): PAT002 watch=13.30, bank=13.85; 13.00 ในระดับควบคุมปกติ -> ปกติ (Lv 1)
      expect(station.riskLevel, RiskLevel.normal);
      expect(station.remainingToBank, closeTo(0.85, 0.001));
      expect(station.hasBank, isTrue);
      expect(station.trend, WaterTrend.steady);
      expect(station.agencyShortTh, 'สสน.');
    });

    test('สถานีที่ situation_level เป็น null ไม่ถูกตีความผิดเป็นอันตราย', () {
      // BLGTU05 เขื่อนบางลาง: situation_level = null และตลิ่ง = 0
      final record = records.firstWhere(
        (r) => r['station']['tele_station_oldcode'] == 'BLGTU05',
      );
      final station = Station.fromThaiWaterJson(record);
      expect(station.situationLevel, isNull);
      expect(station.leftBank, 0);
      expect(station.hasBank, isFalse);
      // ไม่มีตลิ่ง จึงไม่ควรถูกตัดสินจาก diff_wl_bank ที่ไม่มีความหมาย
      expect(station.riskLevel, RiskLevel.unknown);
    });

    test('สถานีที่มีตลิ่งแต่ไม่มี situation_level ประเมินจากระดับน้ำได้', () {
      final record = records.firstWhere(
        (r) => r['station']['tele_station_oldcode'] == 'X.77',
      );
      final station = Station.fromThaiWaterJson(record);
      expect(station.situationLevel, isNull);
      expect(station.hasBank, isTrue);
      // น้ำ 35.02 ตลิ่ง 40.30 → เหลือ 5.28 ม. → ปกติ
      expect(station.riskLevel, RiskLevel.normal);
      expect(station.remainingToBank, closeTo(5.28, 0.01));
    });

    test('round-trip ผ่าน toJson/fromJson ได้คงค่า', () {
      final station = Station.fromThaiWaterJson(records.first);
      final restored = Station.fromJson(station.toJson());
      expect(restored.code, station.code);
      expect(restored.nameTh, station.nameTh);
      expect(restored.waterLevelMsl, station.waterLevelMsl);
      expect(restored.situationLevel, station.situationLevel);
      expect(restored.riskLevel, station.riskLevel);
    });
  });

  group('RiskLevel', () {
    test('fromSituation ตามเกณฑ์จริง ThaiWater 1–5 (1-3=ปกติ, 4=มาก/เฝ้าระวัง, 5=ล้นตลิ่ง/อันตราย)', () {
      expect(RiskLevel.fromSituation(5), RiskLevel.danger);
      expect(RiskLevel.fromSituation(4), RiskLevel.watch);
      expect(RiskLevel.fromSituation(3), RiskLevel.normal);
      expect(RiskLevel.fromSituation(2), RiskLevel.normal);
      expect(RiskLevel.fromSituation(1), RiskLevel.normal);
      expect(RiskLevel.fromSituation(0), RiskLevel.normal);
      expect(RiskLevel.fromSituation(null), RiskLevel.unknown);
      expect(RiskLevel.fromSituation(99), RiskLevel.unknown);
    });

    test('escalate เพิ่มครบ 5 ระดับไม่เกินอันตราย', () {
      expect(RiskLevel.normal.escalate(), RiskLevel.watch);
      expect(RiskLevel.watch.escalate(), RiskLevel.warning);
      expect(RiskLevel.warning.escalate(), RiskLevel.high);
      expect(RiskLevel.high.escalate(), RiskLevel.danger);
      expect(RiskLevel.danger.escalate(), RiskLevel.danger);
    });
  });
}
