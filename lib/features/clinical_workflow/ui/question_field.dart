import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/radio_choice_group.dart';
import '../domain/clinical_question.dart';

/// Renders one data-driven [ClinicalQuestion] with the app's existing input
/// widgets. Holds no clinical logic.
class QuestionField extends StatelessWidget {
  const QuestionField({
    super.key,
    required this.question,
    required this.options,
    required this.value,
    required this.isRequired,
    required this.today,
    required this.onChanged,
  });

  final ClinicalQuestion question;

  /// Options currently visible (option-level conditions applied).
  final List<QuestionOption> options;
  final Object? value;
  final bool isRequired;
  final DateTime today;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final q = question;
    final text = Theme.of(context).textTheme;
    final label = isRequired ? '${q.question} *' : q.question;

    final Widget input = switch (q.type) {
      QuestionType.singleChoice => RadioChoiceGroup<Object>(
          value: value,
          onChanged: onChanged,
          horizontal:
              options.every((o) => o.image == null && o.subtitle == null) &&
                  options.every((o) => o.label.length <= 14),
          options: [
            for (final o in options)
              ChoiceOption<Object>(
                o.value,
                o.label,
                subtitle: o.subtitle,
                leading: o.image == null
                    ? null
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          o.image!,
                          width: 64,
                          height: 56,
                          fit: BoxFit.cover,
                          semanticLabel: '${q.question}: ${o.label}',
                          errorBuilder: (_, __, ___) =>
                              const SizedBox(width: 64, height: 56),
                        ),
                      ),
              ),
          ],
        ),
      QuestionType.multipleChoice => CheckList<Object>(
          items: [for (final o in options) (o.value, o.label)],
          selected: value is Set ? {...(value! as Set).cast<Object>()} : {},
          onChanged: onChanged,
        ),
      QuestionType.numeric => NumberField(
          label: label,
          suffix: q.unit,
          value: value as int?,
          min: q.min ?? 0,
          max: q.max ?? 100000,
          helper: q.helper,
          rangeHint: q.stwRange,
          onChanged: onChanged,
        ),
      QuestionType.text => TextFormField(
          initialValue: value as String?,
          decoration: InputDecoration(labelText: label, helperText: q.helper),
          onChanged: (v) => onChanged(v.trim().isEmpty ? null : v),
        ),
      QuestionType.date => DateField(
          label: label,
          value: value as DateTime?,
          helper: q.helper,
          firstDate: today.subtract(const Duration(days: 730)),
          lastDate: q.pastOnly ? today : today.add(const Duration(days: 365)),
          onChanged: onChanged,
        ),
      QuestionType.boolean => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: q.helper == null ? null : Text(q.helper!),
          value: value == true,
          onChanged: onChanged,
        ),
    };

    final hasOwnLabel = q.type == QuestionType.numeric ||
        q.type == QuestionType.text ||
        q.type == QuestionType.date ||
        q.type == QuestionType.boolean;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasOwnLabel) ...[
          Text(
            label,
            style: text.titleSmall?.copyWith(
              color: AppTheme.primaryNavy,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (q.helper != null) Text(q.helper!, style: text.bodySmall),
          const SizedBox(height: 6),
        ],
        input,
      ],
    );
  }
}
