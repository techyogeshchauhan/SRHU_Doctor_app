import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/core/voice/speech_service.dart';
import 'package:neonatal_stw/core/voice/tts_service.dart';
import 'package:neonatal_stw/features/clinical_workflow/state/assessment_controller.dart';
import 'package:neonatal_stw/features/clinical_workflow/voice/voice_entry_controller.dart';
import 'package:neonatal_stw/features/clinical_workflow/voice/voice_prompts.dart';
import 'package:neonatal_stw/features/rd/domain/rd_workflow.dart';

import 'assessment_test_utils.dart';

/// Answers each listen with [reply] for the question being asked
/// (null questionId = end of page).
class FakeSpeech implements SpeechService {
  FakeSpeech(this.reply, {this.available = true});

  final String? Function(String? questionId, int call) reply;
  final bool available;
  late ProviderContainer container;
  final heardFor = <String?>[];
  final locales = <String>[];

  @override
  Future<bool> init() async => available;

  @override
  Future<Set<String>> localeIds() async => {'en_IN', 'hi_IN'};

  @override
  String? lastError;

  @override
  Future<HeardSpeech?> listenOnce({
    required String localeId,
    AnswerLength length = AnswerLength.short,
    void Function(String words)? onPartial,
  }) async {
    locales.add(localeId);
    final q = container.read(voiceEntryProvider).questionId;
    heardFor.add(q);
    final words = reply(q, heardFor.length);
    if (words == null) return null;
    onPartial?.call(words);
    return HeardSpeech(words);
  }

  @override
  Future<void> stop() async {}
}

class FakeTts implements TtsService {
  final spoken = <String>[];

  @override
  Future<void> speak(String text, {required String localeId}) async =>
      spoken.add(text);

  @override
  Future<void> stop() async {}
}

const retry = 'This value seems incorrect. Please repeat it.';

