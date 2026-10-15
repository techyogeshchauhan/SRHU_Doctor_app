import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/voice/speech_service.dart';
import '../../../core/voice/tts_service.dart';
import '../domain/assessment_engine.dart';
import '../domain/clinical_question.dart';
import '../state/assessment_controller.dart';
import 'voice_answer_parser.dart';
import 'voice_commands.dart';
import 'voice_prompts.dart';

enum VoiceStatus { idle, starting, speaking, listening }

class VoiceEntryState {
  const VoiceEntryState({
    this.status = VoiceStatus.idle,
    this.guided = false,
    this.questionId,
    this.partial = '',
    this.message,
    this.language = VoiceLanguage.english,
    this.available,
    this.languages = const {VoiceLanguage.english},
  });

  final VoiceStatus status;

  /// True during a hands-free run through the pages.
  final bool guided;

  /// Question being asked or listened for.
  final String? questionId;

  /// Words recognised so far while listening.
  final String partial;

  /// Last prompt spoken (shown as text too).
  final String? message;
  final VoiceLanguage language;

  /// Null until first used; false when this device/browser cannot
  /// recognise speech.
  final bool? available;

  /// Languages the recogniser supports here.
  final Set<VoiceLanguage> languages;

  bool get active => status != VoiceStatus.idle;

  VoiceEntryState copyWith({
    VoiceStatus? status,
    bool? guided,
    Object? questionId = _keep,
    String? partial,
    Object? message = _keep,
    VoiceLanguage? language,
    bool? available,
    Set<VoiceLanguage>? languages,
  }) =>
      VoiceEntryState(
        status: status ?? this.status,
        guided: guided ?? this.guided,
        questionId: identical(questionId, _keep)
            ? this.questionId
            : questionId as String?,
        partial: partial ?? this.partial,
        message: identical(message, _keep) ? this.message : message as String?,
        language: language ?? this.language,
        available: available ?? this.available,
        languages: languages ?? this.languages,
      );

  static const _keep = Object();
}

/// How asking one question ended.
enum _Outcome { answered, skipped, gaveUp, next, back, stop, aborted }

/// Voice data entry: speaks questions, listens, parses the answer and stores
/// it through [AssessmentController.answer]. Invalid or unclear answers are
/// asked again ("This value seems incorrect. Please repeat it.") up to
/// [voiceMaxAttempts] times, then left for manual entry.
class VoiceEntryController extends Notifier<VoiceEntryState> {
  /// Incremented by every start/stop; a run whose id is no longer current
  /// ends at its next step.
  int _run = 0;
  bool _disposed = false;

  /// Pause between the app finishing speaking and the microphone opening,
  /// so the first word is not cut off and the app's own voice (or its echo
  /// from laptop speakers) is not recognised.
  @visibleForTesting
  static Duration afterSpeechGap = const Duration(milliseconds: 450);
  final Map<VoiceLanguage, String> _listenIds = {};

  SpeechService get _speech => ref.read(speechServiceProvider);
  TtsService get _tts => ref.read(ttsServiceProvider);
  AssessmentEngine get _engine => ref.read(assessmentEngineProvider);
  AssessmentController get _assessment => ref.read(assessmentProvider.notifier);
  VoicePrompts get _prompts => VoicePrompts(state.language);

  @override
  VoiceEntryState build() {
    final speech = _speech;
    final tts = _tts;
    ref.onDispose(() {
      _disposed = true;
      _run++;
      speech.stop();
      tts.stop();
    });
    return const VoiceEntryState();
  }

  void setLanguage(VoiceLanguage language) {
    if (state.languages.contains(language)) {
      state = state.copyWith(language: language);
    }
  }

  /// Initialises speech recognition (asking for permission) and finds the
  /// supported languages. False when voice entry cannot be used here.
  Future<bool> ensureReady() async {
    if (state.available == false) return false;
    if (state.available == true) return true;
    final ok = await _speech.init();
    if (!ok) {
      state = state.copyWith(available: false);
      return false;
    }
    final ids = await _speech.localeIds();
    _listenIds.clear();
    for (final lang in VoiceLanguage.values) {
      final id = _matchLocale(ids, lang.localeId);
      if (id != null) _listenIds[lang] = id;
    }
    // Browsers list only the user's languages but recognise many more.
    if (kIsWeb || ids.isEmpty) {
      for (final lang in VoiceLanguage.values) {
        _listenIds.putIfAbsent(lang, () => lang.localeId);
      }
    }
    _listenIds.putIfAbsent(VoiceLanguage.english, () => 'en-IN');
    state = state.copyWith(available: true, languages: _listenIds.keys.toSet());
    return true;
  }

