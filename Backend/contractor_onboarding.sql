-- Linen contractor onboarding, migration 002
-- Specialists work as independent contractors and are paid as 1099 contractors.
-- Run after schema.sql.

create table if not exists contractor_onboarding (
  profile_id uuid primary key references profiles(id) on delete cascade,
  step_contractor_status boolean not null default false,
  step_tax_details boolean not null default false,
  step_w9 boolean not null default false,
  step_agreement boolean not null default false,
  step_payout boolean not null default false,
  step_background_check boolean not null default false,
  submitted_at timestamptz,
  updated_at timestamptz not null default now()
);

-- Tax profile. The full tax ID is never stored in Linen.
-- It is collected by the contractor payment provider during payout setup.
-- Linen keeps only the last 4 digits and the provider reference.
create table if not exists contractor_tax_profiles (
  profile_id uuid primary key references profiles(id) on delete cascade,
  legal_name text not null,
  business_name text,
  tax_classification text not null check (tax_classification in ('individual', 'llc', 'corporation', 'partnership')),
  mailing_address text not null,
  tin_last4 text not null check (char_length(tin_last4) = 4),
  exempt_from_backup_withholding boolean not null default false,
  w9_signed_name text not null,
  w9_signed_at timestamptz not null,
  provider_ref text,
  updated_at timestamptz not null default now()
);

create table if not exists contractor_agreements (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  agreement_version text not null,
  accepted_at timestamptz not null default now(),
  background_check_consent_at timestamptz
);

alter table contractor_onboarding enable row level security;
alter table contractor_tax_profiles enable row level security;
alter table contractor_agreements enable row level security;

create policy "own onboarding" on contractor_onboarding for all using (auth.uid() = profile_id);
create policy "own tax profile" on contractor_tax_profiles for all using (auth.uid() = profile_id);
create policy "own agreements" on contractor_agreements for all using (auth.uid() = profile_id);

-- Year end: 1099 NEC forms are issued from the payment provider records
-- joined to contractor_tax_profiles on provider_ref. Linen stores no full
-- tax IDs, so a Linen database copy can never leak one.
