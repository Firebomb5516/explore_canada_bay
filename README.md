# Explore Canada Bay

Explore Canada Bay is a Flutter civic and community discovery app created for a
NSW Design & Technology project. It helps people who are new to the City of
Canada Bay discover local services, community activities, walking routes,
environmental places and local organisations.

The Community Passport connects these features by rewarding meaningful local
exploration through GPX journeys, QR discoveries, XP, stamps and badge
collections. An account is optional, so the core app can also be demonstrated
as a guest.

## Main features

- Personalised newcomer home screen
- Interactive Canada Bay map and place discovery
- GPX walking and cycling routes
- Community directory and newcomer journey
- Practical local service and safety information
- Community Passport, XP, badges and collections
- QR reward scanner with camera lifecycle protection
- Optional Supabase email authentication
- English, Simplified Chinese, Korean, Italian and Hindi support
- Responsive phone, web and desktop layouts

## Quick start

Requirements:

- Flutter SDK compatible with Dart `^3.12.1`
- Chrome for the simplest desktop demonstration, or a configured Android/iOS
  development environment for a phone build

From the project directory, run:

```powershell
flutter pub get
flutter run -d chrome
```

The app works in guest mode without Supabase. Camera scanning is best tested on
a physical phone; the scanner includes a debug manual-input option in debug
builds.

## Optional account configuration

Authentication is enabled only when both public Supabase values are supplied:

```powershell
flutter run -d chrome `
  --dart-define="SUPABASE_URL=https://YOUR_PROJECT.supabase.co" `
  --dart-define="SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY"
```

Use only the client publishable/anonymous key. Never include a Supabase
`service_role` key in the application, repository, screenshots or handoff.

Accounts provide authentication and connect unique Passport activities to the
shared Community Challenge. Passport progress remains available locally, while
signed-in challenge contributions, collective totals and the opt-in seasonal
leaderboard are stored in Supabase. Practical details entered during the guided
Journey—such as bin day, library reference and usual transport stop—also sync
to a private account-owned settlement profile while retaining an offline local
copy.

Before enabling the feature, apply the SQL migrations in `supabase/migrations/`
to the Supabase project. The migration creates the challenge tables, row-level
security policies and restricted RPC functions used by the app. Users only
publish a generated `Neighbour` alias when they explicitly join the
leaderboard; account names and email addresses are never returned publicly.

## Quality checks

Before creating a demonstration build, run:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

For an installable Android build:

```powershell
flutter build apk --release
```

The APK is normally generated at
`build/app/outputs/flutter-apk/app-release.apk`.

## Project references

- `PRODUCT_BRIEF.md` — single source of truth for the product
- `PROJECT.md` — project overview
- `DESIGN.md` — interface direction
- `CODING_RULES.md` — Flutter implementation rules
- `QR_REWARDS.md` — QR reward format and testing
- `TEACHER_DEMO_GUIDE.md` — presentation and handoff guide
- `RELEASE_CHECKLIST.md` — final readiness checklist

## Data and privacy

Local content is loaded from `assets/data/`, while route geometry is loaded from
`assets/gpx/`. Camera access is used for QR rewards and location access is used
to show nearby content. Public/social profiles are intentionally not part of the
current product.
