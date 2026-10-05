import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/app_branding.dart';
import '../../../core/widgets/responsive.dart';
import 'institutional_partners_section.dart';

/// Landing Screen shown on app launch.
///
/// Features:
/// - Partner logos at the top in order ICMR (featured, larger), SRHU,
///   AIIMS Delhi, PGIMER, GMCH
/// - "STW Neo" wordmark and headline "Clinical guidance for newborn care"
/// - Subtitle: "Covers: Respiratory Distress in Neonates and Retinopathy of Prematurity (ROP), based on ICMR / DHR Standard Treatment Workflows."
/// - Full-width "Continue" primary button (min 46-50 px, primary blue)
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
        child: SafeArea(
          // Phone-proportioned on every device; scrolls on short screens.
          child: PhoneColumn(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact =
                    constraints.maxHeight < 680 || constraints.maxWidth < 420;
                final isVeryShort = constraints.maxHeight < 600;

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    isVeryShort ? 8 : 16,
                    16,
                    isVeryShort ? 10 : 16,
                  ),
                  child: Column(
                    children: [
                      // Free space is shared out so the header sits a little
                      // below the top edge and the page reads as balanced.
                      const Spacer(flex: 2),

                      // Header: ICMR hero, then partner institutions
                      InstitutionalPartnersSection(isCompact: isCompact),
                      const Spacer(flex: 3),

                      // Middle: app name and purpose
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StwNeoBrand(
                              showLogo: false,
                              showTitle: true,
                              titleSize:
                                  isVeryShort ? 20 : (isCompact ? 24 : 28),
                              mainAxisAlignment: MainAxisAlignment.center,
                            ),
                            SizedBox(height: isVeryShort ? 4 : 8),
                            Text(
                              'Clinical guidance for newborn care',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize:
                                    isVeryShort ? 16 : (isCompact ? 17.5 : 19),
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryNavy,
                                letterSpacing: -0.3,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: isVeryShort ? 3 : 6),
                            Text(
                              'Covers: Respiratory Distress in Neonates and Retinopathy of Prematurity (ROP), based on ICMR / DHR Standard Treatment Workflows.',
                              textAlign: TextAlign.center,
                              maxLines: isVeryShort ? 2 : 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: isVeryShort
                                    ? 11.0
                                    : (isCompact ? 12.0 : 13.0),
                                fontWeight: FontWeight.w400,
                                color: AppTheme.mutedText,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(flex: 3),

                      // Bottom: Continue
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
