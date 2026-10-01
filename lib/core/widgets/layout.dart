import 'package:flutter/material.dart';

import '../theme.dart';

/// Numbered form section with consistent 14 px radius and subtle medical border.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.number,
    this.subtitle,
    this.trailing,
    this.enabled = true,
    this.disabledHint,
  });

  final String title;
  final Widget child;
  final int? number;
  final String? subtitle;
  final Widget? trailing;
  final bool enabled;
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (number != null) ...[
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: AppTheme.primaryNavy,
                    child: Text(
                      '$number',
                      style: text.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: text.bodySmall?.copyWith(
                            color: const Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            if (!enabled && disabledHint != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  disabledHint!,
                  style: text.bodySmall?.copyWith(color: scheme.outline),
                ),
              ),
            IgnorePointer(
              ignoring: !enabled,
              child: Opacity(opacity: enabled ? 1 : 0.45, child: child),
            ),
          ],
        ),
      ),
    );
  }
}

class Bullets extends StatelessWidget {
  const Bullets(this.lines, {super.key, this.style, this.bullet = '•'});

  final List<String> lines;
  final TextStyle? style;
  final String bullet;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$bullet  ', style: style),
                Expanded(child: Text(l, style: style)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Colour-coded recommendation with actions and the rule that fired ("Why").
class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.tone,
    required this.title,
    this.actions = const [],
    this.why = const [],
    this.footer,
    this.badge,
  });

  final Tone tone;
  final String title;
  final List<String> actions;
  final List<String> why;
  final Widget? footer;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final fg = tone.foreground();
    final bg = tone.background();
    final text = Theme.of(context).textTheme;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: fg.withValues(alpha: 0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(tone.icon, color: fg, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (badge != null) ...[
                        Text(
                          badge!.toUpperCase(),
                          style: text.labelSmall?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        title,
                        style: text.titleMedium?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Bullets(
                actions,
                style: text.bodyMedium?.copyWith(
                  color: const Color(0xFF1E293B),
                  height: 1.35,
                ),
              ),
            ],
            if (why.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WHY',
                      style: text.labelSmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Bullets(
                      why,
                      bullet: '›',
                      style: text.bodySmall?.copyWith(
                        color: const Color(0xFF334155),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (footer != null) ...[const SizedBox(height: 8), footer!]
          ],
        ),
      ),
    );
  }
}

class AlertBanner extends StatelessWidget {
  const AlertBanner({super.key, required this.tone, required this.text});

  final Tone tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    final fg = tone.foreground();
    final bg = tone.background();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tone.icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.tone, required this.label});

  final Tone tone;
  final String label;

  @override
  Widget build(BuildContext context) {
    final fg = tone.foreground();
    final bg = tone.background();
    return Chip(
      avatar: Icon(tone.icon, size: 16, color: fg),
      label: Text(label),
      labelStyle: TextStyle(
        color: fg,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      backgroundColor: bg,
      side: BorderSide(color: fg.withValues(alpha: 0.25), width: 1),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}

class DisclaimerFooter extends StatelessWidget {
  const DisclaimerFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        'Based on ICMR/DHR Standard Treatment Workflows (Aug 2026). '
        'Advisory only — management of an individual patient is decided by '
        'the treating physician.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF64748B),
              fontSize: 11,
              height: 1.4,
            ),
      ),
    );
  }
}

/// Form on the left, live result on the right on wide screens (tablets);
/// stacked on phones, where the result is reached via a bottom bar.
class ResponsiveSplit extends StatelessWidget {
  const ResponsiveSplit({
    super.key,
    required this.form,
    required this.result,
    this.breakpoint = 900,
  });

  final List<Widget> form;
  final Widget result;
  final double breakpoint;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 900;

  @override
  Widget build(BuildContext context) {
    final formView = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [...form, const DisclaimerFooter()],
      ),
    );
    if (!isWide(context)) return formView;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: formView),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: result,
          ),
        ),
      ],
    );
  }
}

/// Sticky, colour-coded bar summarising the live recommendation on phones.
/// Tapping opens the full result in a bottom sheet.
class RecommendationBar extends StatelessWidget {
  const RecommendationBar({
    super.key,
    required this.tone,
    required this.title,
    required this.detail,
  });

  final Tone tone;
  final String title;
  final Widget detail;

  @override
  Widget build(BuildContext context) {
    final fg = tone.foreground();
    final bg = tone.background();
    return Material(
      color: bg,
      elevation: 6,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.65,
              maxChildSize: 0.95,
              builder: (context, controller) => SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: detail,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(tone.icon, color: fg, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.expand_less, color: fg, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
