# KLINIKCARE
# Product Requirements Document (PRD)

**Nama Produk:** KlinikCare  
**Jenis Produk:** Aplikasi layanan klinik kesehatan  
**Platform:** Android (Pasien), Flutter Web (Dokter, Admin, dan Farmasi)  
**Frontend:** Flutter + Dart  
**Backend:** Firebase  
**Database:** Cloud Firestore  
**Status Dokumen:** PRD Final — Baseline Pengembangan  
**Versi:** 1.0  
**Tanggal:** 8 November 2026

---

# 1. Executive Summary

## 1.1 Ringkasan Produk

KlinikCare merupakan aplikasi layanan klinik kesehatan digital yang dirancang untuk menghubungkan pasien dengan operasional klinik dalam satu sistem terintegrasi.

Aplikasi ini membantu pasien memperoleh informasi layanan klinik, melihat jadwal dokter, melakukan pendaftaran pemeriksaan, memantau antrean secara digital, membaca panduan penanganan awal, menerima pengingat obat, dan mengakses ringkasan rekam medis.

Di sisi operasional, dokter dapat mengelola pemeriksaan dan resep digital, admin mengelola data klinik serta jadwal pelayanan, dan petugas farmasi memproses resep pasien.

KlinikCare dikembangkan menggunakan Flutter dan Dart dengan Firebase sebagai layanan backend.

## 1.2 Visi Produk

Menjadi platform layanan klinik digital yang mempermudah akses pelayanan kesehatan, meningkatkan transparansi antrean, dan membantu klinik menjalankan operasional secara lebih terintegrasi.

## 1.3 Permasalahan Utama

1. Pasien tidak mengetahui posisi antrean dan estimasi waktu pelayanan.
2. Pasien kesulitan memperoleh informasi penanganan awal ketika mengalami gejala kesehatan.
3. Pasien sering lupa jadwal konsumsi obat.
4. Informasi jadwal dokter dan perubahan jadwal belum tersampaikan secara optimal.
5. Riwayat pemeriksaan dan resep masih berisiko tercecer atau sulit ditemukan.
6. Proses pelayanan antar-poli dan farmasi belum terintegrasi.
7. Klinik membutuhkan pengelolaan kuota pasien yang lebih terkontrol.

## 1.4 Solusi Produk

KlinikCare menyediakan delapan modul utama:

1. Antrean Digital dan Real-Time.
2. Informasi Jadwal Dokter.
3. Panduan Penanganan Awal.
4. Pengingat Obat Smart.
5. Rekam Medis Elektronik.
6. E-Resep dan Integrasi Farmasi.
7. Pindah Poli dan Rujukan Internal.
8. Manajemen Kuota Dokter.

## 1.5 Sasaran Pengguna

- Pasien.
- Dokter.
- Admin klinik.
- Apoteker atau petugas farmasi.

---

# 2. Background & Context

## 2.1 Latar Belakang

Pelayanan klinik membutuhkan koordinasi antara pasien, dokter, admin, dan farmasi. Proses yang masih dilakukan secara manual dapat menyebabkan antrean tidak teratur, informasi jadwal kurang transparan, pencatatan medis sulit ditelusuri, dan pemrosesan resep membutuhkan waktu lebih lama.

Digitalisasi melalui KlinikCare diharapkan dapat membantu mengurangi kendala tersebut dengan menyediakan sistem yang saling terhubung.

## 2.2 Permasalahan dan Dampak

| Permasalahan | Dampak | Solusi KlinikCare |
|---|---|---|
| Antrean tidak transparan | Pasien menunggu tanpa informasi | Antrean digital real-time |
| Informasi gejala terbatas | Pasien bingung menentukan langkah awal | Panduan penanganan awal |
| Lupa minum obat | Jadwal pengobatan tidak terikuti | Pengingat obat |
| Jadwal dokter berubah | Pasien berpotensi datang pada waktu yang tidak tepat | Informasi jadwal dokter |
| Riwayat medis sulit ditemukan | Proses pemeriksaan menjadi kurang efisien | Rekam medis elektronik |
| Resep masih diproses manual | Potensi keterlambatan dan kesalahan pencatatan | E-Resep dan farmasi |
| Rujukan antar-poli kurang terkoordinasi | Pasien harus mengulang proses administrasi | Rujukan internal |
| Kuota tidak terkontrol | Risiko kelebihan pendaftaran | Manajemen kuota dokter |

## 2.3 Asumsi Produk

1. Klinik memiliki data dokter dan poli yang dapat dikelola oleh admin.
2. Setiap pasien memiliki akun untuk mengakses layanan.
3. Dokter, admin, dan farmasi memiliki akun dengan hak akses berbeda.
4. Klinik memiliki koneksi internet untuk sinkronisasi data.
5. Informasi medis yang ditampilkan telah melalui proses validasi tenaga kesehatan.
6. Pengembangan awal difokuskan pada satu klinik sebagai lokasi implementasi.

## 2.4 Batasan Produk

