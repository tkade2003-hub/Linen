-- Migration 006: stream booking status changes over Realtime.
-- Applied 2026-11-24 to Vashon's Supabase project (ref vftlwlnbfqqqxfdscato)
-- so the homeowner tracking screen follows the status ladder live
-- (searching, confirmed, en route, in progress, completed) as the pro
-- updates the booking, alongside the job_locations stream from migration 005.

alter publication supabase_realtime add table public.bookings;
