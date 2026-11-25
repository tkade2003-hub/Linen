# Location permissions the project must carry

The pro side shares its position during a visit through LocationPublisher.swift. iOS shows the permission prompt from the usage strings in the app project settings, so the Rork project for Linen needs these entries before the tracking build ships.

## Required now (When In Use sharing)

- Privacy, Location When In Use Usage Description:
  "Linen shares your location with your client while you are on the way to a clean and during the visit, so they can follow your arrival."

## Required for sharing with the app closed (later stage)

- Privacy, Location Always and When In Use Usage Description:
  "Linen shares your location with your client while you are on the way to a clean and during the visit, so they can follow your arrival even when the app is in the background."
- Background Modes: Location updates.

Until the Always permission and the background mode are set, LocationPublisher shares only while the pro has the app open, which covers the drive over with the job screen up.
