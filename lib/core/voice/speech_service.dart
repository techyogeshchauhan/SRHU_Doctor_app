import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'web_speech_service_stub.dart'
    if (dart.library.js_interop) 'web_speech_service.dart';

/// Speech recognition used by voice data entry. Overridden in tests.
///
/// Browsers use the Web Speech API directly (single-utterance mode, see
/// [createWebSpeechService]); Android/iOS use the speech_to_text plugin.
final speechServiceProvider = Provider<SpeechService>(
  (ref) => (kIsWeb ? createWebSpeechService() : null) ?? DeviceSpeechService(),
);

/// How long an answer may be: short (a number, an option, yes/no, a date)
/// or long (free text).
enum AnswerLength { short, long }

/// What the recogniser heard for one answer.
class HeardSpeech {
  const HeardSpeech(this.text, {this.confidence, this.alternatives = const []});

  /// Best transcript.
  final String text;

  /// 0–1 for [text], when the recogniser reports one.
  final double? confidence;

  /// Other candidate transcripts, best first (without [text]).
  final List<String> alternatives;

  @override
  String toString() => [
        '"$text"',
        if (confidence != null) '(${confidence!.toStringAsFixed(2)})',
        if (alternatives.isNotEmpty)
          'alts: ${alternatives.map((a) => '"$a"').join(', ')}',
      ].join(' ');
}

/// One-utterance-at-a-time speech recognition.
abstract class SpeechService {
  /// Prepares the recogniser. False when speech recognition is unavailable
  /// (e.g. Firefox, no permission, no recogniser on the device).
  Future<bool> init();

  /// Locale ids the recogniser supports (e.g. "en_IN", "hi-IN"); empty
  /// when it cannot tell (browsers).
  Future<Set<String>> localeIds();

  /// Listens for one answer in [localeId]. [onPartial] receives words as
  /// they are recognised. Returns what was heard, or null when nothing was
  /// (silence, no match, error, or [stop]; see [lastError]).
  Future<HeardSpeech?> listenOnce({
    required String localeId,
    AnswerLength length = AnswerLength.short,
    void Function(String words)? onPartial,
  });

  /// Error reported by the last [listenOnce], if any (e.g. "no-speech",
  /// "not-allowed", "error_permission").
  String? get lastError;

  Future<void> stop();
}

/// Errors meaning the microphone or speech service may not be used.
const speechPermissionErrors = {
  'not-allowed',
  'service-not-allowed',
  'error_permission',
  'error_insufficient_permissions',
};

/// [SpeechService] on the speech_to_text plugin (Android/iOS speech
/// services).
class DeviceSpeechService implements SpeechService {
  DeviceSpeechService({SpeechToText? speech}) : _stt = speech ?? SpeechToText();

  final SpeechToText _stt;
  Future<bool>? _init;
  Completer<HeardSpeech?>? _pending;
  HeardSpeech? _heard;
  String? _lastError;

  @override
  String? get lastError => _lastError;

  /// The plugin's pause timer also runs before the first word, so it must
  /// leave time to start speaking (e.g. after reading a monitor). The
  /// device recogniser still ends the answer itself once speech stops.
  static Duration pauseFor(AnswerLength l) => l == AnswerLength.short
      ? const Duration(seconds: 5)
      : const Duration(seconds: 7);

  static Duration listenFor(AnswerLength l) => l == AnswerLength.short
      ? const Duration(seconds: 15)
      : const Duration(seconds: 30);

  @override
  Future<bool> init() => _init ??= _initialize();

  Future<bool> _initialize() async {
    try {
      return await _stt.initialize(
        // Wait longer for the final result before falling back to the last
        // partial one, which may be cut short.
        finalTimeout: const Duration(seconds: 3),
        onError: (e) {
          _lastError = e.errorMsg;
          _finish();
        },
        onStatus: (s) {
          if (s == SpeechToText.doneStatus || s == 'doneNoResult') _finish();
        },
      );
    } catch (e) {
      debugPrint('Speech recognition unavailable: $e');
      return false;
    }
  }

  @override
  Future<Set<String>> localeIds() async {
    if (!await init()) return const {};
    try {
      return {for (final l in await _stt.locales()) l.localeId};
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<HeardSpeech?> listenOnce({
    required String localeId,
    AnswerLength length = AnswerLength.short,
    void Function(String words)? onPartial,
  }) async {
    if (!await init()) return null;
    _finish();
    final done = _pending = Completer<HeardSpeech?>();
    _heard = null;
    _lastError = null;
    try {
      await _stt.listen(
        onResult: (r) {
          final alts = [
            for (final a in r.alternates)
              if (a.recognizedWords.trim().isNotEmpty) a.recognizedWords.trim(),
          ];
          if (alts.isEmpty) return;
          final c = r.alternates.first.confidence;
          _heard = HeardSpeech(
            alts.first,
            confidence: c > 0 ? c : null,
            alternatives: alts.skip(1).toSet().toList(),
          );
          onPartial?.call(alts.first);
          if (r.finalResult) _finish();
        },
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: listenFor(length),
          pauseFor: pauseFor(length),
          partialResults: true,
          cancelOnError: true,
          listenMode: length == AnswerLength.short
              ? ListenMode.confirmation
              : ListenMode.dictation,
        ),
      );
    } catch (e) {
      _lastError = '$e';
      _finish();
    }
    // Safety net when a platform never reports "done".
    return done.future.timeout(
      listenFor(length) + const Duration(seconds: 5),
      onTimeout: () {
        _stt.cancel();
        return _heard;
      },
    );
  }

  /// Completes the pending listen with what was heard so far.
  void _finish() {
    final p = _pending;
    if (p == null || p.isCompleted) return;
    _pending = null;
    p.complete(_heard);
  }

  @override
  Future<void> stop() async {
    _heard = null;
    _finish();
    if (_stt.isListening) await _stt.cancel();
  }
}
