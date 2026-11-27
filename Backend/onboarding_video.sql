-- Migration 010: required cleaner onboarding video.
-- A verified pro must watch the full onboarding video once before the Pro
-- workspace opens. The app sets this to true only when the video plays to
-- the end; there is no partial progress, so leaving mid video and coming
-- back starts the video over.
alter table public.profiles
  add column if not exists onboarding_video_completed boolean not null default false;
