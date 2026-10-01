import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../content/stw_content.dart';
import '../../core/theme.dart';
import '../../core/widgets/layout.dart';
import '../../shared/baby_context.dart';
import '../rd/state/rd_controller.dart';
import '../rd/ui/rd_results.dart';
import '../rop/state/rop_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedTab = 0; // 0: Workflows, 1: References

  @override
  Widget build(BuildContext context) {
    final baby = ref.watch(babyProvider);
    final rdTitle = initialTitle(ref.watch(rdInitialProvider));
    final rop = ref.watch(ropEligibilityProvider);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final showHowToUse = screenHeight >= 680;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Neonatal STW'),
        actions: [
          Semantics(
            button: true,
            label: 'References and source STW PDFs',
            child: IconButton(
              tooltip: 'References & source PDFs',
              icon: const Icon(Icons.menu_book_outlined, size: 22),
              onPressed: () => context.push('/references'),
            ),
          ),
          Semantics(
            button: true,
            label: 'About and disclaimer',
            child: IconButton(
              tooltip: 'About & disclaimer',
              icon: const Icon(Icons.info_outline, size: 22),
              onPressed: () => context.push('/about'),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. Segmented tab pill chips (SRHU website style)
              _buildPillTabs(),
              const SizedBox(height: 12),

              // 2. Stats-style big-number strip with true facts
              const _StatsStrip(),
              const SizedBox(height: 12),

              // 3. Numbered steps "How to use" strip (hidden on compact screens <680 px)
              if (showHowToUse) ...[
                const _HowToUseStrip(),
                const SizedBox(height: 14),
              ],

              // 4. Section Heading with 3 px blue accent bar
              _SectionHeader(
                title: _selectedTab == 0
                    ? 'Clinical Workflows'
                    : 'References & Documents',
              ),
              const SizedBox(height: 10),

              // 5. Tab content
              if (_selectedTab == 0) ...[
                // RD Module Card
                _ModuleCard(
                  icon: Icons.air,
                  title: 'Respiratory Distress',
                  code: 'ICD-11 KB23',
                  accentColor: AppTheme.accentRd,
                  description: 'SAS scoring → CPAP / nasal O₂ → reassess, '
                      'surfactant, wean or optimize.',
                  status: baby.isEmpty ? null : rdTitle,
                  onTap: () => context.push('/rd'),
                ),

                // ROP Module Card
                _ModuleCard(
                  icon: Icons.visibility_outlined,
                  title: 'Retinopathy of Prematurity',
                  code: 'ICD-11 9B71.3',
                  accentColor: AppTheme.accentRop,
                  description:
                      'Eligibility → first-screen date → exam findings '
                      '→ treatment indication → follow-up plan.',
                  status: switch (rop.eligible) {
                    true => 'Eligible for ROP screening',
                    false => 'Not eligible per STW criteria',
                    null => null,
                  },
                  onTap: () => context.push('/rop'),
                ),

                // References compact card
                _ReferencesCard(
                  onTap: () => context.push('/references'),
                ),
                const SizedBox(height: 4),

                // Baby Context Card
                BabyContextCard(
                  onClearAll: () {
                    ref.read(babyProvider.notifier).clear();
                    ref.read(rdProvider.notifier).reset();
                    ref.read(ropProvider.notifier).reset();
                  },
                ),
              ] else ...[
                // References view
                _ReferencesCard(
                  onTap: () => context.push('/references'),
                ),
                const SizedBox(height: 6),
                _DirectPdfCard(
                  title: 'Respiratory Distress in Neonates',
                  code: 'ICD-11 KB23 · ICMR / DHR STW',
                  onTap: () => context.push(
                    '/pdf-viewer?path=assets/pdfs/respiratory_distress_neonates_stw.pdf&title=Respiratory Distress in Neonates',
                  ),
                ),
                const SizedBox(height: 6),
                _DirectPdfCard(
                  title: 'Retinopathy of Prematurity (ROP)',
                  code: 'ICD-11 9B71.3 · ICMR / DHR STW',
                  onTap: () => context.push(
                    '/pdf-viewer?path=assets/pdfs/retinopathy_of_prematurity_stw.pdf&title=Retinopathy of Prematurity (ROP)',
                  ),
                ),
              ],

              const SizedBox(height: 6),
              const DisclaimerFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillTabs() {
    return Row(
      children: [
        _buildPill(
          label: 'Workflows',
          isSelected: _selectedTab == 0,
          onTap: () => setState(() => _selectedTab = 0),
        ),
        const SizedBox(width: 8),
        _buildPill(
          label: 'References',
          isSelected: _selectedTab == 1,
          onTap: () => setState(() => _selectedTab = 1),
        ),
      ],
    );
  }

  Widget _buildPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : AppTheme.tint,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : AppTheme.dividerColor,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.primaryNavy,
          ),
        ),
      ),
    );
  }
}