  /// [wanted] ("en-IN") as the recogniser spells it, else the same
  /// language in another region.
  static String? _matchLocale(Set<String> ids, String wanted) {
    String norm(String s) => s.replaceAll('_', '-').toLowerCase();
    final w = norm(wanted);
    final lang = w.split('-').first;
    return ids.where((i) => norm(i) == w).firstOrNull ??
        ids.where((i) => norm(i).split('-').first == lang).firstOrNull;
  }

  /// Ends any voice activity.
  Future<void> stop() async {
    if (_disposed) return;
    _run++;
    state = state.copyWith(
      status: VoiceStatus.idle,
      guided: false,
      questionId: null,
      partial: '',
    );
    await Future.wait([_speech.stop(), _tts.stop()]);
  }

  // ------------------------------------------------------------ runs

  Future<int?> _begin({required bool guided}) async {
    final run = ++_run;
    await Future.wait([_speech.stop(), _tts.stop()]);
    state = state.copyWith(
      status: VoiceStatus.starting,
      guided: guided,
      questionId: null,
      partial: '',
      message: null,
    );
    if (!await ensureReady() || run != _run) {
      if (run == _run) state = state.copyWith(status: VoiceStatus.idle);
      return null;
    }
    return run;
  }

  void _end(int run) {
    if (run != _run) return;
    state = state.copyWith(
      status: VoiceStatus.idle,
      guided: false,
      questionId: null,
      partial: '',
    );
  }

  bool _alive(int run) => run == _run;

  /// Hands-free entry: asks every unanswered question of the current page,
  /// then offers to continue to the next page, until stopped or the
  /// assessment is complete.
  Future<void> startGuided() async {
    final run = await _begin(guided: true);
    if (run == null) return;
    String? page;
    final passed = <String>{}; // skipped or left for manual entry
    var quietPageEnds = 0;

    while (_alive(run)) {
      final a = ref.read(assessmentProvider);
      final group = a.currentGroup;
      if (group == null) {
        await _say(run, _prompts.assessmentComplete());
        break;
      }
      if (group != page) {
        page = group;
        passed.clear();
        quietPageEnds = 0;
      }
      final rq = _engine
          .pageQuestions(a.context, group)
          .where((rq) =>
              !passed.contains(rq.id) &&
              !rq.question.isAnswered(a.context.answers[rq.question.variable]))
          .firstOrNull;

      final outcome = rq == null
          ? await _pageEnd(run)
          : await _ask(run, rq, readQuestion: true);
      switch (outcome) {
        case _Outcome.answered:
          quietPageEnds = 0;
        case _Outcome.skipped || _Outcome.gaveUp:
          if (rq != null) passed.add(rq.id);
          if (rq == null && ++quietPageEnds >= voiceMaxAttempts) {
            await _say(run, _prompts.stopped());
            _end(run);
            return;
          }
        case _Outcome.next:
          final g = ref.read(assessmentProvider).currentGroup;
          final ctx = ref.read(assessmentProvider).context;
          if (g != null && _engine.canConfirm(ctx, g)) {
            _assessment.confirmPage();
          } else {
            await _say(run, _prompts.requiredMissing());
            // Ask the skipped questions again.
            passed.clear();
          }
        case _Outcome.back:
          if (!_assessment.back()) await _say(run, _prompts.firstPage());
        case _Outcome.stop || _Outcome.aborted:
          _end(run);
          return;
      }
    }
    _end(run);
  }

  /// Per-field mic: listens for an answer to [questionId] only.
  Future<void> listenField(String questionId) async {
    final run = await _begin(guided: false);
    if (run == null) return;
    final a = ref.read(assessmentProvider);
    final rq = _engine
        .applicableQuestions(a.context)
        .where((q) => q.id == questionId)
        .firstOrNull;
    if (rq != null) await _ask(run, rq, readQuestion: false);
    _end(run);
  }

  /// End of a page in guided mode: waits for "next", "back" or "stop".
  Future<_Outcome> _pageEnd(int run) async {
    state = state.copyWith(questionId: null);
    await _say(run, _prompts.pageComplete());
    final heard = await _listen(run, null);
    if (!_alive(run)) return _Outcome.aborted;
    if (heard == null && _micBlocked()) return _blocked(run, null);
    final command = heard == null ? null : matchVoiceCommand(heard.text);
    _log(null, heard,
        command == null ? 'no command' : 'command ${command.name}');
    return switch (command) {
      VoiceCommand.next => _Outcome.next,
      VoiceCommand.back => _Outcome.back,
      VoiceCommand.stop => await _stopSaid(run),
      // Silence or anything else: say the prompt again (counted).
      _ => _Outcome.gaveUp,
    };
  }

  bool _micBlocked() => speechPermissionErrors.contains(_speech.lastError);

