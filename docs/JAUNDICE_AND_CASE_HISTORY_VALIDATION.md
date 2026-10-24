# Neonatal Jaundice STW and case-history entry: 24 October 2026

Branch `feature/case-history-multi-stw`. Two parts:

1. **STW Jaundice** is now available. It was the `jaundice` "coming soon"
   slot; the enum ordinal, disease code (`jaundice`) and display position are
   unchanged.
2. **Case history** (`/case`): a short free-text history is read by fixed
   rules on the device. The clinician confirms what was read, and the app
   then runs every STW the case triggers as one combined assessment.

## Part 1: Jaundice STW

### Source and scope

`Pdfs/Neonatal Jaundice.pdf`, copied to `assets/pdfs/Neonatal Jaundice.pdf`.
DHR STW "Neonatal jaundice in infants ≥ 35 weeks", July 2020, ICD-10 P59.9.
SHA-256 `19aadebc9175451e411416f50a78a2c2009116208205082a12ccdd978f46ac12`.

`tools/update_jaundice_source.py` generates 21 cards from the PDF. Every
heading and line must be found verbatim inside its box, or the build fails.
The printed spelling is kept ("ASSESMENT", "Peipheral"). From those cards it
writes `jaundice_content.dart`, the regions, crops, chatbot fallback chunks,
the page render and the STW Map headings. No other clinical source is used.

| PDF section | Implementation |
| --- | --- |
| Title: infants ≥ 35 weeks | GA <35 weeks: "Not covered by this STW", no questions or advice. When GA is uncertain, the clinician records whether the baby is ≥35 weeks. |
| Visual assessment; Kramer zones | Kramer zone question (zones 1–5 with the printed bands, "no visible jaundice", "unsure about visual assessment") |
| Serious jaundice (any one of 4) | First 24 hrs (age <24 h with visible jaundice, or recorded as visible before 24 h); palms and soles; any ABE sign; any posturing sign |
| Management: serious | "Start Intensive Phototherapy", "Document serum bilirubin simultaneously", "Prepare for EBT if signs of ABE" |
| Does the infant require TSB? | First 24 hrs; beyond 24 hrs Kramer zone ≥3 or TcB >12; near PT cut-off (clinician); unsure about visual assessment |
| As per TSB … at/more than cut-off? | Clinician records: below PT cut-off / at or above PT / at or above EBT / result awaited. **No cut-off is calculated.** |
| At/above cut-off | "Continue phototherapy/prepare for EBT and determine the cause" plus the investigation list |
| Below cut-off | "Stop phototherapy" and visual assessment/TcB every 12–24 hrs till discharge |
| Stop phototherapy | Optional repeat TSB and unit cut-off: met when TSB <13 or ≤ cut-off − 2 |
| Optimal phototherapy / EBT | Full source text; EBT volume 2 × 80–100 mL/kg is calculated from the recorded birth weight |
| Not serious, TSB not needed | Visual assessment/TcB every 12–24 hrs; clinical examination every 12 hrs in the first 3–5 days |
| Risk factors, DOs, DON'Ts, discharge, key message | Full source text; risk factors are recorded only and do not change the pathway |

### For the neonatologist's review

These points are flagged `needsClinicalReview` in the app ("Requires clinical
review" under the finding):

1. **"More than 12-14 mg/dL" (TSB needed).** The app uses the lower end of
   the band: TcB >12 mg/dL, or Kramer zone 3 (12 to 14 mg/dL) and above. This
   reading sends more babies for TSB, never fewer.
2. **"Falls below 13-14 mg/dL" (stop phototherapy).** The app uses <13 mg/dL,
   so phototherapy is never stopped early.
3. **Abnormal posturing and EBT.** The PDF says to prepare for EBT "if signs
   of ABE are present" and lists posturing as a separate serious-jaundice
   bullet. The app also prompts EBT preparation for posturing signs.
4. **EBT volume** uses the recorded birth weight. The finding says to
   recalculate with the current weight.
5. **Investigations.** In the flowchart they belong to the "TSB at/above
   cut-off" branch, so they are shown there, not for every case of serious
   jaundice.
6. **"Hands and feet" in Hinglish case text** ("haath pair tak") is read as
   palms and soles (zone 5). The review screen says so and asks the
   clinician to change it to zone 4 if only the arms/legs are yellow.

The PDF has no hour-specific phototherapy / exchange transfusion chart. The
app asks whether TSB is at or above the unit's own chart, and the chatbot
answers "not covered" for cut-off values.

### Chatbot

`StwTopic.jaundice` routes jaundice, bilirubin, phototherapy, TSB/TcB, EBT
and Kramer questions to this STW, with whole PDF boxes as answers. A question
that names Triage still gets the Triage jaundice box. "Neonatal jaundice
treatment" and "when to stop phototherapy" are now answered; threshold, cut-off,
level and chart questions stay out of scope.

## Part 2: Case history → multi-STW plan

- **Parser** (`case_entry/domain/case_parser.dart`, pure Dart). It reuses
  `analyzeQuery()`, which now also reads RR, RD signs, Kramer zone, age in
  hours, day of life, ABE/posturing signs, TSB/TcB, GA "+days" and weight in
  kg. Topics come from findings: RR ≥60 or an RD sign → RD; jaundice or a
  bilirubin value → Jaundice; BG → Hypoglycemia; an explicit sepsis or
  asphyxia mention → that STW. Negated findings ("no jaundice", "RR normal",
  "no grunting") do not select a topic.
- **Safety.** The parser only pre-fills answers to existing questions. No
  pre-filled answer is marked complete, so every page is still shown for
  confirmation. Values outside each question's range are dropped. "Day 1" is
  not converted to hours, because it could be either side of 24 h. Day N ≥2
  becomes N × 24 h, with a note asking to check it. Text that nothing matched
  is listed as "Not recognised: ignored". A TSB in mg/dL is no longer read as
  a blood glucose.
- **Privacy.** The case text stays on the device. The audit event
  `case_entry_started` records only topic codes and field names.
- **Summary.** When more than one STW is assessed, an "Immediate actions"
  strip lists findings at action level or above, each labelled with its STW.
  They are ordered by the existing level and display order; no cross-STW
  priority is invented.
- **Entry points.** The Home app-bar button "Case history", and "Open as
  guided case →" under a chat message that holds two or more values across
  two or more STWs.

## Verification

- `flutter test`: the full suite passes, including the new
  `jaundice_rules_test`, `jaundice_workflow_test`, `jaundice_chatbot_test`,
  `case_parser_test` and `case_entry_flow_widget_test`.
- `flutter analyze`: no issues in `lib/`.
- Manual: Home → Case history → "Baby, 36 wk, BW 2.4 kg, day 3. RR 70/min.
  Jaundice up to palms and soles." Then try "33 wk, jaundice up to chest" and
  check the "Not covered" message.
- Clinical sign-off: review points 1–6 above against the PDF before release.
