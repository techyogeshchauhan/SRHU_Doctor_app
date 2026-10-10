import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/layout.dart';
import '../../../shared/pdf_navigation.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
import '../../follow_up/data/disease_follow_up_registry.dart';
import '../../follow_up/state/follow_up_controller.dart';
import '../domain/clinical_finding.dart';
import '../domain/combined_summary.dart';
import '../state/assessment_controller.dart';

Tone toneFor(FindingLevel l) => switch (l) {
      FindingLevel.info => Tone.info,
      FindingLevel.ok => Tone.success,
      FindingLevel.action => Tone.warning,
      FindingLevel.treat => Tone.treat,
      FindingLevel.urgent => Tone.danger,
    };

/// One finding with its category, actions, reasons and STW source.
class FindingCard extends StatelessWidget {
  const FindingCard({super.key, required this.finding});

  final ClinicalFinding finding;

  @override
  Widget build(BuildContext context) {
    final f = finding;
    final small = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: const Color(0xFF475569));
    final pdf = stwPdfForDocument(f.source.document);
    final regionId = f.source.pdfRegionId;

    return ResultCard(
      tone: toneFor(f.level),
      badge: f.category.label,
      title: f.title,
      actions: f.actions,
      why: f.why,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Source: ${f.source.citation}', style: small),
              ),
              _FooterLink(
                icon: Icons.account_tree_outlined,
                label: 'Why?',
                semanticLabel: 'Why this recommendation?',
                onTap: () => context.push(
                  '/assessment-map?focus=${Uri.encodeComponent(f.id)}',
                ),
              ),
              if (pdf != null)
                InkWell(
                  onTap: () {
                    if (regionId != null) {
                      openStwRegion(context, pdf: pdf, regionId: regionId);
                    } else {
                      openStwPdf(
                        context,
                        assetPath: pdf.asset,
                        title: pdf.title,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 13,
                          color: AppTheme.primaryBlue,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'View PDF',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (f.source.needsClinicalReview)
            Text(
              'Requires clinical review: ${f.source.note ?? 'app reading of '
                  'ambiguous STW wording'}',
              style: small?.copyWith(fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}

/// Small text link in a finding card footer.
class _FooterLink extends StatelessWidget {
  const _FooterLink({
    required this.icon,
    required this.label,
    required this.onTap,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final String? semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semanticLabel ?? label,
        excludeSemantics: semanticLabel != null,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: AppTheme.primaryBlue),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Combined assessment for all selected topics.
class AssessmentSummaryView extends ConsumerWidget {
  const AssessmentSummaryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(assessmentProvider.select((s) => s.context));
    final n = ref.read(assessmentProvider.notifier);
    final summary = CombinedAssessmentSummary.from(
      ctx,
      engine: ref.read(assessmentEngineProvider),
    );
    final text = Theme.of(context).textTheme;
    final heading = text.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: AppTheme.primaryNavy,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Clinical Assessment Summary',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryNavy,
          ),
        ),
        const SizedBox(height: 12),
        for (final s in summary.subjects)
          SectionCard(
            title: s.label == 'Baby' ? 'Baby details' : s.label,
            child: Text(s.line, style: text.bodyLarge),
          ),
        SectionCard(
          title: 'Topics assessed',
          subtitle: 'Selected for assessment — not diagnoses',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in summary.topics)
                    StatusChip(
                      tone: t.available ? Tone.success : Tone.info,
                      label: t.title,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Questions answered: ${summary.answered} of '
                '${summary.applicable} applicable',
                style: text.bodyMedium,
              ),
            ],
          ),
        ),
        if (ctx.findings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton.icon(
              onPressed: () => context.push('/assessment-map'),
              icon: const Icon(Icons.account_tree_outlined, size: 18),
              label: const Text('Assessment map: how your answers led here'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryNavy,
                minimumSize: const Size(0, 46),
              ),
            ),
          ),
        for (final t in summary.topics) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              children: [
                Expanded(child: Text(t.title, style: heading)),
                StatusChip(
                  tone: t.available ? Tone.success : Tone.info,
                  label: definitionOf(t.topic).status.label,
                ),
              ],
            ),
          ),
          const Divider(height: 12),
          if (!t.available)
            const AlertBanner(tone: Tone.info, text: pendingStwMessage)
          else ...[
            if (t.findings.isEmpty)
              const AlertBanner(tone: Tone.info, text: noFindingsText),
            for (final f in t.findings) FindingCard(finding: f),
            if (t.topic == NeonatalCondition.respiratoryDistress &&
                n.canRecordRdReassessment)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  onPressed: n.recordRdReassessmentAndRepeat,
                  icon: const Icon(Icons.playlist_add_check),
                  label: const Text('Record SAS & start next reassessment'),
                ),
              ),
            if (t.dischargeCard != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: SelectableText(
                    t.dischargeCard!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                      height: 1.45,
                    ),
                  ),
                ),
              ),
          ],
        ],
        const SizedBox(height: 8),
        const AlertBanner(tone: Tone.info, text: combinedSummaryAdvisory),
        const SizedBox(height: 12),
        Builder(
          builder: (context) {
            final hasFollowUp = hasFollowUpForSelected(ctx.selected);
            if (hasFollowUp) {
              final conditionWithMcqs = ctx.selected.firstWhere(
                hasFollowUpForCondition,
                orElse: () => ctx.selected.first,
              );
              final pkg = getFollowUpPackage(conditionWithMcqs)!;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0x330B2545),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0x1A0B2545),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.school_outlined,
                            color: AppTheme.primaryNavy,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Follow-up Assessment: ${pkg.title}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryNavy,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pkg.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        ref.read(followUpProvider.notifier).initForCondition(
                              conditionWithMcqs,
                              startImmediately: true,
                            );
                        context.push('/follow-up-assessment');
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Proceed to Follow-up Assessment'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryNavy,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final conditionLabels =
                ctx.selected.map((c) => definitionOf(c).title).join(', ');
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.school_outlined,
                          color: Color(0xFF64748B),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Follow-up Assessment: $conditionLabels',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryNavy,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Follow-up MCQs and bedside clinical case scenarios for $conditionLabels are currently under preparation as per ICMR / DHR STW guidelines.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                      ClipboardData(text: summary.toPlainText()));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Summary copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Share.share(
                  summary.toPlainText(),
                  subject: 'Clinical assessment summary',
                ),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.home_rounded, size: 18),
            label: const Text('Back to Home (Condition Selection)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryNavy,
              minimumSize: const Size(0, 48),
              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
