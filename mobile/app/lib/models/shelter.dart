/// ศูนย์พักพิงชั่วคราว จ.ยะลา (ตรงกับ backend/registry/shelters.yaml v3)
class Shelter {
  const Shelter({
    required this.nameTh,
    required this.amphoeTh,
    required this.addressTh,
    required this.lat,
    required this.lng,
    this.capacity,
    this.phone,
    this.notesTh = '',
    this.isHistoricalUnconfirmed = false,
  });

  final String nameTh;
  final String amphoeTh;
  final String addressTh;
  final double lat;
  final double lng;
  final int? capacity;
  final String? phone;
  final String notesTh;
  final bool isHistoricalUnconfirmed;

  String get capacityLabel => capacity == null ? 'ไม่ระบุ' : 'รองรับ ~$capacity คน';
}
