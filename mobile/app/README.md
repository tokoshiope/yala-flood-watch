# น้ำท่วมยะลา (Yala Flood App)

แอพ Flutter ฟรีเพื่อประชาชน แสดงระดับน้ำของจังหวัดยะลา (รหัส 95) จาก ThaiWater API
พร้อมแผนที่ OpenStreetMap, แจ้งเตือน, SOS และจุดอพยพ

## แหล่งข้อมูลจริง

- **ระดับน้ำ**: ThaiWater API v3
  `https://api-v3.thaiwater.net/api/v1/thaiwater30/public/waterlevel?province_code=95`
  (ค่าคงที่อยู่ใน `lib/config/app_config.dart`)
- **แผนที่**: OpenStreetMap tiles
- **พิกัด/ตลิ่ง/situation_level**: มาจาก API เท่านั้น ไม่ hardcode

## โครงสร้าง

```
lib/
  config/app_config.dart          ค่าคงที่ (จังหวัด 95, เกณฑ์, deep link, เบอร์ฉุกเฉิน)
  models/                         station, alert, alert_settings, risk_level,
                                  rain_forecast, shelter, sos_request
  services/
    thai_water_service.dart       เรียก API จริง + timeout/retry + fallback แคช
    alert_engine.dart             situation>=3 เตือนภัย, >=4 อันตราย, รองรับคะแนนฝน
    rain_forecast_service.dart    เตรียมไว้สำหรับค่าฝนในอนาคต (endpoint ยังไม่เปิดใช้)
    local_store.dart              บันทึกแจ้งเตือน/การตั้งค่า/คำขอ SOS ในเครื่อง
    notification_service.dart     แจ้งเตือนในเครื่อง + Firebase (ข้ามได้ถ้ายังไม่ตั้งค่า)
    deep_link_service.dart        yalaflood://station/PAT002, /alerts, /sos, ...
  state/alert_provider.dart       state กลาง (provider)
  screens/                        home(แผนที่), station_detail, alerts, sos,
                                  shelters, settings, app_shell
  widgets/                        station_marker, risk_badge
test/                             ทดสอบจริงด้วยข้อมูลจาก API (14 สถานี)
```

## วิธีรัน

```bash
flutter pub get
flutter analyze   # ผล: No issues found!
flutter test      # ผล: 30 tests passed
flutter run -d <device>
```

ตรวจสอบจริงบนเครื่องนี้: Flutter 3.50.1 / Dart 3.14.0 — `flutter analyze` ผ่านทุกไฟล์
`flutter test` ผ่าน 30 ข้อ และเคยรันดึงข้อมูล **API จริง** ได้ 14 สถานีพร้อมชื่อ/ระดับน้ำ/ตลิ่งถูกต้อง
(ดู `test/fixtures/yala_water_sample.json` — ข้อมูลจริงที่ดึงมาจาก API เมื่อเขียน)

## ข้อจำกัดที่ซื่อสัตย์

- จุดอพยพเป็น **ข้อมูลตัวอย่าง** 8 อำเภอ (`lib/screens/shelters_screen.dart`)
- ปุ่ม SOS บันทึกคำขอ + พิกัดไว้ในเครื่อง และแสดงสถานะจำลอง ยังไม่ส่งไปยัง
  ศูนย์ปภ.ยะลาโดยตรง — ต้องโทร 1677 ด้วยตนเอง
- ค่าฝนในอนาคตยังไม่มีแหล่งข้อมูล (`AppConfig.rainForecastEndpoint` ว่าง)
- ศูนย์ปภ.ยะลาใช้เบอร์ 1677 เป็นค่าเริ่มต้น กรุณาใส่เบอร์จริงใน `app_config.dart`
- ยังไม่มีโฟลเดอร์ platform (android/ios) ใน prototype นี้
