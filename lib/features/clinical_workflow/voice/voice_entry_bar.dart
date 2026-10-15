import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import 'voice_entry_controller.dart';
import 'voice_prompts.dart';

/// Start button, language choice and live status of voice entry, shown
/// above the assessment page. Stops voice entry when it leaves the screen.
class VoiceEntryBar extends ConsumerStatefulWidget {
  const VoiceEntryBar({super.key, required this.canStart});

  /// False on the summary: only a running session is shown.
  final bool canStart;

  @override
  ConsumerState<VoiceEntryBar> createState() => _VoiceEntryBarState();
}

class _VoiceEntryBarState extends ConsumerState<VoiceEntryBar> {
  late final VoiceEntryController _voice;

  @override
  void initState() {
    super.initState();
    _voice = ref.read(voiceEntryProvider.notifier);
  }

  @override
  void dispose() {
    // Not during the unmount itself: changing provider state then throws.
    final voice = _voice;
    scheduleMicrotask(voice.stop);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(voiceEntryProvider);
    if (s.active) return _ActiveBar(state: s, onStop: _voice.stop);
    if (!widget.canStart) return const SizedBox.shrink();
    if (s.available == false) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(Icons.mic_off_outlined, size: 16, color: AppTheme.mutedText),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Voice entry is not available on this device or browser '
                '(or microphone access was denied). Use Chrome, Edge or '
                'Safari, or the Android/iOS app.',
                style: TextStyle(fontSize: 12, color: AppTheme.mutedText),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.tonalIcon(
            onPressed: _voice.startGuided,
            icon: const Icon(Icons.record_voice_over_rounded, size: 18),
            label: const Text('Voice entry'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              textStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SegmentedButton<VoiceLanguage>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              for (final l in VoiceLanguage.values)
                ButtonSegment(
                  value: l,
                  label: Text(l.shortLabel),
                  enabled: s.available == null || s.languages.contains(l),
                  tooltip: l == VoiceLanguage.english
                      ? 'English (India)'
                      : 'Hindi / Hinglish',
                ),
            ],
            selected: {s.language},
            onSelectionChanged: (v) => _voice.setLanguage(v.first),
          ),
          const Tooltip(
            message: 'Speech is processed by your device or browser speech '
                'service (Google/Apple). Only the values you confirm are '
                'saved; recordings and transcripts are not stored.\n'
                'Say "next", "back", "skip", "repeat", "clear" or "stop" at '
                'any time.',
            triggerMode: TooltipTriggerMode.tap,
            showDuration: Duration(seconds: 8),
            child: Icon(Icons.info_outline_rounded,
                size: 18, color: AppTheme.mutedText),
          ),
        ],
      ),
    );
  }
}

class _ActiveBar extends StatelessWidget {
  const _ActiveBar({required this.state, required this.onStop});

  final VoiceEntryState state;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final listening = state.status == VoiceStatus.listening;
    final (icon, title) = switch (state.status) {
      VoiceStatus.listening => (Icons.mic_rounded, 'Speak now…'),
      VoiceStatus.speaking => (Icons.volume_up_rounded, 'Speaking…'),
      _ => (Icons.hourglass_top_rounded, 'Starting voice entry…'),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Pulse(
              active: listening,
              child: Icon(icon, color: AppTheme.primaryBlue)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.guided
                      ? '$title  ·  ${state.language.shortLabel}'
                      : title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryNavy,
                  ),
                ),
                if (state.message != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    state.message!,
                    style: const TextStyle(fontSize: 12.5, height: 1.3),
                  ),
                ],
                if (listening && state.partial.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '“${state.partial}”',
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ],
                if (state.guided) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Say: next · back · skip · repeat · clear · stop',
                    style: TextStyle(fontSize: 11, color: AppTheme.mutedText),
                  ),
                ],
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.stop_circle_outlined, size: 18),
            label: const Text('Stop'),
          ),
        ],
      ),
    );
  }
}

/// Gently pulses [child] while [active] (the microphone is open).
class _Pulse extends StatefulWidget {
  const _Pulse({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    lowerBound: 0.85,
    upperBound: 1.15,
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Pulse old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _c, child: widget.child);
}
