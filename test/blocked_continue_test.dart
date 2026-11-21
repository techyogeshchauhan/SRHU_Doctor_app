import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neonatal_stw/data/local/offline_queue.dart';
import 'package:neonatal_stw/data/repositories/screening_sync_repository.dart';
import 'package:neonatal_stw/data/services/api_client.dart';
import 'package:neonatal_stw/features/clinical_workflow/domain/shared_questions.dart';
import 'package:neonatal_stw/features/clinical_workflow/state/assessment_controller.dart';
import 'package:neonatal_stw/features/clinical_workflow/ui/workflow_screen.dart';
import 'package:neonatal_stw/features/condition_selection/domain/neonatal_condition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'tapping a greyed-out Continue names the missing required question '
      'and outlines it until it is answered', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.reset);

    final repo = ScreeningSyncRepository(
        queue: OfflineQueue(apiClient: ApiClient(baseUrl: '', apiKey: '')));
    final container = ProviderContainer(overrides: [
      screeningSyncRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    container
        .read(assessmentProvider.notifier)
        .start({NeonatalCondition.jaundice}, forceReset: true);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: WorkflowScreen()),
    ));
    await tester.pumpAndSettle();

    final continueButton = find.widgetWithText(FilledButton, 'Continue');
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
    expect(find.text('Required: answer this to continue'), findsNothing);

    await tester.tap(continueButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Answer "Gestational age" to continue.'), findsOneWidget);
    expect(find.text('Required: answer this to continue'), findsOneWidget);

    container.read(assessmentProvider.notifier).answer(gaKnownKey, false);
    await tester.pumpAndSettle();
    expect(find.text('Required: answer this to continue'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
