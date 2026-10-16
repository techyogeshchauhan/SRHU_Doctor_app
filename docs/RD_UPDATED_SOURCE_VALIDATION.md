# Respiratory Distress source update — 16 October 2026

The sole Respiratory Distress source is **Respiratory_Distress_STW_Final 15-10-26.pdf** (printed date: August 2026).

- Runtime asset: `assets/pdfs/respiratory_distress_neonates_stw.pdf`.
- SHA-256: `ea2d19519976a1ea70b09611be815676096724c1ab00732f2c5ec774dd1890eb`.
- Both user-supplied file locations contain identical bytes. The runtime asset, source copy in `../Pdfs`, and local web release serve those same bytes.
- Removed the superseded duplicate PDF and its rendered page from app assets, obsolete document alias, previous RD segment/coordinate overrides, and obsolete RD extraction logic in both index-builder entry points.

## Current decisions

- RD includes RR **≥60/min**, or any of chest retractions, nasal flaring or grunting.
- Apnoea/gasping, poor effort or shock prompts immediate stabilization and ventilation when indicated, without waiting for GA/SAS completion.
- GA ≤34 with any RD, or GA >34 with SAS ≥4: start CPAP 5–6 cm H₂O. Identify the indication as the starting point for the 30-minute initiation target.
- GA >34 with SAS ≤3: nasal-prong oxygen 0.5–1 L/min **only if SpO₂ <91%**. Missing SpO₂ leaves that decision pending.
- Early rescue surfactant requires suspected worsening RDS, confirmed GA <34, FiO₂ >0.30 and CPAP **≥6 cm H₂O**. Give promptly before established CPAP failure; the superseded two-hour deadline is removed.
- Continuous SpO₂ monitoring on oxygen/CPAP; reassess within 15–30 minutes of starting/changing support, at least hourly on support, and immediately if worsening.
- Worsening on nasal oxygen leads to CPAP. Optimization includes checking prongs/circuit/delivered pressure, increasing CPAP up to 7–8, titrating FiO₂, excluding pneumothorax, considering sepsis and surfactant.
- Improving requires decreasing SAS, target SpO₂ on stable/reducing support, and comfortable breathing. Weaning retains the source's stability/no-significant-apnoea/low-oxygen conditions. Reduce FiO₂ then CPAP as per protocol; trial off at CPAP 5 and FiO₂ 0.21–0.25; monitor for 24 hours after stopping.
- Failure prompts escalation, intubation/ventilation when indicated, stabilization and urgent referral.
- KPI definitions now cover all neonates meeting CPAP criteria and documented continuous pulse-oximetry coverage, respectively; both targets are >90%.

The unchanged GA ≤34 / >34 split retains the app's existing completed-week convention. The PDF does not specify a days boundary. BW is used as an operational surrogate for initial support when GA is uncertain; it does not establish GA <34 for surfactant eligibility.

## Verification

- Full Flutter suite: **492 passed, 1 live-backend test skipped**.
- Updated-code analysis: **no issues found**. Full-project analysis also identifies seven pre-existing unused imports in `screening_reset_and_boundary_box_test.dart`.
- Source audit verifies all **20 RD cards**: exact source text, per-segment coordinates within the correct card, synchronized fallback index, byte-identical regenerated 2× crops, and byte-identical full-page rendering.
- Visual review verifies the revised card boundaries, including oxygen, monitoring, early rescue, weaning, optimization, failure and both KPIs. The SAS chart is pixel-identical to the image embedded in the updated PDF.
- Preservation audit: **109 other-disease files**, all non-RD region/index entries and all non-RD graph headings/contexts/links unchanged from the starting worktree.
- Web release and PWA service-worker generation succeeded. HTTP verification of the local release confirms the updated PDF, all crops, catalogs, graph, page rendering, compiled new inputs and changed offline cache version.
- Android release build succeeded (`build/app/outputs/flutter-apk/app-release.apk`, 85.4 MB). ZIP verification confirms the exact supplied PDF, all 20 crops and the current index/graph/rendered page; the obsolete duplicate is absent. APK SHA-256: `4635b05162973d1bbbde8aab15f5ead120527ae15b94ffc19c26809afd169458`.
- `git diff --check` passed. The RD PDF is marked binary to preserve its bytes through Git checkout.

Browser automation was unavailable (empty browser inventory). Chatbot-to-PDF navigation, zoom/rotation and mobile layouts were exercised by widget tests; no live-browser or physical-device run is claimed. No remote deployment, commit or push was performed.

Re-run the source audit from the Flutter project:

```powershell
python tools/validate_rd_source.py --source '..\Respiratory_Distress_STW_Final 15-10-26.pdf'
flutter test --no-pub
```

`tools/update_rd_source.py` regenerates only RD evidence, crops, graph labels and the standalone RD reference text. It rejects unexpected PDF bytes rather than applying this revision's coordinates to a different poster.
