@Tags(['sweep'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/chatbot/data/bm25_retriever.dart';
import 'package:neonatal_stw/features/chatbot/domain/answering/stw_answer.dart';
import 'package:neonatal_stw/features/chatbot/domain/answering/stw_answerer.dart';

import 'chatbot_eval/eval_harness.dart';

/// Development aid: correct/wrong rates on the dev set for a grid of
/// confidence-gate settings. Run with `flutter test --tags sweep`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('threshold sweep', () async {
    final retriever = Bm25Retriever(
      initialChunks: loadRegions(),
      initialSynonyms: loadSynonyms(),
    );
    final b = StringBuffer('\nanswer margin  correct  wrong  clarify\n');
    for (final answer in [0.8, 0.9, 1.0]) {
      for (final margin in [0.05, 0.1, 0.15, 0.2]) {
        final answerer = StwAnswerer(
          retriever,
          thresholds: AnswerThresholds(answerScore: answer, margin: margin),
        );
        final r = await runEval((q) async {
          final x = await answerer.answer(q);
          return switch (x.kind) {
            AnswerKind.answer => EvalOutcome.answer(
                x.region!.chunkId, [for (final l in x.lines) l.display]),
            AnswerKind.clarify => const EvalOutcome.clarify(),
            AnswerKind.notCovered => const EvalOutcome.notCovered(),
          };
        });
        String p(Verdict v) =>
            '${(r.rate(v) * 100).toStringAsFixed(1)}%'.padLeft(7);
        b.writeln('${answer.toStringAsFixed(2).padLeft(6)} '
            '${margin.toStringAsFixed(2).padLeft(6)} ${p(Verdict.correct)} '
            '${p(Verdict.wrong)} ${p(Verdict.clarified)}');
      }
    }
    // ignore: avoid_print
    print(b);
  });
}
