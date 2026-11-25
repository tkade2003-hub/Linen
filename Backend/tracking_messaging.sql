-- Linen tracking, messaging, and availability support, migration 004
-- Adds the bookings table that tracking and messaging hang off, the live
-- location stream table, the messages table, and relies on the stage 1
-- availability table for weekly availability editing.
-- Run after schema.sql.

create table if not exists bookings (
  id uuid primary key default gen_random_uuid(),
  visit_number text,
  homeowner_id uuid not null references profiles(id) on delete cascade,
  specialist_id uuid references specialists(profile_id),
  service_id uuid references services(id),
  status text not null default 'searching'
    check (status in ('searching', 'confirmed', 'en_route', 'in_progress', 'completed', 'cancelled')),
  scheduled_start timestamptz not null,
  duration_minutes int not null,
  total_cents int not null,
  pro_pay_cents int,
  address text not null,
  created_at timestamptz not null default now()
);

create table if not exists job_locations (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references bookings(id) on delete cascade,
  specialist_id uuid not null references specialists(profile_id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  recorded_at timestamptz not null default now()
);

create index if not exists job_locations_booking_time on job_locations (booking_id, recorded_at desc);

create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references bookings(id) on delete cascade,
  homeowner_id uuid not null references profiles(id) on delete cascade,
  specialist_id uuid not null references specialists(profile_id) on delete cascade,
  sender_id uuid not null references profiles(id),
  body text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index if not exists messages_thread_time on messages (homeowner_id, specialist_id, created_at);

alter table bookings enable row level security;
alter table job_locations enable row level security;
alter table messages enable row level security;

create policy "booking parties read" on bookings for select
  using (auth.uid() = homeowner_id or auth.uid() = specialist_id);
create policy "homeowner creates booking" on bookings for insert
  with check (auth.uid() = homeowner_id);
create policy "booking parties update" on bookings for update
  using (auth.uid() = homeowner_id or auth.uid() = specialist_id);

create policy "specialist writes location" on job_locations for insert
  with check (auth.uid() = specialist_id);
create policy "booking parties read location" on job_locations for select
  using (exists (select 1 from bookings b where b.id = booking_id
    and (b.homeowner_id = auth.uid() or b.specialist_id = auth.uid())));

create policy "thread parties read messages" on messages for select
  using (auth.uid() = homeowner_id or auth.uid() = specialist_id);
create policy "thread parties send messages" on messages for insert
  with check (auth.uid() = sender_id and (auth.uid() = homeowner_id or auth.uid() = specialist_id));

-- Live tracking runs on Supabase Realtime: the pro app inserts a
-- job_locations row every few seconds while en route and the homeowner
-- app subscribes to the booking row. Enable replication for job_locations
-- and bookings in the Supabase dashboard when wiring the live clients.
