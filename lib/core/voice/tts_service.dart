import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech used by voice data entry. Overridden in tests.
final ttsServiceProvider = Provider<TtsService>((ref) => DeviceTtsService());

abstract class TtsService {
  /// Speaks [text] in [localeId] and completes when it has been spoken, so
  /// the app does not listen to its own voice.
  Future<void> speak(String text, {required String localeId});

  Future<void> stop();
}

/// [TtsService] on the platform voice (Android/iOS TTS, browser
/// speechSynthesis).
class DeviceTtsService implements TtsService {
  DeviceTtsService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  Future<void>? _setup;
  String? _locale;

  Future<void> _ensureSetup() => _setup ??= () async {
        try {
          await _tts.awaitSpeakCompletion(true);
        } catch (e) {
          debugPrint('TTS setup failed: $e');
        }
      }();

  @override
  Future<void> speak(String text, {required String localeId}) async {
    if (text.trim().isEmpty) return;
    await _ensureSetup();
    try {
      if (_locale != localeId) {
        _locale = localeId;
        await _tts.setLanguage(localeId);
      }
      // Browsers drop the completion when speech errors, so never wait
      // longer than the text could take.
      await Future<void>.value(_tts.speak(text)).timeout(
        Duration(milliseconds: 3000 + text.length * 90),
        onTimeout: () {},
      );
    } catch (e) {
      debugPrint('TTS failed: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
