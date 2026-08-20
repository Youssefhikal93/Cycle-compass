# Cycle Compass codebase explanation

This document describes the current Flutter application, every Dart file under
`lib/`, and the main runtime flows. Cycle Compass is an offline-first menstrual
cycle education and tracking app. SQLite is the source of persisted data; there
is no account, backend API, or cloud synchronization layer.

## Architecture at a glance

The application uses a small, direct layered architecture:

```text
Flutter screens and widgets
          │
          │ call commands and read immutable views
          ▼
AppController (ChangeNotifier)
          │
          ├── CycleCalculator (pure calculation service)
          ├── CycleNotificationService (Android local scheduling)
          ├── BackupCodec + BackupService (backup file format and file/share IO)
          │
          ▼
AppDatabase (SQLite)
          │
          ▼
UserProfile + calendar-history models
```

- Widgets do not query SQLite directly.
- `AppController` owns the in-memory profile, period entries, intercourse
  entries, and life-stage history, coordinates writes, and notifies the UI
  after changes.
- `AppDatabase` converts SQLite rows to and from model objects.
- `CycleCalculator` is stateless and performs estimates from supplied dates.
- `CycleNotificationService` schedules reminders locally; Firebase and a
  backend are not involved.
- Dates used for cycle tracking are normalized to date-only `DateTime` values.
- All "current time" reads go through the overridable `appNow()` function in
  `lib/services/clock.dart` instead of `DateTime.now()`. Golden tests pin it to
  a fixed date so rendered screenshots stay stable over time; new code should
  keep using `appNow()`.

## Application startup and navigation

1. `main()` initializes Flutter, opens `cycle_compass.db`, and initializes the
   local notification service with the device time zone.
2. An `AppController` is created with the database and notification service,
   then loads the saved profile and calendar history.
3. `CycleCompassApp` listens to the controller.
4. If no profile exists, the app shows onboarding. If a profile exists, it
   shows the four-tab home shell.
5. The home shell keeps Today, Calendar, Learn, and Profile alive in an
   `IndexedStack`, so switching tabs does not recreate each tab's local state.

## State and data flow

For a typical user action, such as logging a period start:

```text
User taps a screen action
        │
        ▼
Screen validates/collects a date
        │
        ▼
AppController.logPeriodStart(...)
        │
        ├── applies pregnancy/postpartum rules
        ├── writes through AppDatabase
        ├── reloads/sorts period entries
        ├── updates UserProfile.lastPeriodStart
        └── notifyListeners()
                │
                ▼
AnimatedBuilder rebuilds the affected UI
```

`AppController.inMemory()` follows the same public behavior without SQLite and
is used by widget tests and golden previews.

## Persistence model

The database is currently schema version 7 and contains four tables:

### `profile`

A single row with `id = 1`. It stores:

- name, date of birth, and optional managed avatar path;
- latest period start, configured cycle length, and configured period length;
- pregnancy flag, pregnancy start, and expected pregnancy due date;
- the theme preference (system, light, or dark);
- a retained-but-unused `next_period_due_date` column (the manual override
  feature was removed; old backups containing it still restore);
- postpartum tracking start and end dates.
- whether cycle and mode-change notifications are enabled; the default is on.

### `period_entries`

One row per unique period start. `start_date` is required and unique;
`end_date` is optional. An explicit end date represents the last recorded
bleeding day. Without one, the UI uses the profile's usual period length as an
estimate. The `source` column currently defaults to `user`.

### `daily_logs`

Stores one optional protected/unprotected intercourse status per date. The
existing flow, pain, mood, energy, and note columns remain available for future
daily tracking.

### `life_stage_entries`

Stores completed pregnancy and postpartum history ranges. Each row has a stage
type plus inclusive start and end dates. Ranges cannot overlap, and completed
history cannot end in the future.

All stored cycle dates use `YYYY-MM-DD` text. The database upgrade callback adds
pregnancy, postpartum, intercourse, notification, and theme columns for older
users, and creates `life_stage_entries` when needed.

## Backup file format

Backups are single UTF-8 JSON files with the `.ccbackup` extension, named
`cycle-compass-YYYY-MM-DD.ccbackup`. The app never uploads them; the export
flow writes a temporary file in app-private storage and hands it to the
Android share sheet, so the user decides where the file goes.

