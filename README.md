<div align="center">

# Debbie

**A mindful money companion that connects spending to what you actually value.**

[![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS-0aa)](#)
[![Local-first](https://img.shields.io/badge/Local--first-SQLite-success)](#)
[![License](https://img.shields.io/badge/License-Unlicensed-lightgrey)](#license)

</div>

Debbie is a local-first Flutter app for Android and iOS that reframes personal finance as a practice of mindful living. Instead of restrictive budgets, it helps you tag every transaction with the values it serves — growth, family, freedom, generosity — and reflect on whether your money is moving in the direction of the life you want.

> No ads. No analytics. No accounts. Your data lives on your device.

---

## Table of Contents

- [Why Debbie](#why-debbie)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [Optional Integrations](#optional-integrations)
  - [Gemini AI](#gemini-ai)
  - [Google Drive Backup](#google-drive-backup)
- [Project Layout](#project-layout)
- [Data & Privacy](#data--privacy)
- [Contributing](#contributing)
- [License](#license)

---

## Why Debbie

Most finance apps make you feel watched. Debbie is built on a different premise:

- **Values over budgets.** You don't restrict — you align. Every Rupiah is energy moving toward something you care about.
- **Reflection over reporting.** Charts are useful, but the real insight comes from journaling about *why* you spent.
- **Privacy by default.** Everything runs offline; cloud is opt-in and only used for your own backups.
- **A calm interface.** The app feels like a journal, not a spreadsheet — warm typography, generous whitespace, gentle motion.

## Features

- **Values-first onboarding** — pick, prioritize, and allocate a monthly Values Plan
- **Multi-item transactions** with notes, tags, goals, receipt photos, and place labels
- **Values Wheel & alignment score** to compare planned vs. actual spending
- **Impact Goals** tied to the values that matter most
- **Daily intentions and weekly planning** for short-horizon awareness
- **Recurring bills & subscriptions** with monthly payment tracking and history
- **Reflection tools** — weekly check-ins, monthly Money Story entries, guided prompts
- **Optional AI** for reflections, spending insights, value suggestions, and receipt scanning (Gemini)
- **Export & backup** — CSV, Excel, and Google Drive ZIP backup/restore with daily auto-checks
- **Offline-first** with bundled fonts and local SQLite storage

## Tech Stack

| Layer | Technology |
| --- | --- |
| Framework | Flutter 3.41.x · Dart 3.11.4 |
| State management | `flutter_riverpod` |
| Navigation | `go_router` |
| Local persistence | `sqflite` + SQLite |
| Charts & visuals | `fl_chart`, `CustomPainter`, `flutter_animate` |
| Images | `image_picker`, `flutter_image_compress`, `photo_view` |
| Export | `csv`, `excel`, `share_plus` |
| Backup | Google Sign-In · Google Drive API · ZIP archives |
| AI (optional) | `google_generative_ai` (Gemini) |
| Location | `geolocator`, `geocoding`, OpenStreetMap place search |

## Getting Started

### Requirements

- [Flutter SDK](https://docs.flutter.dev/get-started/install) compatible with Dart `3.11.4`
- Xcode and/or Android Studio for simulators, emulators, and platform tooling
- *(Optional)* a Gemini API key for AI features
- *(Optional)* Google OAuth credentials for Drive backup and restore

### Install & Run

```bash
flutter pub get
flutter run
```

Target a specific device:

```bash
flutter devices
flutter run -d <device-id>
```

### Test

```bash
flutter test
```

### Build

```bash
flutter build apk --release        # Android
flutter build ios --release        # iOS (requires signing)
```

### Notes

- Fonts are bundled under `assets/google_fonts/`; runtime font fetching is disabled.
- Core flows work without API keys or cloud services.
- Currency is currently optimized for Indonesian Rupiah (`Rp`, `id_ID` locale).

---

## Optional Integrations

### Gemini AI

AI features are opt-in. Enter your API key in **Settings → AI Reflection** — it is stored on-device only.

Powered features:

- weekly reflections
- journal insights
- transaction value suggestions
- receipt scanning

### Google Drive Backup

Drive backup bundles the local database and transaction images into a single ZIP archive. Backup and restore require Google Sign-In to be configured for the build you are running.

> If Android sign-in fails with `ApiException: 10`, the OAuth client does not match the app package or signing key.

**Setup:**

1. Enable the **Google Drive API** in Google Cloud Console or Firebase.
2. Complete the **OAuth consent screen**.
3. Create an **Android OAuth client** for package `com.debbie.debbie`.
4. Register the SHA-1 for the keystore you are using. For the default debug keystore:

   ```bash
   keytool -list -v -alias androiddebugkey \
     -keystore ~/.android/debug.keystore \
     -storepass android -keypass android | rg SHA1
   ```

5. Create a **Web OAuth client** and pass it at runtime:

   ```bash
   flutter run \
     --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
   ```

6. For iOS, also create an **iOS OAuth client**, add the matching URL scheme to `Info.plist`, and pass both client IDs:

   ```bash
   flutter run \
     --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com \
     --dart-define=GOOGLE_IOS_CLIENT_ID=YOUR_IOS_CLIENT_ID.apps.googleusercontent.com
   ```

---

## Project Layout

```text
lib/
├── app/          # Router and theming
├── data/         # Database, tables, models, repositories
├── features/     # Onboarding, dashboard, transactions, reflect, recurring, settings
├── providers/    # Riverpod async/state providers
├── services/     # AI, Drive backup, export, images, location, suggestions
└── shared/       # Constants, utilities, reusable widgets

test/
└── data/         # Focused persistence and backup coverage tests
```

**Architectural conventions:**

- Repository pattern — screens never call `sqflite` directly.
- Money is stored as **integer IDR** (no sub-units, no floats). Formatting happens only in the UI layer.
- Image paths are stored **relative** in the DB; resolved at read time via `path_provider`.
- App copy lives in `shared/constants/strings.dart` — no inline magic strings.

---

## Data & Privacy

- All user data is stored **locally in SQLite** on the device.
- **No analytics, no ad SDKs, no third-party tracking.**
- Google Drive is used **only** for user-initiated backup and restore after sign-in.
- Network access is required only for opt-in features: AI, Drive backup, and place search.

## Contributing

This is currently a solo project, but issues and thoughtful PRs are welcome. Please:

- Match the existing code style (`flutter_lints`).
- Keep money as integer IDR — no floats anywhere in storage logic.
- Avoid "budget" language in user-facing copy. Prefer: *Values Plan, energy, alignment, intention, purpose.*
- Run `flutter test` before opening a PR.

## License

This repository does not currently include a `LICENSE` file. All rights reserved by the author until one is added.
