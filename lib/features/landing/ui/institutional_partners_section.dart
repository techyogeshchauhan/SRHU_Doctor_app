import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Data model representing an institutional or research partner.
class InstitutionPartner {
  const InstitutionPartner({
    required this.code,
    required this.shortName,
    required this.fullName,
    required this.assetPath,
    required this.semanticsLabel,
  });

  final String code;
  final String shortName;
  final String fullName;
  final String assetPath;
  final String semanticsLabel;
}

/// The 5 official institutions supporting the application.
const List<InstitutionPartner> kInstitutionalPartners = [
  InstitutionPartner(
    code: 'ICMR',
    shortName: 'ICMR',
    fullName: 'Indian Council of Medical Research',
    assetPath: 'assets/images/icmr_logo.png',
    semanticsLabel: 'Indian Council of Medical Research (ICMR) Logo',
  ),
  InstitutionPartner(
    code: 'SRHU',
    shortName: 'SRHU',
    fullName: 'Swami Rama Himalayan University',
    assetPath: 'assets/images/logo212.png',
    semanticsLabel: 'Swami Rama Himalayan University (SRHU) Logo',
  ),
  InstitutionPartner(
    code: 'AIIMS',
    shortName: 'AIIMS Delhi',
    fullName: 'All India Institute of Medical Sciences, New Delhi',
    assetPath: 'assets/images/aiims-delhi.jpg',
    semanticsLabel: 'All India Institute of Medical Sciences Delhi Logo',
  ),
  InstitutionPartner(
    code: 'PGIMER',
    shortName: 'PGIMER',
    fullName:
        'Postgraduate Institute of Medical Education and Research, Chandigarh',
    assetPath: 'assets/images/pgi-logo.jpg',
    semanticsLabel:
        'Postgraduate Institute of Medical Education and Research Chandigarh Logo',
  ),
  InstitutionPartner(
    code: 'GMCH',
    shortName: 'GMCH',
    fullName: 'Government Medical College & Hospital, Chandigarh',
    assetPath: 'assets/images/GMCH chandigrah.png',
    semanticsLabel: 'Government Medical College and Hospital Chandigarh Logo',
  ),
];

/// Partner logos shown at the top of the landing page, in the order of
/// [kInstitutionalPartners]: ICMR first as a larger featured card (STW
/// author), then SRHU, AIIMS Delhi, PGIMER and GMCH in one row.
class InstitutionalPartnersSection extends StatelessWidget {
  const InstitutionalPartnersSection({
    super.key,
    this.isCompact = false,
  });

  /// When true (e.g. on small/short mobile viewports), typography and padding
  /// are scaled down to preserve the first-screen layout without overflow.
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final featured = kInstitutionalPartners.first;
    final others = kInstitutionalPartners.skip(1).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 700;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ICMR, featured
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: _PartnerCard(
                  partner: featured,
                  isDesktop: isDesktop,
                  isCompact: isCompact,
                  featured: true,
                ),
              ),
            ),
            SizedBox(height: isCompact ? 6 : 8),

            // SRHU, AIIMS Delhi, PGIMER, GMCH
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < others.length; i++) ...[
                    if (i > 0) SizedBox(width: isDesktop ? 8 : 6),
                    Expanded(
                      child: _PartnerCard(
                        partner: others[i],
                        isDesktop: isDesktop,
                        isCompact: isCompact,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: isCompact ? 6 : 10),

            Text(
              'Trusted By Leading Medical & Research Institutions',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: isCompact ? 11.5 : 13.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryNavy,
                letterSpacing: -0.2,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Developed with support, expertise, and collaboration from leading medical and research institutions.',
              textAlign: TextAlign.center,
              maxLines: isCompact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: isCompact ? 9.5 : 11.0,
                fontWeight: FontWeight.w400,
                color: AppTheme.mutedText,
                height: 1.25,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// An individual clean, neutral white partner card with subtle border,
/// soft shadow, accessible label, and hover elevation.
class _PartnerCard extends StatefulWidget {
  const _PartnerCard({
    required this.partner,
    required this.isDesktop,
    required this.isCompact,
    this.featured = false,
  });

  final InstitutionPartner partner;
  final bool isDesktop;
  final bool isCompact;

  /// Larger logo, tinted border and full name always shown (ICMR).
  final bool featured;

  @override
  State<_PartnerCard> createState() => _PartnerCardState();
}

class _PartnerCardState extends State<_PartnerCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.partner;
    final isDesktop = widget.isDesktop;
    final isCompact = widget.isCompact;

    final featured = widget.featured;

    final logoHeight = featured
        ? (isDesktop ? 110.0 : (isCompact ? 72.0 : 92.0))
        : (isDesktop ? 52.0 : (isCompact ? 34.0 : 42.0));
    final cardPaddingVertical = featured
        ? (isCompact ? 8.0 : 10.0)
        : (isDesktop ? 8.0 : (isCompact ? 5.0 : 6.0));
    final cardPaddingHorizontal = featured ? 12.0 : (isDesktop ? 6.0 : 4.0);
    final restingBorder =
        featured ? const Color(0x731F5FBF) : const Color(0xFFE2E8F0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            vertical: cardPaddingVertical,
            horizontal: cardPaddingHorizontal,
          ),
          decoration: BoxDecoration(
            color: featured ? const Color(0xFFF5F9FF) : Colors.white,
            borderRadius: BorderRadius.circular(featured ? 14 : 10),
            border: Border.all(
              color: _isHovered ? const Color(0x731F5FBF) : restingBorder,
              width: featured ? 1.4 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? const Color(0x181F5FBF)
                    : const Color(0x0A000000),
                blurRadius: _isHovered ? 8 : 3,
                offset: Offset(0, _isHovered ? 3 : 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo image container with object-fit: contain & aspect-ratio preservation
              SizedBox(
                height: logoHeight,
                width: double.infinity,
                child: Semantics(
                  label: p.semanticsLabel,
                  image: true,
                  child: Image.asset(
                    p.assetPath,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        p.code,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: isCompact ? 3 : 4),

              // Short Name
              Text(
                p.shortName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: featured
                      ? (isCompact ? 12.0 : 13.0)
                      : (isDesktop ? 11.0 : (isCompact ? 9.5 : 10.5)),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryNavy,
                  letterSpacing: -0.1,
                  height: 1.15,
                ),
              ),

              // Full Name (featured card, and every card on desktop)
              if (featured || isDesktop) ...[
                const SizedBox(height: 1),
                Text(
                  p.fullName,
                  textAlign: TextAlign.center,
                  maxLines: featured ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: featured ? (isCompact ? 9.5 : 10.5) : 9.0,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.mutedText,
                    height: 1.15,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
