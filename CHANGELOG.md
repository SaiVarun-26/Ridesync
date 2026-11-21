# Changelog

All notable changes to RideSync are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Each version matches the `version` in `pubspec.yaml`, a `v*` git tag and a [GitHub Release](https://github.com/SaiVarun-26/Ridesync/releases) with the Android APK.

## v1.0.0

The first public release of RideSync.

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
