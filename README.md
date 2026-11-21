# RideSync

**Never lose your ride.** RideSync is a real-time ride companion for motorcyclists and cyclists: ride alone or with a group, see everyone live on the map, follow a planned route, and relive every ride afterwards.

<p>
  <a href="https://flutter.dev"><img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white"></a>
  <a href="https://dart.dev"><img alt="Dart" src="https://img.shields.io/badge/Dart-3.13-0175C2?logo=dart&logoColor=white"></a>
  <a href="https://firebase.google.com"><img alt="Firebase" src="https://img.shields.io/badge/Firebase-Realtime%20Database-FFCA28?logo=firebase&logoColor=black"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-8C3EE2"></a>
  <a href="https://github.com/SaiVarun-26/Ridesync/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/SaiVarun-26/Ridesync?label=Latest%20release&color=8C3EE2"></a>
  <a href="https://github.com/SaiVarun-26/Ridesync/releases"><img alt="Downloads" src="https://img.shields.io/github/downloads/SaiVarun-26/Ridesync/total?label=Downloads&color=8C3EE2"></a>
  <img alt="Platform: Android" src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white">
</p>

---

# 📲 Download RideSync

<p>
  <a href="https://github.com/SaiVarun-26/Ridesync/releases/latest">
    <img alt="Download Latest APK" src="https://img.shields.io/badge/Download-Latest%20APK-8C3EE2?style=for-the-badge&logo=android&logoColor=white">
  </a>
</p>

