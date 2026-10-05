import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/app_branding.dart';
import 'institutional_partners_section.dart';

/// Landing Screen shown on app launch.
///
/// Features:
/// - Edge-to-edge portrait poster (landingpageimage.png) with soft bottom fade to white
/// - Headline: "Clinical guidance for newborn care" (Poppins SemiBold, navy)
/// - Subtitle: "Covers: Respiratory Distress in Neonates and Retinopathy of Prematurity (ROP), based on ICMR / DHR Standard Treatment Workflows."
/// - Institutional / Research Partners section (ICMR, SRHU, AIIMS Delhi, PGIMER, GMCH)
/// - Full-width "Continue" primary button (min 50 px, primary blue)
/// - Responsive and compact layout fitting within the first screen without overflow
/// - Tapping "Continue" navigates to /home (replacing route so back exits app)
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  late final Animation<double> _fadeAnim = CurvedAnimation(
    parent: _fadeCtrl,
    curve: Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    _fadeCtrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(
      const AssetImage('assets/images/landingpageimage.png'),
      context,
      onError: (_, __) {},
    );
    for (final partner in kInstitutionalPartners) {
      precacheImage(
        AssetImage(partner.assetPath),
        context,
        onError: (_, __) {},
      );
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact =
                constraints.maxHeight < 680 || constraints.maxWidth < 420;
            final isVeryShort = constraints.maxHeight < 600;

            return Column(
              children: [
                // Top: Image filling top portion edge-to-edge with bottom soft white fade
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/landingpageimage.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        cacheWidth: 800,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFEAF2FF),
                          child: const Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 48,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                      // Soft white gradient fade at bottom edge blending into white area
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: isVeryShort ? 50 : 70,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x00FFFFFF),
                                Colors.white,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom: Text, Institutional Partners, and Continue button
                SafeArea(
                  top: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          isVeryShort ? 4 : 8,
                          16,
                          isVeryShort ? 10 : 16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Prominent ICMR + STW Neo Brand
                            StwNeoBrand(
                              logoHeight: isVeryShort ? 24 : (isCompact ? 28 : 34),
                              titleSize: isVeryShort ? 17 : (isCompact ? 19 : 22),
                              mainAxisAlignment: MainAxisAlignment.center,
                            ),
                            SizedBox(height: isVeryShort ? 3 : 6),
                            Text(
                              'Clinical guidance for newborn care',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: isVeryShort ? 16 : (isCompact ? 17.5 : 19),
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryNavy,
                                letterSpacing: -0.3,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: isVeryShort ? 3 : 5),
                            Text(
                              'Covers: Respiratory Distress in Neonates and Retinopathy of Prematurity (ROP), based on ICMR / DHR Standard Treatment Workflows.',
                              textAlign: TextAlign.center,
                              maxLines: isVeryShort ? 2 : 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: isVeryShort ? 11.0 : (isCompact ? 12.0 : 13.0),
                                fontWeight: FontWeight.w400,
                                color: AppTheme.mutedText,
                                height: 1.25,
                              ),
                            ),
                            SizedBox(height: isVeryShort ? 6 : (isCompact ? 10 : 14)),

                            // Institutional Partners Section
                            InstitutionalPartnersSection(isCompact: isCompact),

                            SizedBox(height: isVeryShort ? 8 : (isCompact ? 12 : 16)),

                            // Continue Action Button
                            SizedBox(
                              width: double.infinity,
                              height: isVeryShort ? 46 : 50,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () => context.go('/home'),
                                child: const Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

