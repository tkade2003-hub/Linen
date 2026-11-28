-- Migration 012: one time handoff codes between the Linen app and the
-- payout setup web page. The app asks connect-handoff for a code while
-- signed in, then opens the page with that code. The page trades the code
-- once for a page token (stored here as a SHA 256 hash) that can mint fresh
-- Stripe Account Session secrets for thirty minutes. Service role only:
-- row level security is on with no client policies, so the app and the page
-- can only reach this table through the edge functions.
create table if not exists public.connect_handoffs (
    code text primary key,
    profile_id text not null,
    page_token_hash text,
    expires_at timestamptz not null,
    created_at timestamptz not null default now()
);

alter table public.connect_handoffs enable row level security;
