import 'package:flutter/material.dart';

import '../../../content/stw_content.dart';
import '../../../core/widgets/app_branding.dart';
import '../../../core/widgets/back_to_home_button.dart';
import '../../../shared/reference_view.dart';
import '../../ancs/domain/ancs_content.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../../hypoglycemia/domain/hypo_content.dart';

/// Verbatim STW text (all boxes, DOs/DON'Ts, KPIs, abbreviations,
/// references, disclaimer) for a topic, in PDF order.
class StwReferenceScreen extends StatelessWidget {
  const StwReferenceScreen({super.key, required this.condition});

  final NeonatalCondition condition;

  /// Topics that have a verbatim reference page.
  static bool has(NeonatalCondition c) => _content(c) != null;

  /// Route path for [c], e.g. `/stw-reference/ancs`.
  static String routeFor(NeonatalCondition c) => '/stw-reference/${c.name}';

  static (String, List<RefSection>, List<RelatedLink>)? _content(
    NeonatalCondition c,
  ) =>
      switch (c) {
        NeonatalCondition.ancs => (
            'ANCS Reference',
            ancsReference,
            ancsRelatedLinks,
          ),
        NeonatalCondition.hypoglycemia => (
            'Hypoglycemia Reference',
            hypoReference,
            hypoRelatedLinks,
          ),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final content = _content(condition);
    return Scaffold(
      appBar: AppBar(
        title: StwNeoBrand(subtitle: content?.$1 ?? 'STW Reference'),
        actions: const [
          BackToHomeButton(compact: true),
          SizedBox(width: 8),
        ],
      ),
      body: content == null
          ? const Center(child: Text(pendingStwMessage))
          : ReferenceView(sections: content.$2, links: content.$3),
    );
  }
}
