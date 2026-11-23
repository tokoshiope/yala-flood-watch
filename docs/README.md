# Yala Flood Watch — เอกสารโครงการ

แอพเฝ้าระวัง/แจ้งเตือนน้ำท่วม จังหวัดยะลา ฟรีเพื่อประชาชน

- **PRD ฉบับเต็ม (ภาษาไทย):** [`docs/PRD-yala-flood-app.md`](PRD-yala-flood-app.md)
- **Dashboard ต้นแบบ:** [`dashboard/index.html`](../dashboard/index.html)

## เปิดดู Dashboard

ไฟล์ dashboard อยู่ที่ `../dashboard/index.html` เปิดได้ 2 วิธี:

**วิธีที่ 1 — เปิดไฟล์โดยตรง (เร็วสุด)**

ดับเบิลคลิกไฟล์ `../dashboard/index.html` ใน Finder หรือรันคำสั่ง:

```bash
open /Users/tokyo/yala-flood-app/dashboard/index.html
```

**วิธีที่ 2 — เปิดผ่าน local server**

```bash
cd /Users/tokyo/yala-flood-app
python3 -m http.server 8000
# จากนั้นเปิด http://localhost:8000/dashboard/ ในเบราว์เซอร์
```

## หมายเหตุสำคัญ

- `index.html` เป็น dashboard ต้นแบบที่ **ฝังข้อมูล snapshot ไว้ในไฟล์**
  (ดึงจาก ThaiWater API เมื่อ 23 พ.ย. 2568 20:10 น.) — ยังไม่ได้ดึงข้อมูลสด
  และไม่มี backend จริง
- ข้อมูลจริง 14 สถานีวัดระดับน้ำจาก ThaiWater API (`province_code=95`)
- รายละเอียดทั้งหมด (เกณฑ์แจ้งเตือน, Alert Score, roadmap 12 สัปดาห์,
  acceptance criteria) อยู่ใน [`docs/PRD-yala-flood-app.md`](PRD-yala-flood-app.md)
