import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/voice/speech_service.dart';
import '../../../core/widgets/back_to_home_button.dart';
import '../../../core/widgets/layout.dart';
import '../../../data/repositories/audit_log_repository.dart';
import '../../clinical_workflow/voice/voice_prompts.dart';
import '../domain/case_parser.dart';
import 'structured_case_form.dart';

const caseEntryExample =
    'e.g. Baby, 36 wk, BW 2.4 kg, day 3. RR 70/min. Jaundice up to palms '
    'and soles.';

/// Free-text case history (typed or dictated), read by on-device rules.
/// The text stays on the device: it is neither synced nor logged.
class CaseEntryScreen extends ConsumerStatefulWidget {
  const CaseEntryScreen({super.key, this.initialText});

  /// Pre-filled text (e.g. from the chat assistant).
  final String? initialText;

  @override
  ConsumerState<CaseEntryScreen> createState() => _CaseEntryScreenState();
}

class _CaseEntryScreenState extends ConsumerState<CaseEntryScreen> {
  late final _text = TextEditingController(text: widget.initialText ?? '');
  var _language = VoiceLanguage.english;
  var _listening = false;

  /// Structured form first; free text when opened with text (e.g. chat).
  late var _mode =
      widget.initialText == null ? _CaseInput.form : _CaseInput.text;
  var _partial = '';

  @override
  void dispose() {
    if (_listening) ref.read(speechServiceProvider).stop();
    _text.dispose();
    super.dispose();
  }

  static String? _matchLocale(Set<String> ids, String wanted) {
    String norm(String s) => s.replaceAll('_', '-').toLowerCase();
    final w = norm(wanted);
    return ids.where((i) => norm(i) == w).firstOrNull ??
        ids
            .where((i) => norm(i).split('-').first == w.split('-').first)
            .firstOrNull;
  }

  Future<void> _toggleMic() async {
    final speech = ref.read(speechServiceProvider);
    if (_listening) {
      await speech.stop();
      return;
    }
    ref.read(auditLogProvider).tap('case_entry_mic');
    if (!await speech.init()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Voice entry is not available on this device or '
            'browser (or microphone access was denied).'),
      ));
      return;
    }
    final ids = await speech.localeIds();
    final locale = _matchLocale(ids, _language.localeId) ?? _language.localeId;
    if (!mounted) return;
    setState(() => _listening = true);
    final heard = await speech.listenOnce(
      localeId: locale,
      length: AnswerLength.long,
      onPartial: (w) {
        if (mounted) setState(() => _partial = w);
      },
    );
    if (!mounted) return;
    setState(() {
      _listening = false;
      _partial = '';
      final words = heard?.text.trim() ?? '';
      if (words.isNotEmpty) {
        final current = _text.text.trimRight();
        _text.text = current.isEmpty ? words : '$current, $words';
        _text.selection = TextSelection.collapsed(offset: _text.text.length);
      }
    });
  }

  void _analyse() => _openAnalysis(parseCase(_text.text), 'text');

  void _openAnalysis(ParsedCase parsed, String input) {
    ref.read(auditLogProvider).tap('case_entry_analyse', {
      'input': input,
      'topics': [for (final c in parsed.topics) c.name],
      'fields': [for (final i in parsed.items) i.key],
    });
    context.push('/case/review', extra: parsed);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 58,
        titleSpacing: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_rounded, color: AppTheme.primaryNavy),
          tooltip: 'Back',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: const Text(
          'Case history',
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
                Text(
                  'Select the findings (or type / dictate them). You review '
                  'what was recorded, the app shows the STWs the findings '
                  'trigger, then guides management with each of them.',
                  style: text.bodyMedium?.copyWith(color: AppTheme.mutedText),
                ),
                const SizedBox(height: 12),
                SegmentedButton<_CaseInput>(
                  key: const ValueKey('case-input-mode'),
                  segments: const [
                    ButtonSegment(
                      value: _CaseInput.form,
                      icon: Icon(Icons.checklist_rounded),
                      label: Text('Select findings'),
                    ),
                    ButtonSegment(
                      value: _CaseInput.text,
                      icon: Icon(Icons.keyboard_voice_outlined),
                      label: Text('Type or dictate'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (m) => setState(() => _mode = m.single),
                ),
                const SizedBox(height: 12),
                // Both inputs keep what was entered while the other is shown.
                Visibility(
                  visible: _mode == _CaseInput.form,
                  maintainState: true,
                  child: StructuredCaseForm(
                    onAnalyse: (c) => _openAnalysis(c, 'form'),
                  ),
                ),
                Visibility(
                  visible: _mode == _CaseInput.text,
                  maintainState: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const ValueKey('case-text'),
                        controller: _text,
                        minLines: 5,
                        maxLines: 10,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: caseEntryExample,
                          hintMaxLines: 3,
                          border: OutlineInputBorder(),
                          helperText:
                              'Do not enter names or other identifiers.',
                        ),
                      ),
                      if (_listening) ...[
                        const SizedBox(height: 8),
                        AlertBanner(
                          tone: Tone.info,
                          text: _partial.isEmpty
                              ? 'Listening… speak now'
                              : _partial,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            key: const ValueKey('case-mic'),
                            onPressed: _toggleMic,
                            icon: Icon(_listening
                                ? Icons.stop_circle_outlined
                                : Icons.mic_none_rounded),
                            label: Text(_listening ? 'Stop' : 'Dictate'),
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 46)),
                          ),
                          SegmentedButton<VoiceLanguage>(
                            segments: [
                              for (final l in VoiceLanguage.values)
                                ButtonSegment(
                                    value: l, label: Text(l.shortLabel)),
                            ],
                            selected: {_language},
                            showSelectedIcon: false,
                            onSelectionChanged: _listening
                                ? null
                                : (s) => setState(() => _language = s.single),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        key: const ValueKey('case-analyse'),
                        onPressed: _text.text.trim().isEmpty ? null : _analyse,
                        icon: const Icon(Icons.manage_search_rounded),
                        label: const Text('Analyse'),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const AlertBanner(
                  tone: Tone.info,
                  text: 'The case stays on this device. Recommendations '
                      'come only from the STW rules, after you confirm each '
                      'value.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _CaseInput { form, text }
