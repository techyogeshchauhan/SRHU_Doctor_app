import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/radio_choice_group.dart';
import '../../../shared/baby_context.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../../rd/state/rd_controller.dart';
import '../../rd/ui/rd_results.dart';
import '../../rd/domain/rd_rules.dart';
import '../../rop/domain/rop_rules.dart';
import '../../rop/state/rop_controller.dart';
import '../domain/clinical_question.dart';
import '../domain/workflow_definition.dart';
import '../state/workflow_controller.dart';

// ---------------------------------------------------------------------------
// Shared baby details (asked once)
// ---------------------------------------------------------------------------

class CommonInfoStepView extends ConsumerWidget {
  const CommonInfoStepView({super.key, required this.fields});

  final Set<SharedField> fields;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baby = ref.watch(babyProvider);
    return SectionCard(
      title: 'Baby details',
      subtitle: 'Entered once and shared by the selected workflows. '
          'Not saved.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GaBwFields(showGa: fields.contains(SharedField.gestationalAge)),
          if (fields.contains(SharedField.dateOfBirth)) ...[
            const SizedBox(height: 12),
            DateField(
              label: 'Date of birth',
              value: baby.dob,
              firstDate: DateTime.now().subtract(const Duration(days: 730)),
              lastDate: DateTime.now(),
              onChanged: ref.read(babyProvider.notifier).setDob,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Existing dedicated modules (RD, ROP)
// ---------------------------------------------------------------------------

/// Live status of each dedicated module, shown on its step and in the
/// summary. Keyed by condition so the step view itself stays generic.
final Map<NeonatalCondition, WidgetBuilder> moduleStatusBuilders = {
  NeonatalCondition.respiratoryDistress: (_) => const RdStatusView(),
  NeonatalCondition.rop: (_) => const RopStatusView(),
};

class ModuleStepView extends StatelessWidget {
  const ModuleStepView({super.key, required this.workflow});

  final ModuleWorkflow workflow;

  @override
  Widget build(BuildContext context) {
    final title = workflow.definition.title;
    final status = moduleStatusBuilders[workflow.condition];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: title,
          subtitle: workflow.definition.description,
          trailing: StatusChip(
            tone: Tone.success,
            label: workflow.definition.status.label,
          ),
          child: FilledButton.icon(
            onPressed: () => context.push(workflow.route),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text('Open $title workflow'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
        ),
        if (status != null) status(context),
      ],
    );
  }
}

class RdStatusView extends ConsumerWidget {
  const RdStatusView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(rdInitialProvider);
    final o = ref.watch(rdReassessProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResultCard(
          tone: initialTone(r),
          badge: 'Initial plan',
          title: initialTitle(r),
          why: r.plan?.why ?? const [],
        ),
        if (r.plan != null && o.status != ReassessStatus.incomplete)
          ResultCard(
            tone: reassessTone(o.status),
            badge: 'Latest reassessment',
            title: o.title,
            why: o.why,
          ),
      ],
    );
  }
}

/// Same wording as the ROP eligibility step.
ResultCard ropEligibilityCard(RopEligibility e) => switch (e.eligible) {
      true => ResultCard(
          tone: Tone.warning,
          badge: 'Eligibility',
          title: 'SCREEN FOR ROP',
          why: e.reasons,
        ),
      false => ResultCard(
          tone: Tone.success,
          badge: 'Eligibility',
          title: 'Not eligible per STW screening criteria',
          why: e.reasons,
        ),
      null => ResultCard(
          tone: Tone.info,
          badge: 'Eligibility',
          title: 'Eligibility pending',
          actions: e.reasons,
        ),
    };

Tone eyeTone(EyeAction a) => switch (a) {
      EyeAction.urgentTreatment => Tone.danger,
      EyeAction.surgeryReferral => Tone.danger,
      EyeAction.treat => Tone.treat,
      EyeAction.observe => Tone.warning,
      EyeAction.mayStop => Tone.success,
      EyeAction.incomplete => Tone.info,
    };

class RopStatusView extends ConsumerWidget {
  const RopStatusView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(ropProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ropEligibilityCard(ref.watch(ropEligibilityProvider)),
        for (final eye in Eye.values)
          if (!s.eye(eye).isEmpty)
            Builder(builder: (context) {
              final r = ref.watch(ropEyeResultProvider(eye));
              return ResultCard(
                tone: eyeTone(r.action),
                badge: eye.label,
                title: r.title,
                actions: [if (r.followUp != null) r.followUp!],
                why: [s.eye(eye).describe(), ...r.why],
              );
            }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Conditions without an approved STW yet
// ---------------------------------------------------------------------------

class PendingStepView extends StatelessWidget {
  const PendingStepView({super.key, required this.workflow});

  final WorkflowDefinition workflow;

  @override
  Widget build(BuildContext context) {
    final d = workflow.definition;
    return SectionCard(
      title: d.title,
      trailing: StatusChip(tone: Tone.info, label: d.status.label),
      child: const AlertBanner(tone: Tone.info, text: pendingStwMessage),
    );
  }
}

// ---------------------------------------------------------------------------
// Data-driven questionnaire (for future STWs)
// ---------------------------------------------------------------------------

class QuestionnaireStepView extends ConsumerWidget {
  const QuestionnaireStepView({super.key, required this.workflow});

  final QuestionnaireWorkflow workflow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = workflow.condition;
    final answers = ref.watch(workflowProvider.select((s) => s.answersFor(c)));
    final n = ref.read(workflowProvider.notifier);
    return SectionCard(
      title: workflow.definition.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final q in visibleQuestions(workflow.questions, answers))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: QuestionField(
                question: q,
                answer: answers[q.id],
                onChanged: (v) => n.setAnswer(c, q.id, ClinicalAnswer(v)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Renders one [ClinicalQuestion] with the app's existing input widgets.
class QuestionField extends StatelessWidget {
  const QuestionField({
    super.key,
    required this.question,
    required this.answer,
    required this.onChanged,
  });

  final ClinicalQuestion question;
  final ClinicalAnswer? answer;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final q = question;
    final label = q.required ? '${q.question} *' : q.question;
    final input = switch (q.type) {
      QuestionType.singleChoice => RadioChoiceGroup<String>(
          options: [
            for (final o in q.options) ChoiceOption(o.value, o.label),
          ],
          value: answer?.asString,
          onChanged: onChanged,
        ),
      QuestionType.multipleChoice => CheckList<String>(
          items: [for (final o in q.options) (o.value, o.label)],
          selected: answer?.asSet ?? const {},
          onChanged: onChanged,
        ),
      QuestionType.numeric => NumberField(
          label: q.question,
          suffix: q.unit,
          value: answer?.asNum?.toInt(),
          min: q.min ?? 0,
          max: q.max ?? 100000,
          onChanged: onChanged,
        ),
      QuestionType.text => TextFormField(
          initialValue: answer?.asString,
          decoration: InputDecoration(labelText: q.question),
          onChanged: onChanged,
        ),
      QuestionType.date => DateField(
          label: q.question,
          value: answer?.asDate,
          firstDate: DateTime.now().subtract(const Duration(days: 730)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          onChanged: onChanged,
        ),
      QuestionType.boolean => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: answer?.asBool ?? false,
          onChanged: onChanged,
        ),
    };
    final labelled = q.type == QuestionType.singleChoice ||
        q.type == QuestionType.multipleChoice;
    if (!labelled) return input;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.primaryNavy,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        input,
      ],
    );
  }
}
