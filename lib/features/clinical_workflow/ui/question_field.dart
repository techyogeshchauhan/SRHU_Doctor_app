import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/radio_choice_group.dart';
import '../domain/clinical_question.dart';

String _hintFor(ClinicalQuestion question) {
  final label = question.question;
  final lowerInitial = label.isEmpty
      ? 'value'
      : '${label[0].toLowerCase()}${label.substring(1)}';
  return question.inputHint ?? 'Enter $lowerInitial';
}

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
    this.onVoice,
    this.voiceActive = false,
  });

  final ClinicalQuestion question;

  /// Options currently visible (option-level conditions applied).
  final List<QuestionOption> options;
  final Object? value;
  final bool isRequired;
  final DateTime today;
  final ValueChanged<Object?> onChanged;

  /// Answer this question by voice; null hides the mic button.
  final VoidCallback? onVoice;

  /// Voice entry is asking or listening for this question.
  final bool voiceActive;

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
      QuestionType.numeric => q.displayFactor == 1
          ? NumberField(
              label: label,
              suffix: q.displayUnit ?? q.unit,
              hintText: _hintFor(q),
              value: value as int?,
              min: q.min ?? 0,
              max: q.max ?? 100000,
              helper: q.helper,
              rangeHint: q.stwRange,
              onChanged: onChanged,
            )
          : DecimalNumberField(
              label: label,
              suffix: q.displayUnit ?? q.unit,
              hintText: _hintFor(q),
              value: value == null ? null : (value as num) / q.displayFactor,
              min: (q.min ?? 0) / q.displayFactor,
              max: (q.max ?? 100000) / q.displayFactor,
              helper: q.helper,
              rangeHint: q.stwRange,
              onChanged: (v) => onChanged(
                v == null ? null : (v * q.displayFactor).round(),
              ),
            ),
      QuestionType.decimal => DecimalNumberField(
          label: label,
          suffix: q.displayUnit ?? q.unit,
          hintText: _hintFor(q),
          value: value as num?,
          min: q.min ?? 0,
          max: q.max ?? 100000,
          helper: q.helper,
          rangeHint: q.stwRange,
          onChanged: onChanged,
        ),
      QuestionType.text => _TextAnswerField(
          label: label,
          hint: _hintFor(q),
          helper: q.helper,
          value: value as String?,
          onChanged: onChanged,
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
        q.type == QuestionType.decimal ||
        q.type == QuestionType.text ||
        q.type == QuestionType.date ||
        q.type == QuestionType.boolean;

    final mic = onVoice == null
        ? null
        : IconButton(
            onPressed: onVoice,
            tooltip: 'Answer by voice',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              voiceActive ? Icons.mic_rounded : Icons.mic_none_rounded,
              size: 20,
              color: voiceActive ? AppTheme.primaryBlue : AppTheme.mutedText,
            ),
          );

    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasOwnLabel) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: text.titleSmall?.copyWith(
                    color: AppTheme.primaryNavy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (mic != null) mic,
            ],
          ),
          if (q.helper != null) Text(q.helper!, style: text.bodySmall),
          const SizedBox(height: 6),
        ],
        if (hasOwnLabel && mic != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: input),
              Padding(padding: const EdgeInsets.only(top: 4), child: mic),
            ],
          )
        else
          input,
      ],
    );

    if (voiceActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.2,
            duration: const Duration(milliseconds: 250),
          );
        }
      });
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: voiceActive ? const EdgeInsets.all(8) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: voiceActive ? const Color(0xFFEFF6FF) : null,
        borderRadius: BorderRadius.circular(10),
        border: voiceActive
            ? Border.all(color: AppTheme.primaryBlue, width: 1.5)
            : null,
      ),
      child: field,
    );
  }
}

/// Free-text answer that also shows values set from outside (voice entry).
class _TextAnswerField extends StatefulWidget {
  const _TextAnswerField({
    required this.label,
    required this.hint,
    required this.helper,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final String? helper;
  final String? value;
  final ValueChanged<Object?> onChanged;

  @override
  State<_TextAnswerField> createState() => _TextAnswerFieldState();
}

class _TextAnswerFieldState extends State<_TextAnswerField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value ?? '');

  @override
  void didUpdateWidget(_TextAnswerField old) {
    super.didUpdateWidget(old);
    final v = widget.value ?? '';
    // Typing blanks is stored as null; keep what the user typed then.
    final typedBlank = widget.value == null && _controller.text.trim().isEmpty;
    if (v != _controller.text && !typedBlank) _controller.text = v;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: _controller,
        keyboardType: TextInputType.text,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: _controller.text.isEmpty ? widget.hint : null,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
          helperText: widget.helper,
        ),
        onChanged: (v) {
          setState(() {});
          widget.onChanged(v.trim().isEmpty ? null : v);
        },
      );
}