- Aplikasi tidak menggantikan konsultasi dan diagnosis langsung dari dokter.
- Panduan penanganan awal bersifat edukatif.
- Sistem tidak ditujukan untuk layanan gawat darurat.
- Pasien hanya dapat mengakses rekam medis miliknya sendiri.
- Fitur yang berkaitan dengan data medis harus memiliki pembatasan akses.

---

# 3. Goals & Success Criteria

## 3.1 Tujuan Produk

1. Memudahkan pasien melakukan pendaftaran pemeriksaan.
2. Memberikan informasi antrean yang dapat dipantau.
3. Menyediakan informasi jadwal dokter.
4. Membantu pasien mengingat jadwal konsumsi obat.
5. Menyimpan riwayat pemeriksaan secara digital.
6. Mengintegrasikan proses pemeriksaan, resep, dan farmasi.
7. Membantu admin mengelola kuota pelayanan.

## 3.2 Indikator Keberhasilan

Target berikut merupakan target awal yang perlu diuji dan disesuaikan saat uji coba klinik.

| Indikator | Target Awal |
|---|---:|
| Keberhasilan pembuatan booking tanpa duplikasi | ≥ 95% |
| Pembaruan antrean pada kondisi jaringan normal | ≤ 5 detik |
| Booking melebihi kuota dalam pengujian transaksi bersamaan | 0 kasus |
| Notifikasi berhasil diproses oleh sistem | ≥ 95% |
| Kunjungan selesai dengan data wajib terisi | 100% |
| Pengujian akses tanpa izin | 100% ditolak |
| Crash-free sessions saat uji coba | ≥ 99% |

## 3.3 KPI Produk

- Jumlah pasien terdaftar.
- Jumlah booking per hari.
- Jumlah kunjungan yang selesai.
- Rata-rata waktu tunggu.
- Jumlah pembatalan booking.
- Jumlah resep yang diproses.
- Persentase notifikasi yang berhasil diproses.
- Jumlah pengguna aktif.

---

# 4. User Personas & Use Cases

## 4.1 Persona Pasien

**Karakteristik:** Pengguna yang membutuhkan pelayanan klinik dan ingin memperoleh informasi tanpa harus datang langsung untuk sekadar menanyakan jadwal atau antrean.

**Kebutuhan:**
- Membuat akun.
- Melihat informasi poli.
- Melihat jadwal dokter.
- Melakukan booking.
- Memantau antrean.
- Membaca panduan kesehatan.
- Mengakses rekam medis dan resep.
- Mendapatkan pengingat obat.

**User Story:**

Sebagai pasien, saya ingin melakukan pendaftaran secara digital agar proses kunjungan ke klinik lebih mudah.

Sebagai pasien, saya ingin melihat antrean secara real-time agar dapat memperkirakan waktu kedatangan.

Sebagai pasien, saya ingin melihat jadwal dokter agar dapat memilih waktu pemeriksaan yang sesuai.

Sebagai pasien, saya ingin membaca panduan penanganan awal agar mendapatkan informasi edukatif ketika mengalami gejala.

Sebagai pasien, saya ingin mendapatkan pengingat obat agar tidak lupa mengikuti aturan penggunaan obat.

Sebagai pasien, saya ingin melihat riwayat pemeriksaan agar dapat mengetahui catatan kesehatan sebelumnya.

## 4.2 Persona Dokter

**Karakteristik:** Tenaga medis yang menggunakan sistem untuk mengelola antrean dan mencatat hasil pemeriksaan.

**Kebutuhan:**
- Melihat jadwal praktik.
- Melihat daftar antrean.
- Mengakses informasi pasien sesuai kewenangan.
- Mencatat pemeriksaan.
- Mengisi diagnosis.
- Membuat resep digital.
- Membuat rujukan internal.

**User Story:**

Sebagai dokter, saya ingin melihat daftar antrean pasien agar dapat mengatur proses pemeriksaan.

Sebagai dokter, saya ingin mengakses riwayat medis yang relevan agar dapat mempertimbangkan informasi pemeriksaan sebelumnya.

Sebagai dokter, saya ingin mencatat hasil pemeriksaan secara digital agar dokumentasi pasien tersimpan dengan baik.

Sebagai dokter, saya ingin membuat resep digital agar resep dapat diteruskan ke farmasi.

Sebagai dokter, saya ingin membuat rujukan internal agar pasien dapat melanjutkan pelayanan ke poli lain.

## 4.3 Persona Admin Klinik

**Karakteristik:** Petugas yang bertanggung jawab terhadap pengelolaan data dan operasional klinik.

**Kebutuhan:**
- Mengelola data pasien.
- Mengelola data dokter.
- Mengelola data poli.
- Mengatur jadwal dokter.
- Mengatur kuota.
- Memantau booking dan antrean.
- Mengelola akun dan hak akses.

**User Story:**

Sebagai admin, saya ingin mengelola data poli agar informasi layanan selalu diperbarui.

Sebagai admin, saya ingin mengelola jadwal dokter agar pasien memperoleh informasi yang benar.

Sebagai admin, saya ingin mengatur kuota agar jumlah pendaftaran sesuai kapasitas pelayanan.

Sebagai admin, saya ingin memantau antrean agar operasional klinik berjalan teratur.

