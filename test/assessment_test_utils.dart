import 'package:neonatal_stw/features/clinical_workflow/domain/assessment_context.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/assessment_engine.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';

const rd = NeonatalCondition.respiratoryDistress;
const rop = NeonatalCondition.rop;
const sepsis = NeonatalCondition.sepsis;

final testToday = DateTime(2026, 10, 5);
const engine = AssessmentEngine();

ClinicalAssessmentContext evalCtx(
  Set<NeonatalCondition> selected,
  Map<String, Object?> answers, {
  Set<String> completed = const {},
  DateTime? today,
}) =>
    engine.evaluate(
      selected: selected,
      answers: answers,
      completed: completed,
      today: today ?? testToday,
    );

Set<String> applicableIds(ClinicalAssessmentContext ctx) =>
    {for (final q in engine.applicableQuestions(ctx)) q.id};

Set<String> findingIds(ClinicalAssessmentContext ctx) =>
    {for (final f in ctx.findings) f.id};

/// Result of answering an assessment page by page, as the UI does.
class Walk {
  Walk(this.ctx, this.pages);
  final ClinicalAssessmentContext ctx;

  /// Group of each page shown, in order (repeats allowed).
  final List<String> pages;

  /// Every question id that was shown.
  final List<String> asked = [];
}

/// Answers pages in engine order using [answers] (missing answers stay
/// empty), confirming each page, until the assessment is complete.
Walk walk(
  Set<NeonatalCondition> selected,
  Map<String, Object?> answers, {
  DateTime? today,
}) {
  var ctx = evalCtx(selected, answers, today: today);
  final pages = <String>[];
  final asked = <String>[];
  for (var i = 0; i < 60; i++) {
    final g = engine.nextGroup(ctx);
    if (g == null) break;
    pages.add(g);
    asked.addAll(engine.pageQuestions(ctx, g).map((q) => q.id));
    final next = engine.confirmPage(ctx, g);
    ctx = engine.evaluate(
      selected: selected,
      answers: {...answers, ...next.answers},
      completed: next.completed,
      today: today ?? testToday,
    );
  }
  return Walk(ctx, pages)..asked.addAll(asked);
}
