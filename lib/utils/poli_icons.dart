import 'package:flutter/material.dart';

/// Pemetaan polyclinics.icon_key -> ikon. Isi kolom icon_key di database
/// dengan salah satu kunci ini; kunci lain memakai ikon default.
const _iconByKey = <String, IconData>{
  'general': Icons.medical_services_rounded,
  'dental': Icons.mood_rounded,
  'child': Icons.child_care_rounded,
  'internal': Icons.monitor_heart_rounded,
  'eye': Icons.visibility_rounded,
  'obgyn': Icons.pregnant_woman_rounded,
};

IconData poliIcon(String? key) =>
    _iconByKey[key] ?? Icons.local_hospital_rounded;
