# Linen: Build Spec

One app, two workspaces. Linen is an on demand maid service with a homeowner side and a specialist (cleaner) side in a single iOS app, built in SwiftUI. The role choice starts at sign in, and the app menu carries a workspace switcher for people who use both sides. Client payments run through Apple Pay at checkout. Specialist payouts run through a contractor payment integration, weekly by default with a cash out option. One backend serves both sides. This spec maps all nineteen supplied screens and adds nothing they do not call for.

## Onboarding and roles

* **Onboarding and Sign In** (supplied: onboarding_sign_in.html). One sign in screen for the whole app with two paths at the top: Homeowner and Specialist Pro. Email first, then verification. The tagline on the screen: calm, trusted care for your home, book background checked specialists in minutes, or join as a home care pro.
* Every account starts as a homeowner. Choosing the pro path starts pro onboarding: application, background check, payout account setup. The Pro workspace unlocks only when verification clears. The specialist card on the client tracking screen shows the Background checked badge, and the pro profile carries a Verified and Insured Pro badge.
* The app menu (supplied: app_menu_switcher.html) holds the workspace switcher, profile and saved homes, notifications, messages, settings, concierge help, and sign out, with the signed in identity shown once.

## Homeowner workspace

Tabs: Home, Book, Bookings, Account. Messages, tracking, and notifications open as pushed screens.

1. **Home and Quick Book** (supplied: home_quick_book.html). Address header, next visit card with live status, three service tiers with price and duration, specialists near you with rating and clean count.
2. **Configure Your Clean** (supplied: cleaning_scope_scheduling.html). Bedrooms and bathrooms steppers with per room pricing, service tier selector, add on care list, eco supplies note, arrival window picker by day and time, estimated total that updates live, Confirm booking button carrying the total.
3. **Review and Pay** (supplied: checkout_confirmation.html). Line items, total, recurring offer (make it recurring, save 15 percent, pause or skip anytime), home access summary, payment row, Pay button with Apple Pay.
4. **Live Tracking** (supplied: live_cleaner_tracking.html). Map, arrival ETA, four step progress (Confirmed, En route, Cleaning, Done), specialist card with rating, cleans count, and background check badge, Message and Call actions, visit details.
5. **Bookings and History** (supplied: bookings_history.html). Upcoming and Past segments. Upcoming cards carry status, specialist, and the right actions per state: Message and Track arrival while en route; Reschedule and Edit scope while scheduled. Past cards carry the rating given and Rebook.
6. **Messaging** (supplied: in_app_messaging.html). One thread per visit, tied to the visit number, with a call action in the header.
7. **Notifications** (supplied: notifications.html). Arrival alerts, booking confirmations, and receipts in one feed, with mark read.
8. **Post Clean Rating and Tip** (supplied: post_clean_rating_tip.html). Shown when a visit completes: visit summary with task count, star rating, tip choices of 10, 15, or 25 dollars or none, with the promise that 100 percent of the tip goes to the pro, an optional note, and one Submit button carrying the tip amount.
9. **Account** (supplied: homeowner_account.html). Profile, saved homes with entry notes, care preferences, preferred specialist, payment method, settings entry, sign out.
10. **Settings** (supplied: homeowner_settings.html). Arrival alerts, completion photos, recurring reminders, smart lock and key codes, two factor authentication, privacy, about, delete account.

## Specialist Pro workspace

Tabs, exactly as the supplied pro screens show them: Jobs, Schedule, Earnings, Profile.

1. **Jobs Dashboard** (supplied: worker_jobs_dashboard.html). Online toggle, today projected pay with visits and hours booked, the up next job with status, distance, service, client, address, pay, home size, add ons, and entry note, with Navigate and Start visit actions. Below it, new requests nearby with service, day, time, duration, distance, and pay, each with Decline and Accept job.
2. **Active Job Checklist** (supplied: active_job_checklist.html). Visit header with client first name and last initial, live job timer, message shortcut, address and entry notes, care flags such as pet friendly supplies only, room by room checklist with per room progress, photo action, Complete visit button carrying the payout.
3. **Visit Completion** (supplied: worker_visit_completion.html). Wrap up screen: tasks verified count, base pay, elapsed time, completion photos with add photo, departure checklist (key returned, lights off, door locked), Submit and log payout.
4. **Schedule** (supplied: worker_schedule.html). Month strip, day detail with visits in time order, pay per visit, client and address, break and transit gaps shown between jobs, and Adjust weekly availability.
5. **Earnings** (supplied: worker_earnings.html). Week and month views, available balance, completed cleans count, auto payout date, base pay and client tips broken out, Cash out button, completed visit list with per visit pay including the tip portion, month total with cleans count and average rating.
6. **Profile** (supplied: worker_profile.html). Online toggle, name, Verified and Insured Pro badge, rating, cleans count, on time percentage, work area and service radius, payout account, eco kit supplies with restock date, recent reviews.
7. **Pro Settings** (supplied: worker_settings.html). Same day urgent requests with priority alerts and plus 15 percent surge pay, auto accept repeat clients during open hours, navigation app choice, payouts and tax (weekly direct deposit day and account, 1099 NEC tax documents), safety line, pro handbook, sign out of Linen Pro.

