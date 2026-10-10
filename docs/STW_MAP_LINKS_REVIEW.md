# STW Map: links between STWs for clinical review

The STW Map shows where one approved STW names the topic of another. Each link below quotes the exact words printed in the STW PDF box. Until a clinician approves a link, the app shows it as **"Draft: awaiting clinical review"**.

**How to review:** for each link, decide whether the quoted text is a meaningful connection to the target STW for doctors and nurses using the app.

- **Approve:** set `"approved": true` for that link in `assets/knowledge_graph/stw_map.json`.
- **Reject:** delete the link from that file.
- **No other changes are needed.** The test `test/stw_map_test.dart` checks that every quote is still word-for-word in its PDF box.

"Awaiting STW" means the target topic has no approved STW in the app yet. The map then shows the topic only as a list of the places that mention it.

| # | From (STW · box) | To | Kind | Exact words in the PDF | Approve? |
|---|---|---|---|---|---|
| 1 | RD · REASSESS FREQUENTLY | Sepsis (awaiting STW) | Refers to | "Consider sepsis if perinatal risk factors, systemic illness, worsening distress or rising FiO₂ (see STW: Sepsis in Neonates)" | ☐ |
| 2 | RD · IMMEDIATE ACTIONS | Thermal Care (awaiting STW) | Mentions | "Provide thermal care" | ☐ |
| 3 | RD · IMMEDIATE ACTIONS | Fluids & Feeds (awaiting STW) | Mentions | "Feed enterally if stable" | ☐ |
| 4 | ROP · WHOM TO SCREEN | Sepsis (awaiting STW) | Mentions | "significant anemia, blood transfusion, sepsis, poor postnatal weight gain" | ☐ |
| 5 | ROP · PREVENTION | ANCS | Mentions | "Antenatal corticosteroids for fetal lung maturation" | ☐ |
| 6 | ROP · PREVENTION | Sepsis (awaiting STW) | Mentions | "Prevent and promptly treat sepsis" | ☐ |
| 7 | ROP · DOs | Discharge & Follow-up (awaiting STW) | Mentions | "Document the date and place of next screening in discharge card" | ☐ |
| 8 | ANCS · INTRODUCTION | Respiratory Distress | Mentions | "reduces neonatal mortality, incidence and severity of respiratory distress syndrome" | ☐ |
| 9 | Hypoglycemia · WHOM TO SCREEN FOR HYPOGLYCEMIA | Respiratory Distress | Mentions | "Sick neonates, including those with sepsis, shock, birth asphyxia, respiratory distress, polycythaemia, on IV fluids" | ☐ |
| 10 | Hypoglycemia · WHOM TO SCREEN FOR HYPOGLYCEMIA | Sepsis (awaiting STW) | Mentions | same words as #9 | ☐ |
| 11 | Hypoglycemia · PRACTICAL POINTS | Sepsis (awaiting STW) | Mentions | "Always search for an underlying cause – polycythemia, sepsis, meningitis, hypothermia, IUGR" | ☐ |
| 12 | Hypoglycemia · DON'Ts | Sepsis (awaiting STW) | Mentions | "Do NOT give antibiotics for hypoglycemia unless sepsis is suspected" | ☐ |
| 13 | Hypoglycemia · PREVENTION OF HYPOGLYCEMIA | Thermal Care (awaiting STW) | Mentions | "Maintain normothermia" | ☐ |

## Points to decide

- **#8:** the ANCS STW says "respiratory distress syndrome", while the RD STW is "Respiratory Distress in Neonates". Is this link appropriate?
- **#2, #3, #7, #13:** these name a care area (thermal care, feeds, discharge card, normothermia) rather than an STW. Should the map show them before those STWs are approved?
- **Left out on purpose:** links that depend on clinical inference rather than the printed words:
  - "birth asphyxia" → HIE
  - "convulsions" → Seizures
  - "CPAP" in the ANCS eligibility box → RD
  - "hypothermia" → Thermal Care
  - "maternal glucose" → Hypoglycemia

  Tell us if any of these should be added. Each one needs a quote from its PDF box.
