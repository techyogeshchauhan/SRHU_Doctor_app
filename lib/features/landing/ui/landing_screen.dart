import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';

/// New Landing Screen shown on app launch.
///
/// Features:
/// - Edge-to-edge portrait poster (landingpageimage.png) with soft bottom fade to white
/// - Headline: "Clinical guidance for newborn care" (Poppins SemiBold, navy)
/// - Subtitle: "Covers: Respiratory Distress in Neonates and Retinopathy of Prematurity (ROP), based on ICMR / DHR Standard Treatment Workflows."
/// - Full-width "Continue" primary button (min 52 px, primary blue)
/// - No scroll, no overflow across all device sizes and large font scales
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
        child: Column(
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
                    height: 80,
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

            // Bottom text and button on white
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Clinical guidance for newborn care',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryNavy,
                        letterSpacing: -0.3,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Covers: Respiratory Distress in Neonates and Retinopathy of Prematurity (ROP), based on ICMR / DHR Standard Treatment Workflows.',
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.mutedText,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
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
          ],
        ),
      ),
    );
  }
}