Every file starts with the same envelope header:

```json
{"format": "cycle-compass-backup", "version": 1, "encrypted": false,
 "exportedAt": "<ISO-8601>", ...}
```

- Plain files carry the payload directly in a `data` object with four keys —
  `profile` (object or null), `periodEntries`, `dailyLogs`, and
  `lifeStageEntries` — whose rows mirror the SQLite column names.
- Encrypted files (the default) add `kdf` (PBKDF2-HMAC-SHA256, 210,000
  iterations, base64 16-byte salt), `cipher` (AES-256-GCM, base64 12-byte
  nonce), `ciphertext` (base64 encrypted bytes of the JSON-encoded `data`
  object), and `mac` (base64 16-byte GCM authentication tag).

Restore safety rules, enforced by `BackupCodec` before anything is written:

- files with the wrong `format` value, malformed JSON, or a `version` newer
  than the app are rejected with user-readable messages;
- KDF iterations read from the file are bounded (1–2,000,000) so a hostile
  file cannot stall the app;
- every row is validated column by column: unknown columns are dropped, enum
  columns must hold known values, dates must parse, and duplicate
  `start_date`/`log_date`/`id` keys are rejected up front;
- a wrong passphrase and a tampered file both fail GCM authentication and
  surface as one retryable passphrase error;
- the database import replaces all four tables in a single transaction, so a
  restore either lands completely or leaves the previous data untouched.

## Cycle calculation rules

`CycleCalculator.calculate()` returns a `CycleSnapshot` for a requested date.
Its estimate source has the following practical precedence:

1. If a date lies between two recorded starts, those starts are treated as the
   exact boundaries of a completed cycle.
2. Otherwise, recent valid recorded intervals are used. The calculator takes
   the median of up to six recent intervals between 15 and 60 days, limiting
   the effect of an outlier.
3. If there is not enough history, the configured cycle length is used.

The next period is always derived automatically; there is no manual override.
The Profile screen shows the derived date as read-only information, and logging
the real period on the calendar naturally corrects the estimate.

The estimated ovulation day is approximately cycle length minus 14 and is
clamped so it occurs after the bleeding estimate and before the next period.
The result is educational calendar estimation, not confirmation of ovulation.

The monthly insight API compares recorded intervals with the configured cycle
length and labels a start as early, late, or matching the expected day. It also
flags intervals outside the commonly described 21–35-day adult range so the UI
can show cautious guidance.

## Pregnancy and postpartum lifecycle

Pregnancy and postpartum are one coupled tracking flow:

```text
Normal cycle tracking
        │ enable pregnancy mode (due date required)
        ▼
Pregnancy mode
  - period and phase estimates paused
  - period logging disabled before due date
        │ current date reaches expected due date
        ▼
Postpartum mode (derived automatically)
  - estimates remain paused
  - postpartum calendar days use muted brown
  - first postpartum period action becomes available
        │ user logs first real period after pregnancy
        ▼
Normal cycle tracking resumes
  - first period becomes the new cycle anchor
  - postpartum start/end history is preserved
```

The persisted `isPregnant` flag remains true through active postpartum
tracking. `UserProfile.isPostpartumOn(date)` derives whether the due date has
arrived. This means no background job or database migration is needed at
midnight; the next rebuild derives the correct mode from the current date.

`UserProfile.isPostpartumDate()` supplies the historical/active postpartum date
range used by the Calendar. The first new period day is excluded from the brown
range because it starts a normal menstrual cycle and receives the menstruation
color.

Synchronization rules are enforced in `AppController`, not only in the UI:

- pregnancy mode cannot be enabled without an expected due date;
- a period cannot be logged before that due date while pregnancy is active;
- logging the first period on or after the due date ends postpartum tracking;
- editing that first period also updates `postpartumEndedOn`;
- deleting that first period reopens postpartum mode;
- moving the first postpartum period before the postpartum start is rejected.

The pregnancy due date (`dueDate`) is unrelated to menstrual next-period
estimates, which are always derived automatically from cycle data.

Completed pregnancy and postpartum history is stored separately from the
current-mode profile fields. This lets users add, edit, and delete past ranges
without turning current pregnancy mode on or changing current cycle tracking.

