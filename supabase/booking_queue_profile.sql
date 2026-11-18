-- =============================================================================
-- Arogya: booking, antrean, profil, info klinik
-- Jalankan di Supabase SQL Editor. SESUAIKAN bagian bertanda [SESUAIKAN]
-- dengan skema yang sudah ada di project Anda.
-- =============================================================================

-- ---------------------------------------------------------------- Kolom baru
alter table polyclinics
  add column if not exists short_name   text,   -- label di tile booking ("Poli Gigi")
  add column if not exists subtitle     text,   -- "Gigi & mulut"
  add column if not exists icon_key     text,   -- general|dental|child|internal|eye|obgyn
  add column if not exists queue_prefix text;   -- A, B, C ...

alter table doctors
  add column if not exists specialty text;      -- "Dokter Umum", "Spesialis Anak"

alter table patients
  add column if not exists full_name               text,
  add column if not exists nik                     text,
  add column if not exists birth_date              date,
  add column if not exists gender                  text check (gender in ('L','P')),
  add column if not exists phone                   text,
  add column if not exists email                   text,
  add column if not exists address                 text,
  add column if not exists chronic_conditions      text,
  add column if not exists emergency_contact_name  text,
  add column if not exists emergency_contact_phone text,
  add column if not exists bpjs_number             text,
  add column if not exists notif_queue             boolean not null default true,
  add column if not exists notif_medication        boolean not null default true;

-- Contoh pengisian poli (sesuaikan nama/ID dengan data Anda):
-- update polyclinics set queue_prefix='A', icon_key='general',  short_name='Poli Umum',        subtitle='Keluhan umum'    where name='Poli Umum';
-- update polyclinics set queue_prefix='B', icon_key='dental',   short_name='Poli Gigi',        subtitle='Gigi & mulut'    where name='Poli Gigi & Mulut';
-- update polyclinics set queue_prefix='C', icon_key='child',    short_name='Poli Anak',        subtitle='Bayi & anak'     where name='Poli Anak';
-- update polyclinics set queue_prefix='D', icon_key='internal', short_name='Poli Peny. Dalam', subtitle='Organ dalam'     where name='Poli Penyakit Dalam';
-- update polyclinics set queue_prefix='E', icon_key='eye',      short_name='Poli Mata',        subtitle='Kesehatan mata'  where name='Poli Mata';
-- update polyclinics set queue_prefix='F', icon_key='obgyn',    short_name='Poli Kandungan',   subtitle='Ibu & kehamilan' where name='Poli Kandungan';

-- --------------------------------------------------------------- Info klinik
create table if not exists clinic_settings (
  key   text primary key,
  value text not null
);
insert into clinic_settings(key, value) values ('open_hours', '07:00 - 21:00')
  on conflict (key) do nothing;

alter table clinic_settings enable row level security;
drop policy if exists clinic_settings_read on clinic_settings;
create policy clinic_settings_read on clinic_settings
  for select to authenticated using (true);

-- ----------------------------------------------------------------- Booking
create table if not exists appointments (
  id            uuid primary key default gen_random_uuid(),
  code          text not null unique,
  patient_id    uuid not null references patients(id),
  doctor_id     uuid not null references doctors(id),
  polyclinic_id uuid not null references polyclinics(id),
  appt_date     date not null,
  appt_time     time not null,
  patient_type  text not null default 'umum' check (patient_type in ('umum','bpjs')),
  complaint     text,
  status        text not null default 'booked'
                check (status in ('booked','checked_in','in_exam','pharmacy','done','cancelled')),
  queue_prefix  text not null,
  queue_number  int  not null,
  checked_in_at timestamptz,
  created_at    timestamptz not null default now()
);

-- Satu jam praktik hanya untuk satu pasien; nomor antrean unik per poli/hari.
create unique index if not exists appointments_slot_uq
  on appointments(doctor_id, appt_date, appt_time) where status <> 'cancelled';
create unique index if not exists appointments_queue_uq
  on appointments(polyclinic_id, appt_date, queue_number);
create index if not exists appointments_patient_idx
  on appointments(patient_id, appt_date);

-- Nomor yang sedang dilayani per poli/hari (diisi staf/loket).
create table if not exists queue_state (
  polyclinic_id  uuid not null references polyclinics(id),
  queue_date     date not null,
  current_number int  not null default 0,
  avg_minutes    int  not null default 5,   -- rata-rata menit per pasien
  primary key (polyclinic_id, queue_date)
);

