# Release Readiness Checklist

## Product

- [ ] Every feature supports the Product Brief and target newcomer journey.
- [ ] All primary navigation paths work from Home and bottom navigation.
- [ ] Empty, loading, offline and permission-denied states are understandable.
- [ ] No placeholder, test or misleading production content is visible.
- [ ] Official links, addresses, phone numbers and service information are
      manually verified.

## Passport and QR

- [ ] XP, badge progress, collections and featured achievements persist after a
      restart.
- [ ] Repeated scans cannot incorrectly award the same one-time reward.
- [ ] Production QR rewards are signed or validated by a backend.
- [ ] Debug QR tools are unavailable in release builds.
- [ ] Guest progress has a defined migration path when an account is created.

## Accounts and privacy

- [ ] Sign-up, sign-in, verification, password reset, sign-out and session
      restoration work on a real phone.
- [ ] Account deletion and data deletion are available before public release.
- [ ] Supabase Row Level Security protects every user-owned table.
- [ ] Only public client configuration is bundled with the app.
- [ ] Privacy policy and support contact are available.
- [ ] Public profiles remain disabled unless explicit consent, moderation,
      blocking and reporting have been designed.

## Accessibility and language

- [ ] All user-facing strings change with the selected language.
- [ ] Official place names remain unchanged where appropriate.
- [ ] Text remains usable with large accessibility font sizes.
- [ ] Colour contrast, tap target size and screen-reader labels are checked.
- [ ] Every supported language is reviewed by a fluent speaker where possible.

## Device and platform testing

- [ ] Tested on a physical Android phone.
- [ ] Tested on the smallest supported phone layout.
- [ ] Tested in portrait and landscape where supported.
- [ ] Camera, location and notification permission flows work.
- [ ] Scanner camera activates only while the Scan tab is active.
- [ ] Map tiles, bounds, markers, GPX routes and route selection work.
- [ ] Slow network, offline mode and app restart are tested.
- [ ] Chrome/web layout is tested as a presentation fallback.

## Engineering checks

- [ ] `dart format --output=none --set-exit-if-changed lib test` passes.
- [ ] `flutter analyze` passes with no issues.
- [ ] `flutter test` passes.
- [ ] Release APK builds successfully.
- [ ] The release APK is installed and tested on a second device.
- [ ] Production map tiles use an appropriate provider with attribution.
- [ ] Crash reporting is configured for a public release.
- [ ] The project is stored in version control with a release tag/backup.

## Presentation handoff

- [ ] Teacher demonstration has been rehearsed and timed.
- [ ] Demonstration QR codes are printed and tested.
- [ ] APK, source ZIP, portfolio and backup video are readable from the handoff
      folder.
- [ ] No passwords or private keys appear in files, screenshots or videos.
- [ ] Guest mode works without Supabase or school internet.
