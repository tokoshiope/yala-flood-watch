import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/models/alert.dart';
import 'package:yala_flood_app/models/alert_settings.dart';
import 'package:yala_flood_app/models/sos_request.dart';

/// อ่าน/เขียนข้อมูลที่เก็บในเครื่องแบบ Local-First พร้อมฟังก์ชันลบข้อมูล PDPA
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  // ── แจ้งเตือน ──────────────────────────────────────────────────────────
  List<AlertItem> loadAlerts() {
    final raw = _prefs.getString(AppConfig.alertsPrefsKey);
    if (raw == null || raw.isEmpty) return const <AlertItem>[];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const <AlertItem>[];
      return list
          .whereType<Map<String, dynamic>>()
          .map(AlertItem.fromJson)
          .toList();
    } on FormatException {
      return const <AlertItem>[];
    }
  }

  Future<void> saveAlerts(List<AlertItem> alerts) async {
    final payload = jsonEncode(alerts.map((a) => a.toJson()).toList());
    await _prefs.setString(AppConfig.alertsPrefsKey, payload);
  }

  // ── การตั้งค่า ─────────────────────────────────────────────────────────
  AlertSettings loadSettings() {
    final raw = _prefs.getString(AppConfig.settingsPrefsKey);
    if (raw == null || raw.isEmpty) return const AlertSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const AlertSettings();
      return AlertSettings.fromJson(decoded);
    } on FormatException {
      return const AlertSettings();
    }
  }

  Future<void> saveSettings(AlertSettings settings) async {
    await _prefs.setString(
      AppConfig.settingsPrefsKey,
      jsonEncode(settings.toJson()),
    );
  }

  // ── คำขอ SOS ───────────────────────────────────────────────────────────
  List<SosRequest> loadSosRequests() {
    final raw = _prefs.getString(AppConfig.sosLogPrefsKey);
    if (raw == null || raw.isEmpty) return const <SosRequest>[];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const <SosRequest>[];
      return list
          .whereType<Map<String, dynamic>>()
          .map(SosRequest.fromJson)
          .toList();
    } on FormatException {
      return const <SosRequest>[];
    }
  }

  Future<void> saveSosRequests(List<SosRequest> requests) async {
    final payload = jsonEncode(requests.map((r) => r.toJson()).toList());
    await _prefs.setString(AppConfig.sosLogPrefsKey, payload);
  }

  // ── ความยินยอม PDPA สำหรับ GPS ─────────────────────────────────────────
  bool loadGpsConsent() => _prefs.getBool(AppConfig.gpsConsentPrefsKey) ?? false;

  Future<void> saveGpsConsent(bool granted) async {
    await _prefs.setBool(AppConfig.gpsConsentPrefsKey, granted);
  }

  /// ลบข้อมูลส่วนบุคคลและประวัติทั้งหมดในเครื่อง (สิทธิเจ้าของข้อมูล PDPA)
  Future<void> deleteAllUserData() async {
    await _prefs.remove(AppConfig.alertsPrefsKey);
    await _prefs.remove(AppConfig.settingsPrefsKey);
    await _prefs.remove(AppConfig.sosLogPrefsKey);
    await _prefs.remove(AppConfig.gpsConsentPrefsKey);
  }
}
