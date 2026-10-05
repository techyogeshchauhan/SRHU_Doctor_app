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
    semanticsLabel:
        'Government Medical College and Hospital Chandigarh Logo',
  ),
];

/// Professional "Institutional / Research Partners" section displayed on the
/// landing page to establish medical and research credibility in the first screen.
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header
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
        SizedBox(height: isCompact ? 8 : 12),

        // Partner Cards Responsive Grid/Row
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isDesktop = width >= 700;

            if (isDesktop) {
              // Desktop: Exactly 5 equal-width logo cards in ONE horizontal row
              return Row(
                children: [
                  for (int i = 0; i < kInstitutionalPartners.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _PartnerCard(
                        partner: kInstitutionalPartners[i],
                        isDesktop: true,
                        isCompact: isCompact,
                      ),
                    ),
                  ],
                ],
              );
            } else {
              // Mobile / Tablet: 3 + 2 balanced layout
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1: ICMR, SRHU, AIIMS Delhi
                  Row(
                    children: [
                      for (int i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: _PartnerCard(
                            partner: kInstitutionalPartners[i],
                            isDesktop: false,
                            isCompact: isCompact,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Row 2: PGIMER, GMCH (balanced width)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 3; i < 5; i++) ...[
                        if (i > 3) const SizedBox(width: 6),
                        Expanded(
                          child: _PartnerCard(
                            partner: kInstitutionalPartners[i],
                            isDesktop: false,
                            isCompact: isCompact,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              );
            }
          },
        ),
      ],
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
  });

  final InstitutionPartner partner;
  final bool isDesktop;
  final bool isCompact;

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

    final logoHeight = isDesktop
        ? 34.0
        : (isCompact ? 24.0 : 28.0);
    final cardPaddingVertical = isDesktop
        ? 8.0
        : (isCompact ? 5.0 : 6.0);
    final cardPaddingHorizontal = isDesktop ? 6.0 : 4.0;

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
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovered
                  ? const Color(0x731F5FBF)
                  : const Color(0xFFE2E8F0),
              width: 1.0,
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
                    fontSize: isDesktop ? 11.0 : (isCompact ? 9.5 : 10.5),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryNavy,
                    letterSpacing: -0.1,
                    height: 1.15,
                  ),
                ),

                // Full Name (displayed on desktop and standard tablet/mobile)
                if (!isCompact || isDesktop) ...[
                  const SizedBox(height: 1),
                  Text(
                    p.fullName,
                    textAlign: TextAlign.center,
                    maxLines: isDesktop ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: isDesktop ? 9.0 : 8.5,
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

