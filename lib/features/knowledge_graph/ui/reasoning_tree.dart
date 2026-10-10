import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../shared/pdf_navigation.dart';
import '../../clinical_workflow/domain/clinical_finding.dart';
import '../../clinical_workflow/domain/source_reference.dart';
import '../../clinical_workflow/ui/assessment_summary.dart' show toneFor;
import '../../condition_selection/domain/neonatal_condition.dart';
import '../domain/reasoning.dart';

/// Short topic name for badges.
String topicShort(NeonatalCondition c) => switch (c) {
      NeonatalCondition.respiratoryDistress => 'RD',
      NeonatalCondition.rop => 'ROP',
      NeonatalCondition.ancs => 'ANCS',
      NeonatalCondition.hypoglycemia => 'Hypoglycemia',
      _ => definitionOf(c).title.replaceFirst('STW ', ''),
    };

/// Whether [s] can be opened in a bundled STW PDF.
bool hasPdf(SourceReference? s) =>
    s != null && s.isClinical && stwPdfForDocument(s.document) != null;

/// Opens the STW PDF of [s], scrolled to and highlighting its box (as the
/// chatbot's "View in PDF" does); the whole PDF when the box is unknown.
void openSourceInPdf(BuildContext context, SourceReference s) {
  final pdf = stwPdfForDocument(s.document);
  if (pdf == null) return;
  final rid = s.pdfRegionId;
  if (rid != null) {
    openStwRegion(context, pdf: pdf, regionId: rid);
  } else {
    openStwPdf(context, assetPath: pdf.asset, title: pdf.title);
  }
}

({Color bg, Color fg, Color border, Color dot, IconData icon}) _look(
  ReasonNode n,
) {
  switch (n.kind) {
    case ReasonKind.finding:
      final t = toneFor(n.level ?? FindingLevel.info);
      return (
        bg: t.background(),
        fg: t.foreground(),
        border: t.foreground().withValues(alpha: 0.45),
        dot: t.foreground(),
        icon: t.icon,
      );
    case ReasonKind.computed:
      return (
        bg: AppTheme.tint,
        fg: AppTheme.primaryNavy,
        border: AppTheme.midBlue.withValues(alpha: 0.55),
        dot: AppTheme.midBlue,
        icon: Icons.calculate_outlined,
      );
    case ReasonKind.answer:
      return (
        bg: AppTheme.surfaceWhite,
        fg: AppTheme.bodyText,
        border: const Color(0xFFCBD5E1),
        dot: const Color(0xFF64748B),
        icon: Icons.edit_note_rounded,
      );
  }
}

/// Colour key for the three kinds of step.
class ReasonLegend extends StatelessWidget {
  const ReasonLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(label,
                style:
                    const TextStyle(fontSize: 11.5, color: AppTheme.mutedText)),
          ],
        );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        item(const Color(0xFF854D0E), 'STW finding'),
        item(AppTheme.midBlue, 'Computed from answers'),
        item(const Color(0xFF64748B), 'Your answer'),
      ],
    );
  }
}

/// A finding and, step by step, what it is based on.
///
/// The finding is the main node. Its direct reasons are listed under it,
/// joined by connector lines; each reason that has reasons of its own
/// opens with "Based on …". Tapping any box opens its STW box in the PDF.
class ReasonTree extends StatefulWidget {
  const ReasonTree({
    super.key,
    required this.root,
    this.initiallyOpen = true,
    this.expandAll = false,
    this.onRootHeaderTap,
  });

  final ReasonNode root;

  /// Whether the finding's direct reasons are shown at first.
  final bool initiallyOpen;

  /// Open every level (changing it re-applies to the whole tree).
  final bool expandAll;

  final VoidCallback? onRootHeaderTap;

  @override
  State<ReasonTree> createState() => _ReasonTreeState();
}

class _ReasonTreeState extends State<ReasonTree> {
  final _open = <String>{};

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(ReasonTree old) {
    super.didUpdateWidget(old);
    if (old.expandAll != widget.expandAll || old.root != widget.root) {
      _reset();
    }
  }

  void _reset() {
    _open.clear();
    if (widget.initiallyOpen || widget.expandAll) _open.add('');
    if (widget.expandAll) _collect(widget.root, '');
  }

  void _collect(ReasonNode n, String path) {
    for (final c in n.children) {
      final p = '$path/${c.id}';
      if (c.children.isNotEmpty) {
        _open.add(p);
        _collect(c, p);
      }
    }
  }

  void _toggle(String path) => setState(
      () => _open.contains(path) ? _open.remove(path) : _open.add(path));