/// Compact stats-style strip in SRHU big-number style using only true facts.
class _StatsStrip extends StatelessWidget {
  const _StatsStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dividerColor, width: 1.0),
      ),
      child: const Row(
        children: [
          Expanded(
            child: _StatItem(
              highlight: '2',
              label: 'Workflows',
            ),
          ),
          _StatDivider(),
          Expanded(
            child: _StatItem(
              highlight: 'ICMR / DHR',
              label: 'STW',
            ),
          ),
          _StatDivider(),
          Expanded(
            child: _StatItem(
              highlight: 'Aug 2026',
              label: 'Edition',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.highlight, required this.label});

  final String highlight;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            highlight,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryBlue,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.mutedText,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: AppTheme.dividerColor,
    );
  }
}

/// Numbered steps "How to use" strip (01, 02, 03 with tiny blue circles).
class _HowToUseStrip extends StatelessWidget {
  const _HowToUseStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.tint.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor, width: 1.0),
      ),
      child: const Row(
        children: [
          _StepItem(step: '01', title: 'Choose workflow'),
          SizedBox(width: 6),
          _StepItem(step: '02', title: 'Enter details'),
          SizedBox(width: 6),
          _StepItem(step: '03', title: 'Follow steps'),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({required this.step, required this.title});

  final String step;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: AppTheme.primaryBlue,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              step,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.bodyText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading in Navy Poppins SemiBold with 3 px blue accent bar.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryNavy,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 28,
          height: 3,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

/// Compact horizontal module tile (76-90 px height) with 38 px badge & 20 px icon.
class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.code,
    required this.description,
    required this.onTap,
    this.accentColor,
    this.status,
  });

  final IconData icon;
  final String title;
  final String code;
  final String description;
  final Color? accentColor;
  final String? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? AppTheme.primaryBlue;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 38 px circle badge with 20 px icon inside
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppTheme.tint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: effectiveAccent, size: 20),
              ),
              const SizedBox(width: 12),

              // Title, ICD code, description and status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    Text(
                      code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.mutedText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        height: 1.3,
                        color: AppTheme.bodyText,
                      ),
                    ),
                    if (status != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        status!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: effectiveAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Small "Open →" link in primary blue
              Text(
                'Open →',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: effectiveAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact references card with 38 px badge & "View →" link in primary blue.
class _ReferencesCard extends StatelessWidget {
  const _ReferencesCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        label: 'Open References and source STW PDFs',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppTheme.tint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.menu_book_outlined,
                    color: AppTheme.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'References & STW Documents',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                      Text(
                        'ICMR / DHR · 2026',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.mutedText,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'View the two original Standard Treatment Workflow PDFs and cited sources.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          height: 1.3,
                          color: AppTheme.bodyText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'View →',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectPdfCard extends StatelessWidget {
  const _DirectPdfCard({
    required this.title,
    required this.code,
    required this.onTap,
  });

  final String title;
  final String code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppTheme.tint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: AppTheme.primaryBlue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    Text(
                      code,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: AppTheme.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Open PDF →',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
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
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppTheme.tint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medical_services_outlined,
                size: 22,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Neonatal STW decision support',
            style: text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryNavy,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Interactive version of the ICMR / Department of Health Research '
            'Standard Treatment Workflows "Respiratory Distress in Neonates" '
            'and "Retinopathy of Prematurity (ROP)" (August 2026). '
            'No patient data is stored: everything entered is kept in memory '
            'and cleared when the app is closed or "New baby" is tapped.',
            style: TextStyle(color: AppTheme.bodyText, height: 1.4),
          ),
          const SizedBox(height: 20),
          Text(
            'Disclaimer (from the STW)',
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryNavy,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            stwDisclaimer,
            style: TextStyle(color: AppTheme.mutedText, height: 1.4),
          ),
        ],
      ),
    );
  }
}
