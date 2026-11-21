<div align="center">

# 🏍️ RideSync

### Never lose your ride.

**Solo and group motorcycle rides, synchronized in real time.**

<p>
  <a href="../../releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/SaiVarun-26/Ridesync?label=release&color=8C3EE2"></a>
  <a href="../../releases"><img alt="Downloads" src="https://img.shields.io/github/downloads/SaiVarun-26/Ridesync/total?label=downloads&color=8C3EE2"></a>
  <a href="../../actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/SaiVarun-26/Ridesync/ci.yml?branch=main&label=CI"></a>
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-8C3EE2"></a>
  <img alt="Platform: Android" src="https://img.shields.io/badge/platform-Android-3DDC84?logo=android&logoColor=white">
  <a href="https://flutter.dev"><img alt="Built with Flutter" src="https://img.shields.io/badge/built%20with-Flutter-02569B?logo=flutter&logoColor=white"></a>
  <a href="https://firebase.google.com"><img alt="Firebase" src="https://img.shields.io/badge/backend-Firebase-FFCA28?logo=firebase&logoColor=black"></a>
</p>

<a href="../../releases/latest"><img alt="Download the latest APK" src="https://img.shields.io/badge/Download-Latest%20APK-8C3EE2?style=for-the-badge&logo=android&logoColor=white"></a>

