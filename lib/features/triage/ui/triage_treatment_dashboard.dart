import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/layout.dart';
import '../../../shared/pdf_navigation.dart';
import '../../clinical_workflow/state/assessment_controller.dart';
import '../domain/triage_treatment.dart';
import '../domain/triage_workflow.dart';
import 'triage_category_banner.dart';

/// Shown as soon as the Triage page is confirmed: the computed category,
/// the TABC cards and the protocol cards, each linking to its STW box.
/// Emergency shows every card; Priority only the flagged ones.
class TriageTreatmentDashboard extends ConsumerWidget {
  const TriageTreatmentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(assessmentProvider.select((s) => s.context));
    final category = ctx.valueOf(triageCategoryKey);
    if (category is! String) return const SizedBox.shrink();
    final emergency = category == triageEmergency;
    final cards = [
      for (final c in triageTreatmentCards(ctx))
        if (emergency || c.flagged) c,
    ];
    final tabc = cards.where((c) => c.isTabc).toList();
    final protocols = cards.where((c) => !c.isTabc).toList()
      ..sort((a, b) => (b.flagged ? 1 : 0) - (a.flagged ? 1 : 0));
    final text = Theme.of(context).textTheme;
    final heading = text.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: AppTheme.primaryNavy,
    );

    return Column(
      key: const ValueKey('triage-treatment-dashboard'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          emergency ? 'Emergency Treatment' : 'Triage Treatment',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryNavy,
          ),
        ),
        const SizedBox(height: 10),
        TriageCategoryBanner(reader: ctx),
        if (tabc.isNotEmpty) ...[
          Text('TABC', style: heading),
          const SizedBox(height: 8),
          _CardGrid(cards: tabc),
        ],
        if (protocols.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Specific protocols', style: heading),
          const SizedBox(height: 8),
          _CardGrid(cards: protocols),
        ],
        const Divider(height: 24),
      ],
    );
  }
}

/// Two columns on wide screens, stacked on phones.
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.cards});

  final List<TriageProtocolCard> cards;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          const gap = 12.0;
          final width = constraints.maxWidth >= 600
              ? (constraints.maxWidth - gap) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final c in cards)
                SizedBox(width: width, child: _ProtocolCardView(card: c)),
            ],
          );
        },
      );
}

class _ProtocolCardView extends StatelessWidget {
  const _ProtocolCardView({required this.card});

  final TriageProtocolCard card;

  @override
  Widget build(BuildContext context) {
    final c = card;
    final tone = c.flagged ? Tone.danger : Tone.info;
    final fg = c.flagged ? tone.foreground() : AppTheme.primaryNavy;
    final text = Theme.of(context).textTheme;

    return Container(
      key: ValueKey('triage-card-${c.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.flagged ? tone.background() : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.flagged
              ? fg.withValues(alpha: 0.55)
              : AppTheme.dividerColor,
          width: c.flagged ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (c.letter != null) ...[
                CircleAvatar(
                  radius: 15,
                  backgroundColor: fg.withValues(alpha: 0.12),
                  child: Text(
                    c.letter!,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  c.title,
                  style: text.titleSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (c.flagged)
                StatusChip(
                  key: ValueKey('triage-card-${c.id}-flagged'),
                  tone: Tone.danger,
                  label: 'FLAGGED',
                ),
            ],
          ),
          if (c.flagged) ...[
            const SizedBox(height: 6),
            Text(
              c.flaggedBecause.join(' · '),
              style: text.bodySmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          for (final a in c.actions)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      a.applies
                          ? Icons.arrow_right_rounded
                          : Icons.circle_outlined,
                      size: a.applies ? 18 : 8,
                      color: a.applies ? fg : AppTheme.mutedText,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      a.text,
                      style: text.bodyMedium?.copyWith(
                        color: a.applies
                            ? const Color(0xFF1E293B)
                            : AppTheme.mutedText,
                        fontWeight:
                            a.applies ? FontWeight.w700 : FontWeight.w400,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final link in c.links)
                if (stwPdfFor(link.stw) case final pdf?)
                  OutlinedButton.icon(
                    key: ValueKey('triage-link-${c.id}-${link.regionId}'),
                    onPressed: () => openStwRegion(
                      context,
                      pdf: pdf,
                      regionId: link.regionId,
                      origin: 'triage_card:${c.id}',
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
                    label: Text(link.label),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          c.flagged ? fg : AppTheme.primaryBlue,
                      backgroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}
