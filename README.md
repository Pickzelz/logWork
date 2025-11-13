
# log_work

Log Work is a Flutter desktop application (Windows/Linux/macOS) for tracking activities and recurring schedules.

This README contains quick pointers to run, test, and package the project, and a short summary of recent changes added in the current branch.

## Quick start

- Install Flutter (stable channel) and the desktop tooling for your platform.
- From the project root run:

```powershell
flutter pub get
flutter run -d windows   # or -d linux / -d macos depending on your OS
```

## Testing

This repository includes focused unit tests for model logic. They are fast and do not require a database or desktop UI.

Run the test suite with:

```powershell
flutter test --reporter=expanded
```

Files added for tests:
- `test/models/activity_test.dart` — tests `Activity.duration` and JSON round-trip
- `test/models/recurring_schedule_test.dart` — tests `RecurringSchedule` rules and time/notify matching
- `test/widget_test.dart` — minimal smoke test to keep the suite stable

All tests should pass on a typical developer machine (they passed locally during the changeset).

## Packaging (Windows release)

To build a Windows release and create a zip containing the release output:

```powershell
flutter build windows --release
Compress-Archive -Path .\build\windows\x64\runner\Release\* -DestinationPath .\build\windows_release.zip -Force
```

After these commands the packaged zip will be at `build\windows_release.zip`.

## Recent notable changes (summary)

- Model tests: added unit tests for `Activity` and `RecurringSchedule` models.
- Fixed `Activity.duration` so elapsed time is only counted when an activity is actually running (`isActive == true`). This prevents newly-created activities with a `startTime` from appearing to be running.
- Add dialog: a Start DateTime picker was added to the "Tambah Kegiatan" dialog and defaults to the current date/time. Important: newly added activities do NOT auto-start — they are saved with `isActive=false`.
- UI tweaks: moved the small 'Aktif' label adjacent to the delete button; adjusted left-panel header (filter, add button, divider); added ThemeService and a dark theme toggle in the AppBar.

For detailed rationale and the full change list, see `COMMIT_NOTES/2025-11-13-model-tests-and-ui-fixes.md`.

## Verification notes

- To verify the Start field and non-auto-start behavior:
	1. Click the Add (+) button in the left header.
	2. Note the default Start shown as the current date/time. You may press "Pilih" to change it or the small ✕ to clear it.
	3. Press "Tambah" — the new item will be created but will not show the 'Aktif' label and the timer won't start until you press Play.

## Next steps (optional)

- Add DB integration tests via `sqflite_common_ffi` for desktop test runs.
- Add a checkbox "Mulai langsung" to the Add dialog to allow auto-starting on creation.
- Add CI (GitHub Actions) to run `flutter test` on push and PR.

If you'd like any of these, I can implement them next.
