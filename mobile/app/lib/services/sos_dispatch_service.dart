import 'dart:convert';
import 'dart:typed_data';

import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/flood_snapshot.dart';

/// บริการเตรียมและส่งข้อความขอความช่วยเหลือฉุกเฉิน (Smart SOS Dispatch — Zero-Server PII)
/// รองรับการส่งจริงผ่าน SMS (ทำงานได้แม้เน็ตล่ม), LINE Share, คัดลอกพร้อมพิกัด และโทรด่วน 1784 / 073-203559 / 1669
class SosDispatchService {
  SosDispatchService._();

  /// สร้างลิงก์ Google Maps นำทางตรงไปยังจุดเกิดเหตุ
  static String buildGoogleMapsPinUrl(double lat, double lng) =>
      'https://maps.google.com/?q=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';

  /// สร้างชุดข้อความ SOS ครบถ้วนพร้อมส่งจริงผ่าน SMS / LINE / คัดลอก
  static String buildSosMessage({
    required AppStrings strings,
    required String typeTh,
    required double lat,
    required double lng,
    required DateTime timestamp,
    double? accuracyMeters,
    String phone = '',
    String note = '',
    UserPinAssessment? pinAssessment,
  }) {
    final lines = <String>[
      strings.get('sos_msg_header'),
      '${strings.get('sos_msg_type')}: ${strings.sosTypeLabel(typeTh)}',
    ];

    if (pinAssessment != null &&
        (pinAssessment.amphoeTh != null || pinAssessment.tumbonTh != null)) {
      final areaParts = <String>[];
      if (pinAssessment.tumbonTh != null && pinAssessment.tumbonTh!.isNotEmpty) {
        areaParts.add(
          strings.tumbonName(
            pinAssessment.tumbonTh!,
            pinAssessment.tumbonEn,
          ),
        );
      }
      if (pinAssessment.amphoeTh != null && pinAssessment.amphoeTh!.isNotEmpty) {
        areaParts.add(strings.amphoe(pinAssessment.amphoeTh!));
      }
      if (areaParts.isNotEmpty) {
        lines.add('${strings.get('sos_msg_area')}: ${areaParts.join(', ')}');
      }
    }

    if (pinAssessment?.elevationMsl != null) {
      final elevText =
          '${pinAssessment!.elevationMsl!.toStringAsFixed(1)} ${strings.get('unit_msl')}';
      if (pinAssessment.marginMeters != null) {
        final m = pinAssessment.marginMeters!;
        final sign = m >= 0 ? '+' : '';
        lines.add(
          '${strings.get('sos_msg_elevation')}: $elevText ($sign${m.toStringAsFixed(1)} ${strings.get('unit_m')})',
        );
      } else {
        lines.add('${strings.get('sos_msg_elevation')}: $elevText');
      }
    }

    final accSuffix = (accuracyMeters != null && accuracyMeters.isFinite)
        ? ' (±${accuracyMeters.toStringAsFixed(0)} ${strings.get('unit_m')})'
        : '';
    lines.add(
      '${strings.get('sos_msg_gps')}: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}$accSuffix',
    );
    lines.add(
      '${strings.get('sos_msg_map')}: ${buildGoogleMapsPinUrl(lat, lng)}',
    );

    final cleanPhone = phone.trim();
    if (cleanPhone.isNotEmpty) {
      lines.add('${strings.get('sos_msg_phone')}: $cleanPhone');
    }
    final cleanNote = note.trim();
    if (cleanNote.isNotEmpty) {
      lines.add('${strings.get('sos_msg_note')}: $cleanNote');
    }
    lines.add(
      '${strings.get('sos_msg_time')}: ${strings.formatTime(timestamp)}',
    );
    return lines.join('\n');
  }

  /// สร้าง URI สำหรับเปิดแอป SMS บน iOS/Android โดยใช้ %20 แทน + (แก้บั๊ก iOS Messages แสดงเครื่องหมาย +)
  static Uri buildSmsUri(String message, {String recipient = ''}) {
    final sanitized = recipient.replaceAll(RegExp(r'[^0-9+*#]'), '');
    final encodedBody = Uri.encodeComponent(message);
    return Uri.parse('sms:$sanitized?body=$encodedBody');
  }

  /// สร้าง HTTPS URI สำหรับแชร์ข้อความ SOS ผ่านแอป LINE โดยตรง
  static Uri buildLineShareUri(String message) {
    final encoded = Uri.encodeComponent(message);
    return Uri.parse('https://line.me/R/share?text=$encoded');
  }

  /// SHA-256 บริสุทธิ์ (Pure Dart RFC 6234 — ไม่ต้องเพิ่มไลบรารีภายนอก)
  static String sha256Hex(String input) {
    final bytes = utf8.encode(input);
    final bitLen = bytes.length * 8;

    // Padding: 0x80, zeros until length ≡ 56 (mod 64), then 64-bit big-endian bit length
    final paddedLen = ((bytes.length + 9 + 63) ~/ 64) * 64;
    final msg = Uint8List(paddedLen);
    msg.setRange(0, bytes.length, bytes);
    msg[bytes.length] = 0x80;
    final bd = ByteData.view(msg.buffer);
    // Write 64-bit big-endian length (safe for inputs up to 512MB)
    bd.setUint32(paddedLen - 8, (bitLen ~/ 0x100000000) & 0xFFFFFFFF);
    bd.setUint32(paddedLen - 4, bitLen & 0xFFFFFFFF);

    const k = <int>[
      0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
      0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
      0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
      0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
      0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
      0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
      0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
      0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ];

    var h0 = 0x6a09e667;
    var h1 = 0xbb67ae85;
    var h2 = 0x3c6ef372;
    var h3 = 0xa54ff53a;
    var h4 = 0x510e527f;
    var h5 = 0x9b05688c;
    var h6 = 0x1f83d9ab;
    var h7 = 0x5be0cd19;

    final w = Uint32List(64);
    int rotr(int x, int n) => ((x >>> n) | (x << (32 - n))) & 0xFFFFFFFF;

    for (var chunk = 0; chunk < msg.length; chunk += 64) {
      for (var i = 0; i < 16; i++) {
        w[i] = bd.getUint32(chunk + i * 4);
      }
      for (var i = 16; i < 64; i++) {
        final s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >>> 3);
        final s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >>> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
      }

      var a = h0;
      var b = h1;
      var c = h2;
      var d = h3;
      var e = h4;
      var f = h5;
      var g = h6;
      var h = h7;

      for (var i = 0; i < 64; i++) {
        final s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
        final ch = (e & f) ^ ((~e & 0xFFFFFFFF) & g);
        final temp1 = (h + s1 + ch + k[i] + w[i]) & 0xFFFFFFFF;
        final s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xFFFFFFFF;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xFFFFFFFF;
      }

      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
      h5 = (h5 + f) & 0xFFFFFFFF;
      h6 = (h6 + g) & 0xFFFFFFFF;
      h7 = (h7 + h) & 0xFFFFFFFF;
    }

    String hex32(int v) => (v & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
    return '${hex32(h0)}${hex32(h1)}${hex32(h2)}${hex32(h3)}'
        '${hex32(h4)}${hex32(h5)}${hex32(h6)}${hex32(h7)}';
  }
}
