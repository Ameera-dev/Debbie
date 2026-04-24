# Debbie — Mindful Money Companion

> Mindful money tracking — connect your spending to your values, not just your numbers.

Debbie is a cross-platform mobile app (Android & iOS) that transforms financial tracking into a practice of mindful living. Instead of traditional budgeting, Debbie connects your daily spending to your core personal values — helping you see not just where your money goes, but whether it reflects what matters most to you.

---

## Screenshots

> Coming soon.

---

## Features

- **Values-based tracking** — tag every transaction to a personal value (Family, Health, Growth, Freedom, etc.)
- **Values Wheel** — a custom animated donut chart showing how your energy is distributed across what you care about
- **Alignment Score** — see how closely your actual spending matches your monthly intentions
- **Impact Goals** — set and track meaningful financial goals linked to your values
- **Multi-item sessions** — log a full shopping trip as a single session with multiple line items
- **Weekly reflection & journal** — write about your relationship with money, not just the numbers
- **AI-powered insights** — weekly spending narratives and reflection prompts powered by Gemini
- **Transaction photo attachments** — capture receipts and screenshots per transaction
- **Google Drive backup** — full data + photo backup as a single ZIP file, with auto-backup support
- **Dark mode** — full warm dark theme throughout
- **Offline-first** — everything runs on-device; internet is only needed for AI insights and backup

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x (Dart) |
| State management | Riverpod |
| Navigation | GoRouter |
| Database | sqflite (SQLite) |
| Fonts | Google Fonts — Lora + Nunito |
| Charts | fl_chart + CustomPainter |
| Images | image_picker + flutter_image_compress + photo_view |
| Backup | Google Drive API + archive (ZIP) |
| AI | Google Gemini API |
| Animations | flutter_animate + built-in Flutter animations |

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x stable)
- Android Studio or Xcode (for emulator/simulator)
- A Google Cloud project with **Google Drive API** and **Gemini API** enabled (optional — app works fully without them)

### Installation

```bash
# Clone the repository
git clone https://github.com/YOUR_ORG/debbie.git
cd debbie

# Install dependencies
flutter pub get

# Run on Android
flutter run -d android

# Run on iOS
flutter run -d ios
```

### Environment Setup (optional)

For AI reflection and Google Drive backup, you need API keys:

- **Gemini API key** — enter it in the app under Settings → AI Reflection
- **Google Drive** — sign in with Google directly inside the app under Settings → Data

No `.env` files or build-time secrets are needed. All credentials are entered and stored on-device by the user.

---

## Project Structure

```
lib/
├── app/                    # Router and theme
├── data/
│   ├── database/           # SQLite helper and migrations
│   ├── models/             # Immutable data models
│   └── repositories/       # All database access
├── features/
│   ├── onboarding/         # 6-screen onboarding flow
│   ├── dashboard/          # Home screen with Values Wheel
│   ├── transactions/       # Add, edit, list, and detail screens
│   ├── reflect/            # Weekly check-in and Money Story journal
│   ├── analytics/          # Spending analytics and charts
│   ├── settings/           # Appearance, data, backup, and AI settings
│   └── splash/             # Splash screen
├── providers/              # Riverpod providers (one per domain)
├── services/               # Google Drive, image, AI, insights
└── shared/
    ├── constants/          # Strings, default values, colors
    ├── utils/              # Currency formatting, date helpers
    └── widgets/            # Reusable UI components
```

---

## Design Philosophy

The UI is designed to feel like a **calm, premium journaling app** — not a finance spreadsheet.

- **Warm off-white background** (`#FAF8F5`) with terracotta (`#C4704B`) and sage green (`#8BA888`) accents
- **Lora** (serif) for headings, **Nunito** for body text, **JetBrains Mono** for numbers
- Smooth 300ms+ transitions, haptic feedback on save, staggered list animations
- No "budget" language anywhere — uses: *Values Plan, energy, alignment, intention, purpose*

---

## Currency

Default currency is **Indonesian Rupiah (IDR)**, formatted as `Rp 1.250.000`. All amounts are stored as integers (IDR has no sub-units), avoiding floating point issues entirely.

---

## Data & Privacy

- All data is stored **locally on-device** using SQLite
- No analytics, no tracking, no third-party data collection
- Google Drive is used **only** for backup/restore at the user's explicit request
- No ads, ever

---

## License

MIT