## 4.4 Persona Farmasi

**Karakteristik:** Petugas yang bertanggung jawab terhadap penerimaan dan penyiapan obat berdasarkan resep dokter.

**Kebutuhan:**
- Melihat resep masuk.
- Melihat detail resep.
- Memeriksa ketersediaan obat.
- Memproses resep.
- Memperbarui status penyiapan.
- Mengelola stok obat.

**User Story:**

Sebagai petugas farmasi, saya ingin menerima resep digital agar tidak perlu memasukkan ulang data resep.

Sebagai petugas farmasi, saya ingin memperbarui status resep agar pasien dapat mengetahui proses penyiapan obat.

Sebagai petugas farmasi, saya ingin mengelola stok obat agar ketersediaan obat dapat dipantau.

---

# 5. Product Requirements

## 5.1 Modul 1 — Antrean Digital dan Real-Time

**Deskripsi:** Modul untuk melakukan pendaftaran pemeriksaan dan memantau posisi antrean pasien.

**Kebutuhan fungsional:**
- Pasien memilih poli.
- Pasien memilih dokter dan jadwal yang tersedia.
- Sistem memvalidasi kuota.
- Sistem membuat nomor antrean.
- Pasien dapat melihat status antrean.
- Status antrean diperbarui ketika petugas mengubah proses pelayanan.
- Pasien dapat melihat estimasi waktu tunggu jika data pendukung tersedia.

**Status antrean:**
- Menunggu.
- Dipanggil.
- Sedang diperiksa.
- Selesai.
- Dibatalkan.
- Tidak hadir.

**Acceptance Criteria:**
- Booking tidak dapat dibuat jika kuota sudah penuh.
- Nomor antrean tidak boleh duplikat dalam satu sesi pelayanan.
- Pasien hanya dapat melihat booking miliknya.
- Perubahan status dapat diterima pengguna melalui sinkronisasi real-time.

## 5.2 Modul 2 — Informasi Jadwal Dokter

**Deskripsi:** Menyediakan informasi jadwal praktik dokter dan status ketersediaannya.

**Kebutuhan fungsional:**
- Menampilkan daftar dokter.
- Menampilkan poli dokter.
- Menampilkan hari dan jam praktik.
- Menampilkan status tersedia atau tidak tersedia.
- Menampilkan perubahan jadwal.
- Menyaring dokter berdasarkan poli dan tanggal.

**Acceptance Criteria:**
- Jadwal yang ditampilkan berasal dari data yang dikelola admin.
- Jadwal yang tidak aktif tidak dapat dipilih untuk booking.
- Perubahan jadwal diperbarui pada aplikasi pasien.

## 5.3 Modul 3 — Panduan Penanganan Awal

**Deskripsi:** Menyediakan informasi edukatif berdasarkan kategori gejala atau kondisi kesehatan.

**Kebutuhan fungsional:**
- Menampilkan kategori panduan.
- Menampilkan informasi gejala.
- Menampilkan langkah penanganan awal.
- Menampilkan tanda bahaya.
- Menampilkan rekomendasi mencari bantuan medis.
- Menampilkan disclaimer.

**Acceptance Criteria:**
- Konten telah ditinjau oleh tenaga kesehatan yang berwenang.
- Sistem tidak memberikan diagnosis pasti.
- Kondisi dengan tanda bahaya harus mengarahkan pengguna mencari pertolongan medis segera.
- Konten dapat diperbarui oleh pihak yang berwenang.

## 5.4 Modul 4 — Pengingat Obat Smart

**Deskripsi:** Membantu pasien mengingat jadwal penggunaan obat berdasarkan resep.

**Kebutuhan fungsional:**
- Menampilkan daftar obat.
- Menampilkan dosis dan aturan pakai.
- Mengatur jadwal pengingat.
- Mengatur tanggal mulai dan akhir.
- Mengaktifkan atau menonaktifkan pengingat.
- Mencatat konfirmasi konsumsi jika fitur diaktifkan.

**Acceptance Criteria:**
- Pengingat mengikuti jadwal yang tersimpan.
- Pengingat hanya dapat diakses oleh pemilik akun.
- Pasien dapat mengubah preferensi pengingat.
- Sistem menjelaskan bahwa pengingat bukan pengganti instruksi dokter.

## 5.5 Modul 5 — Rekam Medis Elektronik

**Deskripsi:** Menyimpan ringkasan pemeriksaan pasien secara digital.

**Kebutuhan fungsional:**
- Menampilkan riwayat kunjungan.
- Menampilkan tanggal pemeriksaan.
- Menampilkan poli dan dokter.
- Menampilkan diagnosis.
- Menampilkan alergi yang tercatat.
- Menampilkan tanda vital jika tersedia.
- Menampilkan ringkasan hasil pemeriksaan.

**Acceptance Criteria:**
- Pasien hanya dapat membaca rekam medis miliknya.
- Dokter hanya dapat mengakses data pasien sesuai kewenangan pelayanan.
- Perubahan catatan medis harus tercatat.
- Catatan yang telah difinalisasi tidak boleh diubah tanpa mekanisme koreksi dan audit.

