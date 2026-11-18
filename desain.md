# KLINIKCARE — DESIGN SYSTEM & UI/UX SPECIFICATION

**Nama Produk:** KlinikCare  
**Gaya Desain:** 3D Glassmorphism / Frosted Glass UI  
**Target Platform:** Mobile (Android - Pasien) & Web Dashboard (Dokter, Admin, Farmasi)  
**Versi Dokumen:** 1.0  
**Tanggal:** 8 November 2026  

---

## 1. Vision & Visual Strategy

Dokumen ini mendefinisikan panduan visual dan UI/UX untuk **KlinikCare**. Mengacu pada konsep desain **3D Glassmorphism / Frosted Glass**, aplikasi ini memadukan kesan futuristik, bersih (*clean*), dan ramah pengguna (*friendly*) dengan utilitas medis yang profesional.

### 1.1 Pilar Utama Visual
1. **Translucency & Layering (Frosted Glass):** Menggunakan efek *backdrop blur*, efek kaca semi-transparan, serta gradasi halus untuk memisahkan tingkatan informasi (*depth & elevation*).
2. **Soft Vibrant Colors:** Dominasi latar belakang lembut (pastel light/dark) yang memantulkan pendaran warna ungu-kebiruan (*purple-blue glow*), teal, dan oranye pastel.
3. **Rounded & Organic Shapes:** Sudut elemen yang sangat membulat (*extra rounded corners*, $16\text{px} - 24\text{px}$) memberikan rasa aman, modern, dan bebas ketegangan medis.
4. **Subtle 3D & Soft Shadows:** Efek pencahayaan lembut di tepi kartu (*border highlight* $1\text{px}$) dan bayangan jatuh bergradasi (*colored drop shadows*).

---

## 2. Palette Warna (Color System)

Warna dikalibrasi untuk mendukung aspek keterbacaan (*readability*) dan suasana kesehatan yang tenang.

### 2.1 Main Palette
| Elemen | Hex Code | Deskripsi & Penggunaan |
|---|---|---|
| **Primary Base** | `#6C5CE7` | Violet / Purple (Aksen utama, tombol aktif, badge penting) |
| **Primary Soft** | `#A29BFE` | Lavender / Light Purple Glow |
| **Secondary Teal** | `#00CEC9` | Teal / Cyan (Elemen kesehatan, poli umum) |
| **Background Light** | `#F3F4F9` | Off-white lembut dengan tint biru/ungu tipis |
| **Background Dark** | `#0F0E17` | Obsidian Glass (Dark mode background) |
| **Card Surface (Glass)** | `rgba(255, 255, 255, 0.45)` | Permukaan kartu dengan *backdrop blur* $16\text{px} - 24\text{px}$ |
| **Card Border** | `rgba(255, 255, 255, 0.6)` | *Inner stroke* $1\text{px}$ pembentuk efek tepian kaca |

### 2.2 Semantic Colors (Status Antrean & Farmasi)
| Status | Hex Code | Glass Overlay |
|---|---|---|
| **Success / Menunggu / Selesai** | `#00B894` | `rgba(0, 184, 148, 0.15)` |
| **Warning / Dipanggil / Diproses** | `#FDCB6E` | `rgba(253, 203, 110, 0.2)` |
| **Error / Dibatalkan / Penuh** | `#FF7675` | `rgba(255, 118, 117, 0.15)` |
| **Info / Sedang Diperiksa** | `#0984E3` | `rgba(9, 132, 227, 0.15)` |

---

## 3. Tipografi & Hirarki Text

Menggunakan font modern sans-serif: **Plus Jakarta Sans** atau **Inter**.

- **Display Title (Antrean Real-time):** 36pt / Bold / Spacing -0.5px
- **Heading 1 (Header Halaman):** 24pt / SemiBold
- **Heading 2 (Sub-kategori/Poli):** 18pt / Medium
- **Body 1 (Teks Utama/Detail Resep):** 14pt / Regular
- **Body 2 (Keterangan/Jadwal):** 12pt / Medium / Opacity 70%
- **Caption/Badge:** 10pt / Bold / ALL CAPS

---

## 4. Komponen UI Utama & Spesifikasi Glassmorphism

### 4.1 Frosted Glass Card (`KlinikGlassCard`)
Seluruh kartu widget (Dokter, Jadwal, Antrean, Rekam Medis) menerapkan rumus CSS/Flutter styling berikut:

