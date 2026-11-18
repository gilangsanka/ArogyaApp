import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/format.dart';

typedef Json = Map<String, dynamic>;

/// Semua query ke Supabase untuk layar-layar Arogya.
/// Keamanan data diatur oleh RLS di database (pasien hanya melihat datanya
/// sendiri); filter patient_id di sini hanya agar akun staf yang sedang
/// login sebagai pasien tidak ikut melihat data semua pasien.
class ClinicRepository {
  ClinicRepository._();
  static final ClinicRepository instance = ClinicRepository._();

  SupabaseClient get _db => Supabase.instance.client;

  String? _pid;
  String? _pidUser;

  /// patients.id milik akun yang sedang login (di-cache per user).
  Future<String> patientId() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('Belum masuk');
    if (_pid != null && _pidUser == uid) return _pid!;
    final row =
        await _db.from('patients').select('id').eq('user_id', uid).single();
    _pid = row['id'] as String;
    _pidUser = uid;
    return _pid!;
  }

  List<Json> _rows(Object? r) => List<Json>.from(r as List);

  // ------------------------------------------------------------------ Akun
  String? get userEmail => _db.auth.currentUser?.email;

  Future<void> signOut() async {
    try {
      // Logout lokal menghapus sesi pada perangkat ini tanpa menunggu
      // permintaan revoke sesi global ke server.
      await _db.auth.signOut(scope: SignOutScope.local);
    } finally {
      _pid = null;
      _pidUser = null;
    }
  }

  // ---------------------------------------------------------------- Jadwal
  Future<List<Json>> polyclinics() async => _rows(await _db
      .from('polyclinics')
      .select(
          'id, code, name:full_name, full_name, description, icon_key, queue_prefix, '
          'color_primary, color_secondary')
      .eq('is_active', true)
      .order('sort_order'));

  Future<List<Json>> doctorColors() async => _rows(await _db
      .from('doctors')
      .select('id, specialization, color_primary, color_secondary'));

  /// RPC get_doctor_schedule: jadwal + sisa kuota + catatan perubahan.
  /// p_polyclinic_id boleh null untuk mengambil seluruh poli.
  Future<List<Json>> doctorSchedule(
    DateTime date, {
    String? polyclinicId,
  }) async =>
      _rows(await _db.rpc('get_doctor_schedule', params: {
        'p_date': ymd(date),
        'p_polyclinic_id': polyclinicId,
      }));

  /// Jadwal dokter untuk halaman Booking, difilter berdasarkan poli.
  /// Warna dokter menggunakan warna poli sebagai fallback.
  Future<List<Json>> bookingDoctors({
    required DateTime date,
    required String polyclinicId,
  }) async =>
      styledSchedule(date, polyclinicId: polyclinicId);

  /// Jadwal dokter pada [date] + `specialty`, `color_primary`,
  /// `color_secondary` (warna dokter, atau warna poli bila dokter belum
  /// punya warna sendiri). Dipakai Beranda & Booking.
  Future<List<Json>> styledSchedule(
    DateTime date, {
    String? polyclinicId,
  }) async {
    final res = await Future.wait<List<Json>>([
      doctorSchedule(date, polyclinicId: polyclinicId),
      doctorColors(),
      polyclinics(),
    ]);
    final docs = {for (final d in res[1]) d['id'] as String: d};
    final polis = {for (final p in res[2]) p['id'] as String: p};
    final out = <Json>[];
    for (final r in res[0]) {
      final d = docs[r['doctor_id']];
      final p = polis[r['polyclinic_id']];
      final ownColors =
          d?['color_primary'] != null && d?['color_secondary'] != null;
      final src = ownColors ? d : p;
      out.add({
        ...r,
        'specialization': r['specialization'] ?? d?['specialization'],
        'specialty': r['specialization'] ?? d?['specialization'],
        'color_primary': src?['color_primary'],
        'color_secondary': src?['color_secondary'],
      });
    }
    return out;
  }

  // ----------------------------------------------------------------- Resep
  Future<List<Json>> prescriptions() async {
    final pid = await patientId();
    return _rows(await _db
        .from('prescriptions')
        .select('id, code, status, issued_at, '
            'doctors(full_name), polyclinics(name), '
            'prescription_items(medicine_name, dosage, instructions, quantity, unit, sort_order)')
        .eq('patient_id', pid)
        .order('issued_at', ascending: false));
  }

  // --------------------------------------------------------------- Farmasi
  /// Pesanan farmasi untuk [rxCode], atau pesanan terbaru yang belum diambil.
  Future<Json?> pharmacyOrder({String? rxCode}) async {
    final pid = await patientId();
    final base = _db
        .from('pharmacy_orders')
        .select('id, queue_label, status, eta_minutes, '
            'prescriptions!inner(code, patient_id, '
            'prescription_items(medicine_name, quantity, unit, sort_order))')
        .eq('prescriptions.patient_id', pid);
    final filtered = rxCode != null
        ? base.eq('prescriptions.code', rxCode)
        : base.neq('status', 'picked_up');
    final rows =
        _rows(await filtered.order('received_at', ascending: false).limit(1));
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Json>> pharmacyHistory() async {
    final pid = await patientId();
    return _rows(await _db
        .from('pharmacy_orders')
        .select('id, picked_up_at, prescriptions!inner(code, patient_id)')
        .eq('prescriptions.patient_id', pid)
        .eq('status', 'picked_up')
        .order('picked_up_at', ascending: false)
        .limit(10));
  }

  // ------------------------------------------------------------ Rekam medis
  Future<Json> patientSummary() async {
    final pid = await patientId();
    return await _db
        .from('patients')
        .select(
            'medical_record_no, blood_type, height_cm, weight_kg, is_verified')
        .eq('id', pid)
        .single();
  }

  Future<List<String>> allergies() async {
    final pid = await patientId();
    final r = _rows(await _db
        .from('patient_allergies')
        .select('allergen')
        .eq('patient_id', pid)
        .order('created_at'));
    return [for (final a in r) a['allergen'] as String];
  }

  Future<List<Json>> medicalRecords() async {
    final pid = await patientId();
    return _rows(await _db
        .from('medical_records')
        .select('id, visit_date, complaint, diagnosis, action_taken, '
            'bp_systolic, bp_diastolic, temperature_c, pulse_bpm, '
            'weight_kg, height_cm, doctors(full_name), '
            'polyclinics(name, color_primary)')
        .eq('patient_id', pid)
        .order('visit_date', ascending: false)
        .order('created_at', ascending: false));
  }

  // ------------------------------------------------------------ Panduan awal
  Future<List<Json>> firstAidTopics() async => _rows(await _db
      .from('first_aid_topics')
      .select('id, title, icon_key, urgency, summary, warning_text, '
          'first_aid_steps(step_no, content)')
      .eq('is_published', true)
      .order('sort_order'));

  Future<List<Json>> emergencyNumbers() async => _rows(await _db
      .from('emergency_numbers')
      .select('label, phone_number')
      .eq('is_active', true)
      .order('sort_order'));

  // ------------------------------------------------------ Pengingat minum obat
  Future<List<Json>> reminders() async {
    final pid = await patientId();
    return _rows(await _db
        .from('medication_reminders')
        .select(
            'id, medicine_name, dose, usage_rule, remind_time, days_of_week, '
            'start_date, end_date, is_active')
        .eq('patient_id', pid)
        .order('remind_time'));
  }

  /// Apakah pengingat [j] berlaku pada [day] (hari dalam seminggu + rentang
  /// tanggal).
  static bool reminderAppliesOn(Json j, DateTime day) {
    final days = List<int>.from((j['days_of_week'] as List?) ?? const []);
    if (!days.contains(day.weekday)) return false;
    final d = ymd(day);
    if ((j['start_date'] as String).compareTo(d) > 0) return false;
    final end = j['end_date'] as String?;
    return end == null || end.compareTo(d) >= 0;
  }

  /// Pengingat yang berlaku hari ini (urut jam), tiap baris diberi
  /// `taken` = sudah ditandai diminum.
  Future<List<Json>> todayReminders() async {
    final today = wibToday();
    final rows =
        (await reminders()).where((r) => reminderAppliesOn(r, today)).toList();
    final taken = await takenReminderIds(
        today, [for (final r in rows) r['id'] as String]);
    return [
      for (final r in rows) {...r, 'taken': taken.contains(r['id'])},
    ];
  }

  /// id pengingat yang sudah ditandai diminum pada [day].
  Future<Set<String>> takenReminderIds(DateTime day, List<String> ids) async {
    if (ids.isEmpty) return {};
    final r = _rows(await _db
        .from('medication_intake_logs')
        .select('reminder_id')
        .eq('log_date', ymd(day))
        .inFilter('reminder_id', ids));
    return {for (final x in r) x['reminder_id'] as String};
  }

  Future<void> setMedicationTaken(String reminderId, bool taken) =>
      _db.rpc('set_medication_taken',
          params: {'p_reminder_id': reminderId, 'p_taken': taken});

  Future<void> setReminderActive(String id, bool active) => _db
      .from('medication_reminders')
      .update({'is_active': active}).eq('id', id);

  Future<void> deleteReminder(String id) =>
      _db.from('medication_reminders').delete().eq('id', id);

  Future<Json> addReminder({
    required String name,
    required String dose,
    required String rule,
    required String time, // 'HH:mm:ss'
  }) async {
    final pid = await patientId();
    return await _db
        .from('medication_reminders')
        .insert({
          'patient_id': pid,
          'medicine_name': name,
          'dose': dose,
          'usage_rule': rule,
          'remind_time': time,
        })
        .select()
        .single();
  }

  // ------------------------------------------------------- Booking & antrean
  /// Slot dari RPC get_available_slots.
  /// Baris: { slot_time: 'HH:mm:ss', is_available: bool }.
  Future<List<Json>> bookingSlots({
    required String doctorId,
    required DateTime date,
  }) async =>
      _rows(await _db.rpc('get_available_slots', params: {
        'p_doctor_id': doctorId,
        'p_date': ymd(date),
      }));

  /// Membuat booking melalui RPC book_appointment.
  /// Nomor antrean dan booking_code diisi trigger database.
  Future<Json> createAppointment({
    required String doctorId,
    required DateTime date,
    required String time, // 'HH:mm' atau 'HH:mm:ss'
    required bool bpjs,
    String complaint = '',
  }) async {
    final slot = time.length == 5 ? '$time:00' : time;
    final result = await _db.rpc('book_appointment', params: {
      'p_doctor_id': doctorId,
      'p_date': ymd(date),
      'p_slot': slot,
      'p_patient_type': bpjs ? 'bpjs' : 'umum',
      'p_complaint': complaint.trim().isEmpty ? null : complaint.trim(),
    });

    // RETURNS appointments biasanya dikirim PostgREST sebagai object.
    // Penanganan List disediakan agar tetap kompatibel bila respons berupa
    // satu baris dalam array.
    if (result is Map) return Map<String, dynamic>.from(result);
    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    throw StateError('Respons book_appointment tidak berisi data booking.');
  }

  static const _activeStatuses = [
    'booked',
    'checked_in',
    'in_exam',
    'pharmacy'
  ];

  /// Booking aktif milik pasien (hari ini atau yang akan datang), atau null.
  Future<Json?> activeAppointment() async {
    final pid = await patientId();
    final rows = _rows(await _db
        .from('appointments')
        .select('id, code:booking_code, status, appt_date:appointment_date, '
            'appt_time:slot_time, patient_type, complaint, queue_prefix, '
            'queue_number, queue_label, polyclinic_id, '
            'doctors(full_name), polyclinics(name, icon_key, color_primary, '
            'color_secondary)')
        .eq('patient_id', pid)
        .inFilter('status', _activeStatuses)
        .gte('appointment_date', ymd(wibToday()))
        .order('appointment_date')
        .order('slot_time')
        .limit(1));
    return rows.isEmpty ? null : rows.first;
  }

  /// Semua booking aktif pasien (hari ini atau yang akan datang), urut
  /// tanggal lalu jam. Dipakai kartu antrean di Beranda.
  Future<List<Json>> activeAppointments() async {
    final pid = await patientId();
    return _rows(await _db
        .from('appointments')
        .select('id, code:booking_code, status, appt_date:appointment_date, '
            'appt_time:slot_time, patient_type, complaint, queue_prefix, '
            'queue_number, queue_label, polyclinic_id, '
            'doctors(full_name), polyclinics(name, full_name, icon_key, color_primary, '
            'color_secondary)')
        .eq('patient_id', pid)
        .inFilter('status', _activeStatuses)
        .gte('appointment_date', ymd(wibToday()))
        .order('appointment_date')
        .order('slot_time'));
  }

  Future<void> checkInAppointment(String id) =>
      _db.rpc('check_in_appointment', params: {'p_id': id});

  Future<void> cancelAppointment(String id) =>
      _db.rpc('cancel_appointment', params: {'p_id': id});

  /// RPC get_queue_board: kondisi antrean tiap poli pada [date].
  /// Baris: polyclinic_id, name, queue_prefix, icon_key, color_primary,
  /// color_secondary, current_number, last_number, waiting, avg_minutes.
  Future<List<Json>> queueBoard(DateTime date) async =>
      _rows(await _db.rpc('get_queue_board', params: {'p_date': ymd(date)}));

  // ------------------------------------------------------------ Info klinik
  /// Nilai dari tabel clinic_settings (key/value), mis. 'open_hours'.
  Future<String?> clinicSetting(String key) async {
    final r = await _db
        .from('clinic_settings')
        .select('value')
        .eq('key', key)
        .maybeSingle();
    return r?['value'] as String?;
  }

  // ----------------------------------------------------------------- Profil
  /// Menggabungkan data akun, pasien, alergi, dan pengaturan.
  Future<Json> patientProfile() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('Belum masuk');
    final pid = await patientId();
    final results = await Future.wait<dynamic>([
      _db
          .from('profiles')
          .select('full_name, email, phone')
          .eq('id', uid)
          .single(),
      _db
          .from('patients')
          .select(
              'medical_record_no, nik, birth_date, gender, address, blood_type, '
              'chronic_conditions, height_cm, weight_kg, emergency_contact_name, '
              'emergency_contact_phone, bpjs_number, is_verified')
          .eq('id', pid)
          .single(),
      _db
          .from('patient_allergies')
          .select('allergen, note')
          .eq('patient_id', pid)
          .order('created_at'),
      _db
          .from('user_settings')
          .select('notify_queue, notify_medication, biometric_lock, language')
          .eq('user_id', uid)
          .maybeSingle(),
    ]);
    final profile = Map<String, dynamic>.from(results[0] as Map);
    final patient = Map<String, dynamic>.from(results[1] as Map);
    final allergies = List<Json>.from(
        (results[2] as List).map((e) => Map<String, dynamic>.from(e as Map)));
    final settings = results[3] == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(results[3] as Map);
    return {...profile, ...patient, ...settings, 'allergies': allergies};
  }

  /// Menyimpan data diri, informasi medis, alergi, dan preferensi akun.
  /// Pastikan migrasi SQL izin edit profil pasien di bawah sudah dijalankan.
  Future<void> updateMyProfile({required Json data}) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('Belum masuk');
    final pid = await patientId();

    await _db.from('profiles').update({
      'full_name': data['full_name'],
      'phone': data['phone'],
      'email': data['email'],
    }).eq('id', uid);

    await _db.from('patients').update({
      'nik': _nullIfEmpty(data['nik']),
      'birth_date': _nullIfEmpty(data['birth_date']),
      'gender': _nullIfEmpty(data['gender']),
      'address': _nullIfEmpty(data['address']),
      'blood_type': _nullIfEmpty(data['blood_type']),
      'chronic_conditions': _nullIfEmpty(data['chronic_conditions']),
      'height_cm': _numberOrNull(data['height_cm']),
      'weight_kg': _numberOrNull(data['weight_kg']),
      'emergency_contact_name': _nullIfEmpty(data['emergency_contact_name']),
      'emergency_contact_phone': _nullIfEmpty(data['emergency_contact_phone']),
      'bpjs_number': _nullIfEmpty(data['bpjs_number']),
    }).eq('id', pid);

    final settings = <String, dynamic>{
      'user_id': uid,
      'notify_queue': data['notify_queue'] ?? true,
      'notify_medication': data['notify_medication'] ?? true,
      'biometric_lock': data['biometric_lock'] ?? false,
      'language': data['language'] ?? 'id',
    };
    await _db.from('user_settings').upsert(settings, onConflict: 'user_id');

    await _db.from('patient_allergies').delete().eq('patient_id', pid);
    final allergyRows = (data['allergies'] as List? ?? const [])
        .where((e) =>
            e is Map && (e['allergen'] ?? '').toString().trim().isNotEmpty)
        .map((e) => {
              'patient_id': pid,
              'allergen': (e['allergen'] as String).trim(),
              'note': _nullIfEmpty(e['note']),
            })
        .toList();
    if (allergyRows.isNotEmpty) {
      await _db.from('patient_allergies').insert(allergyRows);
    }
  }

  String? _nullIfEmpty(dynamic value) {
    final s = value?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  num? _numberOrNull(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    return num.tryParse(value.toString().replaceAll(',', '.'));
  }

  Future<void> updateMySettings(
      {bool? notifQueue, bool? notifMedication, bool? biometricLock}) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw StateError('Belum masuk');
    final values = <String, dynamic>{};
    if (notifQueue != null) values['notify_queue'] = notifQueue;
    if (notifMedication != null) values['notify_medication'] = notifMedication;
    if (biometricLock != null) values['biometric_lock'] = biometricLock;
    if (values.isNotEmpty) {
      await _db.from('user_settings').update(values).eq('user_id', uid);
    }
  }

  /// Statistik profil: kunjungan, resep aktif, dan booking belum selesai.
  Future<({int visits, int activeRx, int activeBookings})>
      profileStats() async {
    final pid = await patientId();
    final today = ymd(wibToday());
    final results = await Future.wait<List<Json>>([
      _db.from('medical_records').select('id').eq('patient_id', pid),
      _db
          .from('prescriptions')
          .select('id')
          .eq('patient_id', pid)
          .eq('status', 'active'),
      _db
          .from('appointments')
          .select('id')
          .eq('patient_id', pid)
          .inFilter('status', _activeStatuses)
          .gte('appointment_date', today),
    ]);
    return (
      visits: results[0].length,
      activeRx: results[1].length,
      activeBookings: results[2].length
    );
  }

  // --------------------------------------------------------------- Realtime
  /// Dengarkan perubahan tabel; kembalikan channel agar bisa di-remove.
  RealtimeChannel listen(String name, String table, void Function() onChange) {
    return _db
        .channel(name)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<void> unlisten(RealtimeChannel ch) => _db.removeChannel(ch);
}