## File-by-file guide for `lib/`

### `lib/main.dart`

The executable entry point and application composition root.

- Opens the database, creates the controller, loads local data, and calls
  `runApp`.
- `CycleCompassApp` selects onboarding or the main application based on
  `controller.isOnboarded`.
- Defines the shared Material 3 theme: color scheme, typography, input fields,
  buttons, navigation bar, and snackbars. Light and dark themes are built from
  the same seed color; the active mode comes from the saved theme preference
  (system, light, or dark) exposed by the controller.
- Sets the app locale to day-first `en_GB`, so date pickers accept manual
  entry as DD/MM/YYYY and displayed dates read like "19 August 2026".
  `initializeAppLocale()` loads the date symbols and is shared with tests.
- The Android launch screen (blood-drop logo on a themed surface, with dark
  variants and Android 12+ styles) and the adaptive launcher icon live under
  `android/app/src/main/res/`.

This is the best place for application-wide initialization and theme changes.

### `lib/app_controller.dart`

The central state coordinator and mutation API.

- Holds the current `UserProfile` and an immutable public view of period
  entries, intercourse entries, and completed life-stage ranges.
- Loads and persists data through `AppDatabase`.
- Completes onboarding and creates the initial period entry.
- Adds, edits, deletes, and adjusts period ranges.
- Keeps `lastPeriodStart` and postpartum end dates synchronized with history
  changes.
- Exposes the persisted theme preference and `setThemeMode(...)`.
- Enforces pregnancy/postpartum transition rules.
- Adds or replaces one intercourse status per date.
- Rejects moving a period start onto a date that already has another entry, so
  an edit can never silently merge or destroy an existing record.
- Validates, sorts, and persists non-overlapping past pregnancy/postpartum
  ranges.
- Builds backup payloads (`createBackupPayload`) and restores them
  (`restoreBackup`), in both the SQLite and in-memory modes, resyncing
  notifications afterwards.
- Clears all database state during reset.
- Reconciles scheduled phase and mode-change reminders after tracking changes.
- Requests Android notification permission and persists the default-on setting.
- Offers an in-memory constructor for tests.

New persistent user actions should normally be added here rather than directly
inside a screen.

### `lib/data/app_database.dart`

The SQLite adapter.

- Opens `cycle_compass.db` at schema version 7.
- Creates and upgrades the `profile`, `period_entries`, `daily_logs`, and
  `life_stage_entries` tables.
- Reads and replaces the single profile row.
- Inserts, updates, and deletes period entries.
- Reads and writes intercourse entries in `daily_logs`.
- Inserts, updates, reads, and deletes `life_stage_entries`.
- Uses a transaction when moving a period start so a compatible end date is
  preserved.
- Exports every row of every table for backups (`exportAllData`) and replaces
  all tables from a validated backup in one transaction (`importAllData`).
- Deletes all local rows transactionally.

SQL details and future schema migrations belong in this file.

### `lib/models/user_profile.dart`

The immutable profile and tracking-status model.

