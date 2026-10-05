import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../condition_selection/domain/neonatal_condition.dart';
import '../../condition_selection/state/condition_selection_controller.dart';
import '../../rd/domain/rd_workflow.dart';
import '../domain/assessment_context.dart';
import '../domain/assessment_engine.dart';

/// Date used by age/timing rules. Overridden in tests.
final assessmentTodayProvider = Provider<DateTime>((ref) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
});

final assessmentEngineProvider =
    Provider<AssessmentEngine>((ref) => const AssessmentEngine());

/// In-memory state of the dynamic assessment. Nothing is saved.
class AssessmentState {
  const AssessmentState({
    required this.context,
    this.history = const [],
    this.cursor,
    this.currentGroup,
  });

  final ClinicalAssessmentContext context;

  /// Pages (question groups) confirmed so far, in order, for Back.
  final List<String> history;

  /// Page being revisited with Back; null = follow the engine.
  final String? cursor;

  /// Page shown now; null when no applicable question is left (summary).
  final String? currentGroup;

  bool get isComplete => currentGroup == null;
}

class AssessmentController extends Notifier<AssessmentState> {
  AssessmentEngine get _engine => ref.read(assessmentEngineProvider);

  @override
  AssessmentState build() => AssessmentState(
        context: ClinicalAssessmentContext.empty(
          ref.read(assessmentTodayProvider),
        ),
      );

  /// Starts or updates the assessment for [selected]. Answers to shared
  /// questions are kept; anything only used by removed topics is dropped.
  void start(Set<NeonatalCondition> selected) => _update(
        selected: selected,
        cursor: null,
      );

  /// Stores (or clears, with null) the answer to [questionId] and
  /// re-evaluates variables, rules, findings and applicable questions.
  void answer(String questionId, Object? value) {
    final ctx = state.context;
    final rq = _engine
        .applicableQuestions(ctx)
        .where((q) => q.id == questionId)
        .firstOrNull;
    if (rq == null) return;
    final q = rq.question;
    final valid = q.validate(value) == null ? value : null;
    final answers = {...ctx.answers}..remove(q.variable);
    if (valid != null) answers[q.variable] = valid;
    _update(answers: answers);
  }

  /// Confirms the current page; moves to the next page (or the summary).
  void confirmPage() {
    final group = state.currentGroup;
    if (group == null || !_engine.canConfirm(state.context, group)) return;
    final r = _engine.confirmPage(state.context, group);
    final history = [
      ...state.history,
      if (!state.history.contains(group)) group,
    ];
    final i = history.indexOf(group);
    final reviewing = state.cursor != null;
    _update(
      answers: r.answers,
      completed: r.completed,
      history: history,
      cursor: reviewing && i + 1 < history.length ? history[i + 1] : null,
    );
  }

  /// Goes to the previous page. Returns false when there is none (the UI
  /// then returns to the condition selection).
  bool back() {
    final h = state.history;
    final current = state.currentGroup;
    final i = current == null ? h.length : h.indexOf(current);
    final target = i < 0 ? h.length - 1 : i - 1;
    if (target < 0 || h.isEmpty) return false;
    _update(cursor: h[target]);
    return true;
  }

  /// RD: stores the repeat SAS in the trend and asks the reassessment again.
  bool get canRecordRdReassessment =>
      recordRdReassessment(
        state.context.answers,
        state.context.completedQuestions,
      ) !=
      null;

  void recordRdReassessmentAndRepeat() {
    final r = recordRdReassessment(
      state.context.answers,
      state.context.completedQuestions,
    );
    if (r == null) return;
    _update(answers: r.answers, completed: r.completed, cursor: null);
  }

  /// Clears the selection and every answer.
  void newAssessment() {
    ref.read(conditionSelectionProvider.notifier).clear();
    state = build();
  }

  static const _keep = Object();

  void _update({
    Set<NeonatalCondition>? selected,
    Map<String, Object?>? answers,
    Set<String>? completed,
    List<String>? history,
    Object? cursor = _keep,
  }) {
    final prev = state.context;
    final ctx = _engine.evaluate(
      selected: selected ?? prev.selected,
      answers: answers ?? prev.answers,
      completed: completed ?? prev.completedQuestions,
      today: ref.read(assessmentTodayProvider),
    );
    bool hasPage(String g) => _engine.pageQuestions(ctx, g).isNotEmpty;
    final h = (history ?? state.history).where(hasPage).toList();
    var c = identical(cursor, _keep) ? state.cursor : cursor as String?;
    if (c != null && !hasPage(c)) c = null;
    state = AssessmentState(
      context: ctx,
      history: h,
      cursor: c,
      currentGroup: c ?? _engine.nextGroup(ctx),
    );
  }
}

final assessmentProvider =
    NotifierProvider<AssessmentController, AssessmentState>(
  AssessmentController.new,
);
