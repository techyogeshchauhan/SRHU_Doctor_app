import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/utils/condition_exit_dialog.dart';
import '../../../core/widgets/back_to_home_button.dart';
import '../../../core/widgets/layout.dart';
import '../../clinical_workflow/domain/shared_questions.dart';
import '../../clinical_workflow/state/assessment_controller.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../domain/case_parser.dart';

/// "We understood": every value read from the case history, editable, and
/// the STWs it triggers. Nothing is recommended here.
class CaseReviewScreen extends ConsumerStatefulWidget {
  const CaseReviewScreen({super.key, required this.parsed});

  final ParsedCase parsed;

  @override
  ConsumerState<CaseReviewScreen> createState() => _CaseReviewScreenState();
}

class _CaseReviewScreenState extends ConsumerState<CaseReviewScreen> {
  late final Map<String, Object?> _answers = {...widget.parsed.answers};
  late final Set<NeonatalCondition> _topics = {...widget.parsed.topics};
  late final Map<String, TextEditingController> _edits = {
    for (final i in widget.parsed.items)
      if (i.kind != ParsedValueKind.fixed)
        i.key: TextEditingController(text: '${i.value}'),
  };

  @override
  void dispose() {
    for (final c in _edits.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _remove(ParsedItem item) => setState(() {
        _answers.remove(item.key);
        // GA weeks carry "GA known" and "+ days" with them.
        if (item.key == gaWeeksKey) {
          _answers
            ..remove(gaKnownKey)
            ..remove(gaDaysKey);
        }
      });

  void _edit(ParsedItem item, String text) {
    final v = item.kind == ParsedValueKind.integer
        ? int.tryParse(text.trim())
        : double.tryParse(text.trim());
    setState(() {
      if (v == null) {
        _answers.remove(item.key);
      } else {
        _answers[item.key] = v;
      }
    });
  }

  void _start() {
    final selected = {
      for (final c in NeonatalCondition.values)
        if (_topics.contains(c)) c,
    };
    clearConditionData(ref);
    ref.read(assessmentProvider.notifier).startFromCase(selected, _answers);
    context.push('/workflow');
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.parsed;
    final text = Theme.of(context).textTheme;
    final small = text.bodySmall?.copyWith(color: AppTheme.mutedText);
    final offered = [
      for (final d in conditionDefinitions)
        if (d.implemented) d.id,
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 58,
        titleSpacing: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_rounded, color: AppTheme.primaryNavy),
          tooltip: 'Back',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/case'),
        ),
        title: const Text(
          'We understood',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 17.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryNavy,
          ),
        ),
        actions: const [BackToHomeButton(iconOnly: true), SizedBox(width: 8)],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionCard(
                  title: 'Values read from the case',
                  subtitle: 'Check each value. You will confirm them again on '
                      'each assessment page.',
                  child: p.items.isEmpty
                      ? const Text('No values recognised.')
                      : Column(
                          children: [
                            for (final item in p.items)
                              if (_answers.containsKey(item.key))
                                _ItemRow(
                                  key: ValueKey('case-item-${item.key}'),
                                  item: item,
                                  controller: _edits[item.key],
                                  onChanged: (t) => _edit(item, t),
                                  onRemove: () => _remove(item),
                                ),
                          ],
                        ),
                ),
                SectionCard(
                  title: 'STWs to use',
                  subtitle: 'Detected from the findings. Tap to add or remove.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final c in offered)
                            FilterChip(
                              key: ValueKey('case-topic-${c.name}'),
                              label: Text(definitionOf(c).title),
                              selected: _topics.contains(c),
                              onSelected: (on) => setState(() =>
                                  on ? _topics.add(c) : _topics.remove(c)),
                            ),
                        ],
                      ),
                      for (final e in p.topicReasons.entries)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                              '${definitionOf(e.key).title}: ${e.value}',
                              style: small),
                        ),
                    ],
                  ),
                ),
                if (p.notes.isNotEmpty)
                  SectionCard(
                    title: 'Also noted (not filled in)',
                    child: Bullets(p.notes),
                  ),
                if (p.unrecognised.isNotEmpty)
                  SectionCard(
                    title: 'Not recognised: ignored',
                    subtitle: 'Enter these on the assessment pages if they '
                        'matter.',
                    child: Bullets(p.unrecognised),
                  ),
                const SizedBox(height: 4),
                FilledButton.icon(
                  key: const ValueKey('case-start'),
                  onPressed: _topics.isEmpty ? null : _start,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start guided plan'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
                if (_topics.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Select at least one STW.', style: small),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onRemove,
    this.controller,
  });

  final ParsedItem item;
  final TextEditingController? controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final small = text.bodySmall?.copyWith(color: AppTheme.mutedText);
    final unit =
        RegExp(r'[^\d.+]+$').firstMatch(item.display)?.group(0)?.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    item.label,
                    if (item.topic != null) definitionOf(item.topic!).title,
                  ].join(' · '),
                  style: text.labelLarge?.copyWith(color: AppTheme.primaryNavy),
                ),
                const SizedBox(height: 4),
                if (controller == null)
                  Text(item.display, style: text.bodyLarge)
                else
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: controller,
                      onChanged: onChanged,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        isDense: true,
                        suffixText: unit,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                const SizedBox(height: 2),
                Text('From: "${item.source}"', style: small),
                if (item.note != null) Text(item.note!, style: small),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
