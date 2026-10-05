# STW Content Coverage: why 12 topics show "Coming soon"

The app lists 14 neonatal topics, but only **Respiratory Distress** and **ROP** have clinical workflows. The other 12 are marked **"Coming soon"** because the source PDFs in the project don't contain workflows for them. The app reads the PDFs correctly; it simply has no approved content for those 12 topics yet.

---

## 1. What the source PDFs contain

### `assets/pdfs/`

| File | Content | Pages | Notes |
|---|---|---|---|
| `respiratory_distress_neonates_stw.pdf` | ICMR/DHR STW *Respiratory Distress in Neonates* (ICD-11 KB23) | 1 | ~710 words. Used by the app. |
| `Respiratory distress in neonates_New.pdf` | Same document | 1 | Byte-for-byte duplicate of the file above. |
| `retinopathy_of_prematurity_stw.pdf` | ICMR/DHR STW *Retinopathy of Prematurity (ROP)* (ICD-11 9B71.3) | 1 | ~830 words. Used by the app. |
| `Retinopathy of Prematurity (ROP).pdf` | Same document | 1 | Byte-for-byte duplicate of the file above. |

So there are **two distinct documents**, one page each.

### `docs/`

All three supporting PDFs are about ROP:

- `…icrop3classification.pdf`: International Classification of ROP, 3rd edition (ICROP3)
- `…ropscreeningform.pdf`: SNCU ROP screening / examination record form
- `S100.pdf`: *Retinopathy of Prematurity: Information for Parents and FAQs*

None of them covers the other 12 topics.

---

## 2. The 12 "Coming soon" topics, checked against the PDFs

Each topic was searched for in the extracted text of both STWs, using related terms (e.g. *hypoglycemia / glucose*, *jaundice / bilirubin / phototherapy*, *HIE / encephalopathy / asphyxia*).

| Topic | Found in the PDFs? | What is actually there |
|---|---|---|
| Triage | No | – |
| Thermal Care | One line, inside RD | "Provide thermal care" / "maintain temperature" as a step of the RD and ROP workflows. No thermal-care workflow. |
| KMC | No | – |
| Fluids & Feeds | A few lines, inside RD and ROP | RD: direct breastfeed or gastric-tube feeds, and IV fluids if severe distress. ROP: withhold feeds 1 hour before screening. Both are already in the app; there is no fluids & feeds workflow. |
| ANCS | One line, inside ROP | "Antenatal corticosteroids for fetal lung maturation", listed as ROP prevention advice only. |
| Sepsis | Mentions only | RD: "Consider sepsis … **(see STW: Sepsis in Neonates)**", which is a separate STW not supplied. ROP lists sepsis as a risk factor. |
| Hypoglycemia | No | – |
| Jaundice | No | – |
| Seizures | No | – |
| HIE | No | The only text match was the letters inside "ac**hie**ve". |
| Transport | No | Only "refer urgently" / "safe referral", as steps inside RD and ROP. |
| Discharge & Follow-up | ROP-specific lines only | "Do not discharge/transfer an at-risk neonate without a documented ROP follow-up plan". Already in the ROP workflow; there is no general discharge workflow. |

**Conclusion:** where a topic is mentioned at all, the line is a step inside RD or ROP, and those steps are already in the app's RD and ROP workflows. None of the mentions gives the criteria, thresholds, algorithm or actions a standalone workflow would need.

---

## 3. Where "Coming soon" comes from in the code

| What | Where |
|---|---|
| Topic status | [`lib/features/condition_selection/domain/neonatal_condition.dart`](../lib/features/condition_selection/domain/neonatal_condition.dart): every topic defaults to `ConditionStatus.comingSoon`. Only Respiratory Distress and ROP are set to `ConditionStatus.available`. |
| Workflow for each topic | [`lib/features/clinical_workflow/domain/workflow_registry.dart`](../lib/features/clinical_workflow/domain/workflow_registry.dart): RD and ROP map to their workflows; every other topic gets an empty `PendingWorkflow`, with no questions or rules. |
| On screen | "Coming soon" chips on the topic selection screen, "12 more coming soon" on Home, and the placeholder *"Clinical workflow content requires the corresponding approved STW."* in the assessment summary. |

This is deliberate. The app is clinical decision support, and its rule is that **no clinical questions, thresholds or recommendations are created without an approved source**. Building a workflow from the single lines above would mean inventing the rest of it.

---

## 4. How to enable a topic

1. **Supply its approved ICMR/DHR STW PDF**, for example *Sepsis in Neonates*, which the RD STW already refers to.
2. **Add the workflow** as a file next to [`rd_workflow.dart`](../lib/features/rd/domain/rd_workflow.dart): its questions, derived values and rules, each citing the STW section it comes from.
3. **Register it** in `workflowFor()` in `workflow_registry.dart`.
4. **Switch its status** to `ConditionStatus.available` in `neonatal_condition.dart`.

The topic selection screen, the assessment engine and the combined summary pick the new topic up automatically; no other screens need changing.

---

## 5. Housekeeping

The two duplicate PDFs (`Respiratory distress in neonates_New.pdf` and `Retinopathy of Prematurity (ROP).pdf`, 8.4 MB in total) can be deleted. `pubspec.yaml` now lists only the two `*_stw.pdf` files, so the duplicates are no longer bundled into the Android, iOS or web builds; removing them only tidies the repository.