## 5.6 Modul 6 — E-Resep dan Integrasi Farmasi

**Deskripsi:** Menghubungkan resep dokter dengan proses penyiapan obat di farmasi.

**Kebutuhan fungsional:**
- Dokter membuat resep.
- Resep berisi nama obat, dosis, rute, frekuensi, durasi, jumlah, dan instruksi.
- Farmasi menerima resep.
- Farmasi memeriksa ketersediaan obat.
- Farmasi memperbarui status resep.
- Pasien melihat status resep.

**Status resep:**
- Menunggu.
- Diproses.
- Menunggu ketersediaan.
- Siap diambil.
- Selesai.
- Dibatalkan.

**Acceptance Criteria:**
- Resep hanya dapat dibuat oleh dokter dengan hak akses yang sesuai.
- Resep terhubung dengan kunjungan pasien.
- Perubahan status resep tercatat.
- Informasi resep yang ditampilkan kepada pasien sesuai data yang telah dipublikasikan.

## 5.7 Modul 7 — Pindah Poli dan Rujukan Internal

**Deskripsi:** Memungkinkan dokter mengarahkan pasien ke poli lain dalam klinik.

**Kebutuhan fungsional:**
- Dokter memilih poli tujuan.
- Dokter mengisi alasan rujukan.
- Dokter menentukan prioritas jika diperlukan.
- Sistem menyimpan data rujukan.
- Poli tujuan menerima informasi rujukan.
- Pasien memperoleh informasi proses selanjutnya.

**Acceptance Criteria:**
- Rujukan hanya dapat dibuat oleh petugas yang berwenang.
- Data rujukan terhubung dengan kunjungan asal.
- Rujukan tidak otomatis mengubah status kunjungan tanpa proses yang ditentukan klinik.
- Sistem mengikuti aturan antrean poli tujuan.

## 5.8 Modul 8 — Manajemen Kuota Dokter

**Deskripsi:** Mengelola batas jumlah pasien berdasarkan dokter, poli, tanggal, dan sesi praktik.

**Kebutuhan fungsional:**
- Admin mengatur kuota.
- Admin melihat jumlah booking.
- Sistem menghitung sisa kuota.
- Sistem menolak booking ketika kuota penuh.
- Sistem memperbarui kuota ketika booking dibatalkan sesuai aturan klinik.

**Acceptance Criteria:**
- Kuota tidak dapat dilampaui akibat booking bersamaan.
- Validasi dilakukan di backend.
- Perubahan kuota tercatat.
- Jadwal yang tidak memiliki kuota tersedia tidak dapat dipilih.

## 5.9 Prioritas Pengembangan

| Tahap | Fitur |
|---|---|
| MVP / Tahap 1 | Login dan profil pasien, data poli, jadwal dokter, booking, antrean digital |
| Tahap 2 | Rekam medis, diagnosis, E-Resep, farmasi, pengingat obat |
| Tahap 3 | Panduan penanganan awal, rujukan internal, grafik tren kesehatan, pengelolaan kuota lanjutan |

Tahapan ini merupakan rekomendasi pengembangan. Seluruh delapan modul tetap menjadi ruang lingkup produk jangka panjang.

## 5.10 Fitur di Luar Ruang Lingkup Awal

- Telemedicine atau konsultasi video.
- Pembayaran online dan payment gateway.
- Integrasi BPJS.
- Integrasi laboratorium eksternal.
- Kecerdasan buatan untuk diagnosis.
- Integrasi multi-cabang klinik.
- Aplikasi iOS.

---

# 6. UX & Design

## 6.1 Prinsip Desain

- Friendly: tampilan ramah dan tidak mengintimidasi.
- Simple: navigasi mudah dipahami.
- Professional: sesuai konteks layanan kesehatan.
- Consistent: komponen dan pola interaksi seragam.
- Accessible: teks terbaca dan tombol mudah dijangkau.
- Responsive: mendukung ukuran layar berbeda.

## 6.2 Design Direction

**Gaya:** Friendly, modern, clean, professional.  
**Mode:** Light Mode dan Dark Mode.  
**Target:** Seluruh kelompok pengguna.

## 6.3 Rekomendasi Design System

| Elemen | Rekomendasi |
|---|---|
| Primary | Teal / hijau kebiruan |
| Secondary | Biru |
| Background | Putih keabu-abuan |
| Surface | Putih |
| Success | Hijau |
| Warning | Oranye |
| Error | Merah |
| Font | Inter atau Plus Jakarta Sans |
| Radius kartu | 12–16 px |
| Radius tombol | 12 px |
| Spacing dasar | Kelipatan 4 atau 8 |

Warna final perlu ditetapkan dalam file theme Flutter agar konsisten.

## 6.4 Navigasi Pasien

Navigasi utama:

1. Beranda.
2. Booking.
3. Antrean.
4. Profil.

Menu tambahan di Beranda:

- Jadwal dokter.
- Panduan kesehatan.
- Pengingat obat.
- Rekam medis.
- Resep digital.
- Notifikasi.

## 6.5 Kebutuhan Halaman Pasien

