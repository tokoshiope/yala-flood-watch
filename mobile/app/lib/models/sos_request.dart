import 'package:material_ui/material_ui.dart';

/// คำขอความช่วยเหลือฉุกเฉิน (SOS) ที่ผู้ใช้ส่งจากแอพ
class SosRequest {
  const SosRequest({
    required this.id,
    required this.typeTh,
    required this.createdAt,
    required this.lat,
    required this.lng,
    required this.phone,
    this.note = '',
    this.status = SosStatus.pending,
    this.statusHistory = const <SosStatus>[],
  });

  final String id;
  final String typeTh;
  final DateTime createdAt;
  final double lat;
  final double lng;
  final String phone;
  final String note;

  /// สถานะล่าสุด
  final SosStatus status;

  /// ประวัติสถานะตามลำดับเวลา
  final List<SosStatus> statusHistory;

  SosRequest copyWith({
    SosStatus? status,
    List<SosStatus>? statusHistory,
  }) =>
      SosRequest(
        id: id,
        typeTh: typeTh,
        createdAt: createdAt,
        lat: lat,
        lng: lng,
        phone: phone,
        note: note,
        status: status ?? this.status,
        statusHistory: statusHistory ?? this.statusHistory,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'typeTh': typeTh,
        'createdAt': createdAt.toIso8601String(),
        'lat': lat,
        'lng': lng,
        'phone': phone,
        'note': note,
        'status': status.name,
        'statusHistory': statusHistory.map((s) => s.name).toList(),
      };

  factory SosRequest.fromJson(Map<String, dynamic> json) => SosRequest(
        id: json['id'] as String? ?? '',
        typeTh: json['typeTh'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime.now(),
        lat: (json['lat'] as num?)?.toDouble() ?? 0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0,
        phone: json['phone'] as String? ?? '',
        note: json['note'] as String? ?? '',
        status: SosStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => SosStatus.pending,
        ),
        statusHistory: (json['statusHistory'] as List? ?? [])
            .whereType<String>()
            .map(
              (name) => SosStatus.values.firstWhere(
                (s) => s.name == name,
                orElse: () => SosStatus.pending,
              ),
            )
            .toList(),
      );
}

enum SosStatus {
  pending('รอตอบรับ', Icons.hourglass_top, Color(0xFFF9A825)),
  accepted('รับเรื่องแล้ว', Icons.assignment_turned_in, Color(0xFF0E5FA6)),
  inProgress('กำลังส่งช่วยเหลือ', Icons.local_shipping, Color(0xFFEF6C00)),
  resolved('ช่วยเหลือแล้ว', Icons.check_circle, Color(0xFF2E7D32));

  const SosStatus(this.labelTh, this.icon, this.color);

  final String labelTh;
  final IconData icon;
  final Color color;

  SosStatus? get next => switch (this) {
        SosStatus.pending => SosStatus.accepted,
        SosStatus.accepted => SosStatus.inProgress,
        SosStatus.inProgress => SosStatus.resolved,
        SosStatus.resolved => null,
      };
}

/// ประเภทคำขอที่เลือกได้ในแอพ
const List<String> kSosTypes = [
  'น้ำท่วมท่วมบ้าน/ชุมชน',
  'ต้องการพาตัวอพยพ',
  'ต้องการอาหาร/น้ำดื่ม',
  'ป่วย/ต้องการยา',
  'อุบัติเหตุบนน้ำ',
  'อื่น ๆ',
];

/// ช่วงเวลาที่แปลงเป็นข้อความไทย
String thaiRelativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'เมื่อสักครู่';
  if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
  if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
  if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';
  return '${time.day}/${time.month}/${time.year + 543}';
}

/// เลขที่เป็นภาษาไทย (ใช้ใน UI ที่ไม่พิมพ์เป็นเลขอารบิก)
String thaiDigits(String input) {
  const arabic = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const thai = ['๐', '๑', '๒', '๓', '๔', '๕', '๖', '๗', '๘', '๙'];
  var output = input;
  for (var i = 0; i < arabic.length; i++) {
    output = output.replaceAll(arabic[i], thai[i]);
  }
  return output;
}
