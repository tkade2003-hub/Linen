-- Migration 007: profile photo storage and concierge support messages.
-- Applied 2026-11-25 to Vashon's own Supabase project (ref vftlwlnbfqqqxfdscato).
-- The avatars bucket is public read so the app can show profile photos by URL;
-- each member can only write inside the folder named with their own user id,
-- using the same user_id() helper the table policies use.
-- support_messages backs the in app Concierge help thread: a member reads and
-- writes only their own thread, and can only send as the member. Concierge
-- replies are written by the team with the service role.

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy "Avatar images are publicly readable"
  on storage.objects for select
  using (bucket_id = 'avatars');

create policy "Members upload their own avatar"
  on storage.objects for insert
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = user_id());

create policy "Members replace their own avatar"
  on storage.objects for update
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = user_id())
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = user_id());

create policy "Members delete their own avatar"
  on storage.objects for delete
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = user_id());

create table if not exists public.support_messages (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  sender text not null check (sender in ('member', 'concierge')),
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists support_messages_user_time_idx
  on public.support_messages (user_id, created_at);

alter table public.support_messages enable row level security;

create policy "Members read own support messages"
  on public.support_messages for select
  using (user_id = user_id());

create policy "Members send support messages"
  on public.support_messages for insert
  with check (user_id = user_id() and sender = 'member');