  @override
  Widget build(BuildContext context) {
    final root = widget.root;
    final open = _open.contains('');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepCard(node: root, main: true),
        if (root.children.isNotEmpty)
          _ExpandButton(
            open: open,
            count: root.children.length,
            onTap: () => _toggle(''),
          ),
        if (open) _children(root, ''),
      ],
    );
  }

  Widget _children(ReasonNode parent, String path) {
    final kids = parent.children;
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < kids.length; i++)
            _branch(kids[i], '$path/${kids[i].id}', last: i == kids.length - 1),
        ],
      ),
    );
  }

  Widget _branch(ReasonNode n, String path, {required bool last}) {
    final open = _open.contains(path);
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _Connector(last: last, color: _look(n).dot),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 26, top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepCard(node: n),
              if (n.children.isNotEmpty)
                _ExpandButton(
                  open: open,
                  count: n.children.length,
                  onTap: () => _toggle(path),
                ),
              if (open) _children(n, path),
            ],
          ),
        ),
      ],
    );
  }
}

/// Rail from the parent down to this step, with an elbow and a dot.
class _Connector extends CustomPainter {
  const _Connector({required this.last, required this.color});

  final bool last;
  final Color color;

  static const _x = 7.0;
  static const _elbowY = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFFB6C2D4)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      const Offset(_x, 0),
      Offset(_x, last ? _elbowY : size.height),
      line,
    );
    canvas.drawLine(
      const Offset(_x, _elbowY),
      const Offset(22, _elbowY),
      line,
    );
    canvas.drawCircle(const Offset(22, _elbowY), 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Connector old) => old.last != last || old.color != color;
}

class _ExpandButton extends StatelessWidget {
  const _ExpandButton({
    required this.open,
    required this.count,
    required this.onTap,
  });

  final bool open;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primaryNavy,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(48, 40),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          icon: Icon(
            open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            size: 20,
          ),
          label: Text(
            open
                ? 'Hide what this is based on'
                : 'Based on $count ${count == 1 ? 'step' : 'steps'}',
          ),
        ),
      );
}

/// One step: kind, label, value, the rule's check and its STW source.
class _StepCard extends StatelessWidget {
  const _StepCard({required this.node, this.main = false});

  final ReasonNode node;
  final bool main;

  @override
  Widget build(BuildContext context) {
    final n = node;
    final look = _look(n);
    final src = n.source;
    final canOpen = hasPdf(src);

    final caption = [
      if (n.kind == ReasonKind.finding)
        n.finding?.category.label ?? n.kind.label
      else
        n.kind.label,
      if (n.isShared) 'shared ${n.topics.map(topicShort).join(' + ')}',
    ].join(' · ');

    return Semantics(
      button: canOpen,
      label: '$caption: ${n.label}'
          '${n.value == null ? '' : ', ${n.value}'}'
          '${canOpen ? '. Opens the STW source in the PDF' : ''}',
      excludeSemantics: true,
      child: Material(
        color: look.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: look.border, width: main ? 1.6 : 1.1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: canOpen ? () => openSourceInPdf(context, src!) : null,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, main ? 12 : 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(look.icon, size: 15, color: look.fg),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        caption.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w700,
                          color: look.fg.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  n.label,
                  style: TextStyle(
                    fontSize: main ? 16 : 14,
                    height: 1.3,
                    fontWeight: n.kind == ReasonKind.finding || main
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: n.kind == ReasonKind.finding
                        ? look.fg
                        : AppTheme.bodyText,
                  ),
                ),
                if (n.value != null || n.check != null) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (n.value != null) _ValuePill(n.value!),
                      if (n.check != null) _CheckPill(n.check!),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                _SourceLine(source: src, canOpen: canOpen),
                if (src?.needsClinicalReview ?? false) ...[
                  const SizedBox(height: 6),
                  _ReviewNote(src!.note),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ValuePill extends StatelessWidget {
  const _ValuePill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.primaryNavy.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryNavy,
          ),
        ),
      );
}

class _CheckPill extends StatelessWidget {
  const _CheckPill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Tone.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: t.background(),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 14, color: t.foreground()),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              'Rule check: $text',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: t.foreground(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.source, required this.canOpen});

  final SourceReference? source;
  final bool canOpen;

  @override
  Widget build(BuildContext context) {
    final s = source;
    if (s == null) {
      return const Text(
        'App data: not an STW rule',
        style: TextStyle(fontSize: 11.5, color: AppTheme.mutedText),
      );
    }
    if (!canOpen) {
      return Text(
        'Source: ${s.citation} (not in the STW PDF)',
        style: const TextStyle(fontSize: 11.5, color: AppTheme.mutedText),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.picture_as_pdf_outlined,
            size: 15,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: s.pdfRegionId != null
                      ? 'View in STW PDF: '
                      : 'Open STW PDF: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: '${s.document}, ${s.section}'),
              ],
            ),
            style: const TextStyle(
              fontSize: 12,
              height: 1.3,
              color: AppTheme.primaryBlue,
            ),
          ),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: AppTheme.primaryBlue,
        ),
      ],
    );
  }
}

class _ReviewNote extends StatelessWidget {
  const _ReviewNote(this.note);
  final String? note;

  @override
  Widget build(BuildContext context) {
    final t = Tone.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: t.background(),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Requires clinical review: '
        '${note ?? 'app reading of ambiguous STW wording'}',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: t.foreground(),
        ),
      ),
    );
  }
}
