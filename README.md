# Irene Helper

A personal daily assistant, built with Flutter and shipped as a **web app**.

## Tabs

| Tab | What it does |
|---|---|
| Focus | Pomodoro timer with ambient sounds (rain / fire / cafe) and a growing-plant animation |
| Finance | Income & expense tracking, payment methods, tutoring fee checklist |
| Exercise | Workout logging |
| Habits | Daily water intake, skincare mask schedule, hobby practice log |
| Schedule | Calendar, teaching sessions, period tracker, live Luk Fook gold price |
| Skincare | Skincare deals — manual promos plus price tracking |

All data is stored locally in the browser via `shared_preferences`; there is no backend.

## Running it

```sh
flutter pub get
flutter run -d chrome
```

## Building the site

```sh
flutter build web
```

Output lands in `build/web/`. Serve that directory as static files:

```sh
cd build/web && python3 -m http.server 8000
```

## Project layout

```
lib/
  main.dart              app entry point + bottom navigation
  models/                plain data classes (finance, habits, schedule, skincare, exercise)
  screens/               one file per tab
  services/
    storage_service.dart    thin wrapper over SharedPreferences
    gold_price_service.dart fetches the Luk Fook 9999/999 gold price
  sound_manager.dart     ambient sound playback
  plant_painter.dart     custom painter for the focus timer's plant
web/                     web target — index.html, manifest, icons
assets/sounds/           ambient loops (mp3)
```

## Tests

```sh
flutter test
```

## Notes

- This project targets **web only**. The native platform folders (`android/`, `ios/`,
  `macos/`, `linux/`, `windows/`) were removed deliberately — run `flutter create --platforms=<name> .`
  to regenerate one if that ever changes.
- Local notifications were removed along with the native platforms, since
  `flutter_local_notifications` has no web implementation. The Habits tab now tracks
  water and skincare without reminders.
