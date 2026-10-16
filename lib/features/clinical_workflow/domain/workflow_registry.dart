/// The single place that maps each of the 14 topics to its workflow.
library;

import '../../ancs/domain/ancs_workflow.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../../hypoglycemia/domain/hypo_workflow.dart';
import '../../kmc/domain/kmc_workflow.dart';
import '../../rd/domain/rd_workflow.dart';
import '../../rop/domain/rop_workflow.dart';
import '../../sepsis/domain/sepsis_workflow.dart';
import '../../triage/domain/triage_workflow.dart';
import 'workflow_definition.dart';

/// Triage, KMC, RD, ROP, ANCS, Hypoglycemia and Sepsis use their supplied STWs.
/// Every other topic stays [PendingWorkflow] until its approved STW is supplied.
WorkflowDefinition workflowFor(NeonatalCondition c) => switch (c) {
      NeonatalCondition.triage => triageWorkflow,
      NeonatalCondition.kmc => kmcWorkflow,
      NeonatalCondition.respiratoryDistress => rdWorkflow,
      NeonatalCondition.rop => ropWorkflow,
      NeonatalCondition.ancs => ancsWorkflow,
      NeonatalCondition.hypoglycemia => hypoWorkflow,
      NeonatalCondition.sepsis => sepsisWorkflow,
      _ => PendingWorkflow(c),
    };
