import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../content/stw_content.dart';
import '../../../core/theme.dart';

/// Redesigned Landing Screen matching the clean White + Blue SRHU-inspired aesthetic.
///
/// Designed to fit on ONE screen without scrolling on all supported sizes
/// (320x568, 360x640, 360x740, 412x915).
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  // Staggered entrance animation controller (<1s total)
  late final AnimationController _entranceCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  // Subtle breathing scale controller for hero baby photo
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );

  late final Animation<double> _heroFade = CurvedAnimation(
    parent: _entranceCtrl,
    curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
  );

  late final Animation<double> _cardsFade = CurvedAnimation(
    parent: _entranceCtrl,
    curve: const Interval(0.2, 0.75, curve: Curves.easeOut),
  );

  late final Animation<Offset> _cardsSlide = Tween<Offset>(
    begin: const Offset(0.0, 0.08),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _entranceCtrl,
    curve: const Interval(0.2, 0.75, curve: Curves.easeOutCubic),
  ));

  late final Animation<double> _footerFade = CurvedAnimation(
    parent: _entranceCtrl,
    curve: const Interval(0.4, 0.95, curve: Curves.easeOut),
  );

  // Subtle breathing scale for baby hero image (1.0 to 1.02)
  late final Animation<double> _breathingScale = Tween<double>(
    begin: 1.0,
    end: 1.02,
  ).animate(CurvedAnimation(
    parent: _pulseCtrl,
    curve: Curves.easeInOutSine,
  ));

  @override
  void initState() {
    super.initState();
    _entranceCtrl.forward();

    // In unit / widget tests, avoid infinite repeat so tester.pumpAndSettle settles instantly
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTest) {
      _pulseCtrl.repeat(reverse: true);
    } else {
      _pulseCtrl.value = 0.5;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(
      const AssetImage('assets/images/logo212.png'),
      context,
      onError: (_, __) {},
    );
    precacheImage(
      const AssetImage('assets/images/hu.png'),
      context,
      onError: (_, __) {},
    );
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _showDisclaimerSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: AppTheme.primaryBlue,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'STW Advisory Disclaimer',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    stwDisclaimer,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      height: 1.5,
                      color: AppTheme.bodyText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Background gradient with soft ambient waves (White + Blue only)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF0F5FD),
                    Color(0xFFFFFFFF),
                    Color(0xFFF7FAFF),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _BackgroundWavesPainter(),
            ),
          ),

          // 2. Main adaptive single-screen layout
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height = constraints.maxHeight;
                final isShort = height < 680;
                final isVeryShort = height < 580;
                final maxHeroHeight = (height * 0.28).clamp(95.0, 185.0);

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: isVeryShort ? 4 : 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // A. Brand Row
                      _buildBrandRow(isShort: isShort),
                      SizedBox(height: isVeryShort ? 4 : 8),

                      // B. Hero Section (Moderate height <=30%, fading into white)
                      Flexible(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: maxHeroHeight),
                          child: FadeTransition(
                            opacity: _heroFade,
                            child: _buildHeroSection(
                              isShort: isShort,
                              isVeryShort: isVeryShort,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: isVeryShort ? 6 : 10),

                      // C. Two Compact Horizontal Module Cards
                      FadeTransition(
                        opacity: _cardsFade,
                        child: SlideTransition(
                          position: _cardsSlide,
                          child: _buildCardsRow(
                            isShort: isShort,
                            isVeryShort: isVeryShort,
                          ),
                        ),
                      ),

                      // D. Feature Row (Shown on screens ≥680 px)
                      if (!isShort) ...[
                        const SizedBox(height: 12),
                        FadeTransition(
                          opacity: _footerFade,
                          child: _buildFeatureRow(),
                        ),
                      ],

                      const Spacer(),

                      // E. Footer
                      FadeTransition(
                        opacity: _footerFade,
                        child: _buildFooter(context, isShort: isShort),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 1. Top Brand Row with free SRHU logo and "SRHU STW" title
  Widget _buildBrandRow({required bool isShort}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Free SRHU logo: no box, no circle, no border, no shadow, height 36-40 px
        Image.asset(
          'assets/images/logo212.png',
          height: isShort ? 36 : 40,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'SRHU',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: isShort ? 18 : 21,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryBlue,
                        letterSpacing: -0.3,
                      ),
                    ),
                    TextSpan(
                      text: ' STW',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: isShort ? 18 : 21,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryNavy,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Based on ICMR / DHR Standard Treatment Workflows',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.mutedText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 2. Hero Section with soft wavy bottom, headline, and softly fading newborn photo
  Widget _buildHeroSection({
    required bool isShort,
    required bool isVeryShort,
  }) {
    return ClipPath(
      clipper: _HeroWaveClipper(),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEAF2FF),
              Color(0xFFF7FAFF),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.dividerColor, width: 1.0),
        ),
        padding: EdgeInsets.fromLTRB(
          14,
          isVeryShort ? 8 : 12,
          10,
          isVeryShort ? 12 : 16,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: Headline and Subtitle
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Better Care for\nEvery New\nBeginning',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: isVeryShort ? 16 : (isShort ? 18 : 21),
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: AppTheme.primaryNavy,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  SizedBox(height: isVeryShort ? 3 : 5),
                  Text(
                    'Guidance from the ICMR / DHR Standard Treatment Workflows for newborn care.',
                    maxLines: isVeryShort ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: isVeryShort ? 10 : (isShort ? 11 : 12),
                      height: 1.3,
                      color: AppTheme.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right: hu.png with transparent background shown as is, aligned right & bottom
            Expanded(
              flex: 4,
              child: Align(
                alignment: Alignment.bottomRight,
                child: AnimatedBuilder(
                  animation: _breathingScale,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _breathingScale.value,
                      alignment: Alignment.bottomRight,
                      child: child,
                    );
                  },
                  child: Image.asset(
                    'assets/images/hu.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomRight,
                    cacheWidth: 450,
                    errorBuilder: (_, __, ___) => _buildHeroPlaceholder(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroPlaceholder() {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: AppTheme.tint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: Icon(
          Icons.health_and_safety_outlined,
          size: 24,
          color: AppTheme.primaryBlue,
        ),
      ),
    );
  }

  /// 3. Two Compact Horizontal Module Cards
  Widget _buildCardsRow({
    required bool isShort,
    required bool isVeryShort,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ModuleCardItem(
          primaryTitle: 'Respiratory Distress',
          subtitleTitle: 'in Neonates',
          description: 'Assessment and management workflow as per ICMR/DHR STW.',
          buttonText: 'Get Started →',
          buttonColor: AppTheme.primaryBlue,
          badgeIcon: Icons.air,
          badgeColor: AppTheme.primaryBlue,
          semanticsLabel: 'Open Respiratory Distress workflow',
          onTap: () => context.push('/rd'),
          isShort: isShort,
          isVeryShort: isVeryShort,
        ),
        SizedBox(height: isVeryShort ? 6 : (isShort ? 8 : 10)),
        _ModuleCardItem(
          primaryTitle: 'Retinopathy of Prematurity',
          subtitleTitle: '(ROP)',
          description: 'Screening and follow-up workflow as per ICMR/DHR STW.',
          buttonText: 'Get Started →',
          buttonColor: AppTheme.midBlue,
          badgeIcon: Icons.visibility_outlined,
          badgeColor: AppTheme.midBlue,
          semanticsLabel: 'Open Retinopathy of Prematurity workflow',
          onTap: () => context.push('/rop'),
          isShort: isShort,
          isVeryShort: isVeryShort,
        ),
      ],
    );
  }

  /// 4. Feature Row with 4 pastel circle icons (all White + Blue, icons 18 px in 34 px circles)
  Widget _buildFeatureRow() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _FeatureItem(
          icon: Icons.menu_book_rounded,
          title: 'Based on STW\nWorkflows',
        ),
        _FeatureItem(
          icon: Icons.verified_user_rounded,
          title: 'Guideline-\nAligned',
        ),
        _FeatureItem(
          icon: Icons.groups_rounded,
          title: 'For Medical\nStudents & Doctors',
        ),
        _FeatureItem(
          icon: Icons.assignment_rounded,
          title: 'Practical Clinical\nSupport',
        ),
      ],
    );
  }

  /// 5. Footer with handwriting motto and Disclaimer/References links
  Widget _buildFooter(BuildContext context, {required bool isShort}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        final estimatedContentWidth = (isShort ? 250.0 : 275.0) * textScale;
        final spacerWidth =
            math.max(8.0, constraints.maxWidth - estimatedContentWidth);

        return SizedBox(
          width: constraints.maxWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Left: Handwriting motto with blue heart ribbon doodle
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CustomPaint(
                        painter: _HeartRibbonPainter(),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Small Steps, Brighter Tomorrows',
                      style: TextStyle(
                        fontFamily: 'Caveat',
                        fontFamilyFallback: const ['cursive', 'Inter'],
                        fontStyle: FontStyle.italic,
                        fontSize: isShort ? 12 : 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: spacerWidth),

                // Right: Disclaimer and References links in primary blue
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Read STW disclaimer',
                      child: InkWell(
                        onTap: () => _showDisclaimerSheet(context),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          child: Text(
                            'Disclaimer',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Text(
                      ' · ',
                      style: TextStyle(color: AppTheme.mutedText, fontSize: 12),
                    ),
                    Semantics(
                      button: true,
                      label: 'Open References and source STW PDFs',
                      child: InkWell(
                        onTap: () => context.push('/references'),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          child: Text(
                            'References',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Feature item widget with rounded icon and 2-line title (max 34 px circle, 18 px icon)
class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppTheme.tint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primaryBlue, size: 18),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: AppTheme.bodyText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact horizontal module tile (76-88 px height) inspired by SRHU website cards.
class _ModuleCardItem extends StatefulWidget {
  const _ModuleCardItem({
    required this.primaryTitle,
    required this.subtitleTitle,
    required this.description,
    required this.buttonText,
    required this.buttonColor,
    required this.badgeIcon,
    required this.badgeColor,
    required this.semanticsLabel,
    required this.onTap,
    required this.isShort,
    required this.isVeryShort,
  });

  final String primaryTitle;
  final String subtitleTitle;
  final String description;
  final String buttonText;
  final Color buttonColor;
  final IconData badgeIcon;
  final Color badgeColor;
  final String semanticsLabel;
  final VoidCallback onTap;
  final bool isShort;
  final bool isVeryShort;

  @override
  State<_ModuleCardItem> createState() => _ModuleCardItemState();
}

class _ModuleCardItemState extends State<_ModuleCardItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final tileHeight =
        widget.isVeryShort ? 72.0 : (widget.isShort ? 78.0 : 86.0);
    final badgeSize = widget.isVeryShort ? 34.0 : 38.0;
    final iconSize = widget.isVeryShort ? 18.0 : 20.0;

    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.985 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            height: tileHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.dividerColor, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryNavy.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: widget.isVeryShort ? 6 : 8,
            ),
            child: Row(
              children: [
                // Small blue icon badge (36-38 px circle with 18-20 px icon)
                Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: const BoxDecoration(
                    color: AppTheme.tint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.badgeIcon,
                    color: widget.badgeColor,
                    size: iconSize,
                  ),
                ),
                const SizedBox(width: 12),

                // Title, description and "Get Started →" link
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.primaryTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: widget.isVeryShort
                                    ? 13.5
                                    : (widget.isShort ? 14.5 : 15.5),
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryNavy,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Small "Get Started →" (SRHU link style)
                          Text(
                            widget.buttonText,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: widget.isVeryShort ? 11.5 : 12.5,
                              fontWeight: FontWeight.w600,
                              color: widget.buttonColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: widget.isVeryShort ? 10.5 : 11.5,
                          color: AppTheme.mutedText,
                        ),
                      ),
                    ],
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

/// Custom clipper that draws a gentle soft wave along the bottom edge of the hero
class _HeroWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 12);
    path.quadraticBezierTo(
      size.width * 0.35,
      size.height,
      size.width * 0.7,
      size.height - 10,
    );
    path.quadraticBezierTo(
      size.width * 0.88,
      size.height - 16,
      size.width,
      size.height - 8,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}


/// Custom painter for the looping heart-ribbon doodle in the footer (blue only)
class _HeartRibbonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.8);
    path.cubicTo(
      size.width * 0.35,
      size.height * 0.1,
      size.width * 0.65,
      size.height * 0.1,
      size.width * 0.5,
      size.height * 0.55,
    );
    path.cubicTo(
      size.width * 0.35,
      size.height * 0.95,
      size.width * 0.85,
      size.height * 0.85,
      size.width * 0.95,
      size.height * 0.5,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for faint ambient curves at bottom (soft blue tints only, no pink)
class _BackgroundWavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final wave1 = Path();
    wave1.moveTo(0, h * 0.94);
    wave1.quadraticBezierTo(w * 0.3, h * 0.88, w * 0.65, h * 0.93);
    wave1.quadraticBezierTo(w * 0.85, h * 0.96, w, h * 0.91);
    wave1.lineTo(w, h);
    wave1.lineTo(0, h);
    wave1.close();

    final paint1 = Paint()
      ..color = const Color(0xFFE8F1FC).withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    canvas.drawPath(wave1, paint1);

    final wave2 = Path();
    wave2.moveTo(0, h * 0.97);
    wave2.quadraticBezierTo(w * 0.4, h * 0.93, w * 0.75, h * 0.97);
    wave2.quadraticBezierTo(w * 0.9, h * 0.98, w, h * 0.95);
    wave2.lineTo(w, h);
    wave2.lineTo(0, h);
    wave2.close();

    final paint2 = Paint()
      ..color = const Color(0xFFDCE6F5).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawPath(wave2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
