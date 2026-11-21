# Changelog

All notable changes to RideSync are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Each version matches the `version` in `pubspec.yaml`, a `v*` git tag and a [GitHub Release](https://github.com/SaiVarun-26/Ridesync/releases) with the Android APK.

## Highlights

The newest features, and the release each one arrived in.

| Feature | Release | Milestone |
|---|---|---|
| Google Sign-In | v1.1.0 | 5.5 |
| Profile page with personal statistics | v1.1.0 | 5.5 |
| Cloud ride history, restored on any phone | v1.1.0 | 5.5 |
| Solo rider colour | v1.1.0 | 5.5 |
| History and settings sync across devices | v1.1.0 | 5.5 |
| Offline ride upload | v1.1.0 | 5.5 |
| Improved ride saving | v1.0.0 | 5.4.1 |
| History delete | v1.0.0 | 5.4.1 |
| Pause / Resume | v1.0.0 | 5.4 |
| Smart Auto End | v1.0.0 | 5.4 |
| Fuel brand markers | v1.0.0 | 5.3 |
| Fuel toggle | v1.0.0 | 5.3 |
| Replay improvements | v1.0.0 | 5.2 |

## v1.1.0

Accounts and cloud sync (Milestone 5.5). Sign in with Google, and your rides, statistics and preferences follow you to any phone.

> [!IMPORTANT]
> v1.1.0 is signed with a different key than v1.0.0, so Android cannot install it over v1.0.0. Uninstall v1.0.0 first. Rides saved in v1.0.0 belonged to an anonymous session on that phone and cannot be carried over after uninstalling.

### Added

- **Google Sign-In:** one "Continue with Google" button. Signed-in riders skip the sign-in screen on later launches.
- **Rider name:** after the first sign-in RideSync asks "What should we call you?". That name, never the Google account name, is used everywhere: group rides, the leaderboard, history and share cards.
- **Profile page:** picture, rider name, email and member since. Totals (rides, distance, ride time), records (highest speed, longest ride, average distance, average speed) and rides by type (guided, free roam, group, solo).
- **Cloud sync status** on the profile: ✓ Synced, Syncing... or Offline, with a **Sync Now** button.
- **Edit Profile:** change the rider name and the solo ride colour. A profile picture of your own is planned.
- **Solo rider colour:** choose your colour for solo rides: your dot, trail, replay, history and ride cards. Group rides still give every rider their own colour.
- **Cloud ride history:** history belongs to your Google account and restores on any phone you sign in on, with its routes, replays, insights and ride cards.
- **Settings sync:** rider name, solo colour and the fuel layer setting follow you across devices.
- **Offline ride upload:** a ride finished without a connection is saved on the phone, queued, and uploaded automatically when the connection returns, even after the app is closed.
- **Sign Out** from the profile page.

### Changed

- **Sign-in** is now with Google instead of an anonymous session.
- **Home** greets you by rider name and has a profile button.
- **The saving screen** explains when the phone is offline and that the ride will upload by itself.

### Security

- **Firestore rules** limit each rider to their own profile document, and allow only the known profile fields and preference types.

## v1.0.0

The first public release of RideSync (Milestones 1 to 5.4.1).

### Added

- **Solo riding:** one-tap solo rides from the home screen, as Free Roam or Guided.
- **Group riding:** ride rooms joined with a short code, rider colours, a lobby, and live positions and trails for every rider.
- **Guided rides:** destination search, road route planning, turn-by-turn guidance, route progress and off-route help.
- **Live Leaderboard:** live ranking along the shared path or planned route, live rider speed, and the gap to each rider.
- **Ride notices:** banners when a rider re-routes, leaves the planned route, rejoins, pauses, resumes or completes the ride.
- **Safety tools for group rides:** I'm OK, Regroup, Follow me, shareable live status and a slide-to-alert.
- **Ride results** told as a story of cards: overview, top speed, performance, insights, timeline, standings and group moments.
- **Ride Replay** on the real recorded GPS timeline, with playback speed and rider focus.
- **Ride History** with route thumbnails, finishing positions and offline access.
- **Share cards** with the real map and route.
- **Automatic ride names** from where the ride ended, always editable.
- **Fuel stations:** nearby stations around the rider, anywhere in India, with company-coloured markers, clustering and a station sheet with a Google Maps hand-off.
- **Fuel toggle** on the map, remembered between rides, with a fuel information sheet.
- **Smart Auto End:** after a long genuine stop, a 15-second countdown asks whether the ride is over.
- **Pause and Resume:** paused time is kept apart from ride and moving time, and the same ride carries on.
- **Delete ride** from history, with confirmation.
- **Background tracking** with a live ride notification.

### Changed

- **Every rider ends their own ride.** The host only creates the room; the last rider to finish closes it.
- **New Home screen** with a dedicated Solo Ride card.
- **Ride details page** opens on a large interactive map, followed by the overview and statistics.
- **End Ride and Pause** are clearly labelled floating buttons, always in view.
- **Safety tools** appear only in group rides.

### Fixed

- **Auto-ended rides** are always saved to history before the Ride Complete screen appears.
- **Fuel station markers** now load reliably: a faster primary data source, with a fallback.
- **Group ride summaries** include every rider's final statistics.
- **Replay keeps every rider on one shared timeline**, so riders who started together move together.
- **Map rotation and follow mode** behave consistently.
- **Route colours** in history match each rider's colour.

### Improved

- **Ride saving** retries automatically until it succeeds, and a completed ride is never discarded.
- **Fuel stations** are cached on the device, loaded in the background and rate-limited.
- **Stationary detection** for Auto End filters out GPS noise and weak fixes.
- **Map markers** are drawn efficiently for smooth map interaction.

## Milestone history

How the development milestones map to releases.

| Milestone | Summary | Release |
|---|---|---|
| 1 | App foundation: project structure, dark theme, routing and the app shell. | v1.0.0 |
| 2 | Firebase: authentication, user profiles and the Realtime Database backend. | v1.0.0 |
| 3 | Ride rooms: create and join with a code, the lobby, rider colours and live group tracking. | v1.0.0 |
| 4 | Ride statistics, results, ride history, insights, guided routes with turn-by-turn navigation, and group safety tools. | v1.0.0 |
| 5.0 | New Home screen with one-tap solo rides. | v1.0.0 |
| 5.1 | Live Leaderboard, live rider speed, rankings, and re-route and rejoin notices. | v1.0.0 |
| 5.2 | Redesigned history and insights, flex cards, an interactive history map and timestamp-accurate replay. | v1.0.0 |
| 5.3 | Fuel stations across India with brand markers, a fuel toggle, caching and background loading. | v1.0.0 |
| 5.4 | Smart Auto End, Pause and Resume, and every rider ending their own ride. | v1.0.0 |
| 5.4.1 | Reliable saving before Ride Complete, deleting rides from history, and clearer End and Pause controls. | v1.0.0 |
| 5.5 | Google Sign-In, profiles, cloud history, personal statistics, solo rider colour, settings sync and offline upload. | v1.1.0 |
