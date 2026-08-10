# Teacher Demonstration Guide

## What to submit

The safest final handoff contains three parts:

1. A short live presentation on your own tested device.
2. An installable Android APK for convenient independent testing.
3. A ZIP of the source project for assessment and backup.

Also include a one-page PDF or slide containing the problem, target user,
solution, key features, testing evidence and a QR code/link to the files.

Do not depend on a teacher having Flutter installed. Treat the source project as
evidence and the APK as the runnable product. If the teacher uses an iPhone,
demonstrate from your device or provide a hosted web build; an APK cannot be
installed on iOS.

## Recommended presentation story

Keep the demonstration to approximately five minutes and tell one clear user
story instead of listing every screen.

### 1. Establish the problem

“A person who has just moved to Canada Bay has to search across council,
community and environmental websites to understand their new area.”

Explain that the application centralises practical information and makes local
participation feel approachable.

### 2. Introduce a realistic user

Use a short scenario, such as a new resident who wants to understand bin
collection, find a walking route and meet a community group.

### 3. Demonstrate the journey

Follow this order:

1. Select a language and complete the newcomer introduction.
2. Use Home to see the most important personalised starting points.
3. Open Local Services and find a practical civic answer.
4. Open Community and discover an activity or organisation.
5. Open Explore, start a GPX route and show the mapped route.
6. Scan a prepared demonstration QR code.
7. Finish on Passport and show how the discovery becomes progress, XP or a
   collection stamp.

This ending shows that Passport is the thread connecting civic learning,
community participation and exploration—not a separate leaderboard.

### 4. Explain technical decisions

Briefly mention:

- Flutter provides phone, web and desktop layouts from one codebase.
- JSON keeps local content structured and maintainable.
- GPX files provide real route geometry.
- Supabase supports optional accounts while guest access remains available.
- The QR scanner activates only on its own tab.
- The map is constrained around the relevant local area.

### 5. Finish with evaluation

Show how the product meets the Product Brief and acknowledge sensible next
steps: verified council content maintenance, cloud passport synchronisation and
production-secure QR redemption.

## Demonstration preparation

- Use a fully charged physical phone where possible.
- Install and open the final build before the assessment.
- Complete one clean rehearsal from onboarding to Passport.
- Prepare two printed QR rewards and test both immediately beforehand.
- Ensure the Supabase project is available if demonstrating sign-in.
- Keep a guest-mode path ready in case school internet blocks authentication.
- Save screenshots or a short screen recording as a no-network backup.
- Disable notification pop-ups and unrelated apps during the presentation.
- Do not expose API keys, account passwords or private dashboards on screen.

## Handoff folder

Suggested structure:

```text
Explore_Canada_Bay_Submission/
  Explore_Canada_Bay.apk
  Source_Code.zip
  Product_Brief.pdf
  Design_Portfolio.pdf
  Demo_Video.mp4
  README.pdf
```

The APK should be tested on another Android device before submission. The source
ZIP should exclude temporary build folders but retain `lib/`, `assets/`,
`android/`, `ios/`, `web/`, `test/`, `pubspec.yaml`, `pubspec.lock` and the
project documentation.

## If the teacher runs the source

From the extracted project folder:

```powershell
flutter pub get
flutter run -d chrome
```

Guest mode requires no account configuration. For full account testing, provide
the public Supabase values separately rather than embedding secret credentials
in the submitted source.
