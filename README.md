# 🩺 Arogya

> **Layanan Kesehatan Digital** — aplikasi mobile untuk booking pemeriksaan, memantau antrean secara realtime, mengelola pengingat obat, serta mengakses resep digital dan rekam medis dalam satu aplikasi.

## 📖 Daftar Isi

- [Tentang Arogya](#-tentang-arogya)
- [Fitur](#-fitur)
- [Alur Penggunaan](#-alur-penggunaan)
- [Screenshot](#-screenshot)
- [Teknologi](#-teknologi)
- [Struktur Folder](#-struktur-folder)
- [Instalasi](#-instalasi)
- [Konfigurasi Supabase](#-konfigurasi-supabase)
- [Cara Menjalankan](#-cara-menjalankan)
- [Anggota Tim](#-anggota-tim)
- [Lisensi](#-lisensi)

## 🎯 Tentang Arogya

**Arogya** (bahasa Sanskerta: *kesehatan*) membantu pasien klinik menjalani seluruh alur pelayanan secara digital, mulai dari mendaftar, booking poliklinik, menunggu giliran, diperiksa dokter, hingga mengambil obat di farmasi, tanpa perlu antre lama di klinik.

Data tersimpan di **Supabase** (autentikasi, database, dan realtime), sehingga status antrean dan pesanan farmasi ter-update otomatis di layar pasien.

## ✨ Fitur

### 🔐 Akun & Autentikasi
- Registrasi akun pasien (nama, email, no. HP, kata sandi) dengan indikator kekuatan kata sandi
- Persetujuan Syarat & Ketentuan serta pengelolaan data kesehatan
- Verifikasi email setelah pendaftaran
- Login dengan email & kata sandi, serta **lupa kata sandi** (tautan reset via email)
- Splash screen animatif

### 🏠 Beranda
- **Live monitor** antrean poliklinik (realtime)
- Ringkasan antrean milik pasien dan akses cepat ke status antrean
- Menu layanan: Jadwal Dokter, Panduan Awal, Pengingat Obat, Rekam Medis, Resep Digital, Status Farmasi
- Pengingat obat berikutnya dan jadwal dokter hari ini langsung di beranda

### 📅 Booking Pemeriksaan
Booking online dalam 4 langkah:
1. Pilih **poliklinik**
2. Pilih **dokter**
3. Pilih **tanggal & jam** (menampilkan sisa slot/kuota, klinik tutup hari Minggu)
4. **Konfirmasi** — pilih jenis pasien (**Umum** / **BPJS Kesehatan**), isi keluhan, lalu terima **nomor antrean**

### 🎫 Antrean
- Status antrean aktif secara realtime beserta nomor antrean, dokter, jadwal, dan keluhan
- Tahapan layanan: *Terdaftar → Check-in → Menunggu → Pemeriksaan → Farmasi → Selesai*
- Info "sedang dilayani", jumlah antrean di depan, dan estimasi waktu tunggu
- **Check-in** kedatangan dan **pembatalan booking**
- Papan antrean poliklinik lain
- Tombol "Ingatkan saya" saat giliran mendekat

### 👨‍⚕️ Jadwal Dokter
- Jadwal praktik per hari dengan filter poliklinik
- Status kuota (tersedia / sisa kuota / penuh) dan tombol langsung ke booking

### 🚑 Panduan Awal
- Panduan pertolongan pertama dengan tingkat urgensi: **Ringan**, **Perlu ke klinik**, **Darurat**
- Nomor darurat yang dapat disalin

### 💊 Pengingat Obat
- Tambah, aktifkan/nonaktifkan, dan hapus pengingat (nama obat, dosis, aturan pakai: sebelum/sesudah/bersama makan, sebelum tidur)
- Tandai obat sudah diminum dan pantau **progres harian**

### 📋 Rekam Medis
- Nomor RM, golongan darah, tinggi/berat badan, dan alergi
- Riwayat kunjungan (diagnosis, keluhan, tanda vital, tindakan) dengan filter per poli

### 🧾 Resep Digital (E-Resep)
- Resep **aktif** dan **riwayat** lengkap dengan daftar obat, dosis, dan jumlah
- Salin kode resep dan lanjut pantau di farmasi

### 🏥 Status Farmasi
- Pantau penyiapan obat secara **realtime**: *Resep diterima → Verifikasi apoteker → Obat disiapkan → Siap diambil*
- Nomor antrean farmasi, estimasi waktu, daftar obat dalam pesanan, dan riwayat pengambilan

### 🔔 Notifikasi
- Pemberitahuan terpadu dari antrean, pengingat obat (termasuk yang terlewat), status farmasi, dan resep aktif
- Filter per kategori dan ketuk kartu untuk membuka halaman terkait

### 👤 Profil
- Data diri, informasi medis, kontak darurat, dan nomor BPJS (dapat disalin)
- Ubah profil
- Pengaturan: notifikasi antrean, pengingat obat, kunci biometrik
- Keluar dari akun

## 🔄 Alur Penggunaan

```
Daftar/Masuk → Booking → Check-in → Antre → Diperiksa dokter
                                              ↓
                  Ambil obat ← Status Farmasi ← E-Resep & Rekam Medis
```

## 🛠️ Teknologi

| Kategori | Teknologi |
|---|---|
| Framework | Flutter (Dart) |
| Backend | Supabase (Auth, PostgreSQL, Realtime) |
| Paket utama | `supabase_flutter`, `google_fonts` |
| UI | Material 3 dengan tema kustom (glass card, animasi) |
| Tools | Android Studio / VS Code, Git |

## 📂 Struktur Folder

```
lib/
├── screens/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── home_screen.dart
│   ├── booking_screen.dart
│   ├── antrean_screen.dart
│   ├── doctor_schedule_screen.dart
│   ├── first_aid_screen.dart
│   ├── med_reminder_screen.dart
│   ├── medical_record_screen.dart
│   ├── e_prescription_screen.dart
│   ├── pharmacy_status_screen.dart
│   ├── notification_screen.dart
│   └── profile_screen.dart
├── services/
│   └── clinic_repository.dart   # Akses data Supabase
├── theme/
│   └── app_colors.dart
├── widgets/                     # Komponen UI reusable (auth, sub page, animasi)
└── main.dart
```

## ⚙️ Instalasi

### Prasyarat

- [Git](https://git-scm.com/)
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Android Studio atau VS Code
- Emulator atau perangkat fisik
- Proyek [Supabase](https://supabase.com/)

### Langkah

```bash
git clone https://github.com/gilangsanka/ArogyaApp.git
cd arogya
flutter pub get
```

## 🗄️ Konfigurasi Supabase

1. Buat proyek di Supabase, lalu salin **Project URL** dan **anon key**.
2. Isi kredensial tersebut pada inisialisasi Supabase di `main.dart`:

   ```dart
   await Supabase.initialize(
     url: 'https://xxxx.supabase.co',
     anonKey: 'ANON_KEY_ANDA',
   );
   ```

3. Siapkan tabel yang dipakai aplikasi: `appointments`, `polyclinics`, `doctors`, `prescriptions`, `prescription_items`, `pharmacy_orders`, serta tabel profil pasien, rekam medis, alergi, pengingat obat, panduan awal, dan nomor darurat.
4. Buat trigger `handle_new_user` agar data `full_name` dan `phone` dari registrasi masuk ke profil pasien.
5. Aktifkan **Realtime** untuk tabel `appointments` dan `pharmacy_orders`.
6. Atur Row Level Security (RLS) agar pasien hanya dapat melihat datanya sendiri.

> ⚠️ Gunakan **anon key** saja di aplikasi. Jangan pernah menyertakan `service_role` key.

## ▶️ Cara Menjalankan

```bash
flutter devices          # lihat perangkat tersedia
flutter run              # jalankan mode debug
flutter build apk --release
```

APK hasil build ada di `build/app/outputs/flutter-apk/app-release.apk`.

## 👥 Anggota Tim

| Nama | NIM | Peran |
|---|---|---|
| Rivan Arief Maulana  | 19230623 |
| Raisha Regina Putri  | 19231923 |
| Gilang Sanka Hakim   | 19232098 |
| Meiyandri Istyanto   | 19230169 |
| Sandi Zulfikar       | 19230462 |

## 📄 Lisensi

Dirilis di bawah [MIT License](LICENSE).

---

⭐ Jika Arogya bermanfaat, beri bintang di repository ini!