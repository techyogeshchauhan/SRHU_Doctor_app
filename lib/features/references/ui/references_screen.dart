import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../knowledge_graph/ui/stw_map_link.dart';
import '../../../core/widgets/app_branding.dart';
import '../../../core/widgets/app_refresh_button.dart';
import '../../../core/widgets/back_to_home_button.dart';
import '../../../shared/pdf_navigation.dart';
import '../../../shared/stw_disclaimer.dart';
import '../../ancs/domain/ancs_content.dart';
import '../../hypoglycemia/domain/hypo_content.dart';

const triageReferences = [
  'MoHFW, Government of India. Facility Based Newborn Care: Training '
      'Module for Doctors and Nurses (2023).',
  'World Health Organization. Paediatric Emergency Triage, Assessment and '
      'Treatment (ETAT): Updated guideline (2016).',
];

const kmcReferences = [
  'World Health Organization. Kangaroo mother care: a clinical practice '
      'guide. Geneva: WHO; 2025.',
  'Government of India. Operational guidelines for Kangaroo Mother Care '
      '(KMC) and optimal feeding of low birth weight infants. New Delhi: '
      'Ministry of Health and Family Welfare; 2014.',
  'Ministry of Health and Family Welfare, Government of India. Facility '
      'Based Newborn Care (FBNC): Participant Manual. New Delhi: MoHFW; 2023.',
];

/// Screen displaying the bundled ICMR / DHR STW reference PDFs,
/// external clinical guidelines cited in the STWs, and standard disclaimer.
class ReferencesScreen extends StatelessWidget {
  const ReferencesScreen({super.key});

  static const rdAsset = 'assets/pdfs/respiratory_distress_neonates_stw.pdf';
  static const rdTitle = 'Respiratory Distress in Neonates';
  static const rdSubtitle =
      'Standard Treatment Workflow · ICD-11 KB23 · ICMR / DHR · August 2026';

  static const ropAsset = 'assets/pdfs/retinopathy_of_prematurity_stw.pdf';
  static const ropTitle = 'Retinopathy of Prematurity (ROP)';
  static const ropSubtitle =
      'Standard Treatment Workflow · ICD-11 9B71.3 · ICMR / DHR · August 2026';

  // As printed on each PDF: the ANCS STW gives no ICD-11 code.
  static const ancsSubtitle =
      'Standard Treatment Workflow · ICMR / DHR · August 2026 · '
      'for pregnant women at risk of preterm birth';
  static const hypoSubtitle =
      'Standard Treatment Workflow · ICD-11 KB60.4 · ICMR / DHR · August 2026';

  static const triageTitle = triagePdfTitle;
  static const triageSubtitle =
      'Standard Treatment Workflow · ICMR / DHR · July 2020';
  static const kmcTitle = kmcPdfTitle;
  static const kmcSubtitle =
      'Standard Treatment Workflow · ICMR / DHR · August 2026';

