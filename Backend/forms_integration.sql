-- Linen tax forms integration, migration 003
-- Provider: TaxBandits (developer.taxbandits.com).
-- TaxBandits collects the W-9 through its drop in UI or secure URL, runs
-- instant TIN matching, records payouts through its transaction API, and
-- generates and files 1099 NEC forms federally and with the states.
-- Linen stores statuses and references only.
-- First wired to Abound on 2026-11-24 and corrected the same day when
-- Abound proved to be retired after a November 2024 acquisition.
-- Run after contractor_onboarding.sql.

alter table contractor_tax_profiles
  add column if not exists forms_provider text not null default 'taxbandits',
  add column if not exists provider_payee_id text,
  add column if not exists w9_status text not null default 'not_started'
    check (w9_status in ('not_started', 'invited', 'submitted', 'verified', 'failed')),
  add column if not exists tin_match_status text not null default 'not_run'
    check (tin_match_status in ('not_run', 'matched', 'mismatch', 'error'));

create table if not exists contractor_filings (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  tax_year int not null,
  form_type text not null default '1099-NEC',
  total_paid_cents int not null default 0,
  status text not null default 'draft'
    check (status in ('draft', 'submitted', 'accepted', 'rejected', 'corrected', 'voided')),
  provider_ref text,
  filed_at timestamptz,
  unique (profile_id, tax_year, form_type)
);

alter table contractor_filings enable row level security;
create policy "own filings read" on contractor_filings for select using (auth.uid() = profile_id);

-- Filing rule: a 1099 NEC is due for a contractor paid at or over the IRS
-- threshold for the tax year, 600 dollars through 2025 and 2,000 dollars
-- for payments made in 2026 and later. The January filing job reads payout
-- totals, creates one filing row per contractor over the threshold, and
-- submits through the provider. Recipient copies are delivered by the
-- provider, electronically or by mail.
