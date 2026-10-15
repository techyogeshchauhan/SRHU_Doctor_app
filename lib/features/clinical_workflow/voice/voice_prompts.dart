/// What voice entry says, in English or Hindi. Pure Dart.
library;

import 'package:intl/intl.dart';

import '../domain/clinical_question.dart';
import 'voice_answer_parser.dart';

/// Language voice entry listens and speaks in. Question and option text
/// stays as written in the STW (English); prompts are translated.
enum VoiceLanguage {
  english('en-IN', 'EN'),
  hindi('hi-IN', 'हिं');

  const VoiceLanguage(this.localeId, this.shortLabel);

  /// Recogniser / TTS locale.
  final String localeId;
  final String shortLabel;
}

/// Most attempts at one question before asking for manual entry.
const voiceMaxAttempts = 3;

class VoicePrompts {
  const VoicePrompts(this.lang);

  final VoiceLanguage lang;

  bool get _hi => lang == VoiceLanguage.hindi;

  /// Read-out of [q] with what can be said: options for choices, the
  /// range for numbers.
  String question(ClinicalQuestion q, List<QuestionOption> options) {
    final text = speakable(q.question);
    return switch (q.type) {
      QuestionType.singleChoice => '$text. ${_optionsLine(options)}',
      QuestionType.multipleChoice => _hi
          ? '$text. ${_optionsLine(options)} जितने लागू हों बोलें, या "कोई नहीं"।'
          : '$text. ${_optionsLine(options)} Say all that apply, or none.',
      QuestionType.numeric when q.min != null && q.max != null => _hi
          ? '$text. ${q.min} से ${q.max} ${spokenUnit(q.unit)}।'
          : '$text. ${q.min} to ${q.max} ${spokenUnit(q.unit)}.',
      QuestionType.boolean => _hi ? '$text. हाँ या नहीं?' : '$text. Yes or no?',
      _ => '$text.',
    };
  }

  String _optionsLine(List<QuestionOption> options) {
    if (options.isEmpty || options.length > 8) return '';
    final labels = [for (final o in options) speakable(o.label)];
    return _hi
        ? 'विकल्प: ${labels.join('; ')}.'
        : 'Options: ${labels.join('; ')}.';
  }

  /// Said after an unusable answer, before listening again.
  String retry(ClinicalQuestion q, List<QuestionOption> options, VoiceParse r,
      DateTime today) {
    final base = _hi
        ? 'यह मान सही नहीं लगता। कृपया दोबारा बोलें।'
        : 'This value seems incorrect. Please repeat it.';
    final hint = switch (r.problem) {
      VoiceProblem.outOfRange => _hi
          ? '${q.min} से ${q.max} ${spokenUnit(q.unit)} के बीच बोलें।'
          : 'It should be between ${q.min} and ${q.max} '
              '${spokenUnit(q.unit)}.',
      VoiceProblem.notWholeNumber =>
        _hi ? 'कृपया पूरी संख्या बोलें।' : 'Please say a whole number.',
      VoiceProblem.ambiguous => _hi
          ? 'क्या आपका मतलब ${r.candidates.map(speakable).join(' या ')} है?'
          : 'Did you mean ${r.candidates.map(speakable).join(' or ')}?',
      VoiceProblem.dateOutOfRange => () {
          final (first, last) = dateBounds(q, today);
          return _hi
              ? '${spokenDate(first)} से ${spokenDate(last)} के बीच की तारीख बोलें।'
              : 'Please say a date between ${spokenDate(first)} and '
                  '${spokenDate(last)}.';
        }(),
      VoiceProblem.notUnderstood => switch (q.type) {
          QuestionType.singleChoice ||
          QuestionType.multipleChoice =>
            _optionsLine(options),
          QuestionType.boolean => _hi ? 'हाँ या नहीं बोलें।' : 'Say yes or no.',
          QuestionType.date => _hi
              ? 'जैसे "आज" या "12 मार्च 2026" बोलें।'
              : 'For example, say today, or 12 March 2026.',
          _ => '',
        },
      null => '',
    };
    return '$base $hint'.trim();
  }

