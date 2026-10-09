import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/ancs/domain/ancs_workflow.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/source_reference.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';
import 'package:neonatal_stw/features/hypoglycemia/domain/hypo_workflow.dart';
import 'package:neonatal_stw/shared/pdf_navigation.dart';

/// "View in PDF" on every ANCS / Hypoglycemia finding and question opens the
/// right PDF and highlights an existing region of that PDF.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (condition, workflow) in [
    (NeonatalCondition.ancs, ancsWorkflow),
    (NeonatalCondition.hypoglycemia, hypoWorkflow),
  ]) {
    test('${condition.name}: every cited region exists in its own PDF',
        () async {
      final pdf = stwPdfFor(condition)!;
      final sources = <SourceReference>[
        for (final r in workflow.rules) r.source,
        for (final u in workflow.uses) ...u.question.sources,
      ].where((s) => s.isClinical);
      for (final s in sources) {
        expect(stwPdfForDocument(s.document)?.asset, pdf.asset,
            reason: s.citation);
        final id = s.regionId;
        if (id == null) continue;
        final target = await stwRegionTarget(id);
        expect(target, isNotNull, reason: 'region $id missing');
        expect(pdf.asset, endsWith('/${target!.document}'), reason: id);
        final box = target.normalizedBboxes.single;
        expect(box.width > 0 && box.height > 0, isTrue, reason: id);
      }
    });
  }

  test('RD and ROP PDFs are unchanged in the registry', () {
    expect(stwPdfFor(NeonatalCondition.respiratoryDistress)!.asset, rdPdfAsset);
    expect(stwPdfFor(NeonatalCondition.rop)!.asset, ropPdfAsset);
    expect(stwPdfFor(NeonatalCondition.sepsis), isNull);
  });
}
