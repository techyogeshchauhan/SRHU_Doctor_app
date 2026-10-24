/// The single place that maps each of the 14 topics to its workflow.
library;

import '../../ancs/domain/ancs_workflow.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../../hypoglycemia/domain/hypo_workflow.dart';
import '../../feeding/domain/feeding_workflow.dart';
import '../../jaundice/domain/jaundice_workflow.dart';
import '../../post_asphyxia/domain/post_asphyxia_workflow.dart';
import '../../kmc/domain/kmc_workflow.dart';
import '../../rd/domain/rd_workflow.dart';
import '../../rop/domain/rop_workflow.dart';
import '../../sepsis/domain/sepsis_workflow.dart';
import '../../triage/domain/triage_workflow.dart';
import 'workflow_definition.dart';

/// Available workflows use their supplied STWs, including Feeding/Nutrition.
/// Every other topic stays [PendingWorkflow] until its approved STW is supplied.
WorkflowDefinition workflowFor(NeonatalCondition c) => switch (c) {
      NeonatalCondition.triage => triageWorkflow,
      NeonatalCondition.kmc => kmcWorkflow,
      NeonatalCondition.fluidsAndFeeds => feedingWorkflow,
      NeonatalCondition.respiratoryDistress => rdWorkflow,
      NeonatalCondition.rop => ropWorkflow,
      NeonatalCondition.ancs => ancsWorkflow,
      NeonatalCondition.hypoglycemia => hypoWorkflow,
      NeonatalCondition.sepsis => sepsisWorkflow,
      NeonatalCondition.hie => postAsphyxiaWorkflow,
      NeonatalCondition.jaundice => jaundiceWorkflow,
      _ => PendingWorkflow(c),
    };