void main() {
  late FakeTts tts;
  VoiceEntryController.afterSpeechGap = Duration.zero;

  ProviderContainer setUpRd(FakeSpeech speech) {
    tts = FakeTts();
    final c = ProviderContainer(overrides: [
      speechServiceProvider.overrideWithValue(speech),
      ttsServiceProvider.overrideWithValue(tts),
      assessmentTodayProvider.overrideWithValue(testToday),
    ]);
    speech.container = c;
    c.read(assessmentProvider.notifier).start({rd});
    return c;
  }

  Object? answerOf(ProviderContainer c, String variable) =>
      c.read(assessmentProvider).context.answers[variable];

  test('per-field: invalid value is re-prompted, then the valid one is stored',
      () async {
    final replies = ['two hundred', 'sixty two'];
    final speech = FakeSpeech((_, call) => replies[call - 1]);
    final c = setUpRd(speech);
    addTearDown(c.dispose);

    await c.read(voiceEntryProvider.notifier).listenField(rdRrKey);

    expect(answerOf(c, rdRrKey), 62);
    expect(
      tts.spoken,
      [
        '$retry It should be between 0 and 150 per minute.',
        'Respiratory rate: 62 per minute, recorded.'
      ],
    );
    expect(c.read(voiceEntryProvider).status, VoiceStatus.idle);
  });

  test('per-field: gives up after $voiceMaxAttempts unusable answers',
      () async {
    final speech = FakeSpeech((_, __) => 'banana');
    final c = setUpRd(speech);
    addTearDown(c.dispose);

    await c.read(voiceEntryProvider.notifier).listenField(rdRrKey);

    expect(speech.heardFor, hasLength(voiceMaxAttempts));
    expect(tts.spoken.where((s) => s.startsWith(retry)),
        hasLength(voiceMaxAttempts - 1));
    expect(tts.spoken.last, 'Please enter this value manually.');
    expect(answerOf(c, rdRrKey), isNull);
    expect(c.read(voiceEntryProvider).status, VoiceStatus.idle);
  });

  test('guided: asks each question, re-prompts, and continues on "next"',
      () async {
    var pageEnds = 0;
    var rrTries = 0;
    final speech = FakeSpeech((q, _) {
      switch (q) {
        case null:
          return ++pageEnds == 1 ? 'next' : 'stop';
        case rdRrKey:
          return ++rrTries == 1 ? 'two hundred' : 'sixty two';
        case rdSignsKey:
          return 'grunting and nasal flaring';
        default:
          return 'skip';
      }
    });
    final c = setUpRd(speech);
    addTearDown(c.dispose);
    expect(c.read(assessmentProvider).currentGroup, 'rd_signs');

    await c.read(voiceEntryProvider.notifier).startGuided();

    expect(answerOf(c, rdRrKey), 62);
    expect(rrTries, 2);
    expect(answerOf(c, rdSignsKey), {'grunting', 'nasalFlaring'});
    expect(
        tts.spoken.first, 'Apnoea/gasping, poor effort or shock. Yes or no?');
    expect(tts.spoken, contains('$retry It should be between 0 and 150 per minute.'));
    expect(tts.spoken, contains(startsWith('Signs present')));
    expect(tts.spoken,
        contains('This page is complete. Say next to continue, or stop.'));
    // "next" confirmed the signs page; "stop" ended on a later page.
    expect(c.read(assessmentProvider).currentGroup, isNot('rd_signs'));
    expect(pageEnds, 2);
    expect(tts.spoken.last, 'Voice entry stopped.');
    expect(c.read(voiceEntryProvider).guided, isFalse);
    expect(c.read(voiceEntryProvider).status, VoiceStatus.idle);
  });

  test('Hindi: listens in hi-IN and speaks Hindi prompts', () async {
    final replies = ['नौ सौ', 'baasath'];
    final speech = FakeSpeech((_, call) => replies[call - 1]);
    final c = setUpRd(speech);
    addTearDown(c.dispose);
    final voice = c.read(voiceEntryProvider.notifier);
    await voice.ensureReady();
    voice.setLanguage(VoiceLanguage.hindi);

    await voice.listenField(rdRrKey);

    expect(speech.locales, everyElement('hi_IN'));
    expect(answerOf(c, rdRrKey), 62);
    expect(tts.spoken.first, startsWith('यह मान सही नहीं लगता।'));
  });

  test('unavailable recogniser: nothing is asked', () async {
    final speech = FakeSpeech((_, __) => '62', available: false);
    final c = setUpRd(speech);
    addTearDown(c.dispose);

    await c.read(voiceEntryProvider.notifier).startGuided();

    expect(c.read(voiceEntryProvider).available, isFalse);
    expect(speech.heardFor, isEmpty);
    expect(tts.spoken, isEmpty);
  });

  test('blocked microphone stops voice entry and hides it', () async {
    late FakeSpeech speech;
    speech = FakeSpeech((_, __) {
      speech.lastError = 'not-allowed';
      return null;
    });
    final c = setUpRd(speech);
    addTearDown(c.dispose);

    await c.read(voiceEntryProvider.notifier).startGuided();

    expect(speech.heardFor, hasLength(1));
    expect(tts.spoken.last, startsWith('Microphone access is blocked.'));
    expect(c.read(voiceEntryProvider).available, isFalse);
    expect(c.read(voiceEntryProvider).status, VoiceStatus.idle);
  });

  test('stop ends a run immediately', () async {
    late ProviderContainer c;
    final speech = FakeSpeech((_, __) {
      c.read(voiceEntryProvider.notifier).stop();
      return '62';
    });
    c = setUpRd(speech);
    addTearDown(c.dispose);

    await c.read(voiceEntryProvider.notifier).startGuided();

    expect(speech.heardFor, hasLength(1));
    expect(answerOf(c, rdRrKey), isNull);
    expect(c.read(voiceEntryProvider).status, VoiceStatus.idle);
  });
}
