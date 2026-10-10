import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../clinical_workflow/domain/clinical_finding.dart';
import '../../clinical_workflow/domain/source_reference.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../domain/kg_graph.dart';
import '../state/stw_regions.dart';
import 'node_graph_view.dart';
import 'reasoning_tree.dart' show hasPdf, openSourceInPdf, topicShort;

/// Details of one node: its value and the rule's threshold, the STW source
/// with "Open in PDF" (highlighted box) and the box's text as printed in
/// the PDF, and the nodes it is related to.
///
/// Every text shown comes from the workflow (question, finding, rule
/// source) or verbatim from the STW PDF; nothing is generated.
class NodeDetailsScreen extends ConsumerWidget {
  const NodeDetailsScreen({
    super.key,
    required this.placement,
    required this.usedBy,
    required this.onShowFinding,
  });

  final KgPlacement placement;

  /// Findings each node id leads to (see `findingsUsing`).
  final Map<String, List<ClinicalFinding>> usedBy;

  /// Shows the graph of another finding.
  final void Function(ClinicalFinding f) onShowFinding;

  static const routeName = 'kg-node-details';

  /// Closes every details page above the graph.
  static void closeAll(BuildContext context) =>
      Navigator.of(context).popUntil((r) => r.settings.name != routeName);

  static Future<void> open(
    BuildContext context, {
    required KgPlacement placement,
    required Map<String, List<ClinicalFinding>> usedBy,
    required void Function(ClinicalFinding f) onShowFinding,
    bool replace = false,
  }) {
    final route = MaterialPageRoute<void>(
      settings: const RouteSettings(name: routeName),
      builder: (_) => NodeDetailsScreen(
        placement: placement,
        usedBy: usedBy,
        onShowFinding: onShowFinding,
      ),
    );
    return replace
        ? Navigator.of(context).pushReplacement(route)
        : Navigator.of(context).push(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = placement.item;
    final look = kgLook(item.kind, item.finding?.level);
    final regions = ref.watch(stwRegionsProvider).valueOrNull ?? const {};
    final src = item.source;
    final region = src?.pdfRegionId == null ? null : regions[src!.pdfRegionId];

    void openRelated(KgItem other, {KgItem? feeds}) => open(
          context,
          placement: KgPlacement(item: other, feeds: feeds),
          usedBy: usedBy,
          onShowFinding: onShowFinding,
        );

    final f = item.finding;
    final usedFor = [
      for (final x in usedBy[item.id] ?? const <ClinicalFinding>[])
        if (x != f) x,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Node details',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryNavy,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => closeAll(context),
          ),
        ],
      ),
      body: MaxWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // Header: kind, label, value, threshold, result.
            Container(
              decoration: BoxDecoration(
                color: look.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: look.fg.withValues(alpha: 0.4)),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(look.icon, color: look.fg, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.kind == KgKind.finding
                              ? f?.category.label ?? item.kind.label
                              : item.kind.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: look.fg,
                          ),
                        ),
                      ),
                      if (item.isShared) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Shared: '
                            '${item.topics.map(topicShort).join(' + ')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 12, color: look.fg),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: item.kind == KgKind.finding
                          ? look.fg
                          : AppTheme.bodyText,
                    ),
                  ),
                  if (item.value != null || item.check != null) ...[
                    const SizedBox(height: 10),
                    _Facts(rows: [
                      if (item.value != null)
                        (
                          item.kind == KgKind.answer
                              ? 'Your value'
                              : 'Computed value',
                          item.value!
                        ),
                      if (item.check != null) ('Threshold', item.check!),
                      if (item.check != null) ('Result', '✓ Met'),
                    ]),
                  ],
                  if (item.kind == KgKind.rule) ...[
                    const SizedBox(height: 10),
                    for (final c in item.checks)
                      _Facts(rows: [
                        ('Checked', c.label),
                        if (c.value != null) ('Your value', c.value!),
                        ('Threshold', c.threshold),
                        ('Result', '✓ Met'),
                      ]),
                    const _Facts(rows: [
                      (
                        'Result',
                        '✓ All conditions met, so the STW finding applies',
                      ),
                    ]),
                  ],
                  if (item.kind == KgKind.computed)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Computed by the app from your answers, using the '
                        'STW rule cited below.',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                ],
              ),
            ),

            // Finding: the STW recommendation, as on the summary.
            if (f != null && item.kind == KgKind.finding) ...[
              if (f.actions.isNotEmpty) ...[
                const KgHeading('STW recommendation'),
                for (final a in f.actions) KgBullet(a),
              ],
              if (f.why.isNotEmpty) ...[
                const KgHeading('Why'),
                for (final w in f.why) KgBullet(w),
              ],
            ],

            // Source and PDF.
            const KgHeading('Source'),
            StwSourceCard(source: src, page: region?.page),
            if (src?.needsClinicalReview ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Requires clinical review: ${src!.note ?? 'app reading of '
                      'ambiguous STW wording'}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Tone.warning.foreground(),
                  ),
                ),
              ),
            if (region != null && region.text.isNotEmpty) ...[
              const KgHeading('Text in the STW PDF'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: const Border(
                    left: BorderSide(color: Color(0xFF6B21A8), width: 3),
                  ),
                ),
                child: SelectableText(
                  region.text,
                  style: const TextStyle(fontSize: 13, height: 1.45),
                ),
              ),
            ],

            // Related nodes.
            if (item.basedOn.isNotEmpty ||
                placement.feeds != null ||
                usedFor.isNotEmpty) ...[
              const KgHeading('Related nodes'),
              if (item.basedOn.isNotEmpty) ...[
                const KgSubHeading('Based on'),
                for (final b in item.basedOn)
                  _RelatedTile(
                    item: b,
                    onTap: () => openRelated(b, feeds: item),
                  ),
              ],
              if (placement.feeds != null) ...[
                const KgSubHeading('Used for'),
                _RelatedTile(
                  item: placement.feeds!,
                  onTap: () => openRelated(placement.feeds!),
                ),
              ],
              if (usedFor.isNotEmpty) ...[
                const KgSubHeading('Leads to these findings'),
                for (final x in usedFor)
                  _FindingTile(
                    finding: x,
                    onTap: () => onShowFinding(x),
                  ),
              ],
            ],
            if (f != null && item.kind == KgKind.finding) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => onShowFinding(f),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('Show the graph of this finding'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            for (final (k, v) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        k,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.mutedText,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        v,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: v.startsWith('✓')
                              ? const Color(0xFF166534)
                              : AppTheme.primaryNavy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}

class StwSourceCard extends StatelessWidget {
  const StwSourceCard({super.key, required this.source, this.page});
  final SourceReference? source;
  final int? page;

  @override
  Widget build(BuildContext context) {
    final s = source;
    if (s == null) {
      return const Text(
        'App data entry: not an STW rule, so there is no PDF source.',
        style: TextStyle(fontSize: 13, color: AppTheme.mutedText),
      );
    }
    final canOpen = hasPdf(s);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.description_outlined,
                  color: AppTheme.primaryNavy),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s.authority} STW: ${s.document}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      [
                        s.section,
                        if (page != null) 'Page $page',
                        if (s.version.isNotEmpty) s.version,
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (canOpen)
            FilledButton.icon(
              onPressed: () => openSourceInPdf(context, s),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(s.pdfRegionId != null
                  ? 'Open in PDF (highlighted)'
                  : 'Open in PDF'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
            )
          else
            const Text(
              'Not part of the bundled STW PDF.',
              style: TextStyle(fontSize: 12.5, color: AppTheme.mutedText),
            ),
        ],
      ),
    );
  }
}

class KgHeading extends StatelessWidget {
  const KgHeading(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryNavy,
          ),
        ),
      );
}

class KgSubHeading extends StatelessWidget {
  const KgSubHeading(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.mutedText,
          ),
        ),
      );
}

class KgBullet extends StatelessWidget {
  const KgBullet(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  '),
            Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
          ],
        ),
      );
}

class _RelatedTile extends StatelessWidget {
  const _RelatedTile({required this.item, required this.onTap});
  final KgItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = kgLook(item.kind, item.finding?.level);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: look.bg,
          child: Icon(look.icon, color: look.fg, size: 20),
        ),
        title: Text(item.label, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [item.kind.label, if (item.value != null) item.value!].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _FindingTile extends StatelessWidget {
  const _FindingTile({required this.finding, required this.onTap});
  final ClinicalFinding finding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = kgLook(KgKind.finding, finding.level);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: look.bg,
          child: Icon(look.icon, color: look.fg, size: 20),
        ),
        title:
            Text(finding.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('${definitionOf(finding.topic).title} · show its graph'),
        trailing: const Icon(Icons.account_tree_outlined),
      ),
    );
  }
}