alter table appointments enable row level security;
alter table queue_state  enable row level security;

drop policy if exists appointments_own_read on appointments;
create policy appointments_own_read on appointments
  for select to authenticated
  using (patient_id in (select id from patients where user_id = auth.uid()));
-- Tulis hanya lewat fungsi security definer di bawah (tidak ada policy insert/update).

drop policy if exists queue_state_read on queue_state;
create policy queue_state_read on queue_state
  for select to authenticated using (true);
-- Update queue_state/status appointment oleh staf: tambahkan policy untuk role staf Anda.

-- ------------------------------------------------------------ Slot booking
-- [SESUAIKAN] tabel jadwal praktik. Di sini diasumsikan:
--   doctor_schedules(doctor_id, polyclinic_id, day_of_week 1=Senin..7=Minggu,
--                    start_time, end_time, quota, is_active)
-- Gunakan tabel/kolom yang sama dengan yang dipakai get_doctor_schedule.
create or replace function get_booking_slots(
  p_doctor_id uuid, p_polyclinic_id uuid, p_date date)
returns table(slot_time time, available boolean)
language sql stable security definer set search_path = public as $$
  with sess as (
    select ds.start_time, ds.end_time
    from doctor_schedules ds
    where ds.doctor_id = p_doctor_id
      and ds.polyclinic_id = p_polyclinic_id
      and ds.day_of_week = extract(isodow from p_date)::int
      and ds.is_active
  ),
  slots as (
    select generate_series(p_date + s.start_time,
                           p_date + s.end_time - interval '30 minutes',
                           interval '30 minutes')::time as t
    from sess s
  )
  select sl.t,
         not (
           exists (select 1 from appointments a
                   where a.doctor_id = p_doctor_id and a.appt_date = p_date
                     and a.appt_time = sl.t and a.status <> 'cancelled')
           or (p_date = (now() at time zone 'Asia/Jakarta')::date
               and sl.t <= (now() at time zone 'Asia/Jakarta')::time)
         )
  from slots sl
  order by sl.t;
$$;

