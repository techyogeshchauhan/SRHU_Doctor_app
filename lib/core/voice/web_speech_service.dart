import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'speech_service.dart';

/// The Web Speech API in this browser, or null when it has none (Firefox).
SpeechService? createWebSpeechService() =>
    WebSpeechService.supported ? WebSpeechService() : null;

/// Chrome/Edge/Safari use the prefixed constructor.
@JS('webkitSpeechRecognition')
extension type _WebkitSpeechRecognition._(web.SpeechRecognition _)
    implements web.SpeechRecognition {
  external factory _WebkitSpeechRecognition();
}

/// [SpeechService] on the browser's Web Speech API.
///
/// Uses single-utterance mode (`continuous = false`): the browser decides
/// when the doctor has finished and returns a final, more accurate result,
/// with up to [maxAlternatives] candidates. The speech_to_text web plugin
/// instead keeps listening continuously and only ever reports interim
/// results, which cut answers short.
class WebSpeechService implements SpeechService {
  static const maxAlternatives = 5;

  static bool get supported =>
      web.window.hasProperty('SpeechRecognition'.toJS).toDart ||
      web.window.hasProperty('webkitSpeechRecognition'.toJS).toDart;

  web.SpeechRecognition? _rec;
  Completer<HeardSpeech?>? _pending;
  Timer? _cap;
  web.AudioContext? _audio;

  String _final = '';
  String _interim = '';
  List<String> _alternatives = const [];
  double? _confidence;
  String? _lastError;

  @override
  String? get lastError => _lastError;

  @override
  Future<bool> init() async => supported;

  /// Browsers do not list recognition languages; any BCP-47 tag is tried.
  @override
  Future<Set<String>> localeIds() async => const {};

  web.SpeechRecognition _create() =>
      web.window.hasProperty('SpeechRecognition'.toJS).toDart
          ? web.SpeechRecognition()
          : _WebkitSpeechRecognition();

  @override
  Future<HeardSpeech?> listenOnce({
    required String localeId,
    AnswerLength length = AnswerLength.short,
    void Function(String words)? onPartial,
  }) async {
    await stop();
    if (!supported) return null;
    final done = _pending = Completer<HeardSpeech?>();
    _final = '';
    _interim = '';
    _alternatives = const [];
    _confidence = null;
    _lastError = null;

    final rec = _rec = _create()
      ..lang = localeId
      ..continuous = false
      ..interimResults = true
      ..maxAlternatives = maxAlternatives;

    rec.onresult = ((web.SpeechRecognitionEvent e) {
      if (!identical(rec, _rec)) return;
      _onResult(e);
      final words = '$_final $_interim'.trim();
      if (words.isNotEmpty) onPartial?.call(words);
    }).toJS;
    rec.onerror = ((web.SpeechRecognitionErrorEvent e) {
      if (identical(rec, _rec)) _lastError = e.error;
    }).toJS;
    rec.onend = ((web.Event _) {
      if (identical(rec, _rec)) _finish();
    }).toJS;

    await _startTone();
    if (!identical(rec, _rec) || done.isCompleted) return done.future;
    try {
      rec.start();
    } catch (e) {
      _lastError = '$e';
      _finish();
      return done.future;
    }
    // The browser ends a single utterance by itself; this only caps a
    // session that never ends (e.g. continuous background noise).
    _cap = Timer(
      length == AnswerLength.short
          ? const Duration(seconds: 15)
          : const Duration(seconds: 30),
      () => rec.stop(),
    );
    return done.future;
  }

  void _onResult(web.SpeechRecognitionEvent e) {
    final finals = <String>[];
    final interim = StringBuffer();
    for (var i = 0; i < e.results.length; i++) {
      final r = e.results.item(i);
      if (r.length == 0) continue;
      final best = r.item(0).transcript.trim();
      if (!r.isFinal) {
        interim.write(' $best');
        continue;
      }
      finals.add(best);
      if (finals.length == 1) {
        final c = r.item(0).confidence;
        _confidence = c > 0 ? c : null;
        _alternatives = {
          for (var j = 1; j < r.length; j++) r.item(j).transcript.trim(),
        }.where((a) => a.isNotEmpty && a != best).toList();
      }
    }
    _final = finals.join(' ').trim();
    _interim = interim.toString().trim();
  }

  /// A short, quiet tone so the doctor knows when to speak. Played before
  /// the microphone opens, so it is not recognised as speech.
  Future<void> _startTone() async {
    try {
      final ctx = _audio ??= web.AudioContext();
      if (ctx.state == 'suspended') ctx.resume();
      final osc = ctx.createOscillator();
      final gain = ctx.createGain();
      osc.frequency.value = 880;
      gain.gain.value = 0.05;
      osc.connect(gain);
      gain.connect(ctx.destination);
      final t = ctx.currentTime;
      osc.start(t);
      osc.stop(t + 0.12);
      await Future<void>.delayed(const Duration(milliseconds: 180));
    } catch (_) {
      // No audio output: the on-screen "Speak now" cue is enough.
    }
  }

  void _finish() {
    _cap?.cancel();
    _cap = null;
    final p = _pending;
    if (p == null || p.isCompleted) return;
    _pending = null;
    // A final result is best; an interim one is used only when the
    // browser ended without finalising (it is then usually complete too).
    final text = _final.isNotEmpty ? _final : _interim;
    p.complete(text.isEmpty
        ? null
        : HeardSpeech(
            text,
            confidence: _final.isNotEmpty ? _confidence : null,
            alternatives: _final.isNotEmpty ? _alternatives : const [],
          ));
  }

  @override
  Future<void> stop() async {
    final rec = _rec;
    _rec = null;
    _final = '';
    _interim = '';
    _finish();
    if (rec != null) {
      try {
        rec.abort();
      } catch (_) {}
    }
  }
}
