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
* Abound fits Linen. It is a tax compliance API built for platforms and marketplaces: an embeddable white label W-9 component, real time TIN verification, 1099 NEC generation and federal and state filing, corrections and B notice handling, document retention, webhooks, and a sandbox for development. Pricing is a custom volume quote with no published per form rate, and signup runs through their sales process.

The build is wired to the Abound pattern. App/FormsService.swift is the provider boundary with the three calls the app needs, currently a stub that simulates the round trip. Backend/forms_integration.sql is migration 003: W-9 and TIN match status on the tax profile, the provider payee reference, and a contractor_filings table keyed by contractor and tax year. The W-9 step in onboarding now opens the provider flow instead of a hand built form. Filing rule recorded in the migration: a 1099 NEC is due at or over 600 dollars paid through 2025, and at or over 2,000 dollars for payments made in 2026 and later, filed each January for the prior year.

Still needed to go live: an Abound account and its API key, held server side and entered through the secure card flow when it exists. Until then the stub keeps the flow walkable.

## Next stages

Stage 2 wires the homeowner booking flow to Supabase and Apple Pay. Stage 3 wires the pro flow. Stage 4 adds live tracking, messaging, and notifications. Stage 5 adds rating and tip, payouts, recurring bookings, and availability editing.
