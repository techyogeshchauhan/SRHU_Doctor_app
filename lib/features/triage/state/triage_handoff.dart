import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../condition_selection/domain/neonatal_condition.dart';
import '../domain/triage_history_exam.dart';

/// STWs suggested by the last Triage results, kept for the Next STW pages:
/// starting an STW there resets the assessment, so the Triage answers are
/// gone by then. Set when the clinician leaves the results for Next Step;
/// cleared with the rest of the screening data.
final triageHandoffProvider =
    NotifierProvider<TriageHandoff, List<StwSuggestion>>(TriageHandoff.new);

class TriageHandoff extends Notifier<List<StwSuggestion>> {
  @override
  List<StwSuggestion> build() => const [];

  void set(List<StwSuggestion> suggestions) =>
      state = List.unmodifiable(suggestions);

  void clear() => state = const [];

  StwSuggestion? of(NeonatalCondition stw) =>
      state.where((s) => s.stw == stw).firstOrNull;
}
