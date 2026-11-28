import 'package:latlong2/latlong.dart';

/// สถานที่เฝ้าระวังส่วนบุคคลและครอบครัว (Multi-Pin Family Watchlist · Local-First · Zero Server PII)
/// รองรับสูงสุด 5 จุด เช่น บ้านของฉัน, บ้านพ่อแม่, โรงเรียนลูก — เก็บเฉพาะในเครื่องและลบได้ครบในปุ่ม PDPA
class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.label,
    required this.amphoeTh,
    this.tumbonTh,
    required this.lat,
    required this.lng,
    this.isGps = false,
    this.isPrimary = false,
  });

  static const int maxSavedPlaces = 5;

  final String id;
  final String label;
  final String amphoeTh;
  final String? tumbonTh;
  final double lat;
  final double lng;
  final bool isGps;
  final bool isPrimary;

  LatLng get point => LatLng(lat, lng);

  SavedPlace copyWith({
    String? label,
    String? amphoeTh,
    String? tumbonTh,
    double? lat,
    double? lng,
    bool? isGps,
    bool? isPrimary,
  }) =>
      SavedPlace(
        id: id,
        label: label ?? this.label,
        amphoeTh: amphoeTh ?? this.amphoeTh,
        tumbonTh: tumbonTh ?? this.tumbonTh,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        isGps: isGps ?? this.isGps,
        isPrimary: isPrimary ?? this.isPrimary,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'amphoeTh': amphoeTh,
        'tumbonTh': tumbonTh,
        'lat': lat,
        'lng': lng,
        'isGps': isGps,
        'isPrimary': isPrimary,
      };

  static SavedPlace? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final label = json['label']?.toString().trim() ?? '';
    final amphoe = json['amphoeTh']?.toString().trim() ?? '';
    final lat = (json['lat'] as num?)?.toDouble();
    final lng = (json['lng'] as num?)?.toDouble();
    if (id.isEmpty ||
        label.isEmpty ||
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
    return SavedPlace(
      id: id,
      label: label,
      amphoeTh: amphoe,
      tumbonTh: json['tumbonTh']?.toString(),
      lat: lat,
      lng: lng,
      isGps: json['isGps'] == true,
      isPrimary: json['isPrimary'] == true,
    );
  }
}