[Features](#features) · [Screenshots](#screenshots) · [Tech Stack](#tech-stack) · [Architecture](#architecture) · [Installation](#installation) · [Download](#download-apk) · [Roadmap](#roadmap) · [Contributing](#contributing)

</div>

---

RideSync is a modern Flutter application for motorcycle riders. Ride alone or with a group: every rider's position, speed and trail are synchronized in real time, a planned route can guide everyone to the same destination, and every finished ride becomes a story you can replay, analyse and share.

Sign in with Google and your rides, statistics and preferences follow you to any phone. Rides finished without a connection are kept on the device and uploaded as soon as you are back online.

Maps, search, routing and fuel stations all run on free, open OpenStreetMap services, with no paid map API.

> [!NOTE]
> RideSync is under active development. Features, data formats and screens may change between releases. Feedback and bug reports are very welcome.

## Features

### 🏍️ Solo Riding

| Feature | What it does |
|---|---|
| **Free Roam** | Start riding in one tap, anywhere, with live speed, distance and ride time. |
| **Guided Navigation** | Search a destination, plan a road route and follow turn-by-turn guidance. |
| **Ride Replay** | Watch the ride again on the map, on its real recorded GPS timeline. |
| **Ride Insights** | Top speed, moving time, performance, a ride score, achievements and a timeline. |
| **Fuel Station Discovery** | Nearby fuel stations on the map, with brand markers and a Google Maps hand-off. |
| **Auto End Ride** | After a long genuine stop, a 15-second countdown asks whether the ride is over. |
| **Pause / Resume** | Stop for tea, fuel or photos; paused time is kept apart from ride time. |
| **Share Ride Cards** | A share-ready card with the real map, route and numbers. |

### 👥 Group Riding

| Feature | What it does |
|---|---|
| **Live Rider Tracking** | Every rider's live position, speed and colour on one map. |
| **Live Leaderboard** | Real-time standings along the shared path or planned route, with gaps. |
| **Group Navigation** | One planned route shared by the whole group, with guidance for everyone. |
| **Rider Trails** | A fading trail behind each rider, in their own colour. |
| **Group Replay** | Every rider replayed together on one shared timeline. |
| **Individual Ride Completion** | Each rider ends their own ride; the rest of the group keeps riding. |
| **Live Notifications** | Banners when a rider pauses, resumes, re-routes, rejoins or finishes, plus group safety signals. |

### ✨ Smart Features

- **Turn-by-turn navigation** with route progress and the next two turns.
- **Off-route detection** with guidance back to the planned route.
- **Automatic ride naming** from where the ride ended, always editable.
- **Ride History** with route thumbnails, finishing positions, rename and delete.
- **Replay Timeline** that scrubs through the ride at adjustable speed.
- **Ride Analytics:** speed-coloured routes, top-speed location, group moments and standings.
- **Google Sign-In**, with a rider name you choose (never your Google name).
- **Cloud-backed Ride History** that restores on any phone you sign in on.
- **Offline saving:** a ride finished offline uploads by itself when the connection returns.
- **Profile page** with cloud sync status, Edit Profile and Sync Now.
- **Personal statistics:** total rides, distance and ride time, records and averages, and rides by type.
- **Solo rider colour** for your dot, trail, replay and ride cards, synced across devices.
- **Fuel station brands** with company-coloured markers and a one-tap fuel layer toggle.
- **Background ride recording** with the screen off, and a live ride notification.

### 🗺️ Maps

RideSync uses free, open services built on [OpenStreetMap](https://www.openstreetmap.org) data. They need no API keys or paid plans, they cover the whole world, and the community keeps them current.

| Service | Used for | Why |
|---|---|---|
| [OpenStreetMap](https://www.openstreetmap.org) | Map tiles (shown in a dimmed night style) and all place data | Open data, worldwide coverage, free to use with attribution. |
| [flutter_map](https://pub.dev/packages/flutter_map) | Drawing the map, routes, trails and markers | Pure Flutter rendering, so riders, trails and replays are ordinary widgets and layers. |
| [Photon](https://photon.komoot.io) | Destination search and the main fuel-station lookup | Fast search-as-you-type over OSM data, with nearest-first results. |
| [Overpass API](https://overpass-api.de) | Complete fuel-station coverage for an area | Queries raw OSM tags with no result limit; merged with Photon so no station is missed. |
| [OSRM](https://project-osrm.org) | Road routes for guided rides | A fast open-source road router; the host plans once and every rider shares the same route. |
| [Nominatim](https://nominatim.org) | Automatic ride names | Reverse geocoding turns where a ride ended into a readable place name. |
| [Open-Meteo](https://open-meteo.com) | Weather at the start of a ride | Free weather data with no key. |

## Screenshots

> Screenshots are coming soon. Their files will live in [`assets/screenshots/`](assets/screenshots/).

| Home | Navigation | Group Ride |
|:---:|:---:|:---:|
| *Coming soon*<br>`assets/screenshots/home.png` | *Coming soon*<br>`assets/screenshots/navigation.png` | *Coming soon*<br>`assets/screenshots/group-ride.png` |

| Leaderboard | Ride Replay | Ride History |
|:---:|:---:|:---:|
| *Coming soon*<br>`assets/screenshots/leaderboard.png` | *Coming soon*<br>`assets/screenshots/ride-replay.png` | *Coming soon*<br>`assets/screenshots/ride-history.png` |

| Insights | Fuel Stations | Profile |
|:---:|:---:|:---:|
| *Coming soon*<br>`assets/screenshots/insights.png` | *Coming soon*<br>`assets/screenshots/fuel-stations.png` | *Coming soon*<br>`assets/screenshots/profile.png` |

## Tech Stack

| Area | Technology |
|---|---|
| App framework | [Flutter](https://flutter.dev) and [Dart](https://dart.dev) |
| Backend | [Firebase](https://firebase.google.com) |
| Live ride data and history | [Firebase Realtime Database](https://firebase.google.com/products/realtime-database), with on-disk persistence |
| Profiles and synced preferences | [Cloud Firestore](https://firebase.google.com/products/firestore) |
| Authentication | [Firebase Authentication](https://firebase.google.com/products/auth) |
| Sign-in | [Google Sign-In](https://pub.dev/packages/google_sign_in) |
| Maps | [flutter_map](https://pub.dev/packages/flutter_map) with [OpenStreetMap](https://www.openstreetmap.org) tiles |
| State management | [Riverpod](https://riverpod.dev) |
| Navigation | [go_router](https://pub.dev/packages/go_router) |
| Location | [Geolocator](https://pub.dev/packages/geolocator) |
| Background recording | [flutter_foreground_task](https://pub.dev/packages/flutter_foreground_task) |
| Local storage | [Shared Preferences](https://pub.dev/packages/shared_preferences) and a file cache via [path_provider](https://pub.dev/packages/path_provider) |
| Sharing and links | [share_plus](https://pub.dev/packages/share_plus), [url_launcher](https://pub.dev/packages/url_launcher) |
| CI/CD | [GitHub Actions](https://github.com/features/actions): analysis and tests on every push, APK builds on version tags |

## Architecture

RideSync is organised by feature (`lib/features/auth`, `room`, `ride`, `history`, `insights`, `fuel`, `profile`, …), and every feature is split into the same layers:

| Layer | Responsibility |
|---|---|
| **Presentation** | Screens, widgets and Riverpod providers. Widgets only render state and forward user actions. |
| **Domain** | Plain Dart models and rules (ride statistics, auto-end detection, route guidance, rankings), with no Flutter or Firebase imports, so they are easy to test. |
| **Data** | Firebase, HTTP and on-device implementations of the domain's repository interfaces. |
| **Services** | Workflows that span repositories, such as finishing a ride (record, summary, history) or recording statistics from GPS fixes. |

- **Repository pattern:** the app depends on interfaces such as `AuthRepository` and `RideHistoryRepository`, and Riverpod injects the implementations, so any backend can be swapped or faked in tests.
- **Offline-first:** the Realtime Database and Firestore keep writes on the device until they reach the server. Recent history, ride details and fuel stations are cached locally, so they still show without a connection.
- **Background synchronization:** a finished ride is queued on the device before it uploads. A background worker publishes anything still waiting as soon as the connection returns, even after the app is restarted.
- **Security:** Firebase security rules restrict every rider to their own profile and history, while shared ride data is open only to that ride's members.

```
lib/
├── app/        # Bootstrap, app root and routing
├── core/       # Theme, shared widgets, errors and utilities
└── features/   # Feature modules: data / domain / presentation
firebase/       # Realtime Database and Firestore security rules
test/           # Tests
```

## Milestones

| Milestone | Highlights |
|---|---|
| **Milestone 1** | App foundation: project structure, dark theme, routing and the app shell. |
| **Milestone 2** | Firebase: authentication, user profiles and the Realtime Database backend. |
| **Milestone 3** | Ride rooms: create and join with a code, the lobby, rider colours and live group tracking. |
| **Milestone 4** | The ride itself: statistics, results, ride history, insights, guided routes with turn-by-turn navigation, and group safety tools. |
| **Milestone 5.0** | New Home screen with one-tap solo rides. |
| **Milestone 5.1** | Live Leaderboard, live rider speed, rankings, and re-route and rejoin notices. |
| **Milestone 5.2** | Redesigned Ride History and insights, flex cards, an interactive history map and timestamp-accurate replay. |
| **Milestone 5.3** | Fuel stations across India: brand markers, a fuel layer toggle, caching and background loading. |
| **Milestone 5.4** | Smart Auto End, Pause and Resume, and every rider ending their own ride. |
| **Milestone 5.4.1** | Reliable ride saving before Ride Complete, deleting rides from history, and clearer End and Pause controls. |
| **Milestone 5.5** | Google Sign-In, profiles, cloud ride history, personal statistics, solo rider colour, settings sync and offline ride upload. |

See [CHANGELOG.md](CHANGELOG.md) for the full history.

## Installation

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install), stable channel
- Android Studio or VS Code with the Flutter extension
- An Android phone or emulator with location services

### Run

```bash
git clone https://github.com/SaiVarun-26/Ridesync.git
cd Ridesync
flutter pub get
flutter run
```

### Firebase setup

To run RideSync against your own Firebase project:

1. Create a Firebase project and add an Android app with the package name `com.ridesync.ridesync`.
2. In **Authentication → Sign-in method**, enable **Google**.
3. Add your signing key's SHA-1 and SHA-256 to the Android app in **Project settings**. For local builds, that is the debug key:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
   ```
4. Create a **Realtime Database** and a **Cloud Firestore** database.
5. Connect the app with the [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup), which writes `lib/firebase_options.dart` and `android/app/google-services.json`:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
6. Deploy the security rules:
   ```bash
   firebase deploy --only database,firestore
   ```

RideSync asks for location access (including background location, so a ride keeps recording with the screen off) and notification permission for the live ride notification.

### Checks and builds

```bash
flutter analyze
flutter test
flutter build apk --release
```

## Download APK

<a href="../../releases/latest"><img alt="Download the latest APK" src="https://img.shields.io/badge/Download-Latest%20APK-8C3EE2?style=for-the-badge&logo=android&logoColor=white"></a>

The newest Android build is always on the **[latest release](../../releases/latest)** page. Every version is listed under **[all releases](../../releases)**, with release notes, the APK and its SHA-256 checksum.

1. Open the [latest release](../../releases/latest) on your phone.
2. Under **Assets**, download the `RideSync-v….apk` file.
3. Open it and allow installing from your browser or file manager if Android asks.
4. Allow **location** (choose *Allow all the time* so rides record with the screen off) and **notifications**.

To check a download, compare its SHA-256 with the `.sha256` file attached to the same release:

```bash
sha256sum RideSync-v*.apk          # Linux and macOS
certutil -hashfile RideSync-v*.apk SHA256   # Windows
```

> APKs are published only through GitHub Releases and are never committed to this repository.

## Roadmap

- [ ] Android Auto
- [ ] Apple CarPlay
- [ ] Wear OS companion
- [ ] Apple Watch companion
- [ ] Offline maps
- [ ] Crash detection
- [ ] Friends
- [ ] Achievements
- [ ] Ride challenges
- [ ] Community rides
- [ ] Cloud sync improvements
- [ ] Live weather along the route
- [ ] Voice navigation
- [ ] Custom themes

Have an idea? [Request a feature](../../issues/new?template=feature_request.yml).

## Contributing

Contributions are welcome. Please read the [Contributing Guide](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md) first.

1. **Fork** the repository and clone your fork.
2. **Branch** from `main`:
   ```bash
   git checkout -b feature/short-description
   ```
3. **Commit** focused changes using [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:` …), and make sure `flutter analyze` and `flutter test` pass.
4. **Open a pull request** against `main` describing what changed and why, with screenshots for UI changes.

- 🐛 [Report a bug](../../issues/new?template=bug_report.yml)
- ✨ [Request a feature](../../issues/new?template=feature_request.yml)
- 🔒 Security issues: please follow the [Security Policy](SECURITY.md) instead of opening a public issue.

## License

RideSync is released under the [MIT License](LICENSE).

## Credits

RideSync is built on these projects and services:

- [Flutter](https://flutter.dev): the UI toolkit.
- [Firebase](https://firebase.google.com): authentication, Realtime Database and Cloud Firestore.
- [OpenStreetMap](https://www.openstreetmap.org/copyright): map tiles and map data, © OpenStreetMap contributors.
- [flutter_map](https://github.com/fleaflet/flutter_map): map rendering.
- [Photon](https://photon.komoot.io) by komoot: place and fuel-station search.
- [Overpass API](https://overpass-api.de): fuel-station data.
- [OSRM](https://project-osrm.org): road routing.
- [Nominatim](https://nominatim.org): reverse geocoding for ride names.
- [Open-Meteo](https://open-meteo.com): weather data (CC BY 4.0).

---

<div align="center">
<sub>Made for riders. Map data © <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors.</sub>
</div>
