import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../shared/pdf_navigation.dart';
import '../../clinical_workflow/domain/source_reference.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../domain/stw_map.dart';
import '../state/stw_regions.dart';
import 'node_details_screen.dart'
    show KgBullet, KgHeading, KgSubHeading, StwSourceCard;
import 'reasoning_tree.dart' show topicShort;
import 'stw_map_look.dart';

/// Details of an STW Map node. Everything shown is from the workflows or
/// verbatim from the STW PDF; links between STWs show the exact words that
/// state them and are marked as drafts until a clinician approves them.
class StwMapDetailsScreen extends ConsumerWidget {
  const StwMapDetailsScreen({
    super.key,
    required this.node,
    required this.map,
    required this.onShowBox,
    required this.onShowTopic,
  });

  final MapNode node;
  final StwMap map;

  /// Shows a box in the map graph.
  final void Function(String regionId) onShowBox;

  /// Shows an STW in the map graph.
  final void Function(NeonatalCondition topic) onShowTopic;

  static const routeName = 'stw-map-details';

  static void closeAll(BuildContext context) =>
      Navigator.of(context).popUntil((r) => r.settings.name != routeName);

  static Future<void> open(
    BuildContext context, {
    required MapNode node,
    required StwMap map,
    required void Function(String regionId) onShowBox,
    required void Function(NeonatalCondition topic) onShowTopic,
  }) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: routeName),
        builder: (_) => StwMapDetailsScreen(
          node: node,
          map: map,
          onShowBox: onShowBox,
          onShowTopic: onShowTopic,
        ),
      ));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = node;
    final look = mapLook(n.kind, n.level);
    final regions = ref.watch(stwRegionsProvider).valueOrNull ?? const {};
    final region = n.kind == MapKind.box ? regions[n.boxId] : null;

    void openChild(MapNode child) => open(
          context,
          node: child,
          map: map,
          onShowBox: onShowBox,
          onShowTopic: onShowTopic,
        );

    final body = <Widget>[
      // Header.
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: look.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: look.fg.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(look.icon, color: look.fg, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    n.kind == MapKind.finding
                        ? n.category?.label ?? n.kind.label
                        : n.kind.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: look.fg,
                    ),
                  ),
                ),
                if (n.topic != null && n.kind != MapKind.topic) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      definitionOf(n.topic!).title,
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
              n.label,
              style: const TextStyle(
                fontSize: 17,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: AppTheme.bodyText,
              ),
            ),
            if (n.subtitle != null && n.kind != MapKind.link)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(n.subtitle!, style: const TextStyle(height: 1.35)),
              ),
          ],
        ),
      ),
      ..._specific(context, n, region, openChild),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'STW Map details',
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
          children: body,
        ),
      ),
    );
  }

  List<Widget> _specific(
    BuildContext context,
    MapNode n,
    StwRegionInfo? region,
    void Function(MapNode) openChild,
  ) {
    MapNode? boxOf(String? id) => id == null ? null : map.box(id);

    switch (n.kind) {
      case MapKind.topic:
        final pdf =
            n.source == null ? null : stwPdfForDocument(n.source!.document);
        return [
          if (n.pending)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'No approved STW for this topic is bundled yet. These boxes '
                'of other STWs mention it:',
              ),
            )
          else ...[
            const KgHeading('Source'),
            StwSourceCard(source: n.source),
            if (pdf != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: () => openStwPdf(
                    context,
                    assetPath: pdf.asset,
                    title: pdf.title,
                  ),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Open the whole STW PDF'),
                ),
              ),
          ],
          const KgHeading('In the map'),
          for (final c in n.children) _Tile(node: c, onTap: () => openChild(c)),
        ];

      case MapKind.box:
        return [
          const KgHeading('Source'),
          StwSourceCard(source: n.source, page: region?.page),
          if (region != null && region.text.isNotEmpty) ...[
            const KgHeading('Text in the STW PDF'),
            _Quote(region.text),
          ],
          if (n.children.isNotEmpty) ...[
            const KgHeading('In the app'),
            for (final kind in [
              MapKind.question,
              MapKind.finding,
              MapKind.link
            ])
              if (n.children.any((c) => c.kind == kind)) ...[
                KgSubHeading(switch (kind) {
                  MapKind.question => 'Questions the assessment asks from it',
                  MapKind.finding => 'Findings its rules produce',
                  _ => 'Links to other STWs',
                }),
                for (final c in n.children)
                  if (c.kind == kind) _Tile(node: c, onTap: () => openChild(c)),
              ],
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => onShowBox(n.boxId!),
            icon: const Icon(Icons.account_tree_outlined),
            label: const Text('Show in the map'),
          ),
        ];

      case MapKind.question:
        final q = n.question!;
        final cited = <(SourceReference, MapNode)>[
          for (final s in q.sources)
            if (boxOf(s.pdfRegionId) case final b?) (s, b),
        ];
        return [
          if (q.options.isNotEmpty) ...[
            const KgHeading('Answer choices'),
            for (final o in q.options) KgBullet(o.label),
          ],
          if (q.stwRange != null) ...[
            const KgHeading('Range in the STW'),
            Text(q.stwRange!),
          ] else if (q.unit != null) ...[
            const KgHeading('Unit'),
            Text(q.unit!),
          ],
          KgHeading(n.isShared ? 'Shared by these STWs' : 'Asked for'),
          Wrap(
            spacing: 6,
            children: [
              for (final t in n.topics)
                ActionChip(
                  label: Text(definitionOf(t).title),
                  onPressed: () => onShowTopic(t),
                ),
            ],
          ),
          if (cited.isNotEmpty) ...[
            const KgHeading('STW boxes it comes from'),
            for (final (s, b) in cited)
              _Tile(
                node: b,
                note: s.citation,
                onTap: () => openChild(b),
              ),
          ],
        ];

      case MapKind.finding:
        return [
          if (n.rules.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'The wording of these findings depends on the patient\'s '
                'answers. Open "Why?" on a finding in an assessment to see '
                'one applied.',
              ),
            ),
            const KgHeading('STW rules'),
            for (final (_, s) in n.rules) KgBullet(s.citation),
          ],
          const KgHeading('Source'),
          StwSourceCard(source: n.source),
          if (boxOf(n.boxId) case final b?) ...[
            const KgHeading('STW box'),
            _Tile(node: b, onTap: () => openChild(b)),
          ],
        ];

      case MapKind.link:
        final l = n.link!;
        final from = boxOf(l.from);
        final target = map.root(l.to);
        return [
          if (!l.approved)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Tone.warning.background(),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Draft: this link between STWs is awaiting clinical review.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Tone.warning.foreground(),
                ),
              ),
            ),
          KgHeading('${l.kind.label} ${definitionOf(l.to).title}: '
              'the words in the STW'),
          _Quote(l.quote),
          const KgHeading('Source'),
          StwSourceCard(source: from?.source),
          if (from != null) ...[
            const KgHeading('From'),
            _Tile(node: from, onTap: () => openChild(from)),
          ],
          const KgHeading('To'),
          if (target != null)
            _Tile(node: target, onTap: () => onShowTopic(l.to))
          else
            Text('${definitionOf(l.to).title}: no approved STW yet.'),
        ];
    }
  }
}

class _Quote extends StatelessWidget {
  const _Quote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
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
          text,
          style: const TextStyle(fontSize: 13, height: 1.45),
        ),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.node, required this.onTap, this.note});
  final MapNode node;
  final VoidCallback onTap;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final look = mapLook(node.kind, node.level);
    final sub = note ??
        [
          node.kind.label,
          if (node.kind == MapKind.box && node.topic != null)
            topicShort(node.topic!),
          if (node.kind == MapKind.link && node.link?.approved != true) 'draft',
        ].join(' · ');
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
        title: Text(node.label, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
