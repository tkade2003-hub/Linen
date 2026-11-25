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

## Next stages

Stage 2 wires the homeowner booking flow to Supabase and Apple Pay. Stage 3 wires the pro flow. Stage 4 adds live tracking, messaging, and notifications. Stage 5 adds rating and tip, payouts, recurring bookings, and availability editing.
