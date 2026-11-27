create table if not exists public.pro_applications (
  profile_id text primary key references public.profiles(id) on delete cascade,
  full_name text not null,
  phone text not null,
  service_area text not null,
  travel_radius_miles integer not null default 10,
  specialty text not null default 'All cleaning types',
  experience_years integer not null default 0,
  bio text,
  has_supplies boolean not null default false,
  background_consent boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.pro_applications enable row level security;
drop policy if exists "Own application" on public.pro_applications;
create policy "Own application" on public.pro_applications
  for all using (user_id() = profile_id) with check (user_id() = profile_id);