```dart
// Flutter Implementation Logic
BoxDecoration(
  color: Colors.white.withOpacity(0.45),
  borderRadius: BorderRadius.circular(20),
  border: Border.all(
    color: Colors.white.withOpacity(0.6),
    width: 1.5,
  ),
  boxShadow: [
    BoxShadow(
      color: Color(0xFF6C5CE7).withOpacity(0.08),
      blurRadius: 24,
      spreadRadius: 0,
      offset: Offset(0, 8),
    ),
  ],
);
```

### 4.2 Floating Navigation Bar (Mobile Pasien)
- **Bentuk:** Capsule mengambang (*pill shape*) di bagian bawah layar.
- **Efek:** Semi-transparan dengan *backdrop blur* $20\text{px}$.
- **Item Menu:** Home, Booking, Antrean (Floating Center Button with Glow), Profile.

### 4.3 Floating Widgets & Quick Stats
- **Antrean Aktif Widget:** Kartu bergelombang dengan grafik status estimasi waktu tunggu (mirip widget *Statistics* pada gambar acuan).
- **Pengingat Obat Smart:** Kartu interaktif berpenanda checkbox bercahaya (*glowing checkmarks*).
- **Panduan Penanganan Awal:** Grid 2 kolom berisi ikon 3D kustom (Poli Umum, Gigi, Anak, Spesialis).

---

## 5. Layout & Halaman Utama Pasien (Mobile)

### 5.1 Dashboard / Beranda Pasien
1. **Header:** 
   - Ucapan selamat (misal: "Good Morning, Sarah 👋")
   - Profil avatar dengan *glow ring*.
   - Tombol Notifikasi bercahaya.
2. **Hero Banner (Status Antrean Hari Ini):**
   - Jika ada antrean aktif: Kartu kaca ungu berpendar menampilkan Nomor Antrean (`A-012`), Nama Dokter, Poli, dan Estimasi Dipanggil.
3. **Pencarian Smart Search Bar:**
   - Input field transparan: *"Cari Dokter, Poli, atau Gejala..."*
4. **Grid Kategori Poli (Glass Icons):**
   - Poli Umum, Poli Gigi, Poli Anak, Spesialis Mata, dll.
5. **Widget Pengingat Obat & Rekam Medis Ringkas:**
   - Daftar jadwal minum obat hari ini dengan *toggle switch* ala Glassmorphism.

### 5.2 Layar Antrean Digital Real-Time
- **Kartu Nomor Antrean Utama:** Tampilan angka antrean besar dengan efek 3D depth.
- **Progress Stepper Interactive:**
  - `Menunggu` ➔ `Dipanggil` ➔ `Sedang Diperiksa` ➔ `Selesai`
- **Animasi Dynamic Pulse:** Indikator lingkaran bercahaya hijau/oranye saat status antrean diperbarui.

---

## 6. Layout Dashboard Web (Dokter, Admin, Farmasi)

Dashboard operasional web mengadopsi struktur *Glass Grid Panel*:

1. **Sidebar Navigation:** Panel kaca vertikal di sebelah kiri dengan ikon minimalis.
2. **Main Canvas:** Background gradasi gelap/terang lembut dengan komponen *bento-grid*:
   - **Panel Dokter:** List antrean masuk pasien, Form SOAP dengan textarea kaca murni, pencetak E-Resep.
   - **Panel Farmasi:** Kartu antrean resep dengan pill badge status (*Menunggu Penyiapan*, *Siap Diambil*).
   - **Panel Admin:** Monitoring kuota dokter dalam bentuk grafik garis/doughnut *glowing lines*.

---

## 7. Mikro-Interaksi & Animasi

- **Hover & Touch Feedback:** Kartu terangkat sedikit ($Y \text{-offset}: -4\text{px}$) saat ditekan/di-hover dengan transisi animasi 200ms.
- **Glass Shimmer Loading State:** Animasi kilauan transparan (*shimmer glass*) menggantikan *loading spinner* standar saat fetching data Firestore.
- **Pop-up Modal:** Dialog konfirmasi booking muncul melayang (*floating modal*) dengan efek latar belakang blur penuh (*full-screen Gaussian blur* $15\text{px}$).

---

## 8. Panduan Aksesibilitas (Contrast & Readability)

Meskipun menggunakan konsep kaca transparan (*glassmorphism*), faktor kenyamanan membaca data medis pasien tetap diutamakan:

1. **Teks Utama:** Selalu menggunakan kontras tinggi (Warna teks `#1F1E2E` pada Light Mode, `#FFFFFF` pada Dark Mode).
2. **Label Sensitif Medis (Alergi, Resep):** Diberikan latar belakang *solid overlay* tipis agar angka dosis obat dan instruksi dokter tidak tersamar transparansi background.
3. **Ukuran Target Sentuh:** Minimal $48 \times 48 \text{ dp}$ untuk semua button mobile.