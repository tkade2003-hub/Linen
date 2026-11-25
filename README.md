# Linen app, stage 1 scaffold

Built from the build spec at ~/workspace/linen-app/linen-build-spec.md.

## What is here

* Backend/schema.sql: Supabase schema for stage 1. Profiles with a pro status gate, homes, specialists, availability, and the service and add on catalog seeded with the launch prices from the supplied screens. Row level security is on for every table.
* App/LinenApp.swift: app entry and the root switch. Signed out goes to onboarding. Pro workspace stays behind the verification gate.
* App/OnboardingView.swift: the two path sign in (Homeowner and Specialist Pro) from the supplied onboarding screen, plus the pro gate screen shown while verification is pending.
* App/WorkspaceMenuView.swift: the app menu with the workspace switcher from the supplied switcher screen.
* App/HomeownerShellView.swift: homeowner tabs (Home, Book, Bookings, Account). Quick book carries the real tiers, prices, and specialists from the supplied screens. The configurator computes the total live from beds, baths, and tier.
* App/ProShellView.swift: pro tabs (Jobs, Schedule, Earnings, Profile) carrying the supplied pro screen data: projected pay, up next job, new requests, earnings split of base pay and tips, and the verified pro profile.
* App/Models.swift and App/AppStore.swift: shared models, pricing constants, and app state.

## Stage 1 demo behavior

Sign in with any email. Choosing Specialist Pro lands in the Pro workspace as a verified pro so the shell can be walked end to end. Choosing Homeowner lands in the homeowner workspace, and the menu switcher can flip to Pro, which is where the gate belongs in production: pending pros see ProGateView instead. Sample names and figures come straight from the supplied screens.

## Contractor onboarding (1099)

Specialists are independent contractors. App/ContractorOnboarding.swift adds the six step flow behind the Pro gate: contractor status acknowledgment, legal and tax details, Form W-9 with typed signature certification, contractor agreement acceptance, payout setup, and background check consent. The Pro gate screen is now the onboarding checklist, and finishing all six steps enables Submit for review, which moves the pro to pending. The Simulate approval button on the pending screen is a stage demo affordance and must be removed before launch.

Backend/contractor_onboarding.sql is migration 002: step state, the tax profile, and agreement records, all with row level security. Security rule: the full tax ID is collected by the tax forms provider only. Linen stores the last 4 digits and the provider reference, never the full number, so a database copy can never leak one.

## Tax forms integration

Researched 2026-11-24 for the obtain the forms and file them properly requirement.

* FreshBooks does not fit. It is bookkeeping software a business runs itself. It has no embeddable W-9 collection or 1099 filing API for a third party app, and its contractor pay runs through its own payroll product. Notably, Tax1099 lists FreshBooks as one of its import integrations, which shows where the filing layer actually sits.
* Tax1099 fits a back office workflow. Self serve, pay per form at 2.99 dollars for the first 20 forms down to 0.72 at volume, W-9 requests at 1 dollar each, real time TIN match at 1 dollar, e delivery at 0.50. Its API exists only on the Scale plan at 349 dollars a year, and its W-9 flow is email requests rather than an in app embedded form.
* Abound looked like the fit and was wired first, then ruled out the same day. It was a tax compliance API for platforms, but it was acquired in November 2024 and the service has been retired: its website no longer resolves, its API and docs hosts are gone, and its GitHub organization was removed. Directory and review pages still describe it as live, which is how it passed the first check. The correction is recorded here so the mistake is not repeated.
* TaxBandits is the provider. It is an IRS authorized e-file service with a real developer program at developer.taxbandits.com: a free developer account and sandbox, W-9 collection through a drop in UI, secure URL, email, or text, instant TIN matching, a transaction API that records contractor payouts through the year, 1099 NEC generation and federal and state e filing, corrections, and recipient copies by secure portal or postal mail. Filing charges draw from prepaid credits in the account. Its gig software flow matches Linen onboarding directly: request the W-9 during onboarding, record payouts, file and distribute in January.

