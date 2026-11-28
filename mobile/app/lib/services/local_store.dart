import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/models/alert.dart';
import 'package:yala_flood_app/models/alert_settings.dart';
import 'package:yala_flood_app/models/saved_place.dart';

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

  // ── ความยินยอม PDPA สำหรับ GPS ─────────────────────────────────────────
  bool loadGpsConsent() => _prefs.getBool(AppConfig.gpsConsentPrefsKey) ?? false;

  Future<void> saveGpsConsent(bool granted) async {
    await _prefs.setBool(AppConfig.gpsConsentPrefsKey, granted);
  }

  // ── หมุดพิกัดของผู้ใช้บนแผนที่ (เก็บในเครื่องเท่านั้น) ──────────────────
  ({double lat, double lng, bool isGps})? loadPinnedLocation() {
    final raw = _prefs.getString(AppConfig.pinnedLocationPrefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final lat = (decoded['lat'] as num?)?.toDouble();
      final lng = (decoded['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return (lat: lat, lng: lng, isGps: decoded['isGps'] == true);
    } on FormatException {
      return null;
    }
  }

  Future<void> savePinnedLocation(double lat, double lng, {bool isGps = false}) async {
    await _prefs.setString(
      AppConfig.pinnedLocationPrefsKey,
      jsonEncode({'lat': lat, 'lng': lng, 'isGps': isGps}),
    );
  }

  Future<void> clearPinnedLocation() async {
    await _prefs.remove(AppConfig.pinnedLocationPrefsKey);
  }

  // ── รายการสถานที่ครอบครัว (Multi-Pin สูงสุด 5 จุด · Local-First) ─────────
  List<SavedPlace> loadSavedPlaces() {
    final raw = _prefs.getString(AppConfig.savedPlacesPrefsKey);
    if (raw == null || raw.isEmpty) return const <SavedPlace>[];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const <SavedPlace>[];
      final out = <SavedPlace>[];
      for (final item in list) {
        if (item is Map) {
          final parsed = SavedPlace.fromJson(item.cast<String, dynamic>());
          if (parsed != null) out.add(parsed);
        }
      }
      return out.take(SavedPlace.maxSavedPlaces).toList();
    } on FormatException {
      return const <SavedPlace>[];
    }
  }

  Future<void> saveSavedPlaces(List<SavedPlace> places) async {
    final trimmed = places.take(SavedPlace.maxSavedPlaces).toList();
    await _prefs.setString(
      AppConfig.savedPlacesPrefsKey,
      jsonEncode(trimmed.map((p) => p.toJson()).toList()),
    );
  }

  // ── สถานะ First-Time Onboarding ──────────────────────────────────────────
  bool loadOnboardingDone() => _prefs.getBool(AppConfig.onboardingDonePrefsKey) ?? false;

  Future<void> saveOnboardingDone(bool done) async {
    await _prefs.setBool(AppConfig.onboardingDonePrefsKey, done);
  }

  /// ลบข้อมูลส่วนบุคคลและประวัติทั้งหมดในเครื่อง (สิทธิเจ้าของข้อมูล PDPA — รวมถึงคีย์เดิมจากเวอร์ชันก่อน)
  Future<void> deleteAllUserData() async {
    await _prefs.remove(AppConfig.alertsPrefsKey);
    await _prefs.remove(AppConfig.settingsPrefsKey);
    await _prefs.remove(AppConfig.sosLogPrefsKey);
    await _prefs.remove(AppConfig.gpsConsentPrefsKey);
    await _prefs.remove(AppConfig.subscribedTopicPrefsKey);
    await _prefs.remove(AppConfig.subscribedTopicsPrefsKey);
    await _prefs.remove(AppConfig.pinnedLocationPrefsKey);
    await _prefs.remove(AppConfig.savedPlacesPrefsKey);
    await _prefs.remove(AppConfig.onboardingDonePrefsKey);
    await _prefs.remove(AppConfig.communityDeviceSaltKey);
    await _prefs.remove(AppConfig.communityLastReportAtKey);
  }
}