| Halaman | Kebutuhan |
|---|---|
| Splash Screen | Identitas dan proses inisialisasi |
| Onboarding | Penjelasan manfaat aplikasi |
| Login | Autentikasi pasien |
| Registrasi | Pembuatan akun |
| Beranda | Ringkasan layanan dan akses cepat |
| Daftar Poli | Informasi poli |
| Daftar Dokter | Daftar dokter berdasarkan poli |
| Detail Dokter | Profil dan jadwal praktik |
| Booking | Pemilihan poli, dokter, dan tanggal |
| Konfirmasi Booking | Ringkasan pendaftaran |
| Detail Antrean | Nomor, status, dan estimasi |
| Jadwal Dokter | Informasi jadwal dan ketersediaan |
| Panduan Kesehatan | Kategori dan informasi penanganan awal |
| Detail Panduan | Gejala, langkah awal, dan tanda bahaya |
| Pengingat Obat | Daftar obat dan jadwal |
| Rekam Medis | Riwayat kunjungan |
| Detail Rekam Medis | Ringkasan pemeriksaan |
| Resep Digital | Daftar resep |
| Detail Resep | Obat dan status farmasi |
| Notifikasi | Informasi aktivitas |
| Profil | Data pasien dan pengaturan |

## 6.6 Kebutuhan Halaman Dokter

- Login dokter.
- Dashboard dokter.
- Jadwal praktik.
- Daftar antrean.
- Detail pasien dan kunjungan.
- Form pemeriksaan SOAP.
- Diagnosis dan tanda vital.
- Form E-Resep.
- Form rujukan internal.

## 6.7 Kebutuhan Halaman Admin

- Login admin.
- Dashboard klinik.
- Manajemen pasien.
- Manajemen dokter.
- Manajemen poli.
- Manajemen jadwal.
- Manajemen kuota.
- Manajemen antrean.
- Manajemen akun dan role.

## 6.8 Kebutuhan Halaman Farmasi

- Login farmasi.
- Dashboard farmasi.
- Daftar resep masuk.
- Detail resep.
- Proses penyiapan obat.
- Manajemen obat.
- Manajemen stok.
- Riwayat pergerakan stok.

## 6.9 UX States

Setiap halaman yang mengambil data harus menyediakan:

- Loading state.
- Empty state.
- Error state.
- Offline atau koneksi bermasalah.
- Success feedback.
- Confirmation dialog untuk tindakan penting.

---

# 7. Technical Specifications

## 7.1 Arsitektur Teknologi

| Lapisan | Teknologi |
|---|---|
| Mobile frontend | Flutter |
| Bahasa pemrograman | Dart |
| Web dashboard | Flutter Web |
| Authentication | Firebase Authentication |
| Database | Cloud Firestore |
| Backend logic | Cloud Functions |
| File storage | Firebase Storage |
| Push notification | Firebase Cloud Messaging |
| App protection | Firebase App Check |
| State management | Riverpod |
| Routing | GoRouter |

## 7.2 Arsitektur Sistem

```text
                  KLINIKCARE
                       |
          +------------+------------+
          |                         |
    Flutter Android            Flutter Web
       (Pasien)              (Dokter/Admin/
                              Farmasi)
          |                         |
          +------------+------------+
                       |
                  Firebase
                       |
       +---------------+----------------+
       |               |                |
 Authentication   Cloud Firestore   Cloud Storage
       |               |
       |          Cloud Functions
       |               |
       +---------------+
                       |
              Firebase Cloud Messaging
                       |
                Push Notification
```

## 7.3 Struktur Folder Flutter

```text
lib/
├── main.dart
├── firebase_options.dart
│
├── app/
│   ├── app.dart
│   ├── router.dart
│   ├── theme/
│   └── providers/
│
├── core/
│   ├── constants/
│   ├── errors/
│   ├── utils/
│   ├── widgets/
│   └── services/
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── home/
│   ├── profile/
│   ├── poli/
│   ├── doctors/
│   ├── booking/
│   ├── queue/
│   ├── health_guide/
│   ├── medical_records/
│   ├── prescriptions/
│   ├── medication_reminders/
│   └── notifications/
│
└── shared/
    ├── models/
    └── widgets/
```

Setiap fitur memiliki pemisahan data, domain, dan presentation. Query Firestore tidak ditempatkan langsung di dalam widget halaman.

## 7.4 Dependensi Flutter

Rekomendasi paket:

```yaml
dependencies:
  flutter:
    sdk: flutter

  firebase_core: any
  firebase_auth: any
  cloud_firestore: any
  firebase_storage: any
  firebase_messaging: any
  firebase_app_check: any

  flutter_riverpod: any
  go_router: any
  intl: any
```

Versi paket harus disesuaikan dengan versi Flutter dan Dart yang digunakan ketika implementasi dimulai. Hindari mempertahankan `any` pada konfigurasi final; gunakan versi kompatibel yang telah diuji.

## 7.5 Struktur Database Firestore

### Collection: users

Menyimpan akun dan role pengguna.

```text
users/{userId}
  uid
  name
  email
  phone
  role
  photoUrl
  isActive
  createdAt
  updatedAt
```

Role:

- patient
- doctor
- admin
- pharmacy

