/// Clinical decision snapshot of one topic, recorded when its results are
/// shown. Pure Dart.
library;

import '../../condition_selection/domain/neonatal_condition.dart';
import '../../triage/domain/triage_decision.dart';
import 'assessment_context.dart';

/// The findings that fired (rule id, level, category) for every topic, plus
/// the topic's own structured decision where it has one (Triage).
Map<String, Object?> clinicalDecisionRecord(
  NeonatalCondition topic,
  ClinicalAssessmentContext ctx,
) =>
    {
      'topic': topic.name,
      'findings': [
        for (final f in ctx.findingsFor(topic))
          {'id': f.id, 'level': f.level.name, 'category': f.category.name},
      ],
      if (topic == NeonatalCondition.triage) ...triageDecisionRecord(ctx),
    };