  String giveUp() =>
      _hi ? 'कृपया यह मान हाथ से भरें।' : 'Please enter this value manually.';

  String recorded(String answer) =>
      _hi ? '$answer दर्ज किया।' : '$answer, recorded.';

  String skipped() => _hi ? 'छोड़ दिया।' : 'Skipped.';

  String cleared() => _hi ? 'हटा दिया।' : 'Cleared.';

  String pageComplete() => _hi
      ? 'यह पेज पूरा हुआ। आगे बढ़ने के लिए "आगे" बोलें, या "रुको"।'
      : 'This page is complete. Say next to continue, or stop.';

  String requiredMissing() => _hi
      ? 'कुछ ज़रूरी जवाब बाकी हैं। उन्हें भरें, फिर "आगे" बोलें।'
      : 'Some required answers are missing. Fill them in, then say next.';

  String firstPage() => _hi ? 'यह पहला पेज है।' : 'This is the first page.';

  String assessmentComplete() => _hi
      ? 'आकलन पूरा हुआ। वॉइस एंट्री बंद।'
      : 'Assessment complete. Voice entry stopped.';

  String stopped() => _hi ? 'वॉइस एंट्री बंद।' : 'Voice entry stopped.';

  String micBlocked() => _hi
      ? 'माइक्रोफ़ोन की अनुमति नहीं है। ब्राउज़र या ऐप सेटिंग में अनुमति दें।'
      : 'Microphone access is blocked. Please allow it in the browser or app '
          'settings.';

  String noSpeech() =>
      _hi ? 'मुझे कुछ सुनाई नहीं दिया।' : "I didn't hear anything.";

  /// [value] (as stored for [q]) said back for confirmation.
  String answerText(
      ClinicalQuestion q, List<QuestionOption> options, Object value) {
    // "Respiratory rate (optional)" → "Respiratory rate".
    final name = speakable(q.question.replaceAll(RegExp(r'\s*\([^)]*\)'), ''));
    String labelOf(Object v) =>
        options.where((o) => o.value == v).firstOrNull?.label ?? '$v';
    return switch (q.type) {
      QuestionType.numeric ||
      QuestionType.decimal =>
        '$name: $value ${spokenUnit(q.unit)}'.trim(),
      QuestionType.singleChoice => speakable(labelOf(value)),
      QuestionType.multipleChoice => (value as Set).isEmpty
          ? (_hi ? 'कोई नहीं' : 'None')
          : value.map((v) => speakable(labelOf(v as Object))).join(', '),
      QuestionType.boolean => '$name: ${switch ((value == true, _hi)) {
          (true, true) => 'हाँ',
          (true, false) => 'yes',
          (false, true) => 'नहीं',
          (false, false) => 'no',
        }}',
      QuestionType.date => spokenDate(value as DateTime),
      QuestionType.text => '$value',
    };
  }
}

/// [unit] as words for speech ("/min" → "per minute").
String spokenUnit(String? unit) => switch (unit) {
      null => '',
      '/min' => 'per minute',
      'g' => 'grams',
      '%' => 'percent',
      'cm H₂O' => 'centimetres of water',
      'mg/dL' => 'milligrams per decilitre',
      'mg/kg/min' => 'milligrams per kilo per minute',
      'd' => 'days',
      _ => unit,
    };

String spokenDate(DateTime d) => DateFormat('d MMMM yyyy').format(d);

/// [text] made easier for TTS: symbols as words, separators as pauses.
String speakable(String text) => text
    .replaceAll(RegExp(r'\s*·\s*'), ', ')
    .replaceAll(RegExp(r'\s*[—–]\s*'), ', ')
    .replaceAll('≥', ' at least ')
    .replaceAll('≤', ' at most ')
    .replaceAll('>', ' more than ')
    .replaceAll('<', ' less than ')
    .replaceAll('/min', ' per minute')
    .replaceAll('₂', '2')
    .replaceAll('*', '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