### Collection: patients

```text
patients/{patientId}
  userId
  medicalRecordNumber
  fullName
  birthDate
  gender
  address
  phone
  createdAt
  updatedAt
```

### Collection: doctors

```text
doctors/{doctorId}
  userId
  name
  specialization
  poliId
  licenseNumber
  phone
  photoUrl
  isActive
```

### Collection: polis

```text
polis/{poliId}
  name
  description
  icon
  isActive
  createdAt
```

### Collection: doctorSchedules

```text
doctorSchedules/{scheduleId}
  doctorId
  poliId
  date
  startTime
  endTime
  quota
  bookedCount
  status
  createdAt
  updatedAt
```

### Collection: bookings

```text
bookings/{bookingId}
  patientId
  doctorId
  poliId
  scheduleId
  bookingDate
  queueNumber
  status
  complaint
  createdAt
  updatedAt
```

### Collection: queues

```text
queues/{queueId}
  bookingId
  patientId
  doctorId
  poliId
  scheduleId
  queueNumber
  status
  calledAt
  startedAt
  completedAt
  updatedAt
```

### Collection: visits

```text
visits/{visitId}
  bookingId
  patientId
  doctorId
  poliId
  visitDate
  subjective
  objective
  assessment
  plan
  diagnosis
  vitalSigns
  notes
  status
  createdAt
  updatedAt
```

### Collection: allergies

```text
allergies/{allergyId}
  patientId
  name
  reaction
  notes
  createdAt
```

### Collection: prescriptions

```text
prescriptions/{prescriptionId}
  visitId
  patientId
  doctorId
  status
  instructions
  createdAt
  updatedAt

  items/{itemId}
    medicineId
    medicineName
    dosage
    route
    frequency
    duration
    quantity
    instructions
```

### Collection: medicines

```text
medicines/{medicineId}
  name
  category
  unit
  stock
  minimumStock
  isActive
  updatedAt
```

### Collection: pharmacyOrders

```text
pharmacyOrders/{orderId}
  prescriptionId
  patientId
  pharmacyUserId
  status
  processedAt
  completedAt
  notes
```

### Collection: medicationSchedules

```text
medicationSchedules/{scheduleId}
  patientId
  prescriptionId
  medicineName
  dosage
  frequency
  reminderTimes
  startDate
  endDate
  isActive
  createdAt
```

### Collection: notifications

```text
notifications/{notificationId}
  userId
  title
  body
  type
  referenceId
  isRead
  createdAt
```

### Collection: referrals

```text
referrals/{referralId}
  visitId
  patientId
  fromPoliId
  toPoliId
  doctorId
  reason
  priority
  status
  createdAt
  updatedAt
```

### Collection: stockMovements

```text
stockMovements/{movementId}
  medicineId
  type
  quantity
  referenceId
  performedBy
  notes
  createdAt
```

### Collection: auditLogs

```text
auditLogs/{logId}
  actorId
  actorRole
  action
  resourceType
  resourceId
  timestamp
  metadata
```

Struktur ini merupakan rancangan awal. Relasi, indeks, retensi data, dan aturan akses harus diuji berdasarkan pola query serta kebutuhan operasional klinik.

## 7.6 Relasi Data Utama

```text
User
 ├── Patient
 ├── Doctor
 ├── Admin
 └── Pharmacy

Patient
 ├── Booking
 ├── Queue
 ├── Visit
 ├── Prescription
 ├── Medication Schedule
 └── Notification

Doctor
 ├── Schedule
 ├── Booking
 ├── Visit
 ├── Prescription
 └── Referral

Poli
 ├── Doctor
 ├── Schedule
 ├── Booking
 └── Queue

Prescription
 └── Pharmacy Order
      └── Stock Movement
```

## 7.7 API dan Backend Operations

KlinikCare menggunakan Firebase SDK dan Cloud Functions. Operasi penting harus dilakukan di backend.

Rekomendasi fungsi:

| Function | Tanggung Jawab |
|---|---|
| createBooking | Validasi jadwal dan kuota, membuat booking |
| cancelBooking | Membatalkan booking sesuai aturan |
| generateQueueNumber | Membuat nomor antrean unik |
| updateQueueStatus | Memperbarui status antrean |
| publishPrescription | Menerbitkan resep dokter |
| processPharmacyOrder | Memproses resep di farmasi |
| updateMedicineStock | Memperbarui stok obat |
| createReferral | Membuat rujukan internal |
| sendNotification | Mengirim notifikasi |
| assignUserRole | Mengatur role melalui proses admin yang aman |

### Aturan penting backend

1. Validasi kuota dilakukan di Cloud Functions menggunakan transaksi Firestore.
2. Pembuatan booking dan perubahan jumlah booking harus konsisten.
3. Nomor antrean dibuat melalui proses backend.
4. Klien Flutter tidak boleh menentukan role sendiri.
5. Stok obat tidak boleh diubah hanya berdasarkan nilai dari aplikasi klien.
6. Perubahan data medis dan resep harus memiliki jejak audit.

## 7.8 Keamanan Sistem

