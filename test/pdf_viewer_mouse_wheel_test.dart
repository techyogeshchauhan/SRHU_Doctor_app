import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/features/hypoglycemia/domain/hypo_content.dart';
import 'package:neonatal_stw/features/references/ui/pdf_viewer_screen.dart';

void main() {
  late TestPointer mouse;

  Future<void> pumpViewer(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: PdfViewerScreen(assetPath: hypoPdfAsset, title: hypoPdfTitle),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
        mouse.hover(tester.getCenter(find.byType(InteractiveViewer))));
  }

  Future<void> wheel(WidgetTester tester, double dy) async {
    await tester.sendEventToBinding(mouse.scroll(Offset(0, dy)));
    await tester.pump(const Duration(milliseconds: 300));
  }

  double offset(WidgetTester tester) => tester
      .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
      .controller!
      .offset;

  double scale(WidgetTester tester) => tester
      .widget<InteractiveViewer>(find.byType(InteractiveViewer))
      .transformationController!
      .value
      .getMaxScaleOnAxis();

  testWidgets('mouse wheel scrolls the PDF up and down without zooming',
      (tester) async {
    await pumpViewer(tester);
    expect(offset(tester), 0);

    await wheel(tester, 300);
    expect(offset(tester), greaterThan(0));
    expect(scale(tester), 1.0);

    final down = offset(tester);
    await wheel(tester, -150);
    expect(offset(tester), lessThan(down));
    expect(scale(tester), 1.0);

    // Already at the top: wheel up does nothing (and does not zoom).
    await wheel(tester, -5000);
    await wheel(tester, -300);
    expect(offset(tester), 0);
    expect(scale(tester), 1.0);
  });

  testWidgets('Ctrl + mouse wheel still zooms', (tester) async {
    await pumpViewer(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    final before = offset(tester);
    await wheel(tester, -200);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(scale(tester), greaterThan(1.0));
    // Zooming does not also scroll the page.
    expect(offset(tester), before);
    // Released: the wheel scrolls again and does not zoom further.
    await tester.pump();
    final zoomed = scale(tester);
    await wheel(tester, 200);
    expect(scale(tester), zoomed);
    expect(offset(tester), greaterThan(before));
  });
}
