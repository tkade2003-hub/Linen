-- Migration 005: live GPS tracking and in app messaging tables.
-- Applied 2026-11-24 to Vashon's own Supabase project (ref vftlwlnbfqqqxfdscato,
-- transferred from Rork) after the base schema Rork generated was verified live.
-- Policy style mirrors the existing tables: user_id() reads the signed in user
-- from the request JWT, and access is limited to the two parties on a booking.

create table if not exists public.job_locations (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  specialist_id text not null,
  latitude double precision not null,
  longitude double precision not null,
  heading double precision,
  speed_mps double precision,
  recorded_at timestamptz not null default now()
);

create index if not exists job_locations_booking_time_idx
  on public.job_locations (booking_id, recorded_at desc);

alter table public.job_locations enable row level security;

create policy "Specialists publish own locations"
  on public.job_locations for insert
  with check (
    user_id() = specialist_id
    and exists (
      select 1 from public.bookings b
      where b.id = booking_id and b.specialist_id = user_id()
    )
  );

create policy "Booking parties read locations"
  on public.job_locations for select
  using (
    exists (
      select 1 from public.bookings b
      where b.id = booking_id
        and (b.homeowner_id = user_id() or b.specialist_id = user_id())
    )
  );

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  sender_id text not null,
  body text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index if not exists messages_booking_time_idx
  on public.messages (booking_id, created_at);

alter table public.messages enable row level security;

create policy "Booking parties read messages"
  on public.messages for select
  using (
    exists (
      select 1 from public.bookings b
      where b.id = booking_id
        and (b.homeowner_id = user_id() or b.specialist_id = user_id())
    )
  );

create policy "Booking parties send messages"
  on public.messages for insert
  with check (
    sender_id = user_id()
    and exists (
      select 1 from public.bookings b
      where b.id = booking_id
        and (b.homeowner_id = user_id() or b.specialist_id = user_id())
    )
  );

alter publication supabase_realtime add table public.job_locations;
alter publication supabase_realtime add table public.messages;
