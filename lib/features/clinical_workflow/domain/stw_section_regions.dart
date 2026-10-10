/// PDF box of each Respiratory Distress and ROP source section. Pure Dart.
///
/// The ANCS and Hypoglycemia workflows name their box on each
/// `SourceReference` (`regionId`). The RD and ROP workflows cite the
/// section numbers of `docs/STW_APP_SPEC_FROM_PDFs.md` instead; this table
/// maps each of those sections to the box of the bundled STW PDF that
/// states it (`assets/regions/regions.json`), so "View in PDF" can
/// highlight it. A section citing several parts maps to the box of the
/// first part.
///
/// Keys are `document|section`, exactly as written in the workflow files;
/// `test/knowledge_graph_test.dart` fails when a cited section is missing
/// here or a box does not exist.
library;

import 'source_reference.dart';

const _rd = rdStwDocument;
const _rop = ropStwDocument;

const Map<String, String> stwSectionRegions = {
  // Respiratory Distress in Neonates
  '$_rd|§1.1 Definition: RD present if ANY ONE': 'rd_diagnostic_criteria',
  '$_rd|§1.2 Immediate actions': 'rd_immediate_actions',
  '$_rd|§1.2 IV fluids': 'rd_immediate_actions',
  '$_rd|§1.2 IV fluids if severe distress, recurrent apnea, poor perfusion, '
      'or abdominal signs': 'rd_immediate_actions',
  // "If GA is uncertain, BW ≤1800 g may be used as an operational
  // surrogate" is printed in the ALGORITHM box.
  '$_rd|§1.3 Inputs: BW only if GA is uncertain': 'rd_algorithm_overview',
  '$_rd|§1.3 BW ≤1800 g as surrogate when GA uncertain':
      'rd_algorithm_overview',
  '$_rd|§1.4 Silverman-Andersen Score (Avery & Fletcher, 1974)':
      'rd_sas_scoring_guide',
  '$_rd|§1.5 Algorithm: choosing initial support': 'rd_algorithm_overview',
  '$_rd|§1.5 Algorithm: GA ≤34 / >34 weeks': 'rd_algorithm_overview',
  '$_rd|§1.5 Assess gestation (GA) + SAS': 'rd_algorithm_overview',
  '$_rd|§1.5 Algorithm; §1.7 Improving (weaning)': 'rd_algorithm_overview',
  '$_rd|§1.5 Reassess frequently': 'rd_reassessment_sepsis',
  '$_rd|§1.5 Reassess: clinical status, SAS, SpO₂': 'rd_reassessment_sepsis',
  '$_rd|§1.5 Consider sepsis (see STW: Sepsis in Neonates)':
      'rd_reassessment_sepsis',
  '$_rd|§1.5 Consider sepsis; §1.6 Target SpO₂ 91–95%':
      'rd_reassessment_sepsis',
  // §1.6: "Maintain SpO₂ 91%-95%." is printed in the DOs box.
  '$_rd|§1.6 Target SpO₂ 91–95%': 'rd_clinical_dos',
  '$_rd|§1.7 Improving': 'rd_improving',
  '$_rd|§1.7 Improving → wean': 'rd_outcome_improving_weaning',
  '$_rd|§1.7 Continue SpO₂ monitoring for 24 h': 'rd_outcome_improving_weaning',
  '$_rd|§1.8 Not improving / worsening; §1.10 CPAP failure': 'rd_not_improving',
  '$_rd|§1.8 Not improving / worsening → optimize CPAP':
      'rd_outcome_not_improving_optimize_cpap',
  '$_rd|§1.8 Optimize CPAP; §1.9 Surfactant':
      'rd_outcome_not_improving_optimize_cpap',
  '$_rd|§1.9 Surfactant: FiO₂ >0.30': 'rd_surfactant_indication',
  '$_rd|§1.9 Surfactant: GA <34 wk, on CPAP, PEEP >6 AND FiO₂ >0.30':
      'rd_surfactant_indication',
  '$_rd|§1.10 CPAP failure → refer urgently': 'rd_cpap_failure_referral',
  "$_rd|§1.12 DON'Ts": 'rd_clinical_donts',

  // Retinopathy of Prematurity
  '$_rop|§2.1 Whom to screen': 'rop_whom_to_screen',
  '$_rop|§2.1 Whom to screen; §2.2 When to screen': 'rop_whom_to_screen',
  '$_rop|§2.1 Whom to screen; §2.3 How to arrange screening':
      'rop_whom_to_screen',
  '$_rop|§2.2 When to screen': 'rop_when_to_screen',
  '$_rop|§2.2 When to screen (postnatal age)': 'rop_when_to_screen',
  '$_rop|§2.2 If follow-up uncertain, screen before discharge':
      'rop_when_to_screen',
  '$_rop|§2.2 If follow-up uncertain, screen before discharge even if not '
      'due': 'rop_when_to_screen',
  '$_rop|§2.2 Repeat screen': 'rop_when_to_screen',
  '$_rop|§2.5 Document ROP findings': 'rop_how_to_screen',
  '$_rop|§2.6 Treatment indications': 'rop_treatment_indications',
  '$_rop|§2.6 Reactivation/significant PAR after anti-VEGF':
      'rop_treatment_indications',
  '$_rop|§2.6 Treatment indications; §2.7 Treatment options':
      'rop_treatment_indications',
  '$_rop|§2.6 Treatment indications; §2.8 When to stop screening':
      'rop_treatment_indications',
  '$_rop|§2.8 When to stop screening': 'rop_when_to_stop',
  '$_rop|§2.8 After anti-VEGF: until 65 weeks PMA': 'rop_when_to_stop',
  // GA days are used only for PMA, which the STW uses in the 65-weeks-PMA
  // follow-up rule.
  '$_rop|§2.8 PMA = GA at birth + postnatal age': 'rop_when_to_stop',
  "$_rop|§2.10 DOs; §2.11 DON'Ts": 'rop_clinical_dos',
  "$_rop|§2.11 DON'Ts": 'rop_clinical_donts',
};

/// Sections cited as a source that are not printed in the bundled STW
/// PDFs (e.g. the SNCU ROP record form). They have no box to highlight.
const Set<String> sectionsOutsideStwPdf = {
  '$_rop|ICROP3 / SNCU ROP record form',
  '$_rop|SNCU ROP record form (discharge card)',
  '$_rd|Whole document (ICD-11 KB23)',
  '$_rop|Whole document (ICD-11 9B71.3)',
};