- Stores personal data, cycle defaults, pregnancy fields, the user-entered
  postpartum tracking dates, notification preference, and theme preference
  (stored as text, exposed as Flutter's `ThemeMode`).
- Derives active postpartum state and whether a calendar date belongs to the
  postpartum range.
- Provides `copyWith`; nullable fields use a sentinel so callers can distinguish
  “leave unchanged” from “set to null.”
- Generates initials and maps the object to/from SQLite rows.

### `lib/models/period_entry.dart`

A small immutable model for one bleeding record.

- `startDate` is Day 1 of the period.
- `endDate` is the optional last recorded bleeding day.
- `durationDays` returns an inclusive duration.
- `contains()` identifies whether a date lies in an explicitly recorded range.

### `lib/models/intercourse_entry.dart`

Defines protected and unprotected statuses and one date-based intercourse
entry. The status extension supplies the displayed label and SQLite value.

### `lib/models/life_stage_entry.dart`

Defines pregnancy and postpartum history types plus an inclusive completed
date range. Entries carry their SQLite ID after they are saved.

### `lib/services/cycle_calculator.dart`

The pure cycle-estimation domain service.

- Defines `CyclePhase`, `CycleEstimateBasis`, and `CycleTiming`.
- `CycleSnapshot` contains phase, cycle day, effective length, cycle anchors,
  next period, estimated ovulation, and confidence basis.
- `CycleIntervalInsight` describes early/late comparisons and range warnings.
- `CycleCalculator` handles recorded cycles, median history estimates, phase
  assignment, negative-date rollover, normalization, and monthly insights.

It has no Flutter widgets, database access, or mutable state, so it is directly
unit-testable.

### `lib/services/clock.dart`

A one-line overridable clock: `appNow`, defaulting to `DateTime.now`. All code
in `lib/` reads the current moment through it (the only exception is the
millisecond timestamp inside avatar file names). Tests — especially golden
screenshot tests — pin it to a fixed date for reproducible output.

### `lib/services/backup_codec.dart`

The pure-Dart backup file format: envelope encode/decode, PBKDF2 key
derivation, AES-256-GCM encrypt/decrypt, and full payload validation. Defines
`BackupData`, `BackupPayload`, `BackupEnvelope`, and the sealed
`BackupException` hierarchy (`BackupFormatException`,
`BackupPassphraseException`) whose messages are written for end users. It has
no Flutter imports, so the whole format is unit-testable. See the "Backup file
format" section above for the envelope layout and validation rules.

### `lib/services/backup_service.dart`

The thin file and platform layer for backups: writes the export to a temporary
app-private file and opens the Android share sheet (`share_plus`), and reads a
user-picked file back as text (`file_picker`). Everything that touches a
platform channel lives here so `BackupCodec` stays a plain Dart unit.

### `lib/services/cycle_notification_planner.dart`

Builds the future around-9:00-AM reminder plan from the same `CycleCalculator`
used by the UI. It emits each estimated phase transition, uses cautious
ovulation copy, and replaces phase reminders with the expected due-date mode
reminder while pregnancy tracking is active.

### `lib/services/cycle_notification_service.dart`

Initializes the Android local-notification plugin and device time zone,
reconciles the next 180 days of reminders, schedules them to run during idle,
and cancels only Cycle Compass-owned pending notifications. Android receivers
restore scheduled reminders after reboot or an app update.

### `lib/screens/onboarding_screen.dart`

The two-step first-run flow.

- Step 1 collects name, date of birth, and an optional profile photo.
- Step 2 collects latest period start, usual cycle length, and usual bleeding
  length.
- Validates required personal data and constrains date pickers/sliders.
- Builds a `UserProfile` and calls `controller.completeOnboarding()`.
- Includes reusable private cards and privacy/estimation information strips.

### `lib/screens/home_shell.dart`

The post-onboarding navigation container.

- Owns the selected bottom-navigation index.
- Displays Today, Calendar, Learn, and Profile in an `IndexedStack`.
- Lets Today open Profile by changing the selected index.
- Explains and requests Android notification permission when default-on
  reminders do not yet have permission.

### `lib/screens/today_screen.dart`

The main current-day experience.

In normal tracking mode it:

- calculates today's snapshot from profile defaults and logged history;
- corrects the menstruation phase using an explicitly recorded bleeding end;
- displays the cycle ring, confidence basis, phase journey, education card,
  next-period wording, and “period started today” action;
- lets the user tap any phase tile to preview that phase in the education card
  below, with a highlight border and a "Back to my phase" action.

When `profile.isPregnant` is true, it switches to `_PregnancyTodayView`:

- before the due date it displays Pregnancy mode and pauses estimates;
- on/after the due date it displays Postpartum mode and offers a date picker
  for the first real postpartum period;
- it includes safety copy distinguishing postpartum bleeding from menstruation.

This file also owns the phase color and icon helpers shared by Learn and
Calendar.

### `lib/screens/calendar_screen.dart`

The month grid, date-management UI, and month explanation layer.

- Navigates between months with the arrow buttons, a horizontal swipe, or a
  tap on the month title, which opens month/year scroll wheels, and
  shows a jump-back-to-current-month button when another month is displayed.
- Calculates each cell's phase.
- Opens one day editor for protected/unprotected sex and period actions.
- Uses explicit period ranges before estimated bleeding lengths.
- Marks period starts, today, and recorded bleeding days, and shows a baby
  icon on the expected pregnancy due date.
- Pauses phase coloring during pregnancy.
- Colors postpartum days muted brown and gives the expected pregnancy due date
  a matching outline.
- Colors completed pregnancy and postpartum history ranges and marks intercourse
  entries with distinct icons.
- Adds/manages period starts and recorded end dates from dialogs and bottom
  sheets, including “add one more day.”
- Shows legends and a monthly summary for early/late intervals, duration
  differences, and cautious range guidance. A legend appears
  only when its phase or event occurs in the displayed month.

### `lib/screens/learn_screen.dart`

Static educational content for the four commonly described cycle stages.

- Uses expandable cards for menstruation, follicular, ovulation, and luteal
  information.
- Reuses the phase colors from Today.
- Contains source/safety language and explicitly states the limitations of the
  app's estimates.

### `lib/screens/profile_screen.dart`

The complete local-data management screen.

- Displays and edits name, date of birth, avatar, cycle length, and usual period
  length.
- Shows the automatically derived next-period date as read-only information.
- Offers the theme preference (System / Light / Dark) in an Appearance group.
- Lets the user turn all phase and mode-change reminders on or off.
- Groups pregnancy and postpartum settings in one coupled section.
- Adds, edits, and deletes completed pregnancy or postpartum history ranges in
  that section without changing current mode.
- Requires a pregnancy due date, shows the derived current mode, and preserves
  previous postpartum tracking dates.
- Lists recent period entries and supports adding, moving, deleting, extending,
  shortening, or clearing an explicit bleeding end date.
- Exports and imports backups: the export sheet encrypts with a passphrase by
  default (with a confirm field and a plain-export warning), and the import
  flow picks a file, asks for the passphrase when needed (with retry), and
  requires explicit confirmation before replacing all local data.
- Makes Personal details, Cycle settings, Notifications, Pregnancy & postpartum,
  Backup & restore, Period history, and Privacy individually collapsible and
  initially expanded.
- Deletes the managed avatar and all local database data after confirmation.

Most editing is implemented with modal bottom sheets and date pickers, while
the controller remains responsible for domain validation and persistence.

### `lib/widgets/profile_avatar.dart`

Shared avatar presentation and local image management.

- `ProfileAvatar` displays a saved local image when it exists, otherwise user
  initials.
- `EditableProfileAvatar` opens gallery/remove actions and adds camera-button
  affordance and accessibility semantics.
- Selected images are copied into application-support storage rather than
  retaining a temporary picker path.
- Old images are deleted only when their path is inside the managed app
  directory.
- `initialsFor()` handles blank, single-part, and multi-part names.

## Where to make common changes

| Change | Primary file(s) |
| --- | --- |
| Global colors/theme | `lib/main.dart` |
| Add a persisted profile field | model, `app_database.dart`, controller, migration |
| Add a calendar history type | model, `app_database.dart`, controller, Calendar and Profile |
| Change cycle math | `services/cycle_calculator.dart` and unit tests |
| Change the backup format | `services/backup_codec.dart`, bump `backupFormatVersion`, unit tests |
| Change backup sharing/picking | `services/backup_service.dart` |
| Change pregnancy/postpartum rules | `user_profile.dart`, `app_controller.dart`, relevant screens |
| Change calendar colors or cell markers | `screens/calendar_screen.dart` |
| Add a new bottom tab | `screens/home_shell.dart` plus a new screen |
| Add profile editing behavior | `screens/profile_screen.dart`, then controller if persistent |
| Change avatar behavior | `widgets/profile_avatar.dart` |
| Change splash screen or launcher icon | `android/app/src/main/res/` (drawables, mipmaps, values/values-v31 styles and colors) |
| Change date locale/format | `lib/main.dart` (`appLocale`, `initializeAppLocale`) |

## Safety and product boundaries

- All calculations are estimates and should not be used as contraception,
  diagnosis, or confirmation of ovulation or pregnancy.
- Pregnancy mode records a user preference; it does not verify or monitor a
  pregnancy.
- “Postpartum mode ended” means app tracking resumed after a recorded period;
  it does not mean clinical postpartum recovery has ended.
- Medical wording should receive qualified clinical review before public
  release.
