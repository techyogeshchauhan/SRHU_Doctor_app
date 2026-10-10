import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clinical_workflow/domain/assessment_context.dart';
import '../../clinical_workflow/state/assessment_controller.dart';
import '../domain/reasoning.dart';

/// Reasoning trees for [ctx].
ReasoningBuilder reasoningBuilder(
  WidgetRef ref,
  ClinicalAssessmentContext ctx,
) =>
    ReasoningBuilder(ctx, engine: ref.read(assessmentEngineProvider));
