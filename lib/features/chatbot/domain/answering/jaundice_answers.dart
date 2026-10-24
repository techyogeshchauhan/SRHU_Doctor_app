/// Whole source cards of the Neonatal Jaundice STW; no cut-off is computed.
library;

import '../understanding/query_analyzer.dart';

/// Explicit Jaundice questions (Triage also lists serious jaundice; an
/// explicit "triage" keeps that STW).
bool isJaundiceQuestion(QueryAnalysis a) =>
    a.topics.contains(StwTopic.jaundice) &&
    a.topics.every((t) => t == StwTopic.jaundice || t == StwTopic.triage) &&
    !RegExp(r'\btriage\b').hasMatch(a.normalized);

/// Box of the PDF that answers [a]; null when the generic ranking decides.
String? jaundiceAnswerRegion(QueryAnalysis a) {
  final n = a.normalized;
  if (a.intents.contains(QueryIntent.abbreviation)) {
    return 'jaundice_abbreviations';
  }
  if (RegExp(r'sunlight|phenobarbit\w*|stop (breast ?feeding|breast ?feeds)')
      .hasMatch(n)) {
    return 'jaundice_donts';
  }
  if (a.intents.contains(QueryIntent.donts)) return 'jaundice_donts';
  if (RegExp(r'naphthalene').hasMatch(n) ||
      a.intents.contains(QueryIntent.dos)) {
    return 'jaundice_dos';
  }
  if (RegExp(r'exchange|\bebt\b').hasMatch(n)) return 'jaundice_optimal_ebt';
  if (RegExp(r'stop\w* phototherapy|phototherapy.*stop').hasMatch(n)) {
    return 'jaundice_stop_pt';
  }
  if (RegExp(r'investigat\w*|\bdct\b|coombs|reticulocyte|smear|cause')
          .hasMatch(n) &&
      !RegExp(r'risk').hasMatch(n)) {
    return 'jaundice_investigation';
  }
  if (RegExp(r'risk').hasMatch(n)) return 'jaundice_risk_factors';
  if (RegExp(r'(optimal|effective|how to give|care during|during) phototherapy|'
          r'eye (cover|patch)|nappy|how often.*(tsb|bilirubin)|repeat tsb')
      .hasMatch(n)) {
    return 'jaundice_optimal_pt';
  }
  if (RegExp(r'(measure|send|check|need\w*|require\w*|test).{0,20}'
          r'(\btsb\b|serum bilirubin)|(\btsb\b|serum bilirubin).{0,20}'
          r'(measure\w*|needed|required)')
      .hasMatch(n)) {
    return 'jaundice_needs_tsb';
  }
  if (RegExp(r'serious|severe|danger|encephalopathy|\babe\b|palms|soles|'
          r'first 24|signs?.*intensive phototherapy')
      .hasMatch(n)) {
    return 'jaundice_serious';
  }
  if (RegExp(r'kramer|zone|extent|visual(ly)? (assess|estimat)\w*')
      .hasMatch(n)) {
    return 'jaundice_kramer';
  }
  if (RegExp(r'examine|examination|how to (look|assess|check)|blanch')
      .hasMatch(n)) {
    return 'jaundice_visual';
  }
  if (RegExp(r'discharge|follow.?up').hasMatch(n)) return 'jaundice_discharge';
  if (RegExp(r'preterm|\b3[0-4] weeks?|35 weeks|gestation|covered')
      .hasMatch(n)) {
    return 'jaundice_scope';
  }
  return null;
}

/// "How to treat jaundice?" starts at the flowchart's first question.
const jaundiceManagementOptions = [
  'jaundice_serious',
  'jaundice_start_pt',
  'jaundice_needs_tsb',
  'jaundice_tsb_cutoff',
];
