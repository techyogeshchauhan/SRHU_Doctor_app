# Sepsis supplied-source integration

## Source

- Only `Sepsis_STW_Final_15-10-26.pdf` supplies Sepsis clinical content. The poster is dated August 2026 and prints ICD-10-P36.
- SHA-256: `8ed946d81d7078c33e994a35a95da8b7cb2a7fc9aec19be9671d0319da209927`.
- The supplied Downloads and App copies, bundled PDF and `../Pdfs` source copy have identical bytes. The superseded `../Pdfs/Neonatal Sepsis.pdf` was removed from the application source folder; an archival copy is outside the application in the task validation temp directory.
- There was no implemented Sepsis assessment to retain: its pending placeholder is replaced with this workflow. Other diseases' own references to Sepsis remain attached to their own source PDFs.

## Implemented paths

| Path | Source-bound behavior |
| --- | --- |
| Initial assessment | Record red flags and yellow signs, plus maternal risks only while age <72 hours. Any red flag or at least two yellow flags meets high probability. One yellow flag is compared with the printed gestation and birth-weight criteria. Unknown values remain unknown. |
| High probability | NICU/SNCU admission, blood culture even after prior antibiotics, empirical antibiotics per local/unit policy, supportive care, indicated investigations, LP when hemodynamically stable. DOs retain antibiotics within 1 hour and culture before the first dose. |
| At-risk / suspect | Serial observation 48–72 hours, monitoring 4–6 hourly, antibiotics if another yellow/red sign appears, culture before antibiotics, LP if starting antibiotics or culture positive. |
| Seizure | Independent urgent cause-evaluation footnote, low threshold for antibiotics and LP; a seizure alone is not silently converted into a red flag. |
| 48-hour review | Separate disappeared, improving-but-present and worsened/new-red-flag branches; disappeared retains observation until a sterile culture after 48 hours of incubation. Early-stopping source statement is shown with its sterile-culture condition. |
| Day-5 review | Stopping criteria require all three explicit confirmations: baby now well, sterile 48-hour blood culture, normal CSF. Unknown/pending is not normal. |
| Duration | Clinician selects a complete, confirmed condition from the source table. Five rows retain 5–7, 5–7, 7–10, 10–14 and 21 days respectively. The normal-CSF, day-5 symptom and no-meningitis conditions stay with their durations. No duration is inferred when a table condition is unconfirmed. |

The PDF gives no antibiotic names, doses, CRP/procalcitonin cutoffs, or LP technique. These are not added. The complete HR persistence/temperature, RR >60/min, neonatal hypothermia/rewarming, maternal fever >38°C, and respiratory red-flag qualifiers are retained in the checklist statements.

## Clarified overlap

One yellow flag with gestation >32 weeks and birth weight <1500 g matches both printed classification boxes. The user explicitly chose **keep overlap for clinical review**. Both source criteria are displayed, without choosing an automatic treatment branch. The chatbot likewise asks for clinical review. Missing gestation or birth weight prompts for the missing information when it can affect this distinction.

## Evidence and interface

- Twenty source cards cover the whole clinical poster, KPIs, related information, abbreviations and references. Eighty complete semantic segments retain their source qualifiers.
- Every clinical assessment source resolves to the new PDF and a valid card. The source catalog and fallback index stay synchronized.
- The knowledge graph derives questions/rules from the new workflow. Sepsis source cards use the existing paged evidence layout, including one card per row on small phones. Other disease source layouts retain their current behavior.
- Chatbot responses select complete source segments. Sepsis cases use their own classifier, including decimal gestation, weeks-plus-days and explicit birth-weight units; they are not passed to another disease's numeric engine.
- Changing assessment stage prunes obsolete answers and findings. No clinical recommendation is derived from an unanswered field.

## Verification

- Full Flutter regression: **534 passed, 1 live-backend test skipped** (`E2E_API_URL` not configured).
- Focused Sepsis and source-map checks: **54 passed**, including mobile selection → assessment → source-linked summary, graph paging at 320 and 1280 pixels, no overlapping/clipped evidence labels, and highlighted PDF navigation.
- After assigning each overlapping criterion its own PDF citation, the related clinical and graph checks also passed (**75 tests**).
- Source validator: pinned PDF bytes; exact card text; all segment coordinates; matching fallback chunks; byte-identical regenerated crops and full-page render.
- Preservation audit: other diseases' workflow files, PDFs, crops, rendered pages, region/index entries and graph headings/contexts/links match the starting worktree.
- Graph screenshots were rendered with the application fonts for visual review.
- Changed-code analysis: **no issues found**. `git diff --check` passed.
- Final web release and PWA service-worker generation succeeded. The local `../neonatal_stw_web` copy matches all 222 build files; 27 local HTTP checks verified the PDF, crops, source catalogs, rendered page, graph and current compiled workflow. PWA cache version: `787baa13d790464d`.
- Android release succeeded: `build/app/outputs/flutter-apk/app-release.apk` (91,712,333 bytes). All 26 checked source assets match the application assets byte-for-byte, only the updated Sepsis PDF is packaged, and all three AOT architectures include the current Sepsis workflow and overlap-review citation rule.
- APK SHA-256: `f2bd04365c1f127f3962fefa784b0e7e74833b7210daf649dc1992ffd666f8b9`.

Re-run from the Flutter project:

```powershell
python tools/validate_sepsis_source.py
flutter test --no-pub
```

Passing the pre-change validation directory to the Python validator also checks preservation against that snapshot. No external clinical sources were consulted.

No live-browser or physical-device run is claimed. Clinical decisions, navigation and mobile layouts were exercised by Flutter unit/widget tests; static release assets were checked over local HTTP. No remote deployment, commit or push was performed.
