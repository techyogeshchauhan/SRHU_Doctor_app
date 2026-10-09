/// Combined assessment summary across all selected topics. Pure Dart.
///
/// Lists only findings produced by STW rules. Selecting a topic is never
/// presented as a diagnosis; topics without an approved STW show the
/// pending message and no recommendations.
library;

import '../../condition_selection/domain/neonatal_condition.dart';
import 'assessment_context.dart';
import 'assessment_engine.dart';
import 'clinical_finding.dart';
import 'shared_questions.dart';
import 'source_reference.dart';
import 'workflow_definition.dart';

const combinedSummaryAdvisory =
    'Advisory clinical decision support based on the configured ICMR/DHR STW '
    'content. Management of an individual patient is decided by the '
    'treating physician.';

const noFindingsText = 'No STW pathway triggered by the answers recorded.';

class TopicSummary {
  const TopicSummary({
    required this.topic,
    required this.available,
    required this.findings,
    this.source,
    this.dischargeCard,
  });

  final NeonatalCondition topic;
  final bool available;
  final List<ClinicalFinding> findings;
  final SourceReference? source;

  /// ROP discharge-card text (existing `buildRopSummary` output).
  final String? dischargeCard;

  String get title => definitionOf(topic).title;
}

/// "Baby: GA 30+2 wk · BW 1200 g", "Pregnant woman: GA 30+2 wk", ...
class SubjectLine {
  const SubjectLine(this.label, this.line);
  final String label;
  final String line;
}

class CombinedAssessmentSummary {
  const CombinedAssessmentSummary({
    required this.babyLine,
    required this.selectedTitles,
    required this.answered,
    required this.applicable,
    required this.topics,
    List<SubjectLine>? subjects,
  }) : subjects = subjects ?? const [];

  factory CombinedAssessmentSummary.from(
    ClinicalAssessmentContext ctx, {
    AssessmentEngine engine = const AssessmentEngine(),
  }) {
    final (answered, applicable) = engine.progress(ctx);
    final workflows = engine.workflowsFor(ctx.selected);
    final ownSubject = [
      for (final w in workflows)
        if (w.subjectLine != null) w,
    ];
    final babyLine = describeBabyLine(ctx);
    return CombinedAssessmentSummary(
      babyLine: babyLine,
      subjects: [
        // Baby line unless every selected workflow describes its own subject.
        if (workflows.isEmpty || ownSubject.length < workflows.length)
          SubjectLine('Baby', babyLine),
        for (final w in ownSubject)
          SubjectLine(w.subjectLabel ?? 'Subject', w.subjectLine!(ctx)),
      ],
      selectedTitles: [
        for (final c in NeonatalCondition.values)
          if (ctx.selected.contains(c)) definitionOf(c).title,
      ],
      answered: answered,
      applicable: applicable,
      topics: [
        for (final c in NeonatalCondition.values)
          if (ctx.selected.contains(c))
            switch (engine.lookup(c)) {
              StwWorkflow(:final source, :final recordTextKey) => TopicSummary(
                  topic: c,
                  available: true,
                  findings: ctx.findingsFor(c),
                  source: source,
                  dischargeCard: recordTextKey == null
                      ? null
                      : ctx.valueOf(recordTextKey) as String?,
                ),
              PendingWorkflow() => TopicSummary(
                  topic: c,
                  available: false,
                  findings: const [],
                ),
            },
      ],
    );
  }

  final String babyLine;
  final List<String> selectedTitles;
  final int answered;
  final int applicable;
  final List<TopicSummary> topics;

  /// Subjects of the assessment, in order (the baby line first when shown).
  final List<SubjectLine> subjects;

  String toPlainText() {
    final b = StringBuffer()..writeln('CLINICAL ASSESSMENT SUMMARY');
    for (final s in subjects.isEmpty ? [SubjectLine('Baby', babyLine)] : subjects) {
      b.writeln('${s.label}: ${s.line}');
    }
    b
      ..writeln('Topics assessed: ${selectedTitles.join(', ')}')
      ..writeln('Questions answered: $answered of $applicable applicable');
    for (final t in topics) {
      b
        ..writeln()
        ..writeln('— ${t.title.toUpperCase()} —');
      if (!t.available) {
        b.writeln(pendingStwMessage);
        continue;
      }
      if (t.findings.isEmpty) b.writeln(noFindingsText);
      for (final f in t.findings) {
        b.writeln('[${f.category.label}] ${f.title}');
        for (final a in f.actions) {
          b.writeln('  • $a');
        }
        for (final w in f.why) {
          b.writeln('  Why: $w');
        }
      }
      if (t.dischargeCard != null) {
        b
          ..writeln()
          ..writeln(t.dischargeCard);
      }
      if (t.source != null) b.writeln('Source: ${t.source!.citation}');
    }
    b
      ..writeln()
      ..writeln(combinedSummaryAdvisory);
    return b.toString().trimRight();
  }
}
