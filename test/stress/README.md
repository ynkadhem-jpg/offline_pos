# Production Stress Test Suite

This suite is test-only tooling. It lives under `test/stress/` and is not
included in release builds.

## Run

Small preset:

```powershell
flutter test test/stress/stress_suite_test.dart --dart-define=RUN_STRESS_TESTS=true --dart-define=STRESS_PRESET=small
```

Medium preset:

```powershell
flutter test test/stress/stress_suite_test.dart --dart-define=RUN_STRESS_TESTS=true --dart-define=STRESS_PRESET=medium
```

Large preset:

```powershell
flutter test test/stress/stress_suite_test.dart --dart-define=RUN_STRESS_TESTS=true --dart-define=STRESS_PRESET=large
```

Extreme preset:

```powershell
flutter test test/stress/stress_suite_test.dart --dart-define=RUN_STRESS_TESTS=true --dart-define=STRESS_PRESET=extreme
```

## Presets

| Preset | Customers | Sales | Installments per sale |
| --- | ---: | ---: | ---: |
| Small | 100 | 500 | 6 |
| Medium | 1,000 | 5,000 | 12 |
| Large | 5,000 | 25,000 | 12 |
| Extreme | 10,000 | 50,000 | 24 |

## Output

Reports are written to:

```text
build/stress_reports/
```

Each run creates:

- a Markdown report
- a JSON report

## Notes

- The suite generates realistic Arabic names, Iraqi phone numbers, addresses,
  products, sales, installments, and payment states.
- Widget opening and scrolling timings are Flutter test measurements. They are
  useful for regression tracking, but they are not a replacement for physical
  Android profile-mode frame analysis.
- App startup is measured as database-open readiness plus first screen pump, not
  full APK cold-start from the Android launcher.
