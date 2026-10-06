import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/layout.dart';
import '../../../shared/pdf_navigation.dart';
import '../../condition_selection/domain/neonatal_condition.dart';
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
    final isRd = f.source.document.toLowerCase().contains('respiratory');
    final isRop = f.source.document.toLowerCase().contains('retinopathy') ||
        f.source.document.toLowerCase().contains('rop');

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
              if (isRd || isRop)
                InkWell(
                  onTap: () {
                    openStwPdf(
                      context,
                      assetPath: isRd ? rdPdfAsset : ropPdfAsset,
                      title: isRd ? rdPdfTitle : ropPdfTitle,
                    );
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
        SectionCard(
          title: 'Baby details',
          child: Text(summary.babyLine, style: text.bodyLarge),
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
