/// จุดอพยพพื้นฐาน (ข้อมูลตัวอย่าง 8 อำเภอ ยกเลิก/เพิ่มได้)
///
/// ค่าพิกัดเป็นพิกัดตัวอย่างใกล้ศูนย์กลางอำเภอ ใช้แสดงแผนที่และเปิด Google Maps ได้
/// เมื่อจังหวัดยะลามีฐานข้อมูลจุดอพยพจริง ให้ดึงจาก API แทนการ hardcode
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
  });

  final String nameTh;
  final String amphoeTh;
  final String addressTh;
  final double lat;
  final double lng;
  final int? capacity;
  final String? phone;
  final String notesTh;

  String get capacityLabel => capacity == null ? 'ไม่ระบุ' : 'รองรับ ~$capacity คน';
}