## Money, as the screens define it

* Client prices: Standard Tidy 118 dollars for 2 hours, Signature Clean 148 dollars for 2.5 hours, Deep Seasonal Reset 215 dollars for 4 hours. Room pricing adds 22 dollars per bedroom and 28 dollars per bathroom in the configurator. Add ons: inside fridge 25, interior oven 30, laundry and fold 20.
* Pro base pay is set per job and shown before acceptance: the supplied screens show 130 dollars on a 148 dollar Signature Clean, 164 dollars offered on a Deep Seasonal Reset, 88 dollars offered on a Standard Tidy. The platform keeps the difference.
* Tips are chosen by the client after the clean and pass through in full. Earnings shows base pay and tips as separate lines, and each completed visit shows its tip portion.
* Same day urgent requests carry plus 15 percent surge pay for the pro.
* Payouts land weekly by direct deposit, Fridays in the supplied screens, with an anytime Cash out of the available balance.

## Core flows

**Book a clean.** Home, pick tier, configure scope, pick window, review, pay with Apple Pay. The booking starts as Searching, nearby pros see it as a new request, and the first acceptance confirms it.

**Run a job.** Pro accepts, the dashboard shows it as up next. Start visit begins travel, the client sees En route and live tracking. On arrival the checklist opens and the timer runs. Rooms get checked off, completion photos attach, and the wrap up screen verifies tasks and the departure checklist before Submit logs the payout.

**Rate and tip.** On completion the client gets the rating and tip screen. The review lands on the pro profile, and the tip lands in the pro earnings as its own line.

**Recurring.** A booking can repeat on a set rhythm with the 15 percent recurring saving. Either side can pause or skip a visit. Reminders go out 24 hours ahead, per the settings screen. Repeat clients can be auto accepted by the pro during open hours.

**Messaging.** One thread per visit, open from booking, tracking, and checklist screens. Threads close when the visit completes, with a short grace window.

## Data model

Backend: one Supabase project, mirroring the pattern already proven on the Tava Labs app.

* **profiles**: id, name, email, phone, photo, pro status (none, pending, verified), created at.
* **homes**: owner id, label, address, beds, baths, entry notes, care preferences, is default.
* **specialists**: profile id, bio, rating average, cleans count, on time percentage, background check status, insured status, service radius and center, payout account reference, eco kit restock date.
* **availability**: specialist id, weekday, open hours. Drives matching and auto accept.
* **services**: name, client price, base minutes, description. Launch catalog above.
* **add ons**: name, price. Launch list above.
* **bookings**: homeowner id, specialist id (null while searching), home id, service id, add on ids, beds, baths, window start, status, client total, pro base pay, surge flag, recurring series id, entry note snapshot.
* **Booking status ladder**: searching, confirmed, en route, in progress, completed, cancelled.
* **checklist items**: booking id, room, label, done. **departure checks**: booking id, label, done.
* **photos**: booking id, kind (progress or completion), url, created at.
* **messages**: booking id, sender id, body, created at.
* **reviews**: booking id, author id, stars, body, tip amount.
* **payouts**: specialist id, booking id, base amount, tip amount, status, paid date.
* **notifications**: profile id, kind, body, read, created at.

## Platform rules applied

* Touch targets at least 44 points, primary actions in thumb reach at the bottom of the screen, per the mobile design system.
* Dynamic type respected on every screen. The checklist, tracking, and jobs screens must stay usable one handed, since a pro works with a phone in one hand.
* The job timer, checklist state, and tracking keep working across brief network drops. State is stored on device and synced when the connection returns.
* Push notifications for arrival alerts, job offers, booking confirmations, and receipts, matching the toggles in both settings screens.

## Build order

1. Backend schema, auth with the two path sign in, pro verification gate, and the workspace switcher shell.
2. Homeowner booking flow end to end: quick book, configure, Apple Pay checkout, bookings list.
3. Pro flow: jobs dashboard and requests, checklist, timer, visit completion.
4. Live tracking, messaging, and notifications, which join the two sides.
5. Rating and tip, earnings and payouts, schedule and availability, recurring bookings.
6. Test on a real phone at every stage before calling any stage done.