- Gunakan Firebase Authentication.
- Terapkan Firestore Security Rules berdasarkan UID dan role.
- Terapkan prinsip least privilege.
- Gunakan App Check.
- Batasi akses data medis berdasarkan kebutuhan pelayanan.
- Jangan menyimpan password secara manual di Firestore.
- Validasi input di frontend dan backend.
- Gunakan Cloud Functions untuk operasi sensitif.
- Hindari menampilkan data medis pada notifikasi layar kunci.
- Simpan audit log untuk perubahan penting.
- Atur backup dan pemulihan data.

**Catatan kepatuhan:** Implementasi produksi wajib ditinjau terhadap UU Perlindungan Data Pribadi, ketentuan rekam medis elektronik, kebijakan retensi data, persetujuan pasien, dan regulasi kesehatan Indonesia yang berlaku. Peninjauan perlu melibatkan pihak klinik dan tenaga ahli hukum atau kepatuhan.

## 7.9 Non-Functional Requirements

| Area | Persyaratan |
|---|---|
| Performance | Halaman utama menampilkan konten inti secara cepat pada jaringan normal |
| Reliability | Booking dan kuota konsisten |
| Security | Akses data berdasarkan role dan kepemilikan |
| Scalability | Struktur koleksi dan query mendukung pertumbuhan pengguna |
| Maintainability | Kode menggunakan pemisahan fitur dan repository |
| Availability | Bergantung pada layanan Firebase dan koneksi internet |
| Usability | Navigasi mudah dipahami |
| Compatibility | Android dan browser modern untuk dashboard |

---

# 8. Go-to-Market

## 8.1 Target Implementasi Awal

Implementasi awal difokuskan pada satu klinik untuk menguji alur pendaftaran, antrean, dan pelayanan.

## 8.2 Strategi Peluncuran

**Tahap 1 — Internal Testing**
- Menguji autentikasi.
- Menguji data poli dan dokter.
- Menguji booking dan antrean.
- Menguji pembatasan role.

**Tahap 2 — Pilot Clinic**
- Melibatkan admin klinik.
- Melibatkan beberapa dokter.
- Menguji pendaftaran pasien.
- Mengumpulkan masukan dari pengguna.

**Tahap 3 — Public Release**
- Memperbaiki bug.
- Menyempurnakan pengalaman pengguna.
- Menyusun panduan penggunaan.
- Menyiapkan proses dukungan pengguna.

## 8.3 Materi Peluncuran

- Panduan pasien.
- Panduan admin.
- Panduan dokter.
- Panduan farmasi.
- Dokumentasi penggunaan aplikasi.
- Informasi kebijakan privasi.

---

# 9. Dependencies & Risks

## 9.1 Dependencies

| Dependensi | Kegunaan |
|---|---|
| Flutter SDK | Pengembangan aplikasi |
| Dart SDK | Bahasa pemrograman |
| Firebase | Backend dan database |
| Firebase Authentication | Autentikasi |
| Cloud Firestore | Penyimpanan data |
| Cloud Functions | Backend operations |
| Firebase Storage | Penyimpanan file |
| Firebase Messaging | Push notification |
| Android SDK | Build aplikasi Android |
| Google Services | Konfigurasi Firebase Android |

## 9.2 Risiko dan Mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Internet tidak stabil | Data terlambat diperbarui | Loading, retry, dan penanganan offline |
| Booking bersamaan | Kuota terlampaui | Firestore transaction di backend |
| Kebocoran data medis | Risiko privasi | Security Rules, role, audit log |
| Notifikasi tidak diterima | Pasien melewatkan informasi | Riwayat notifikasi dalam aplikasi |
| Kesalahan data resep | Risiko pelayanan | Validasi dan konfirmasi dokter |
| Stok obat tidak akurat | Proses farmasi terganggu | Riwayat stock movement |
| Jadwal dokter berubah | Booking tidak sesuai | Status jadwal dan notifikasi perubahan |
| Konten panduan keliru | Risiko kesehatan | Review tenaga kesehatan |

---

# 10. Timeline & Milestones

Rekomendasi jadwal untuk pengembangan solo developer. Durasi perlu disesuaikan dengan kompleksitas implementasi dan hasil pengujian.

| Minggu | Aktivitas | Output |
|---|---|---|
| 1 | Finalisasi kebutuhan, desain, setup Flutter dan Firebase | Project dasar |
| 2 | Authentication, role, profil, data poli dan dokter | Modul akun dan master data |
| 3 | Jadwal dokter dan booking | Modul booking |
| 4 | Antrean digital dan notifikasi | Modul antrean |
| 5 | Rekam medis, pemeriksaan, dan E-Resep | Modul medis |
| 6 | Farmasi dan pengingat obat | Modul farmasi |
| 7 | Panduan kesehatan, rujukan, dan kuota | Modul pendukung |
| 8 | Pengujian, keamanan, perbaikan, dokumentasi | Kandidat rilis |

## 10.1 Milestone

**Milestone 1:** Aplikasi dan Firebase terhubung.

**Milestone 2:** Pasien dapat melakukan booking.

**Milestone 3:** Antrean dapat dipantau secara digital.

