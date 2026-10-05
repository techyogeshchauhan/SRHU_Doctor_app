/// Clinical findings produced by rules. Pure Dart.
///
/// Selected topic ≠ finding: selecting "Respiratory Distress" only asks the
/// RD workflow to run. Findings exist only when a `ClinicalRule` fires on the
/// answers, per the STW.
library;

import '../../condition_selection/domain/neonatal_condition.dart';
import 'source_reference.dart';

enum FindingCategory {
  assessment('Assessment finding'),
  classification('Classification'),
  pathway('STW pathway triggered'),
  screening('Screening'),
  treatment('Treatment criteria met'),
  referral('Referral'),
  followUp('Follow-up'),
  alert('Alert'),
  notMet('Criteria not met'),
  furtherAssessment('Further clinical assessment required');

  const FindingCategory(this.label);
  final String label;
}

/// Display urgency, mapped to the app's colour tones in the UI.
enum FindingLevel { info, ok, action, treat, urgent }

/// What a rule produces; the rule adds id, topic and source.
class FindingContent {
  const FindingContent({
    required this.category,
    required this.level,
    required this.title,
    this.actions = const [],
    this.why = const [],
  });

  final FindingCategory category;
  final FindingLevel level;
  final String title;
  final List<String> actions;
  final List<String> why;
}

class ClinicalFinding {
  const ClinicalFinding({
    required this.id,
    required this.topic,
    required this.content,
    required this.source,
  });

  /// The id of the rule that produced it.
  final String id;
  final NeonatalCondition topic;
  final FindingContent content;
  final SourceReference source;

  FindingCategory get category => content.category;
  FindingLevel get level => content.level;
  String get title => content.title;
  List<String> get actions => content.actions;
  List<String> get why => content.why;
}
