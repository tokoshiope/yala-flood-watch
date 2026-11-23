import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/models/rain_forecast.dart';

/// ดึงคะแนนฝนในอนาคต
///
/// ขณะนี้ [AppConfig.rainForecastEndpoint] ยังว่างอยู่ จึงคืน
/// [RainForecast.none] เสมอ เพื่อให้ตรรกะ [AlertEngine] ทำงานได้ครบถ้วน
/// โดยไม่บังคับต้องมี API ก่อน เมื่อมี endpoint แล้วให้ใส่ค่าแล้วเปิดใช้
class RainForecastService {
  RainForecastService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// คะแนนฝนของสถานี ณ เวลานี้
  Future<RainForecast> current(String stationCode) async {
    final endpoint = AppConfig.rainForecastEndpoint;
    if (endpoint.isEmpty) {
      return RainForecast.none(stationCode: stationCode);
    }

    try {
      final uri = Uri.parse(endpoint).replace(
        queryParameters: {'station': stationCode},
      );
      final response = await _client
          .get(uri, headers: const {'accept': 'application/json'})
          .timeout(AppConfig.networkTimeout);

      if (response.statusCode != 200) {
        return RainForecast.none(stationCode: stationCode);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return RainForecast.none(stationCode: stationCode);
      }
      return RainForecast(
        score: (decoded['score'] as num?)?.toInt() ?? 0,
        source: decoded['source'] as String? ?? 'ไม่ระบุ',
        summaryTh: decoded['summary'] as String? ?? '',
        validAt: DateTime.tryParse(decoded['valid_at'] as String? ?? ''),
        stationCode: stationCode,
      );
    } on Exception {
      return RainForecast.none(stationCode: stationCode);
    }
  }
}
