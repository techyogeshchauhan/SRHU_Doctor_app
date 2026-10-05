/// Baby-detail questions shared by several workflows. Pure Dart.
///
/// Defined once; each workflow decides through its `QuestionUse` when it
/// needs them. The engine asks each one only once.
library;

import 'clinical_question.dart';
import 'condition_expr.dart';
import 'source_reference.dart';

const gaKnownKey = 'ga_known';
const gaWeeksKey = 'ga_weeks';
const gaDaysKey = 'ga_days';
const birthWeightKey = 'birth_weight_g';
const dobKey = 'dob';

const babyGroup = QuestionGroup(
  'baby',
  'Baby details',
  subtitle: 'Asked once and shared by the selected workflows. Not saved.',
  questionOrder: [gaKnownKey, gaWeeksKey, gaDaysKey, birthWeightKey, dobKey],
);

const qGaKnown = ClinicalQuestion(
  id: gaKnownKey,
  group: 'baby',
  question: 'Gestational age',
  type: QuestionType.singleChoice,
  options: [
    QuestionOption(true, 'GA known'),
    QuestionOption(false, 'GA uncertain'),
  ],
  sources: [
    SourceReference.rd('§1.3 Inputs: BW only if GA is uncertain'),
    SourceReference.rop('§2.1 Whom to screen'),
  ],
);

final qGaWeeks = ClinicalQuestion(
  id: gaWeeksKey,
  group: 'baby',
  question: 'Gestational age (completed weeks)',
  type: QuestionType.numeric,
  min: 22,
  max: 44,
  unit: 'weeks',
  visibleWhen: const Var(gaKnownKey).eq(true),
  sources: const [
    SourceReference.rd('§1.5 Algorithm: GA ≤34 / >34 weeks'),
    SourceReference.rop('§2.1 Whom to screen; §2.2 When to screen'),
  ],
);

final qGaDays = ClinicalQuestion(
  id: gaDaysKey,
  group: 'baby',
  question: '+ days',
  type: QuestionType.numeric,
  min: 0,
  max: 6,
  unit: 'd',
  helper: 'Used for postmenstrual age only',
  visibleWhen: const Var(gaKnownKey).eq(true),
  sources: const [
    SourceReference.rop('§2.8 PMA = GA at birth + postnatal age'),
  ],
);

const qBirthWeight = ClinicalQuestion(
  id: birthWeightKey,
  group: 'baby',
  question: 'Birth weight',
  type: QuestionType.numeric,
  min: 300,
  max: 6000,
  unit: 'g',
  sources: [
    SourceReference.rd('§1.3 BW ≤1800 g as surrogate when GA uncertain'),
    SourceReference.rop('§2.1 Whom to screen; §2.2 When to screen'),
  ],
);

const qDob = ClinicalQuestion(
  id: dobKey,
  group: 'baby',
  question: 'Date of birth',
  type: QuestionType.date,
  pastOnly: true,
  sources: [SourceReference.rop('§2.2 When to screen (postnatal age)')],
);

/// dd/MM/yyyy, as on the ROP discharge card.
String formatDmy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// One-line baby details from the shared answers, e.g.
/// `GA 30+2 wk · BW 1200 g · DOB 01/09/2026`.
String describeBabyLine(VariableReader r) {
  final known = r.valueOf(gaKnownKey);
  final ga = r.valueOf(gaWeeksKey);
  final days = r.valueOf(gaDaysKey) ?? 0;
  final bw = r.valueOf(birthWeightKey);
  final dob = r.valueOf(dobKey);
  return [
    if (known == false)
      'GA uncertain'
    else
      ga == null ? 'GA —' : 'GA $ga+$days wk',
    bw == null ? 'BW —' : 'BW $bw g',
    if (dob is DateTime) 'DOB ${formatDmy(dob)}',
  ].join(' · ');
}