  /// Microphone permission was refused: voice entry cannot continue.
  Future<_Outcome> _blocked(int run, ResolvedQuestion? rq) async {
    _log(rq, null, 'microphone blocked (${_speech.lastError})');
    state = state.copyWith(available: false);
    await _say(run, _prompts.micBlocked());
    return _Outcome.stop;
  }

  Future<_Outcome> _stopSaid(int run) async {
    await _say(run, _prompts.stopped());
    return _Outcome.stop;
  }

  /// Asks [rq] until a valid answer is stored, a command is said, or
  /// [voiceMaxAttempts] unusable answers were heard.
  Future<_Outcome> _ask(int run, ResolvedQuestion rq,
      {required bool readQuestion}) async {
    final q = rq.question;
    state = state.copyWith(questionId: rq.id);
    var attempts = 0;
    var readOut = readQuestion;

    while (_alive(run)) {
      final ctx = ref.read(assessmentProvider).context;
      final options = _engine.visibleOptions(q, ctx);
      if (readOut) {
        await _say(run, _prompts.question(q, options));
        readOut = false;
      }
      final heard = await _listen(run, rq);
      if (!_alive(run)) return _Outcome.aborted;

      if (heard == null) {
        if (_micBlocked()) return _blocked(run, rq);
        _log(rq, null, 'nothing heard');
        if (++attempts >= voiceMaxAttempts) return _giveUp(run);
        await _say(run, _prompts.noSpeech());
        readOut = true;
        continue;
      }

      final command = matchVoiceCommand(heard.text);
      if (command != null) _log(rq, heard, 'command ${command.name}');
      switch (command) {
        case VoiceCommand.repeat:
          readOut = true;
          continue;
        case VoiceCommand.stop:
          return _stopSaid(run);
        case VoiceCommand.skip:
          await _say(run, _prompts.skipped());
          return _Outcome.skipped;
        case VoiceCommand.next:
          return _Outcome.next;
        case VoiceCommand.back:
          return _Outcome.back;
        case VoiceCommand.clear:
          _assessment.answer(rq.id, null);
          await _say(run, _prompts.cleared());
          if (!state.guided) return _Outcome.answered;
          readOut = true;
          continue;
        case null:
          break;
      }

      final r = parseVoiceAnswer(q, options, heard.text, today: ctx.today);
      _log(rq, heard,
          r.ok ? 'value ${r.value}' : 'rejected: ${r.problem!.name}');
      if (r.ok) {
        _assessment.answer(rq.id, r.value);
        final stored = ref.read(assessmentProvider).context.answers;
        if (q.isAnswered(stored[q.variable])) {
          await _say(run,
              _prompts.recorded(_prompts.answerText(q, options, r.value!)));
          return _Outcome.answered;
        }
      }
      if (++attempts >= voiceMaxAttempts) return _giveUp(run);
      await _say(
        run,
        _prompts.retry(
          q,
          options,
          r.ok ? const VoiceParse.problem(VoiceProblem.notUnderstood) : r,
          ctx.today,
        ),
      );
    }
    return _Outcome.aborted;
  }

  Future<_Outcome> _giveUp(int run) async {
    await _say(run, _prompts.giveUp());
    return _Outcome.gaveUp;
  }

  Future<void> _say(int run, String text) async {
    if (!_alive(run)) return;
    state = state.copyWith(
      status: VoiceStatus.speaking,
      message: text,
      partial: '',
    );
    await _tts.speak(text, localeId: state.language.localeId);
    if (afterSpeechGap > Duration.zero) await Future.delayed(afterSpeechGap);
  }

  /// Listens for an answer to [rq] (null: a page-end command).
  Future<HeardSpeech?> _listen(int run, ResolvedQuestion? rq) async {
    if (!_alive(run)) return null;
    state = state.copyWith(status: VoiceStatus.listening, partial: '');
    final heard = await _speech.listenOnce(
      localeId: _listenId,
      length: rq?.question.type == QuestionType.text
          ? AnswerLength.long
          : AnswerLength.short,
      onPartial: (w) {
        if (_alive(run)) state = state.copyWith(partial: w);
      },
    );
    return _alive(run) ? heard : null;
  }

  String get _listenId => _listenIds[state.language] ?? state.language.localeId;

  /// Debug builds: what was heard and what it became, to tune recognition
  /// from real use. Release builds log nothing (answers are patient data).
  void _log(ResolvedQuestion? rq, HeardSpeech? heard, String outcome) {
    if (!kDebugMode) return;
    final what = heard == null
        ? '<nothing${_speech.lastError == null ? '' : ': ${_speech.lastError}'}>'
        : '$heard';
    debugPrint('[voice] ${rq?.id ?? 'page-end'} ($_listenId) heard $what '
        '→ $outcome');
  }
}

final voiceEntryProvider =
    NotifierProvider<VoiceEntryController, VoiceEntryState>(
  VoiceEntryController.new,
);
