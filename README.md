# neonatal_stw

A Flutter bedside decision-support app for two ICMR/DHR Standard Treatment Workflows:
**Respiratory Distress in Neonates** and **Retinopathy of Prematurity (ROP)**.
It is stateless: nothing is stored.

See [docs/SPEC.md](docs/SPEC.md) for the screens, the input controls and the decision rules, plus the open points to confirm with the supervisor.

## Run

```bash
flutter pub get
flutter run            # pick an Android/iOS device, or: flutter run -d chrome
flutter test           # 67 tests: domain rules + widget smoke tests
flutter analyze
```

Built and tested with Flutter 3.47.5 / Dart 3.13. Packages are pinned to known-good majors
(`flutter_riverpod` 2.x, `go_router` 14.x, `share_plus` 10.x); newer majors exist and can be adopted later.

## Layout

```
lib/
  main.dart, app.dart                 # ProviderScope, router, theme
  core/theme.dart                     # Tone colours (green/amber/pink/red/blue)
  core/widgets/                       # RadioChoiceGroup, CheckList, NumberField, IntStepper,
                                      # Fio2Slider, DateField, SectionCard, ResultCard, ...
  content/stw_content.dart            # STW text: DOs/DON'Ts, KPIs, abbreviations, references
  shared/baby_context.dart            # GA / BW / DOB shared by both modules (in memory)
  features/rd/domain/                 # sas.dart, rd_rules.dart  ← pure Dart clinical logic
  features/rd/{state,ui}/
  features/rop/domain/rop_rules.dart  # pure Dart clinical logic
  features/rop/{state,ui}/
assets/images/                        # SAS chart + per-grade crops (from the STW PDF)
test/                                 # sas_test, rd_rules_test, rop_rules_test, widget_smoke_test
```

All clinical logic lives in `features/*/domain/` with no Flutter imports, so it can be reviewed and unit-tested on its own.
The UI only renders what those functions return.
