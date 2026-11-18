import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Waktu "sekarang" menurut WIB (sama dengan today_wib() di database).
DateTime wibNow() => DateTime.now().toUtc().add(const Duration(hours: 7));

/// Tanggal hari ini (WIB) tanpa jam.
DateTime wibToday() {
  final n = wibNow();
  return DateTime(n.year, n.month, n.day);
}

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _bulan = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des'
];

String fmtDateId(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_bulan[d.month - 1]} ${d.year}';

/// Kolom `date` ('2026-11-16') -> '16 Nov 2026'.
String fmtDateStr(String? s) => s == null ? '-' : fmtDateId(DateTime.parse(s));

/// Kolom `timestamptz` -> tanggal WIB '16 Nov 2026'.
String fmtTimestampId(String? iso) => iso == null
    ? '-'
    : fmtDateId(DateTime.parse(iso).toUtc().add(const Duration(hours: 7)));

/// '09:00:00' -> '09:00'.
String hhmm(String t) => t.length >= 5 ? t.substring(0, 5) : t;

TimeOfDay parseTime(String t) {
  final p = t.split(':');
  return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
}

/// 37.8 -> '37,8'; 65.0 -> '65'; null -> '-'.
String fmtNum(num? n) {
  if (n == null) return '-';
  if (n % 1 == 0) return n.toInt().toString();
  return n.toString().replaceAll('.', ',');
}

/// '#5341CD' -> Color. Kembali ke [fallback] bila kosong/tidak valid.
Color colorFromHex(String? hex, Color fallback) {
  if (hex == null) return fallback;
  final h = hex.replaceAll('#', '').trim();
  if (h.length != 6) return fallback;
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

/// 'dr. Kevin Pratama' -> 'KP'.
String initialsOf(String name) {
  final words = name
      .replaceAll(RegExp(r'^(dr|drg)\.?\s*', caseSensitive: false), '')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first[0].toUpperCase();
  return (words[0][0] + words[1][0]).toUpperCase();
}

String friendlyError(Object e) {
  if (e is PostgrestException) return e.message;
  if (e is AuthException) return e.message;
  return 'Gagal memuat data. Periksa koneksi internet Anda.';
}
