import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/assessment_context.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/assessment_engine.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/clinical_question.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/workflow_definition.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/workflow_registry.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/hypoglycemia/domain/hypo_workflow.dart';
import 'package:neonatal_stw/features/rd/domain/rd_workflow.dart';
import 'package:neonatal_stw/features/sepsis/domain/sepsis_workflow.dart';
import 'package:neonatal_stw/features/triage/domain/triage_workflow.dart';

const _engine = AssessmentEngine();
final _today = DateTime(2026, 11, 3);

ClinicalAssessmentContext _eval(Map<String, Object?> answers) =>
    _engine.evaluate(
      selected: {NeonatalCondition.triage},
      answers: answers,
      today: _today,
    );

List<NeonatalCondition> _stws(Map<String, Object?> answers) =>
    [for (final s in triageStwSuggestions(_eval(answers))) s.stw];

StwSuggestion _of(Map<String, Object?> answers, NeonatalCondition stw) =>
    triageStwSuggestions(_eval(answers)).singleWhere((s) => s.stw == stw);

/// Every answer of a fully normal history and examination.
const _normal = <String, Object?>{
  triageMaternalRisksKey: <Object>{},
  triageRhStatusKey: 'positive',
  triageAntenatalSteroidsKey: 'complete',
  triageNewbornRisksKey: <Object>{},
  triageExamLookKey: <Object>{},
  triageExamListenKey: <Object>{},
  triageAirEntryKey: 'equal',
  triageExamFeelKey: <Object>{},
  triageFontanelleKey: 'normal',
  triageToneKey: 'normal',
};

void main() {
  group('mapping table', () {
    test('every finding is an option of its question', () {
      for (final r in triageSuggestionRules) {
        expect(
            r.question.validate(r.question.type == QuestionType.multipleChoice
                ? <Object>{r.value}
                : r.value),
            isNull,
            reason: '${r.question.id}: ${r.value}');
      }
    });

    test('every pre-fill is a valid answer to a question of that STW', () {
      for (final r in triageSuggestionRules) {
        final w = workflowFor(r.stw);
        if (r.prefill.isEmpty) continue;
        expect(w, isA<StwWorkflow>(), reason: '${r.stw} has no questions');
        final questions = {
          for (final u in (w as StwWorkflow).uses)
            u.question.variable: u.question,
        };
        for (final MapEntry(:key, :value) in r.prefill.entries) {
          final q = questions[key];
          expect(q, isNotNull, reason: '$key is not asked by ${r.stw}');
          expect(q!.validate(value), isNull, reason: '$key = $value');
        }
      }
    });

    test('STWs without a screening workflow get no pre-fill', () {
      for (final r in triageSuggestionRules) {
        if (workflowFor(r.stw) is! StwWorkflow) {
          expect(r.prefill, isEmpty, reason: '${r.stw}');
        }
      }
    });
  });

  test('a normal history and examination suggests nothing', () {
    expect(_stws({}), isEmpty);
    expect(_stws(_normal), isEmpty);
  });

  test('recorded-only findings suggest nothing', () {
    expect(
        _stws({
          ..._normal,
          triageMaternalRisksKey: <Object>{
            'congenitalAnomalies',
            'hypertension',
            'sle',
          },
          triageAntenatalSteroidsKey: 'notGiven',
          triageNewbornRisksKey: <Object>{'abdominal', 'delayedMeconium'},
          triageExamLookKey: <Object>{
            'severePallor',
            'irritability',
            'dehydration',
          },
          triageExamFeelKey: <Object>{'radioFemoralDelay', 'abdominal'},
          triageFontanelleKey: 'sunken',
          triageToneKey: 'hypertonia',
        }),
        isEmpty);
  });

  test('suggestions are merged per STW, in STW order, with reasons', () {
    final answers = {
      triageMaternalRisksKey: <Object>{'foulLiquor', 'gdm'},
      triageNewbornRisksKey: <Object>{'lethargyPoorFeeding'},
      triageExamLookKey: <Object>{'chestIndrawing', 'lethargy', 'sga'},
      triageExamListenKey: <Object>{'grunting'},
      triageExamFeelKey: <Object>{'crtProlonged'},
    };
    expect(_stws(answers), [
      NeonatalCondition.respiratoryDistress,
      NeonatalCondition.sepsis,
      NeonatalCondition.hypoglycemia,
      NeonatalCondition.hie,
    ]);
    final sepsis = _of(answers, NeonatalCondition.sepsis);
    expect(sepsis.reasons, [
      'Foul-smelling liquor',
      'Lethargy / poor feeding',
      'Lethargy / unconsciousness',
      'Capillary refill time (CRT) >3 s',
    ]);
    expect(sepsis.prefill, {
      sepsisMaternalRedKey: true,
      sepsisYellowKey: {'lethargy', 'refusal'},
    });
    expect(_of(answers, NeonatalCondition.respiratoryDistress).prefill, {
      rdSignsKey: {'retractions', 'grunting'},
    });
    expect(_of(answers, NeonatalCondition.hypoglycemia).prefill, {
      hypoRiskKey: {'idm', 'sga'},
    });
  });

  test('a single-choice finding names its question', () {
    expect(
        _of({triageRhStatusKey: 'negative'}, NeonatalCondition.jaundice)
            .reasons,
        ['Maternal Rh status: Negative']);
    expect(
        _of({triageAirEntryKey: 'reduced'},
                NeonatalCondition.respiratoryDistress)
            .reasons,
        ['Air entry: Reduced']);
  });

  test('Triage RR >=60 suggests RD and carries the RR into it', () {
    final rd = _of(
        {triageRespiratoryRateKey: 72}, NeonatalCondition.respiratoryDistress);
    expect(rd.reasons, ['RR 72/min (≥60/min)']);
    expect(rd.prefill, {rdRrKey: 72});
    // A normal RR is carried only when RD is suggested for another reason.
    expect(_stws({triageRespiratoryRateKey: 45}), isEmpty);
    expect(
        _of({
          triageRespiratoryRateKey: 45,
          triageExamListenKey: <Object>{'stridor'},
        }, NeonatalCondition.respiratoryDistress)
            .prefill,
        {rdRrKey: 45});
  });

  test('history and examination never change the triage category', () {
    final everything = {
      triageMaternalRisksKey: {
        for (final o in qTriageMaternalRisks.options) o.value,
      },
      triageNewbornRisksKey: {
        for (final o in qTriageNewbornRisks.options) o.value,
      },
      triageExamLookKey: {for (final o in qTriageExamLook.options) o.value},
      triageExamListenKey: {
        for (final o in qTriageExamListen.options) o.value,
      },
      triageExamFeelKey: {for (final o in qTriageExamFeel.options) o.value},
      triageAirEntryKey: 'reduced',
      triageFontanelleKey: 'bulging',
      triageToneKey: 'hypotonia',
    };
    for (final page1 in <Map<String, Object?>>[
      {},
      {triageHeartRateKey: 210},
      {triageTemperatureKey: 36.0},
    ]) {
      final without = _eval(page1);
      final withAll = _eval({...page1, ...everything});
      expect(withAll.valueOf(triageCategoryKey),
          without.valueOf(triageCategoryKey));
      expect(withAll.findings.map((f) => f.id).toSet(),
          without.findings.map((f) => f.id).toSet());
    }
  });
}
