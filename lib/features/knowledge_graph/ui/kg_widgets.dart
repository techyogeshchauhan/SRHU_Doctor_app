import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Building blocks shared by the knowledge-graph views: arrows, group
/// frames, the "+N" expand badge and the zoom controls.

class KgArrow {
  KgArrow(this.points, {this.label});
  final List<Offset> points;
  final String? label;
}

class KgArrowPainter extends CustomPainter {
  KgArrowPainter(this.arrows);
  final List<KgArrow> arrows;

  @override
  void paint(Canvas canvas, Size size) {
    const color = Color(0xFF475569);
    final line = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    for (final a in arrows) {
      final p = a.points;
      final path = Path()..moveTo(p.first.dx, p.first.dy);
      for (final q in p.skip(1)) {
        path.lineTo(q.dx, q.dy);
      }
      canvas.drawPath(path, line);
      final end = p.last;
      final dir = end - p[p.length - 2];
      final u = dir / dir.distance;
      final n = Offset(-u.dy, u.dx);
      final back = end - u * 8;
      canvas.drawPath(
        Path()
          ..moveTo(end.dx, end.dy)
          ..lineTo((back + n * 4.5).dx, (back + n * 4.5).dy)
          ..lineTo((back - n * 4.5).dx, (back - n * 4.5).dy)
          ..close(),
        Paint()..color = color,
      );
      if (a.label != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: '✓ ${a.label}',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF166534),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final mid = (p.first + p.last) / 2;
        final r = Rect.fromLTWH(mid.dx + 8, mid.dy - tp.height / 2 - 2,
            tp.width + 10, tp.height + 4);
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(10)),
          Paint()..color = const Color(0xFFDCFCE7),
        );
        tp.paint(canvas, r.topLeft + const Offset(5, 2));
      }
    }
  }

  @override
  bool shouldRepaint(KgArrowPainter old) => old.arrows != arrows;
}

class KgGroupFrame extends StatelessWidget {
  const KgGroupFrame({
    super.key,
    required this.header,
    required this.maxHeaderWidth,
  });
  final String header;
  final double maxHeaderWidth;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        alignment: Alignment.topLeft,
        padding: const EdgeInsets.fromLTRB(12, 7, 12, 0),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxHeaderWidth),
          child: Text(
            header,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedText,
            ),
          ),
        ),
      );
}

class KgExpandBadge extends StatelessWidget {
  const KgExpandBadge({
    super.key,
    required this.count,
    required this.open,
    required this.color,
    required this.onTap,
  });

  final int count;
  final bool open;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: open ? 'Collapse' : 'Show $count more',
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: open ? color : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color),
            ),
            child: Text(
              open ? '−' : '+$count',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: open ? Colors.white : color,
              ),
            ),
          ),
        ),
      );
}

class KgZoomBar extends StatelessWidget {
  const KgZoomBar({
    super.key,
    required this.percent,
    required this.onOut,
    required this.onIn,
  });

  final int percent;
  final VoidCallback onOut;
  final VoidCallback onIn;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: const StadiumBorder(
          side: BorderSide(color: Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Zoom out',
              icon: const Icon(Icons.remove_rounded),
              onPressed: onOut,
            ),
            SizedBox(
              width: 46,
              child: Text(
                '$percent%',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Zoom in',
              icon: const Icon(Icons.add_rounded),
              onPressed: onIn,
            ),
          ],
        ),
      );
}

class KgRoundButton extends StatelessWidget {
  const KgRoundButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: const CircleBorder(
          side: BorderSide(color: Color(0xFFCBD5E1)),
        ),
        child: IconButton(tooltip: tooltip, icon: Icon(icon), onPressed: onTap),
      );
}

/// A fixed-size graph node: caption, label, optional detail line, value
/// and footer, with an optional "+N" badge that opens its children.
class KgCard extends StatelessWidget {
  const KgCard({
    super.key,
    required this.bg,
    required this.fg,
    required this.icon,
    required this.caption,
    required this.label,
    this.boldLabel = false,
    this.labelInColor = false,
    this.detail,
    this.value,
    this.footer,
    this.footerColor,
    this.expandCount,
    this.expanded = false,
    this.onTap,
    this.onToggle,
  });

  final Color bg;
  final Color fg;
  final IconData icon;
  final String caption;
  final String label;
  final bool boldLabel;

  /// Label in [fg] (findings) rather than body text.
  final bool labelInColor;
  final String? detail;
  final String? value;
  final String? footer;
  final Color? footerColor;

  /// Children behind the "+N" badge; null hides it.
  final int? expandCount;
  final bool expanded;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$caption: $label${value == null ? '' : ', $value'}. '
            'Opens details',
        child: Material(
          color: bg,
          elevation: expanded ? 3 : 1,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: fg.withValues(alpha: expanded ? 1 : 0.35),
              width: expanded ? 2.2 : 1.2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 15, color: fg),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          caption.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 0.3,
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                        ),
                      ),
                      if (expandCount != null && onToggle != null)
                        KgExpandBadge(
                          count: expandCount!,
                          open: expanded,
                          color: fg,
                          onTap: onToggle!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Expanded(
                    child: Text(
                      label,
                      maxLines:
                          value == null && footer == null && detail == null
                              ? 4
                              : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.25,
                        fontWeight:
                            boldLabel ? FontWeight.w700 : FontWeight.w500,
                        color: labelInColor ? fg : AppTheme.bodyText,
                      ),
                    ),
                  ),
                  if (detail != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        detail!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.25,
                          color: AppTheme.bodyText,
                        ),
                      ),
                    ),
                  if (value != null)
                    Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                  if (footer != null)
                    Text(
                      footer!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: footerColor ?? const Color(0xFF166534),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}
