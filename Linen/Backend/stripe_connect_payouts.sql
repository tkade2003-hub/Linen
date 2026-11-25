-- Linen Stripe Connect payouts, migration 008
-- Cleaner payout accounts live in their own table because public.specialists
-- is world readable. Only the owner can read their row. Only the service
-- role, used by the Connect edge functions, writes.

create table if not exists specialist_payouts (
  profile_id text primary key references profiles(id) on delete cascade,
  stripe_account_id text unique,
  charges_enabled boolean not null default false,
  payouts_enabled boolean not null default false,
  details_submitted boolean not null default false,
  onboarding_status text not null default 'not_started'
    check (onboarding_status in ('not_started', 'in_progress', 'complete', 'restricted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table specialist_payouts enable row level security;

create policy "Pros read own payout row" on specialist_payouts
  for select using (user_id() = profile_id);

-- One row per payout to a cleaner. amount_cents is the pro base pay for the
-- booking, tip_cents rides on top at 100 percent, so the transfer total is
-- amount_cents + tip_cents.
create table if not exists connect_transfers (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references bookings(id) on delete set null,
  profile_id text not null references profiles(id) on delete cascade,
  stripe_transfer_id text unique,
  amount_cents integer not null,
  tip_cents integer not null default 0,
  status text not null default 'pending'
    check (status in ('pending', 'paid', 'failed')),
  failure_code text,
  created_at timestamptz not null default now()
);

alter table connect_transfers enable row level security;

create policy "Pros read own transfers" on connect_transfers
  for select using (user_id() = profile_id);
