# Cycle Compass

Cycle Compass is an Android-first Flutter app that helps people understand the
four commonly described stages of the menstrual cycle. It is an educational,
offline-first MVP: cycle dates and profile details remain on the device and all
calendar predictions are clearly presented as estimates.

> Cycle Compass is not medical advice, a diagnostic tool, or a method of
> contraception. Public release content should be reviewed by a qualified
> clinician.

## MVP features

- Two-step onboarding for name, date of birth, and basic cycle information
- Optional gallery avatar with automatic first/last-name initials fallback
- Editable name, date of birth, avatar, cycle length, and period length
- Today view with cycle day, estimated phase, and next-period estimate
- Calendar view with phase colors and recorded period starts
- Educational content for menstruation, follicular, ovulation, and luteal stages
- One-tap period-start logging
- Local SQLite storage with Android cloud backup disabled
- Delete-all-data privacy control
- Responsive Material 3 interface with rendered phone-size preview tests

## Preview

| Onboarding | Today | Profile |
| --- | --- | --- |
| ![Onboarding](test/goldens/onboarding.png) | ![Today](test/goldens/home.png) | ![Profile](test/goldens/profile.png) |

## Project structure

```text
lib/
├── data/          SQLite database service
├── models/        Profile models
├── screens/       Onboarding and main app experiences
├── services/      Cycle phase calculation
├── widgets/       Shared avatar UI
├── app_controller.dart
└── main.dart
```

## Run locally

Requirements:

- Flutter SDK compatible with Dart `^3.12.2`
- Android Studio or an Android SDK with an emulator/device configured

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

The configured app ID is `com.hikoo.cyclecompass.cycle_compass`. Release signing
must be configured before publishing to Google Play.

## Current verification

- Flutter static analysis: no issues
- Cycle calculation unit tests: 5 passing
- Phone-size rendered preview tests: 3 passing

An Android APK could not be produced on the development machine because an
Android SDK is not currently installed/configured there. The Flutter source and
tests are complete; configuring the Android SDK is the remaining packaging step.