**Always download the newest stable version from [GitHub Releases](https://github.com/SaiVarun-26/Ridesync/releases/latest).**

Current version: **v1.0.0** · [Changelog](CHANGELOG.md)

Every release contains:

| | |
|---|---|
| 📦 | **Latest Android APK** |
| 📝 | **Release Notes** |
| 🚀 | **New Features** |
| 🐛 | **Bug Fixes** |
| ⚡ | **Performance Improvements** |

### Installing on Android

1. Open the [latest release](https://github.com/SaiVarun-26/Ridesync/releases/latest) on your phone.
2. Under **Assets**, tap `RideSync-vX.Y.Z.apk` to download it.
3. Open the downloaded file. If Android asks, allow installing apps from your browser or file manager.
4. Tap **Install**, then open RideSync.
5. When asked, allow **location** (choose *Allow all the time* so rides keep recording with the screen off) and **notifications**.

**Updating:** download the newer APK from the latest release and install it over the existing app. Your rides are kept as long as the app is not uninstalled.

> RideSync is distributed only through GitHub Releases. APK files are never stored in this repository.

---

## About

Group rides fall apart in familiar ways: someone takes a wrong turn, someone falls behind, nobody knows who stopped for fuel, and at the end of the day the ride exists only in memory.

RideSync keeps a group together while riding and keeps the ride afterwards. Every rider shares their live position, speed and trail with the group. A host can plan a route that everyone follows with turn guidance. When the ride ends, each rider gets a full story of it: the route, statistics, highlights, a replay and a permanent place in their ride history.

It is built for:

- **Motorcycle and cycling groups** who ride together and want to stay together.
- **Solo riders** who want reliable tracking, statistics and a history of their rides.
- **Ride organisers** who plan a route and want everyone on it.

Everything runs on free, open map data (OpenStreetMap), with no paid map or places API.

## Features

### 🏍️ Solo Riding
- Start a solo ride in one tap from the home screen, as Free Roam or Guided.
- Live speed, distance, duration, moving time and stopped time.
- Tracking continues in the background with the screen off, with a live status notification.

### 👥 Group Riding
- Create a ride room and invite others with a short ride code.
- Every rider picks their own colour, shown on their marker, trail and results.
- Live positions of everyone, with smooth marker motion and fading trails.
- Each rider manages only their own ride: anyone can pause or end without affecting the others.
- Safety tools for groups: "I'm OK", "Regroup", "Follow me", a shareable live status, and a deliberate slide-to-alert.

### 🏆 Live Leaderboard
- Real-time standings of the group, ranked along the shared path or planned route.
- Live speed and the gap ahead or behind for each rider.
- Banners when a rider re-routes, leaves the planned route or rejoins the group.

### 🗺️ Maps & Navigation
- Dark, night-style OpenStreetMap map designed for riding.
- Follow camera that keeps the rider in view with heading-up rotation; two-finger rotation and an easy return to follow mode.
- Guided rides: search a destination, plan a road route, and follow turn-by-turn guidance with route progress.
- Off-route detection with help getting back on the route.

### ⏯️ Ride Replay
- Replays a group ride on the map using each rider's real recorded GPS timestamps.
- Riders start, stop and arrive exactly when they did, on one shared timeline.
- Adjustable playback speed, with scrubbing and per-rider focus.

### 📚 Ride History
- Every finished ride is saved to your history automatically.
- History cards with a route thumbnail, distance, duration, top speed and finishing position.
- Rename or delete any ride from its card.
- Recent history stays available offline.

### 📊 Ride Insights
- A results page told as a story of cards: overview, top speed, performance, insights and a timeline.
- An interactive route map with speed colouring, start and finish markers, and turn-around points.
- Top speed shown exactly where it happened, on a mini route drawing and on the map.
- Group standings, group moments, ride score, achievements and the weather at the start.
- Shareable ride cards with the real map and route, ready for any app.
- Rides are named automatically from where they ended (for example "Ride to Marina Beach"), and the name can always be edited.

### ⛽ Fuel Station Discovery
- Nearby fuel stations around the rider's live position, anywhere in India.
- Company-coloured markers for major fuel brands, with a generic marker for others.
- Clustered when zoomed out; tap a station for distance, estimated riding time and a hand-off to Google Maps.
- One-tap Fuel toggle on the map, remembered between rides.
- Loaded in the background and cached on the device for offline use.

### ⏱️ Smart Auto End
- Detects when a rider has genuinely stopped, filtering out GPS noise.
- After a long stop, asks "Looks like you've stopped riding." with a 15-second countdown.
- Continue, pause or end with one tap; the prompt disappears by itself if riding resumes.
- Rides are always saved before the completion screen appears, with automatic retries.

### ⏸️ Pause / Resume
- Pause for tea, fuel or photo stops; auto end is disabled while paused.
- The ride clock and moving time stop while paused, and paused time is kept separately.
- Resume continues the same ride and the same route.

### 🔔 Smart Notifications
- A persistent ride notification with live distance, speed and duration.
- In-app banners when another rider pauses, resumes, completes the ride, re-routes or rejoins.
- Notices for safety signals from the group.

## Ride Types

| Ride Type | Riders | Route | Best For |
|---|---|---|---|
| **Solo Free Roam** | One | Ride anywhere | Everyday rides and exploring |
| **Solo Guided** | One | Planned route with turn guidance | Riding to a destination |
| **Group Free Roam** | Many | Ride anywhere, together | Casual group rides |
| **Group Guided** | Many | Shared planned route for everyone | Organised group rides and tours |

All ride types share the same live map, statistics, auto end, pause, fuel stations, results and history.

## Tech Stack

| Area | Technology |
|---|---|
| Framework | [Flutter](https://flutter.dev) |
| Language | [Dart](https://dart.dev) |
| State management | [Riverpod](https://riverpod.dev) (`flutter_riverpod`) |
| Navigation | [go_router](https://pub.dev/packages/go_router) |
| Authentication | [Firebase Authentication](https://firebase.google.com/products/auth) (anonymous) |
| Live data | [Firebase Realtime Database](https://firebase.google.com/products/realtime-database) |
| User profiles | [Cloud Firestore](https://firebase.google.com/products/firestore) |
| Maps | [flutter_map](https://pub.dev/packages/flutter_map) with [OpenStreetMap](https://www.openstreetmap.org) tiles, `latlong2` |
| Location | [geolocator](https://pub.dev/packages/geolocator) |
| Background tracking | [flutter_foreground_task](https://pub.dev/packages/flutter_foreground_task) |
| Place search & fuel stations | [Photon](https://photon.komoot.io), [Overpass API](https://overpass-api.de) (OpenStreetMap data) |
| Routing | [OSRM](https://project-osrm.org) |
| Ride naming | [Nominatim](https://nominatim.org) reverse geocoding |
| Weather | [Open-Meteo](https://open-meteo.com) |
| Local storage | [shared_preferences](https://pub.dev/packages/shared_preferences), [path_provider](https://pub.dev/packages/path_provider) |
| Sharing & links | [share_plus](https://pub.dev/packages/share_plus), [url_launcher](https://pub.dev/packages/url_launcher) |
| UI | [google_fonts](https://pub.dev/packages/google_fonts), [animations](https://pub.dev/packages/animations) |
| Tooling | `flutter_lints`, `build_runner`, `freezed` |

## Project Structure

```
ridesync/
├── lib/
│   ├── app/          # App entry, bootstrap and routing
│   ├── core/         # Theme, shared widgets, errors and utilities
│   └── features/     # Feature modules, each split into data / domain / presentation
│       ├── auth/       # Sign-in and onboarding
│       ├── room/       # Ride rooms, lobby, joining and solo rides
│       ├── ride/       # Live map, tracking, guidance, leaderboard, safety, auto end
│       ├── history/    # Ride history, ride details and replay
│       ├── insights/   # Ride recap, statistics, achievements and share cards
│       ├── naming/     # Automatic ride naming
│       ├── fuel/       # Fuel station discovery
│       └── ride_card/  # Rider identity card
├── assets/           # Bundled assets (map style)
├── android/          # Android project
├── ios/              # iOS project
├── firebase/         # Firebase security rules
└── test/             # Tests
```

The code follows a feature-first, layered architecture: domain logic is plain Dart with no Flutter or Firebase dependencies, data sources sit behind repository interfaces, and widgets only render state.

## Milestone Progress

Milestones 1–4 laid the foundation: authentication, ride rooms, live group tracking, ride statistics, results, history, ride insights, guided routes, navigation and safety tools.

### ✅ Milestone 5

| Version | Highlights | Status |
|---|---|---|
| **5.0** | New Home UI · Solo Ride button | ✅ Completed |
| **5.1** | Live Leaderboard · Live rider speed · Rider ranking · Re-route detection · Rejoin notifications | ✅ Completed |
| **5.2** | Ride History redesign · Better ride insights · Flex cards · Replay improvements | ✅ Completed |
| **5.3** | Fuel stations · Company markers · Fuel toggle · Caching · Pan-India support | ✅ Completed |
| **5.4** | Auto End · Pause · Resume · Automatic saving · Delete ride · Improved End Ride UI · Better save reliability | ✅ Completed |

## Future Roadmap

- [ ] Crash Detection
- [ ] Emergency SOS
- [ ] Wear OS companion
- [ ] Android Auto
- [ ] Apple Health integration
- [ ] Google Fit integration
- [ ] AI Ride Insights
- [ ] Motorcycle Garage
- [ ] Maintenance Tracker
- [ ] Ride Challenges

## Screenshots

> Screenshots are coming soon. They live in [`docs/screenshots/`](docs/screenshots/).

| Home | Solo Ride | Group Ride | Leaderboard |
|:---:|:---:|:---:|:---:|
| *Coming soon* | *Coming soon* | *Coming soon* | *Coming soon* |

| Ride History | Ride Replay | Fuel Stations | Insights |
|:---:|:---:|:---:|:---:|
| *Coming soon* | *Coming soon* | *Coming soon* | *Coming soon* |

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel, Dart 3)
- Android Studio or VS Code with the Flutter extension
- An Android device or emulator with location services
- A [Firebase](https://console.firebase.google.com) project

### Installation

```bash
# Clone the repository
git clone https://github.com/SaiVarun-26/Ridesync.git
cd Ridesync

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Firebase Configuration

RideSync needs a Firebase project. To use your own:

1. Create a Firebase project and add an Android app with the package name `com.ridesync.ridesync`.
2. Enable **Anonymous** sign-in in Firebase Authentication.
3. Create a **Realtime Database** and a **Cloud Firestore** database.
4. Connect the app with the [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup):
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
5. Deploy the security rules from the `firebase/` folder:
   ```bash
   firebase deploy --only database,firestore
   ```

### Permissions

RideSync asks for location access (including background location, so a ride keeps recording with the screen off) and notification permission for the live ride notification.

### Build

```bash
flutter analyze
flutter test
flutter build apk --release
```

## Releases

Releases are fully automated. To publish a new version:

1. Bump `version` in `pubspec.yaml` following [Semantic Versioning](https://semver.org) (for example `1.1.0+2`).
2. Add a `## v1.1.0` section to [CHANGELOG.md](CHANGELOG.md), and optionally `docs/release-notes/v1.1.0.md`.
3. Commit, then tag and push:
   ```bash
   git tag v1.1.0
   git push origin v1.1.0
   ```

The [release workflow](.github/workflows/release.yml) checks that the tag matches `pubspec.yaml`, runs analysis and tests, builds the release APK, and publishes it to [GitHub Releases](https://github.com/SaiVarun-26/Ridesync/releases) with release notes. See [CHANGELOG.md](CHANGELOG.md) for the history of every version.

## Contributing

Contributions are welcome. Please read the [Contributing Guide](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md) before opening an issue or pull request.

- 🐛 [Report a bug](https://github.com/SaiVarun-26/Ridesync/issues/new?template=bug_report.yml)
- ✨ [Request a feature](https://github.com/SaiVarun-26/Ridesync/issues/new?template=feature_request.yml)
- 🔒 Security issues: see the [Security Policy](SECURITY.md)

## License

RideSync is released under the [MIT License](LICENSE).

---

<p align="center">Map data © <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors.</p>
