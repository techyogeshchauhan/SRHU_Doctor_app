/// Whole source cards only; no inferred Sarnat stage or final cooling eligibility.
library;

import '../understanding/query_analyzer.dart';

bool postAsphyxiaQuestionUnsupported(QueryAnalysis a) =>
    (RegExp(r'\bdoses?\b|dosage|regimen|how much|how many doses|\bmg\b|ml/kg|oxygen flow|fluid volume')
            .hasMatch(a.normalized) &&
        !RegExp(r'phenobarbit\w*').hasMatch(a.normalized)) ||
    RegExp(
      r'cooling (temperature|duration|protocol)|rewarm|target.*cooling|'
      r'(complete|full|strict|all) nnf criteria|'
      r'(repeat|maintenance|maximum|second|third|cumulative|next|additional|further).*phenobar|'
      r'phenobar.*(repeat|maintenance|maximum|second|third|cumulative|next|additional|further)|'
      r'refractory|levetiracetam|phenytoin|morphine|cool.*(72|33\.5)',
    ).hasMatch(a.normalized);

String? postAsphyxiaAnswerRegion(QueryAnalysis a) {
  final n = a.normalized;
  if (a.intents.contains(QueryIntent.abbreviation)) {
    return 'post_asphyxia_abbreviations';
  }
  if (a.intents.contains(QueryIntent.kpi)) {
    return 'post_asphyxia_kpis';
  }
  if (a.intents.contains(QueryIntent.donts)) {
    return 'post_asphyxia_donts';
  }
  if (a.intents.contains(QueryIntent.dos)) {
    return 'post_asphyxia_dos';
  }
  if (RegExp(r'prophyla\w*|unmonitored cooling').hasMatch(n)) {
    return 'post_asphyxia_donts';
  }
  if (RegExp(r'therapeutic hypothermia|cooling|\bth\b|nnf').hasMatch(n)) {
    return 'post_asphyxia_cooling';
  }
  if (RegExp(r'seizur|phenobar|convuls').hasMatch(n)) {
    return 'post_asphyxia_seizures';
  }
  if (RegExp(r'initially normal|evolving|exclude.*hie').hasMatch(n)) {
    return 'post_asphyxia_serial';
  }
  if (RegExp(r'normal (exam|examination)').hasMatch(n)) {
    return 'post_asphyxia_normal';
  }
  if (RegExp(r'\bmild\b').hasMatch(n) &&
      !RegExp(r'sarnat|stage|staging|domain').hasMatch(n)) {
    return 'post_asphyxia_mild';
  }
  if (RegExp(
          r'sarnat|stag|conscious|spontaneous|posture|tone|reflex|autonomic|pupil')
      .hasMatch(n)) {
    return 'post_asphyxia_sarnat';
  }
  if (RegExp(r'moderate|severe|unstable|urgent transfer').hasMatch(n)) {
    return 'post_asphyxia_urgent';
  }
  if (RegExp(r'apgar|ppv|base deficit|\bph\b|high.risk').hasMatch(n)) {
    return 'post_asphyxia_high_risk';
  }
  if (RegExp(r'discharge|follow.?up|hearing').hasMatch(n)) {
    return 'post_asphyxia_discharge';
  }
  if (RegExp(r'glucose|\bbg\b').hasMatch(n)) {
    return 'post_asphyxia_glucose';
  }
  if (RegExp(r'temperature|hypertherm').hasMatch(n)) {
    return 'post_asphyxia_temperature';
  }
  if (RegExp(r'fluid|urine|renal|electrolyte').hasMatch(n)) {
    return 'post_asphyxia_fluids';
  }
  if (RegExp(r'feed|milk|suck.swallow').hasMatch(n)) {
    return 'post_asphyxia_feeding';
  }
  if (RegExp(r'perfusion|blood pressure|\bbp\b|shock|bolus').hasMatch(n)) {
    return 'post_asphyxia_perfusion';
  }
  if (RegExp(r'oxygen|spo2|breath|ventilat|heart rate').hasMatch(n)) {
    return 'post_asphyxia_oxygen';
  }
  if (RegExp(r'neurological|eeg|aeeg|monitor|serial|reassess').hasMatch(n)) {
    return 'post_asphyxia_neurological';
  }
  if (RegExp(r'risk|delayed cry|resuscitat|perinatal event').hasMatch(n)) {
    return 'post_asphyxia_risk';
  }
  if (RegExp(r'stabiliz').hasMatch(n)) {
    return 'post_asphyxia_stabilize';
  }
  return null;
}
