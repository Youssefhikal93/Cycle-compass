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
          │
          ▼
AppDatabase (SQLite)
          │
          ▼
UserProfile + PeriodEntry models
```

- Widgets do not query SQLite directly.
- `AppController` owns the in-memory profile and period-entry list, coordinates
  writes, and notifies the UI after changes.
- `AppDatabase` converts SQLite rows to and from model objects.
- `CycleCalculator` is stateless and performs estimates from supplied dates.
- Dates used for cycle tracking are normalized to date-only `DateTime` values.

## Application startup and navigation

1. `main()` initializes Flutter and opens `cycle_compass.db`.
2. An `AppController` is created with the database and loads the saved profile
   and period entries.
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

The database is currently schema version 4 and contains three tables:

### `profile`

A single row with `id = 1`. It stores:

- name, date of birth, and optional managed avatar path;
- latest period start, configured cycle length, and configured period length;
- pregnancy flag, pregnancy start, and expected pregnancy due date;
- an optional user-entered next-period due date;
- postpartum tracking start and end dates.

### `period_entries`

One row per unique period start. `start_date` is required and unique;
`end_date` is optional. An explicit end date represents the last recorded
bleeding day. Without one, the UI uses the profile's usual period length as an
estimate. The `source` column currently defaults to `user`.

### `daily_logs`

Reserved for future flow, pain, mood, energy, and note tracking. The table is
created and cleared by the app, but the current UI does not write to it.

All stored cycle dates use `YYYY-MM-DD` text. The database upgrade callback adds
new pregnancy, manual period due-date, and postpartum columns for older users.

## Cycle calculation rules

`CycleCalculator.calculate()` returns a `CycleSnapshot` for a requested date.
Its estimate source has the following practical precedence:

1. If a date lies between two recorded starts, those starts are treated as the
   exact boundaries of a completed cycle.
2. Otherwise, recent valid recorded intervals are used. The calculator takes
   the median of up to six recent intervals between 15 and 60 days, limiting
   the effect of an outlier.
3. If the user set a next-period due date after the latest start, that date
   overrides the automatic future estimate.
4. If there is not enough history, the configured cycle length is used.

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

The pregnancy due date (`dueDate`) and the optional next menstrual period due
date (`nextPeriodDueDate`) are intentionally separate concepts.

## File-by-file guide for `lib/`

### `lib/main.dart`

The executable entry point and application composition root.

- Opens the database, creates the controller, loads local data, and calls
  `runApp`.
- `CycleCompassApp` selects onboarding or the main application based on
  `controller.isOnboarded`.
- Defines the shared Material 3 theme: color scheme, typography, input fields,
  buttons, navigation bar, and snackbars.

This is the best place for application-wide initialization and theme changes.

### `lib/app_controller.dart`

The central state coordinator and mutation API.

- Holds the current `UserProfile` and an immutable public view of period
  entries.
- Loads and persists data through `AppDatabase`.
- Completes onboarding and creates the initial period entry.
- Adds, edits, deletes, and adjusts period ranges.
- Keeps `lastPeriodStart`, manual next-period due dates, and postpartum end
  dates synchronized with history changes.
- Enforces pregnancy/postpartum transition rules.
- Clears all database state during reset.
- Offers an in-memory constructor for tests.

New persistent user actions should normally be added here rather than directly
inside a screen.

### `lib/data/app_database.dart`

The SQLite adapter.

- Opens `cycle_compass.db` at schema version 4.
- Creates and upgrades the `profile`, `period_entries`, and `daily_logs`
  tables.
- Reads and replaces the single profile row.
- Inserts, updates, and deletes period entries.
- Uses a transaction when moving a period start so a compatible end date is
  preserved.
- Deletes all local rows transactionally.

SQL details and future schema migrations belong in this file.

### `lib/models/user_profile.dart`

The immutable profile and tracking-status model.

- Stores personal data, cycle defaults, pregnancy fields, the user-entered
  next-period date, and postpartum tracking dates.
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

### `lib/services/cycle_calculator.dart`

The pure cycle-estimation domain service.

- Defines `CyclePhase`, `CycleEstimateBasis`, and `CycleTiming`.
- `CycleSnapshot` contains phase, cycle day, effective length, cycle anchors,
  next period, estimated ovulation, and confidence basis.
- `CycleIntervalInsight` describes early/late comparisons and range warnings.
- `CycleCalculator` handles recorded cycles, median history estimates, manual
  due-date overrides, phase assignment, negative-date rollover, normalization,
  and monthly insights.

It has no Flutter widgets, database access, or mutable state, so it is directly
unit-testable.

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

### `lib/screens/today_screen.dart`

The main current-day experience.

In normal tracking mode it:

- calculates today's snapshot from profile defaults, history, and any manual
  next-period due date;
- corrects the menstruation phase using an explicitly recorded bleeding end;
- displays the cycle ring, confidence basis, phase journey, education card,
  next-period wording, and “period started today” action.

When `profile.isPregnant` is true, it switches to `_PregnancyTodayView`:

- before the due date it displays Pregnancy mode and pauses estimates;
- on/after the due date it displays Postpartum mode and offers a date picker
  for the first real postpartum period;
- it includes safety copy distinguishing postpartum bleeding from menstruation.

This file also owns the phase color and icon helpers shared by Learn and
Calendar.

### `lib/screens/calendar_screen.dart`

The month grid, date-management UI, and month explanation layer.

- Navigates between months and calculates each cell's phase.
- Uses explicit period ranges before estimated bleeding lengths.
- Marks period starts, manual next-period due dates, pregnancy due dates, today,
  and recorded bleeding days.
- Pauses phase coloring during pregnancy.
- Colors postpartum days muted brown and gives the expected pregnancy due date
  a matching outline.
- Adds/manages period starts and recorded end dates from dialogs and bottom
  sheets, including “add one more day.”
- Shows legends and a monthly summary for early/late intervals, duration
  differences, manual due dates, and cautious range guidance.

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
- Allows a user-entered next menstrual period due date.
- Groups pregnancy and postpartum settings in one coupled section.
- Requires a pregnancy due date, shows the derived current mode, and preserves
  previous postpartum tracking dates.
- Lists recent period entries and supports adding, moving, deleting, extending,
  shortening, or clearing an explicit bleeding end date.
- Makes Personal details, Cycle settings, Pregnancy & postpartum, Period
  history, and Privacy individually collapsible and initially expanded.
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
| Change cycle math | `services/cycle_calculator.dart` and unit tests |
| Change pregnancy/postpartum rules | `user_profile.dart`, `app_controller.dart`, relevant screens |
| Change calendar colors or cell markers | `screens/calendar_screen.dart` |
| Add a new bottom tab | `screens/home_shell.dart` plus a new screen |
| Add profile editing behavior | `screens/profile_screen.dart`, then controller if persistent |
| Change avatar behavior | `widgets/profile_avatar.dart` |

## Safety and product boundaries

- All calculations are estimates and should not be used as contraception,
  diagnosis, or confirmation of ovulation or pregnancy.
- Pregnancy mode records a user preference; it does not verify or monitor a
  pregnancy.
- “Postpartum mode ended” means app tracking resumed after a recorded period;
  it does not mean clinical postpartum recovery has ended.
- Medical wording should receive qualified clinical review before public
  release.
