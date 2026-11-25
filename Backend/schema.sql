-- Linen backend schema, Supabase (Postgres)
-- Stage 1: identity, roles, homes, catalog. Bookings arrive in stage 2.

create extension if not exists "pgcrypto";

create table if not exists profiles (
  id uuid primary key,
  name text not null,
  email text not null unique,
  phone text,
  photo_url text,
  pro_status text not null default 'none' check (pro_status in ('none', 'pending', 'verified')),
  created_at timestamptz not null default now()
);

create table if not exists homes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  label text not null,
  address text not null,
  beds int not null default 1,
  baths int not null default 1,
  entry_notes text,
  care_preferences text,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists specialists (
  profile_id uuid primary key references profiles(id) on delete cascade,
  bio text,
  rating_avg numeric(3,2) not null default 0,
  cleans_count int not null default 0,
  on_time_pct int not null default 100,
  background_checked boolean not null default false,
  insured boolean not null default false,
  service_radius_miles numeric(4,1) not null default 6,
  service_center_label text,
  payout_account_ref text,
  eco_kit_restock_date date
);

create table if not exists availability (
  id uuid primary key default gen_random_uuid(),
  specialist_id uuid not null references specialists(profile_id) on delete cascade,
  weekday int not null check (weekday between 0 and 6),
  open_start time not null,
  open_end time not null,
  auto_accept_repeats boolean not null default false
);

create table if not exists services (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  client_price_cents int not null,
  base_minutes int not null,
  blurb text not null
);

create table if not exists add_ons (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  price_cents int not null
);

insert into services (name, client_price_cents, base_minutes, blurb) values
  ('Standard Tidy', 11800, 120, 'Surface dusting, vacuuming, mopping, and kitchen and bath refresh.'),
  ('Signature Clean', 14800, 150, 'Full home clean with crisp linen bed making, mirrors, and baseboards.'),
  ('Deep Seasonal Reset', 21500, 240, 'Inside cabinets, tile grout detailing, window sills, and fixture descaling.')
on conflict do nothing;

insert into add_ons (name, price_cents) values
  ('Inside fridge', 2500),
  ('Interior oven', 3000),
  ('Laundry and fold', 2000)
on conflict do nothing;

-- Pricing constants used by the configurator, mirrored in the app.
-- Bedroom: 2200 cents each. Bathroom: 2800 cents each.
-- Tier uplift over Standard Tidy: Signature 3000, Deep Seasonal Reset 8500.
-- Recurring saving: 15 percent. Same day urgent surge for the pro: plus 15 percent.

alter table profiles enable row level security;
alter table homes enable row level security;
alter table specialists enable row level security;
alter table availability enable row level security;
alter table services enable row level security;
alter table add_ons enable row level security;

create policy "own profile read" on profiles for select using (auth.uid() = id);
create policy "own profile update" on profiles for update using (auth.uid() = id);
create policy "own homes" on homes for all using (auth.uid() = owner_id);
create policy "own specialist row" on specialists for all using (auth.uid() = profile_id);
create policy "own availability" on availability for all using (auth.uid() = specialist_id);
create policy "catalog read" on services for select using (true);
create policy "catalog read addons" on add_ons for select using (true);
