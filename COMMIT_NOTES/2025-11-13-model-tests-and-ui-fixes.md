Summary of changes (2025-11-13)

This commit includes a set of focused unit tests and multiple small UI/behavior fixes collected during the session. Below are the important changes and the rationale for each.

1) Unit tests (new)
- test/models/activity_test.dart
  - Verifies Activity.duration behavior:
    - duration does NOT count elapsed time when activity.isActive is false.
    - duration counts elapsed time when activity.isActive is true.
  - Verifies Activity JSON serialization round-trip (toJson/fromJson) preserves key fields including manualDuration.
- test/models/recurring_schedule_test.dart
  - Tests RecurringSchedule.isDue for daily/weekly/monthly rules.
  - Tests timeMatches and notifyTimeMatches (including 2-minute grace window).
- test/widget_test.dart
  - Replaced the default counter test with a minimal smoke test to keep the suite stable and independent of the full app UI.

2) Activity.duration behavior fix
- File: lib/models/activity.dart
- Problem: duration previously added elapsed time whenever startTime != null which made newly-created activities with a startTime look like they were running.
- Fix: only add elapsed when isActive == true (so startTime alone does not imply running).

3) Add dialog: Start DateTime and default
- File: lib/activity_list_page.dart
- Added an optional Start DateTime field in the "Tambah Kegiatan" dialog (date & time pickers), defaulting to current DateTime.
- Important: activities created via the dialog remain isActive=false by default (they do not auto-start).

4) UI tweaks
- Moved the small 'Aktif' label to appear left of the delete button on list items (visual tweak).
- Reworked left-panel header: moved filter into top header, centered it, added divider, moved compact Add button to the right.
- Added ThemeService and dark theme support (togglable via AppBar cog). (Files: lib/services/theme_service.dart, lib/main.dart)

5) Tests & build
- Ran `flutter test` locally and all tests passed.
- Built a Windows release and created `build/windows_release.zip` (packaging step).

Notes / next steps
- DB integration and widget tests were intentionally not added to keep the test suite light; these can be added later using sqflite_common_ffi for DB tests and using test binding window sizing for widget tests.
- If you'd like, I can add a small "Mulai langsung" checkbox in the Add dialog to let users auto-start when adding.

If anything should be split into smaller commits or if any message/detail needs editing, tell me and I will adjust before pushing.