-- --------------------------------------------------------- Buat booking
create or replace function create_appointment(
  p_doctor_id uuid, p_polyclinic_id uuid, p_date date, p_time time,
  p_patient_type text, p_complaint text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_pid    uuid;
  v_prefix text;
  v_next   int;
  v_quota  int;
  v_used   int;
  v_id     uuid;
  v_code   text;
  v_today  date := (now() at time zone 'Asia/Jakarta')::date;
begin
  select id into v_pid from patients where user_id = auth.uid();
  if v_pid is null then raise exception 'Data pasien tidak ditemukan'; end if;

  select queue_prefix into v_prefix
  from polyclinics where id = p_polyclinic_id and is_active;
  if v_prefix is null then raise exception 'Poliklinik tidak tersedia'; end if;

  if p_date < v_today then raise exception 'Tanggal sudah lewat'; end if;

  -- Satu booking aktif per pasien (aplikasi menampilkan satu tiket).
  if exists (select 1 from appointments
             where patient_id = v_pid and appt_date >= v_today
               and status in ('booked','checked_in','in_exam','pharmacy')) then
    raise exception 'Anda masih memiliki booking aktif';
  end if;

  -- Serialkan pembuatan nomor antrean per poli & tanggal.
  perform pg_advisory_xact_lock(hashtext(p_polyclinic_id::text || p_date::text));

  if not exists (select 1 from get_booking_slots(p_doctor_id, p_polyclinic_id, p_date) s
                 where s.slot_time = p_time and s.available) then
    raise exception 'Jam tersebut sudah tidak tersedia';
  end if;

  -- [SESUAIKAN] kuota harian dokter dari tabel jadwal.
  select coalesce(sum(quota), 0) into v_quota
  from doctor_schedules
  where doctor_id = p_doctor_id and polyclinic_id = p_polyclinic_id
    and day_of_week = extract(isodow from p_date)::int and is_active;
  select count(*) into v_used from appointments
  where doctor_id = p_doctor_id and appt_date = p_date and status <> 'cancelled';
  if v_used >= v_quota then raise exception 'Kuota dokter penuh'; end if;

  select greatest(
           coalesce((select max(queue_number) from appointments
                     where polyclinic_id = p_polyclinic_id and appt_date = p_date), 0),
           coalesce((select current_number from queue_state
                     where polyclinic_id = p_polyclinic_id and queue_date = p_date), 0)
         ) + 1 into v_next;

  v_code := 'BK' || to_char(now() at time zone 'Asia/Jakarta', 'YYMMDD')
            || lpad((floor(random() * 10000))::int::text, 4, '0');

  insert into appointments(code, patient_id, doctor_id, polyclinic_id, appt_date,
                           appt_time, patient_type, complaint, queue_prefix, queue_number)
  values (v_code, v_pid, p_doctor_id, p_polyclinic_id, p_date, p_time,
          case when p_patient_type = 'bpjs' then 'bpjs' else 'umum' end,
          nullif(trim(coalesce(p_complaint, '')), ''), v_prefix, v_next)
  returning id into v_id;

  return jsonb_build_object(
    'id', v_id, 'code', v_code, 'queue_prefix', v_prefix,
    'queue_number', v_next, 'appt_date', p_date, 'appt_time', p_time);
end $$;

-- ------------------------------------------------- Check-in & pembatalan
create or replace function check_in_appointment(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update appointments a
     set status = 'checked_in', checked_in_at = now()
   where a.id = p_id and a.status = 'booked'
     and a.appt_date = (now() at time zone 'Asia/Jakarta')::date
     and a.patient_id in (select id from patients where user_id = auth.uid());
  if not found then
    raise exception 'Check-in hanya bisa dilakukan pada hari kunjungan';
  end if;
end $$;

create or replace function cancel_appointment(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update appointments a set status = 'cancelled'
   where a.id = p_id and a.status in ('booked','checked_in')
     and a.patient_id in (select id from patients where user_id = auth.uid());
  if not found then
    raise exception 'Booking tidak dapat dibatalkan';
  end if;
end $$;

-- ------------------------------------------------------------ Papan antrean
create or replace function get_queue_board(p_date date)
returns table(polyclinic_id uuid, name text, queue_prefix text, icon_key text,
              color_primary text, color_secondary text,
              current_number int, last_number int, waiting int, avg_minutes int)
language sql stable security definer set search_path = public as $$
  select p.id, p.name, p.queue_prefix, p.icon_key, p.color_primary, p.color_secondary,
         coalesce(q.current_number, 0),
         coalesce((select max(a.queue_number) from appointments a
                   where a.polyclinic_id = p.id and a.appt_date = p_date
                     and a.status <> 'cancelled'), 0),
         (select count(*)::int from appointments a
           where a.polyclinic_id = p.id and a.appt_date = p_date
             and a.status in ('booked','checked_in')
             and a.queue_number > coalesce(q.current_number, 0)),
         coalesce(q.avg_minutes, 5)
  from polyclinics p
  left join queue_state q on q.polyclinic_id = p.id and q.queue_date = p_date
  where p.is_active
  order by p.sort_order;
$$;

-- ------------------------------------------------------------------- Profil
create or replace function update_my_profile(
  p_name text, p_phone text, p_email text, p_address text)
returns void language plpgsql security definer set search_path = public as $$
begin
  update patients
     set full_name = trim(p_name), phone = trim(p_phone),
         email = trim(p_email), address = trim(p_address)
   where user_id = auth.uid();
  if not found then raise exception 'Data pasien tidak ditemukan'; end if;
end $$;

create or replace function update_my_settings(
  p_notif_queue boolean default null, p_notif_medication boolean default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  update patients
     set notif_queue      = coalesce(p_notif_queue, notif_queue),
         notif_medication = coalesce(p_notif_medication, notif_medication)
   where user_id = auth.uid();
end $$;

grant execute on function get_booking_slots(uuid, uuid, date)            to authenticated;
grant execute on function create_appointment(uuid, uuid, date, time, text, text) to authenticated;
grant execute on function check_in_appointment(uuid)                     to authenticated;
grant execute on function cancel_appointment(uuid)                       to authenticated;
grant execute on function get_queue_board(date)                          to authenticated;
grant execute on function update_my_profile(text, text, text, text)      to authenticated;
grant execute on function update_my_settings(boolean, boolean)           to authenticated;

-- ----------------------------------------------------------------- Realtime
alter publication supabase_realtime add table appointments;
alter publication supabase_realtime add table queue_state;