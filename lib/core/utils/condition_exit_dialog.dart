import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/screening_sync_repository.dart';
import '../../features/clinical_workflow/state/assessment_controller.dart';
import '../../features/follow_up/domain/follow_up_models.dart';
import '../../features/follow_up/state/follow_up_controller.dart';
import '../../features/rd/state/rd_controller.dart';
import '../../features/rop/state/rop_controller.dart';
import '../../shared/baby_context.dart';
import '../theme.dart';

/// Checks if any screening or assessment progress exists for the opened condition.
bool hasConditionProgress(WidgetRef ref) {
  // 1. Dynamic clinical assessment engine
  final assess = ref.read(assessmentProvider);
  if (assess.context.answers.isNotEmpty ||
      assess.context.completedQuestions.isNotEmpty ||
      assess.history.isNotEmpty ||
      assess.context.findings.isNotEmpty ||
      (assess.context.selected.isNotEmpty &&
          assess.isComplete &&
          assess.context.completedQuestions.isNotEmpty)) {
    return true;
  }

  // 2. Follow-up MCQs and bedside case scenarios
  final followUp = ref.read(followUpProvider);
  if (followUp.mcqAnswers.isNotEmpty ||
      followUp.caseAnswers.isNotEmpty ||
      followUp.stage != FollowUpStage.intro) {
    return true;
  }

  // 3. Standalone ROP module
  final rop = ref.read(ropProvider);
  if (rop.step > 0 ||
      rop.risks.isNotEmpty ||
      rop.followUp != null ||
      rop.prepDone.isNotEmpty ||
      rop.examDate != null ||
      rop.nextExam != null ||
      rop.counselled ||
      rop.hospitalName.isNotEmpty ||
      rop.sncuNumber.isNotEmpty) {
    return true;
  }

  // 4. Standalone RD module
  final rd = ref.read(rdProvider);
  if (rd.signs.isNotEmpty ||
      rd.rr != null ||
      rd.immediateDone.isNotEmpty ||
      rd.sas.grades.isNotEmpty ||
      rd.severeDistress ||
      rd.recurrentApnea ||
      rd.poorPerfusion ||
      rd.abdominalSigns ||
      rd.support != null ||
      rd.spo2 != null ||
      rd.reSas.grades.isNotEmpty ||
      rd.comfortableBreathing ||
      rd.risingO2Need ||
      rd.apneaBrady ||
      rd.fatigue ||
      rd.shock ||
      rd.deterioration ||
      rd.persistentHypoxemia ||
      rd.sepsisTriggers.isNotEmpty ||
      rd.sasHistory.isNotEmpty) {
    return true;
  }

  // 5. Shared baby details
  final baby = ref.read(babyProvider);
  if (!baby.isEmpty) {
    return true;
  }

  return false;
}

/// Clears all screening, assessment, and MCQ data for this condition.
void clearConditionData(WidgetRef ref) {
  // Goal B: Mark in-progress screenings as abandoned in database rather than deleting
  ref.read(screeningSyncRepositoryProvider).abandonActiveScreenings();
  ref.read(assessmentProvider.notifier).reset();
  ref.read(followUpProvider.notifier).reset();
  ref.read(ropProvider.notifier).reset();
  ref.read(rdProvider.notifier).reset();
  ref.read(babyProvider.notifier).clear();
}

/// Confirmation message mandated by Section 6:
const conditionExitAlertMessage =
    'Progress will be reset. Your current progress and everything you have already completed in this condition (screening and assessment) will be cleared if you leave now. Do you want to continue?';

/// Prompts confirmation if any progress exists. If confirmed ("Leave & Reset"),
/// clears all screening and assessment data and navigates to [destinationRoute].
/// If no data has been entered yet, skips the dialog and navigates directly.
Future<void> confirmLeaveCondition(
  BuildContext context,
  WidgetRef ref, {
  required String destinationRoute,
}) async {
  if (!hasConditionProgress(ref)) {
    if (context.mounted) {
      context.go(destinationRoute);
    }
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) => AlertDialog(
      title: const Text(
        'Progress will be reset',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryNavy,
          fontSize: 18,
        ),
      ),
      content: const Text(
        conditionExitAlertMessage,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13.5,
          height: 1.5,
          color: Color(0xFF334155),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(dialogCtx).pop(false),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryNavy,
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Stay',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogCtx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB91C1C),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Leave & Reset',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    clearConditionData(ref);
    context.go(destinationRoute);
  }
}
