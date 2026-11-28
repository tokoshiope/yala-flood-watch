/// ศูนย์พักพิงชั่วคราว จ.ยะลา (ตรงกับ backend/registry/shelters.yaml v3)
class Shelter {
  const Shelter({
    required this.nameTh,
    required this.amphoeTh,
    required this.addressTh,
    required this.lat,
    required this.lng,
    this.id = '',
    this.capacity,
    this.phone,
    this.notesTh = '',
    this.isHistoricalUnconfirmed = false,
    this.status = 'standby',
    this.source = '',
  });

  final String id;
  final String nameTh;
  final String amphoeTh;
  final String addressTh;
  final double lat;
  final double lng;
  final int? capacity;
  final String? phone;
  final String notesTh;
  final bool isHistoricalUnconfirmed;
  final String status;
  final String source;

  String get capacityLabel => capacity == null ? 'ไม่ระบุ' : 'รองรับ ~$capacity คน';

  /// แปลงศูนย์พักพิงจาก CDN Snapshot (`latest.json` → `shelters[]`) สำหรับอัปเดต OTA ทันทีโดยไม่ต้องออกบิลด์ใหม่
  static Shelter? fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? json['nameTh'])?.toString().trim() ?? '';
    final amphoe = (json['amphoe'] ?? json['amphoeTh'])?.toString().trim() ?? '';
    final lat = (json['lat'] as num?)?.toDouble();
    final lng = ((json['lon'] ?? json['lng']) as num?)?.toDouble();
    if (name.isEmpty ||
        amphoe.isEmpty ||
        lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat < 5.5 ||
        lat > 7.2 ||
        lng < 100.5 ||
        lng > 101.9) {
      return null;
    }
    return Shelter(
      id: json['id']?.toString().trim() ?? '',
      nameTh: name,
      amphoeTh: amphoe,
      addressTh: (json['address'] ?? json['addressTh'])?.toString().trim() ?? '',
      lat: lat,
      lng: lng,
      capacity: (json['capacity'] as num?)?.toInt(),
      phone: json['phone']?.toString().trim(),
      notesTh: (json['notes'] ?? json['notesTh'])?.toString().trim() ?? '',
      isHistoricalUnconfirmed: json['is_historical_unconfirmed'] == true ||
          json['isHistoricalUnconfirmed'] == true,
      status: json['status']?.toString().trim() ?? 'standby',
      source: json['source']?.toString().trim() ?? '',
    );
  }
}
