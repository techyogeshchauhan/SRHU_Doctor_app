import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/chatbot/data/bm25_retriever.dart';
import 'package:neonatal_stw/features/chatbot/domain/answering/stw_answer.dart';
import 'package:neonatal_stw/features/chatbot/domain/answering/stw_answerer.dart';

import 'chatbot_eval/eval_harness.dart';

/// Evaluation of the query-understanding chatbot (see eval_harness.dart for
/// scoring). queries.json is the development set; holdout.json was written
/// before tuning and is never used to tune.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final answerer = StwAnswerer(Bm25Retriever(
    initialChunks: loadRegions(),
    initialSynonyms: loadSynonyms(),
  ));

  Future<EvalReport> evaluate(String file) => runEval(
        (q) async {
          final r = await answerer.answer(q);
          return switch (r.kind) {
            AnswerKind.answer => EvalOutcome.answer(
                r.region!.chunkId,
                [for (final l in r.lines) l.display],
              ),
            AnswerKind.clarify =>
              EvalOutcome.clarify(r.options.firstOrNull?.chunkId),
            AnswerKind.notCovered => const EvalOutcome.notCovered(),
          };
        },
        file: file,
      );

  void report(String title, EvalReport r) {
    // ignore: avoid_print
    print('\n=== $title ===\n${r.summary()}\nNot correct:\n${r.failures()}');
  }

  test('development set', () async {
    report('DEV', await evaluate('queries.json'));
  });

  test('hold-out set (never used for tuning)', () async {
    report('HOLD-OUT', await evaluate('holdout.json'));
  });
}
