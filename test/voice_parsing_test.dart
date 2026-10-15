import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/core/voice/number_words.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/clinical_question.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/shared_questions.dart';
import 'package:neonatal_stw/features/clinical_workflow/voice/voice_answer_parser.dart';
import 'package:neonatal_stw/features/clinical_workflow/voice/voice_commands.dart';
import 'package:neonatal_stw/features/clinical_workflow/voice/voice_prompts.dart';
import 'package:neonatal_stw/features/hypoglycemia/domain/hypo_workflow.dart';
import 'package:neonatal_stw/features/rd/domain/rd_workflow.dart';
import 'package:neonatal_stw/features/rop/domain/rop_workflow.dart';

final today = DateTime(2026, 10, 5);

VoiceParse parse(ClinicalQuestion q, String said) =>
    parseVoiceAnswer(q, q.options, said, today: today);

ClinicalQuestion ropRight(String field) =>
    ropRightQuestions.firstWhere((q) => q.id.endsWith(field));

void main() {
  group('parseSpokenInt', () {
    test('digits and English words', () {
      expect(parseSpokenInt('62'), 62);
      expect(parseSpokenInt('2,500'), 2500);
      expect(parseSpokenInt('sixty two'), 62);
      expect(parseSpokenInt('sixty-two'), 62);
      expect(parseSpokenInt('one hundred and twenty'), 120);
      expect(parseSpokenInt('two thousand five hundred'), 2500);
      expect(parseSpokenInt('twenty five hundred'), 2500);
      expect(parseSpokenInt('zero'), 0);
      expect(parseSpokenInt('one five zero'), 150);
    });

    test('ignores surrounding words and units', () {
      expect(parseSpokenInt('respiratory rate is 62 per minute'), 62);
      expect(parseSpokenInt('95%'), 95);
      expect(parseSpokenInt('1500 grams'), 1500);
      expect(parseSpokenInt('62.'), 62);
    });

    test('romanised Hindi, including spelling variants', () {
      expect(parseSpokenInt('baasath'), 62);
      expect(parseSpokenInt('basath'), 62);
      expect(parseSpokenInt('battis'), 32);
      expect(parseSpokenInt('tees'), 30);
      expect(parseSpokenInt('saat'), 7);
      expect(parseSpokenInt('saath'), 60);
      expect(parseSpokenInt('ek sau bees'), 120);
      expect(parseSpokenInt('do hazaar paanch sau'), 2500);
    });

    test('Devanagari words and digits', () {
      expect(parseSpokenInt('बासठ'), 62);
      expect(parseSpokenInt('पाँच'), 5);
      expect(parseSpokenInt('पांच'), 5);
      expect(parseSpokenInt('६२'), 62);
      expect(parseSpokenInt('एक सौ बीस'), 120);
    });

    test('rejects decimals, negatives, several numbers and no number', () {
      expect(parseSpokenInt('36.5'), isNull);
      expect(parseSpokenInt('thirty six point five'), isNull);
      expect(parseSpokenInt('minus five'), isNull);
      expect(parseSpokenInt('62 or 64'), isNull);
      expect(parseSpokenInt('sixty seventy'), isNull);
      expect(parseSpokenInt('hello'), isNull);
      expect(parseSpokenInt(''), isNull);
    });
  });

  group('commands', () {
    test('whole utterances only', () {
      expect(matchVoiceCommand('Next'), VoiceCommand.next);
      expect(matchVoiceCommand('next please'), VoiceCommand.next);
      expect(matchVoiceCommand('aage'), VoiceCommand.next);
      expect(matchVoiceCommand('आगे बढ़ो'), VoiceCommand.next);
      expect(matchVoiceCommand('go back'), VoiceCommand.back);
      expect(matchVoiceCommand('skip'), VoiceCommand.skip);
      expect(matchVoiceCommand('dobara'), VoiceCommand.repeat);
      expect(matchVoiceCommand('stop.'), VoiceCommand.stop);
      expect(matchVoiceCommand('बंद करो'), VoiceCommand.stop);
      expect(matchVoiceCommand('clear'), VoiceCommand.clear);
      expect(matchVoiceCommand('back pain'), isNull);
      expect(matchVoiceCommand('62'), isNull);
    });
  });

  group('numeric answers', () {
    test('in range', () {
      final r = parse(qRdRr, 'sixty two');
      expect(r.ok, isTrue);
      expect(r.value, 62);
      expect(parse(qBirthWeight, 'ek hazaar paanch sau').value, 1500);
    });

    test('out of range', () {
      expect(parse(qRdRr, 'two hundred').problem, VoiceProblem.outOfRange);
      expect(parse(qHypoBg, '700').problem, VoiceProblem.outOfRange);
    });

    test('decimal', () {
      expect(parse(qRdRr, '62.5').problem, VoiceProblem.notWholeNumber);
    });

    test('not understood', () {
      expect(parse(qRdRr, 'banana').problem, VoiceProblem.notUnderstood);
      expect(parse(qRdRr, '   ').problem, VoiceProblem.notUnderstood);
    });
  });

  group('yes / no', () {
    test('English and Hindi', () {
      expect(spokenYesNo('yes'), isTrue);
      expect(spokenYesNo('Haan'), isTrue);
      expect(spokenYesNo('हाँ'), isTrue);
      expect(spokenYesNo('no'), isFalse);
      expect(spokenYesNo('nahi'), isFalse);
      expect(spokenYesNo('नहीं'), isFalse);
      expect(spokenYesNo('not sure'), isNull);
      expect(spokenYesNo('yes no'), isNull);
      expect(spokenYesNo('banana'), isNull);
    });

    test('boolean question', () {
      expect(parse(qRdComfortable, 'yes').value, isTrue);
      expect(parse(qRdComfortable, 'absent').value, isFalse);
      expect(parse(qRdComfortable, 'maybe').ok, isFalse);
    });
  });

  group('single choice', () {
    test('by label words', () {
      expect(parse(qRdSupport, 'CPAP').value, 'cpap');
      expect(parse(qRdSupport, 'nasal oxygen').value, 'nasalO2');
      expect(parse(qRdSupport, 'off respiratory support').value, 'none');
      expect(parse(qGaKnown, 'GA uncertain').value, isFalse);
    });

    test('yes/no for Yes — … / Not now options', () {
      expect(parse(qRdReassessNow, 'yes').value, isTrue);
      expect(parse(qRdReassessNow, 'nahi').value, isFalse);
      expect(parse(qRdReassessNow, 'not now').value, isFalse);
    });

    test('numbers in labels (ROP stage and zone, SAS grade)', () {
      expect(parse(ropRight('stage'), 'stage three').value, 3);
      expect(parse(ropRight('stage'), 'no ROP').value, 0);
      expect(parse(ropRight('zone'), 'zone two').value, 'ii');
      expect(parse(ropRight('zone'), 'zone 1').value, 'i');
      final sas = rdSasQuestions.first;
      expect(parse(sas, 'one').value, 1);
      expect(parse(sas, 'see-saw').value, 2);
    });

    test('ambiguous', () {
      final r = parse(ropRight('vascular'), 'plus');
      expect(r.problem, VoiceProblem.ambiguous);
      expect(r.candidates, hasLength(3));
      expect(parse(ropRight('vascular'), 'pre plus').value, 'prePlus');
      expect(parse(ropRight('vascular'), 'no plus').value, 'noPlus');
    });

    test('nothing matching', () {
      expect(parse(qRdSupport, 'banana').problem, VoiceProblem.notUnderstood);
    });
  });

  group('multiple choice', () {
    test('several options', () {
      expect(parse(qRdSigns, 'grunting and nasal flaring').value,
          {'grunting', 'nasalFlaring'});
      expect(parse(qRdSigns, 'retractions aur grunting').value,
          {'retractions', 'grunting'});
      expect(parse(qRdSigns, 'grunting, nasal flaring').value,
          {'grunting', 'nasalFlaring'});
    });

    test('none', () {
      expect(parse(qRdSigns, 'none').value, <Object>{});
      expect(parse(qRdSigns, 'koi nahi').value, <Object>{});
    });

    test('unknown part', () {
      expect(parse(qRdSigns, 'grunting and banana').ok, isFalse);
    });
  });

  group('dates', () {
    test('relative', () {
      expect(parse(qDob, 'today').value, today);
      expect(parse(qDob, 'yesterday').value, DateTime(2026, 10, 4));
      expect(parse(qDob, 'kal').value, DateTime(2026, 10, 4));
      expect(parse(qDob, '3 days ago').value, DateTime(2026, 10, 2));
      expect(parse(qRopNextExamDate, 'after 2 weeks').value,
          DateTime(2026, 10, 19));
      expect(parse(qRopNextExamDate, 'next exam in one week').value,
          DateTime(2026, 10, 12));
    });

    test('spoken and written dates', () {
      expect(parse(qDob, '12 September 2026').value, DateTime(2026, 9, 12));
      expect(parse(qDob, 'September 12th').value, DateTime(2026, 9, 12));
      expect(parse(qDob, '12/9/26').value, DateTime(2026, 9, 12));
      expect(parse(qDob, 'twelve September twenty twenty six').value,
          DateTime(2026, 9, 12));
      expect(parse(qDob, '12 सितंबर').value, DateTime(2026, 9, 12));
      // No year: the most recent 20 December for a date of birth.
      expect(parse(qDob, '20 December').value, DateTime(2025, 12, 20));
    });

    test('out of the allowed window', () {
      expect(parse(qDob, 'tomorrow').problem, VoiceProblem.dateOutOfRange);
      expect(parse(qDob, '12 March 2020').problem, VoiceProblem.dateOutOfRange);
      expect(
          parse(qDob, '31 February 2026').problem, VoiceProblem.notUnderstood);
    });
  });

  group('prompts', () {
    const en = VoicePrompts(VoiceLanguage.english);
    const hi = VoicePrompts(VoiceLanguage.hindi);

    test('re-prompt names the problem and the range', () {
      final r = parse(qRdRr, 'two hundred');
      expect(
        en.retry(qRdRr, qRdRr.options, r, today),
        'This value seems incorrect. Please repeat it. '
        'It should be between 0 and 150 per minute.',
      );
      expect(hi.retry(qRdRr, qRdRr.options, r, today),
          startsWith('यह मान सही नहीं लगता। कृपया दोबारा बोलें।'));
    });

    test('speakable text', () {
      expect(speakable('RR >60/min'), 'RR more than 60 per minute');
      expect(speakable('Nasal-prong O₂'), 'Nasal-prong O2');
      expect(speakable('0 · Synchronized'), '0, Synchronized');
    });
  });
}