**Milestone 4:** Dokter dapat mencatat pemeriksaan dan resep.

**Milestone 5:** Farmasi dapat memproses resep.

**Milestone 6:** Seluruh modul diuji dan siap untuk pilot.

---

# 11. Resources & Team

## 11.1 Tim Pengembangan

Proyek dirancang untuk dikerjakan oleh satu developer dengan dukungan pihak klinik untuk validasi kebutuhan operasional dan konten medis.

| Peran | Tanggung Jawab |
|---|---|
| Product Owner | Menentukan prioritas kebutuhan |
| Flutter Developer | Implementasi aplikasi mobile dan dashboard |
| Firebase Developer | Database, authentication, rules, functions |
| UI/UX Designer | Desain halaman dan design system |
| Dokter/Penanggung Jawab Medis | Validasi konten dan alur medis |
| Admin Klinik | Validasi operasional |
| Petugas Farmasi | Validasi alur resep dan obat |

Dalam pengembangan solo, beberapa peran teknis dapat dijalankan oleh developer yang sama. Validasi medis dan operasional tetap membutuhkan pihak klinik yang berwenang.

## 11.2 Kebutuhan Perangkat

- Laptop atau komputer pengembangan.
- VS Code.
- Flutter SDK.
- Android SDK.
- Perangkat Android untuk pengujian.
- Akun Firebase.
- Koneksi internet.

## 11.3 Estimasi Biaya

Biaya belum ditetapkan karena belum ada informasi jumlah pengguna, volume transaksi, kebutuhan penyimpanan, dan lingkungan produksi.

Komponen biaya yang perlu dihitung:

- Paket Firebase sesuai pemakaian.
- Cloud Functions dan biaya komputasi.
- Cloud Storage.
- Biaya domain jika diperlukan.
- Biaya distribusi aplikasi.
- Biaya operasional dan pemeliharaan.

Gunakan Firebase Spark untuk prototipe jika layanan dan batas kuotanya mencukupi. Sebelum produksi, lakukan estimasi biaya berdasarkan proyeksi pemakaian dan evaluasi kebutuhan paket berbayar.

---

# 12. Post-Launch Plan

## 12.1 Monitoring

Pantau:

- Crash aplikasi.
- Error Cloud Functions.
- Kegagalan booking.
- Duplikasi antrean.
- Kegagalan notifikasi.
- Perubahan stok.
- Akses yang ditolak.
- Penggunaan fitur.

## 12.2 Maintenance

- Memperbaiki bug.
- Memperbarui dependensi.
- Memeriksa Firestore Security Rules.
- Memantau penggunaan dan biaya Firebase.
- Menguji backup dan pemulihan.
- Memperbarui dokumentasi.

## 12.3 Pengembangan Berikutnya

Setelah MVP berjalan stabil, pengembangan dapat mencakup:

- Grafik tren kesehatan.
- Laporan operasional klinik.
- Pengembangan dashboard analitik.
- Integrasi pembayaran.
- Integrasi layanan eksternal.
- Dukungan multi-cabang.
- Peningkatan sistem notifikasi.

---

# 13. Appendix

## 13.1 Glosarium

| Istilah | Penjelasan |
|---|---|
| PRD | Product Requirements Document |
| MVP | Minimum Viable Product |
| Poli | Unit pelayanan berdasarkan bidang kesehatan |
| Booking | Pendaftaran kunjungan |
| Antrean | Urutan pelayanan pasien |
| E-Resep | Resep elektronik |
| Rekam Medis | Catatan informasi pemeriksaan pasien |
| SOAP | Subjective, Objective, Assessment, Plan |
| Firestore | Database NoSQL dari Firebase |
| Cloud Functions | Backend function berbasis cloud |
| FCM | Firebase Cloud Messaging |
| RBAC | Role-Based Access Control |

## 13.2 Keputusan Produk

| Area | Keputusan |
|---|---|
| Nama aplikasi | KlinikCare |
| Platform pasien | Android |
| Platform operasional | Flutter Web |
| Bahasa | Dart |
| Framework | Flutter |
| Backend | Firebase |
| Database | Cloud Firestore |
| Authentication | Firebase Authentication |
| Notifikasi | Firebase Cloud Messaging |
| State Management | Riverpod |
| Routing | GoRouter |
| Pengguna | Pasien, Dokter, Admin, Farmasi |

## 13.3 Dokumen Acuan

PRD ini mengacu pada materi proyek KlinikCare yang telah disusun sebelumnya:

1. Problem & Solusi KlinikCare.
2. Analisis Masalah & Solusi Fitur Poli KlinikCare.
3. Dokumen Gabungan Fitur KlinikCare.
4. PRD Final KlinikCare — Firebase dan Flutter.

## 13.4 Catatan Final

Dokumen ini menjadi baseline kebutuhan produk dan rancangan implementasi KlinikCare. Detail yang belum ditentukan, seperti identitas klinik, kebijakan pembatalan, aturan antrean, estimasi waktu tunggu, retensi rekam medis, dan biaya operasional, perlu dikonfirmasi bersama pihak klinik sebelum implementasi produksi.

**End of Document — KlinikCare PRD v1.0**