The build is wired to the TaxBandits pattern. App/FormsService.swift is the provider boundary with the calls the app needs, currently a stub that simulates the round trip. Backend/forms_integration.sql is migration 003: W-9 and TIN match status on the tax profile, the provider payee reference, and a contractor_filings table keyed by contractor and tax year. The W-9 step in onboarding opens the provider flow instead of a hand built form. Filing rule recorded in the migration: a 1099 NEC is due at or over 600 dollars paid through 2025, and at or over 2,000 dollars for payments made in 2026 and later, filed each January for the prior year.

Still needed to go live: a free TaxBandits developer account for sandbox credentials, then a live account before the first real filing. The API key is held server side and entered through the secure card flow when it exists. Until then the stub keeps the flow walkable.

## Tracking, messaging, and availability

App/TrackingView.swift is the homeowner live tracking screen: a MapKit map with the home marker, the specialist marker, and the route, a status ladder from confirmed to completed, and the specialist card with Message and Call. The specialist position advances on a timer so the screen walks end to end. It is reachable from the Track live button on the home screen next visit card and from the en route booking in the Bookings tab. In production the position comes from the job_locations stream over Supabase Realtime.

App/MessagesView.swift is the thread screen, one thread per homeowner and specialist pair, with the quick actions from the supplied messaging screen (Share address, Running 10 min late, Please start with the kitchen). It opens from the tracking screen and from the Message button on the pro jobs dashboard.

App/AvailabilityView.swift is weekly availability editing for specialists: open and close times per day, days off, and the auto accept repeat clients rule. It lives in the pro Schedule tab, and edits reflect in the schedule summary immediately because both read the same store state.

Backend/tracking_messaging.sql is migration 004: the bookings table with the status ladder, job_locations for the tracking stream, and messages, all with row level security limited to the two parties on each booking or thread.

Tax forms and payouts are intentionally untouched in this stage. TaxBandits stays as wired, and worker payouts wait on the Branch program.

## Live backend wiring (2026-11-24)

The Linen backend now lives in Vashon's own Supabase account (project ref vftlwlnbfqqqxfdscato), transferred out of Rork the same day. Rork had already created the base tables there (profiles, homes, specialists, availability, services, add_ons, bookings, booking_declines) with row level security built on a user_id() helper and the catalogs seeded. Two migrations were applied to that live project and verified by reading the schema back:

* Backend/realtime_tracking_messaging.sql is migration 005: job_locations and messages tables with policies limited to the two parties on a booking, both added to the supabase_realtime publication.
* Backend/realtime_bookings.sql is migration 006: bookings added to the supabase_realtime publication so status changes stream.

The app side is wired to those tables:

* App/SupabaseConfig.swift holds the project URL and the public anon key. Row level security is the protection; the service role key never ships in the app.
* App/SupabaseClient.swift is the REST client for locations and messages. Requests carry the session token from AppStore.authToken when the app is signed in.
* App/RealtimeClient.swift is a small websocket client for the Realtime stream, one table and one booking at a time.
* App/LocationPublisher.swift publishes the pro position from CoreLocation while a route is shared, throttled to a few seconds or 25 meters.
* TrackingView follows the live position and the live booking status when the store carries a live booking, and falls back to the timer simulation in the demo flow. MessagesView loads, sends, and receives through the messages table in live mode. The pro jobs dashboard gained Start route and share location, and Start visit stops sharing.
* App/LOCATION-PERMISSIONS.md lists the usage strings the app project must carry for the location prompt.

What still connects this to a real clean: the app session setting authToken, currentUserId, and liveBookingId at sign in and when a booking is opened, which lands with the Rork session integration, and push notifications for messages that arrive while the app is closed. Until a session sets those values, the screens run the demo flow exactly as before.

## Brand color and pinned headers (2026-11-24)

Mint green is the app accent, set in App/AppTheme.swift as LinenTheme (mint #3EB489, deep mint #2A7F62, soft tint #DFF5EA) and applied as the root tint in LinenApp, replacing the pink the build was using. The homeowner Home header and the pro Jobs header are pinned above their scroll views, so they stay at the top of the screen while content scrolls under them.

## Next stages

Stage 2 wires the homeowner booking flow to Supabase and Apple Pay. Stage 3 wires the pro flow and the session hookup above. Stage 4 finishes notifications. Stage 5 adds rating and tip, payouts, and recurring bookings.
