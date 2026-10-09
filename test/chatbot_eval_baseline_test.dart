import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/chatbot/data/bm25_retriever.dart';

import 'chatbot_eval/eval_harness.dart';

/// Baseline: the original keyword-only chatbot (BM25 top-1, whole box shown,
/// no clarification). Reported for comparison; not gated.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('baseline: BM25 top-1, whole box', () async {
    final bm25 = Bm25Retriever(
      initialChunks: loadRegions(),
      initialSynonyms: loadSynonyms(),
    );
    final report = await runEval((q) async {
      final r = await bm25.search(q, limit: 1);
      if (r.isEmpty) return const EvalOutcome.notCovered();
      final c = r.first.chunk;
      return EvalOutcome.answer(c.chunkId, c.text.split('\n'));
    });
    // ignore: avoid_print
    print('\n=== BASELINE (BM25 top-1) ===\n${report.summary()}'
        '\nWrong answers:\n${report.failures(wrongOnly: true)}');
    expect(report.total(), greaterThanOrEqualTo(250));
  });
}