  static const _accentAncs = Color(0xFF0F766E);
  static const _accentHypo = Color(0xFFB45309);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const StwNeoBrand(subtitle: 'References'),
        actions: [
          IconButton(
            tooltip: 'Clinical Assistant',
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () => context.push('/chat'),
          ),
          const BackToHomeButton(compact: true),
          const AppRefreshButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Intro note
              Text(
                'Original Standard Treatment Workflows',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryNavy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap "View PDF" to open the high-resolution one-page poster workflow published by ICMR / DHR. Zoom in for details or open in your device’s PDF app.',
                style: text.bodyMedium?.copyWith(
                  color: const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 16),

              // 1. Respiratory Distress Card
              _PdfWorkflowCard(
                title: rdTitle,
                subtitle: rdSubtitle,
                accentColor: AppTheme.accentRd,
                semanticsLabel: 'Open Respiratory Distress STW PDF',
                mapFocus: 'respiratoryDistress',
                onViewPdf: () => _openPdf(
                  context,
                  assetPath: rdAsset,
                  title: rdTitle,
                ),
              ),
              const SizedBox(height: 12),

              // 2. Retinopathy of Prematurity Card
              _PdfWorkflowCard(
                title: ropTitle,
                subtitle: ropSubtitle,
                accentColor: AppTheme.accentRop,
                semanticsLabel: 'Open Retinopathy of Prematurity STW PDF',
                mapFocus: 'rop',
                onViewPdf: () => _openPdf(
                  context,
                  assetPath: ropAsset,
                  title: ropTitle,
                ),
              ),
              const SizedBox(height: 12),

              // 3. Antenatal Corticosteroids Card
              _PdfWorkflowCard(
                title: ancsPdfTitle,
                subtitle: ancsSubtitle,
                accentColor: _accentAncs,
                semanticsLabel:
                    'Open Antenatal Corticosteroids for Preterm Birth STW PDF',
                mapFocus: 'ancs',
                onViewPdf: () => _openPdf(
                  context,
                  assetPath: ancsPdfAsset,
                  title: ancsPdfTitle,
                ),
              ),
              const SizedBox(height: 12),

              // 4. Neonatal Hypoglycemia Card
              _PdfWorkflowCard(
                title: hypoPdfTitle,
                subtitle: hypoSubtitle,
                accentColor: _accentHypo,
                semanticsLabel: 'Open Neonatal Hypoglycemia STW PDF',
                mapFocus: 'hypoglycemia',
                onViewPdf: () => _openPdf(
                  context,
                  assetPath: hypoPdfAsset,
                  title: hypoPdfTitle,
                ),
              ),
              const SizedBox(height: 20),

              // 5. Neonatal emergency triage
              _PdfWorkflowCard(
                title: triageTitle,
                subtitle: triageSubtitle,
                accentColor: AppTheme.accentRd,
                semanticsLabel: 'Open Neonatal Emergency Triage STW PDF',
                mapFocus: 'triage',
                onViewPdf: () => _openPdf(
                  context,
                  assetPath: triagePdfAsset,
                  title: triageTitle,
                ),
              ),
              const SizedBox(height: 12),

              // 6. Kangaroo Mother Care
              _PdfWorkflowCard(
                title: kmcTitle,
                subtitle: kmcSubtitle,
                accentColor: AppTheme.primaryTeal,
                semanticsLabel: 'Open Kangaroo Mother Care STW PDF',
                mapFocus: 'kmc',
                onViewPdf: () => _openPdf(
                  context,
                  assetPath: kmcPdfAsset,
                  title: kmcTitle,
                ),
              ),
              const SizedBox(height: 20),

              _PdfWorkflowCard(
                title: sepsisPdfTitle,
                subtitle:
                    'Standard Treatment Workflow · ICD-10-P36 · ICMR / DHR · August 2026',
                accentColor: AppTheme.primaryTeal,
                semanticsLabel: 'Open Sepsis STW PDF',
                mapFocus: 'sepsis',
                onViewPdf: () => _openPdf(context,
                    assetPath: sepsisPdfAsset, title: sepsisPdfTitle),
              ),
              const SizedBox(height: 20),

              // Sources cited in the STWs
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.format_quote_rounded,
                            color: AppTheme.primaryTeal,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sources cited in the STWs',
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryNavy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // RD sources
                      Text(
                        'Respiratory Distress in Neonates',
                        style: text.labelLarge?.copyWith(
                          color: AppTheme.accentRd,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Oxygen therapy in neonates, and Surfactant Replacement '
                        'therapy in neonates. Evidence-based Clinical Practice '
                        'Guidelines. National Neonatology Forum India. '
                        'Available at www.nnfi.org/cpg',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          height: 1.45,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppTheme.borderColor),
                      const SizedBox(height: 16),

                      // ROP sources
                      Text(
                        'Retinopathy of Prematurity (ROP)',
                        style: text.labelLarge?.copyWith(
                          color: AppTheme.accentRop,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'MoHFW, Government of India. Guidelines for Universal '
                        'Eye Screening in Newborns Including Retinopathy of '
                        'Prematurity. RBSK. Available at: nhm.gov.in',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          height: 1.45,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'National Neonatology Forum of India. Screening and '
                        'Management of Retinopathy of Prematurity: Clinical '
                        'Practice Guideline. Available at: nnfi.org/cpg.php',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          height: 1.45,
                          color: Color(0xFF334155),
                        ),
                      ),
                      for (final (title, color, refs) in [
                        (ancsPdfTitle, _accentAncs, ancsReferences),
                        (hypoPdfTitle, _accentHypo, hypoReferences),
                        (triageTitle, AppTheme.accentRd, triageReferences),
                        (kmcTitle, AppTheme.primaryTeal, kmcReferences),
                      ]) ...[
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: AppTheme.borderColor),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          style: text.labelLarge?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        for (final r in refs) ...[
                          const SizedBox(height: 4),
                          Text(
                            r,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              height: 1.45,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 6. Disclaimer
              Text(
                'Disclaimer (from the STW)',
                style: text.labelSmall?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const StwDisclaimerContent(color: Color(0xFF64748B)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  static void _openPdf(
    BuildContext context, {
    required String assetPath,
    required String title,
  }) {
    openStwPdf(
      context,
      assetPath: assetPath,
      title: title,
    );
  }
}

class _PdfWorkflowCard extends StatelessWidget {
  const _PdfWorkflowCard({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.semanticsLabel,
    required this.onViewPdf,
    this.mapFocus,
  });

  /// Topic to open in the STW Map; null hides the button.
  final String? mapFocus;

  final String title;
  final String subtitle;
  final Color accentColor;
  final String semanticsLabel;
  final VoidCallback onViewPdf;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf_outlined,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (mapFocus != null)
                  Flexible(
                    child: StwMapLinkButton(focus: mapFocus, label: 'STW Map'),
                  ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: semanticsLabel,
                  child: FilledButton.icon(
                    onPressed: onViewPdf,
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('View PDF'),
                    style: FilledButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
