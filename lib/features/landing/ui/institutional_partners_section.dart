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
/// [kInstitutionalPartners]: ICMR first as the hero panel (STW
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
            // ICMR as the hero element
            _IcmrHero(partner: featured, isCompact: isCompact),
            SizedBox(height: isCompact ? 14 : 22),

            Text(
              'Trusted By Leading Medical & Research Institutions',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: isCompact ? 11.5 : 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryNavy,
                letterSpacing: -0.1,
                height: 1.2,
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
            SizedBox(height: isCompact ? 6 : 8),
            Text(
              'Developed with support, expertise, and collaboration from leading medical and research institutions.',
              textAlign: TextAlign.center,
              maxLines: 2,
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

/// ICMR, the STW author, presented as the landing page's hero: the logo
/// spans the panel's full width on a soft gradient with a gentle shadow.
class _IcmrHero extends StatelessWidget {
  const _IcmrHero({required this.partner, required this.isCompact});

  final InstitutionPartner partner;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final p = partner;
    return Container(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 16 : 22,
        isCompact ? 16 : 24,
        isCompact ? 16 : 22,
        isCompact ? 12 : 18,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFEEF4FF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x401F5FBF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x141F5FBF),
            blurRadius: 18,
            spreadRadius: -4,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            // Full width on phones; taller on tablets and desktop.
            constraints: BoxConstraints(maxHeight: isCompact ? 80 : 128),
            child: Semantics(
              label: p.semanticsLabel,
              image: true,
              child: Image.asset(
                p.assetPath,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(
                  p.code,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 28,
                    color: AppTheme.primaryNavy,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: isCompact ? 10 : 14),
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: isCompact ? 6 : 8),
          Text(
            p.shortName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: isCompact ? 15 : 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryNavy,
              letterSpacing: 1.2,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            p.fullName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: isCompact ? 11.5 : 12.5,
              color: AppTheme.mutedText,
              height: 1.2,
            ),
          ),
        ],
      ),
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

    final logoHeight = isDesktop ? 52.0 : (isCompact ? 32.0 : 38.0);
    final cardPaddingVertical = isDesktop ? 8.0 : (isCompact ? 5.0 : 6.0);
    final cardPaddingHorizontal = isDesktop ? 6.0 : 4.0;
    const restingBorder = Color(0xFFE2E8F0);

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
              color: _isHovered ? const Color(0x731F5FBF) : restingBorder,
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

              // Full Name (desktop only)
              if (isDesktop) ...[
                const SizedBox(height: 1),
                Text(
                  p.fullName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9.0,
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
