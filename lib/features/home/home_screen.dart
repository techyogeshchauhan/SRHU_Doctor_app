import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../content/stw_content.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_branding.dart';

/// Redesigned Home Screen matching the clean White + Blue SRHU-inspired aesthetic.
///
/// Features:
/// - Pinned top-left free SRHU logo & "SRHU STW" branding
/// - Hero section with 25% larger hu.png, 20 px rounded corners & soft left fade
/// - Vertical service cards with full titles and 50 px "Get Started →" buttons
/// - Direct "View source PDF →" links on cards
/// - 3-item feature row on taller screens
/// - Footer with Disclaimer bottom sheet and References link
/// - Back button exits the app (does not return to Landing)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

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
    curve: const Interval(0.15, 0.7, curve: Curves.easeOut),
  );

  late final Animation<Offset> _cardsSlide = Tween<Offset>(
    begin: const Offset(0.0, 0.05),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _entranceCtrl,
    curve: const Interval(0.15, 0.7, curve: Curves.easeOutCubic),
  ));

  late final Animation<double> _footerFade = CurvedAnimation(
    parent: _entranceCtrl,
    curve: const Interval(0.35, 0.95, curve: Curves.easeOut),
  );

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
    precacheImage(
      const AssetImage('assets/images/icmr_logo.png'),
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Background subtle gradient
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

            // Adaptive layout without scroll
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final height = constraints.maxHeight;
                  final isShort = height < 680;
                  final isVeryShort = height < 580;
                  final showFeatureRow = height >= 760;

                  // Hero height: grows up to ~38% of screen height, shrinking on small heights
                  final maxHeroHeight = isVeryShort
                      ? 118.0
                      : (isShort
                          ? 155.0
                          : (height * 0.38).clamp(180.0, 260.0));

                  final gapHeroToCards =
                      isVeryShort ? 12.0 : (isShort ? 16.0 : 18.0);
                  final gapCardsToFooter =
                      isVeryShort ? 12.0 : (isShort ? 16.0 : 20.0);

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: isVeryShort ? 4 : (isShort ? 6 : 8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Top Brand Row (pinned top-left inside SafeArea, logo free)
                        _buildBrandRow(isShort: isShort),
                        SizedBox(height: isVeryShort ? 4 : (isShort ? 6 : 8)),

                        // 2. Hero Section (increased hu.png by ~20-25%, 20 px rounded corners, soft left fade)
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
                        SizedBox(height: gapHeroToCards),

                        // 3. Two Vertical Module Cards (sit directly below hero with fixed 16-20 px spacing)
                        FadeTransition(
                          opacity: _cardsFade,
                          child: SlideTransition(
                            position: _cardsSlide,
                            child: _buildCardsColumn(
                              isShort: isShort,
                              isVeryShort: isVeryShort,
                            ),
                          ),
                        ),

                        // 4. Feature Row (3 items, shown on tall screens >= 760 px)
                        if (showFeatureRow) ...[
                          SizedBox(height: isShort ? 8 : 12),
                          FadeTransition(
                            opacity: _footerFade,
                            child: _buildFeatureRow(),
                          ),
                        ],

                        SizedBox(height: gapCardsToFooter),

                        // 5. Footer with Disclaimer and References links
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
      ),
    );
  }

  /// 1. Top Brand Row with primary ICMR logo and "STW Neo" branding
  Widget _buildBrandRow({required bool isShort}) {
    return StwNeoBrand(
      logoHeight: isShort ? 32 : 38,
      titleSize: isShort ? 18 : 21,
      subtitleSize: 11,
      subtitleMaxLines: 2,
      subtitle: 'Based on ICMR / DHR Standard Treatment Workflows',
      mainAxisSize: MainAxisSize.max,
    );
  }

  /// 2. Hero Section with 25% larger hu.png, 20 px rounded corners and soft fade on left edge
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
          isVeryShort ? 6 : (isShort ? 8 : 10),
          10,
          isVeryShort ? 10 : (isShort ? 12 : 14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: Headline and fully visible subtitle (never truncated)
            Expanded(
              flex: isVeryShort ? 5 : 5,
              child: LayoutBuilder(
                builder: (context, colConstraints) {
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: colConstraints.maxWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Better Care for\nEvery New\nBeginning',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: isVeryShort ? 14.5 : (isShort ? 16.5 : 19.0),
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                              color: AppTheme.primaryNavy,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: isVeryShort ? 3 : 5),
                          Text(
                            'Guidance from the ICMR / DHR Standard Treatment Workflows for newborn care, right at your fingertips.',
                            maxLines: 4,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: isVeryShort ? 10.5 : (isShort ? 11.5 : 12.0),
                              height: 1.25,
                              color: AppTheme.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),

            // Right: hu.png increased by ~20-25%, 20 px rounded corners, soft fade on left edge
            Expanded(
              flex: isVeryShort ? 5 : 8,
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
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Colors.black,
                          Colors.black,
                        ],
                        stops: [0.0, 0.16, 1.0],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/hu.png',
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomRight,
                        cacheWidth: 600,
                        errorBuilder: (_, __, ___) => _buildHeroPlaceholder(),
                      ),
                    ),
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

  /// 3. Two Vertical Module Cards with full service titles and 50 px Get Started buttons
  Widget _buildCardsColumn({
    required bool isShort,
    required bool isVeryShort,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ModuleVerticalCard(
          title: 'Respiratory Distress in Neonates',
          description: 'Assessment and management workflow as per ICMR/DHR STW.',
          badgeIcon: Icons.air,
          buttonColor: AppTheme.primaryBlue,
          pdfPath: 'assets/pdfs/respiratory_distress_neonates_stw.pdf',
          onTap: () => context.push('/rd'),
          isShort: isShort,
          isVeryShort: isVeryShort,
        ),
        SizedBox(height: isVeryShort ? 8 : 12),
        _ModuleVerticalCard(
          title: 'Retinopathy of Prematurity (ROP)',
          description: 'Screening and follow-up workflow as per ICMR/DHR STW.',
          badgeIcon: Icons.visibility_outlined,
          buttonColor: AppTheme.midBlue,
          pdfPath: 'assets/pdfs/retinopathy_of_prematurity_stw.pdf',
          onTap: () => context.push('/rop'),
          isShort: isShort,
          isVeryShort: isVeryShort,
        ),
      ],
    );
  }

  /// 4. Feature Row with 3 trust items (shortened from 4, max 2 lines, never truncated)
  Widget _buildFeatureRow() {
    return const Row(
      children: [
        Expanded(
          child: _FeatureItem(
            icon: Icons.menu_book_rounded,
            title: 'Based on STW\nWorkflows',
          ),
        ),
        Expanded(
          child: _FeatureItem(
            icon: Icons.verified_user_rounded,
            title: 'Guideline-\nAligned',
          ),
        ),
        Expanded(
          child: _FeatureItem(
            icon: Icons.groups_rounded,
            title: 'For Medical\nStudents & Doctors',
          ),
        ),
      ],
    );
  }

  /// 5. Footer with handwriting motto, Disclaimer and References links
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

                // Right: Disclaimer and References links
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
                      '•',
                      style: TextStyle(
                        color: AppTheme.dividerColor,
                        fontSize: 12,
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Open STW references and original PDFs',
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

/// Restructured Vertical Module Card
class _ModuleVerticalCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData badgeIcon;
  final Color buttonColor;
  final String pdfPath;
  final VoidCallback onTap;
  final bool isShort;
  final bool isVeryShort;

  const _ModuleVerticalCard({
    required this.title,
    required this.description,
    required this.badgeIcon,
    required this.buttonColor,
    required this.pdfPath,
    required this.onTap,
    required this.isShort,
    required this.isVeryShort,
  });

  @override
  State<_ModuleVerticalCard> createState() => _ModuleVerticalCardState();
}

class _ModuleVerticalCardState extends State<_ModuleVerticalCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.title,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? widget.buttonColor.withValues(alpha: 0.5)
                  : AppTheme.dividerColor,
              width: _isHovered ? 1.4 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.buttonColor.withValues(
                  alpha: _isHovered ? 0.08 : 0.03,
                ),
                blurRadius: _isHovered ? 12 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  widget.isVeryShort ? 8 : (widget.isShort ? 10 : 12),
                  12,
                  widget.isVeryShort ? 8 : (widget.isShort ? 9 : 10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Small icon badge (36-40 px) + full title (wrapped, never truncated)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: widget.isVeryShort ? 34 : 38,
                          height: widget.isVeryShort ? 34 : 38,
                          decoration: BoxDecoration(
                            color: widget.buttonColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            widget.badgeIcon,
                            color: widget.buttonColor,
                            size: widget.isVeryShort ? 18 : 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 2,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: widget.isVeryShort ? 13.5 : (widget.isShort ? 14.5 : 15.5),
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryNavy,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: widget.isVeryShort ? 3 : 5),

                    // Row 2: Description (Inter 12-13 sp, up to 2 lines, no cut words)
                    Text(
                      widget.description,
                      maxLines: 2,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: widget.isVeryShort ? 11 : 12,
                        height: 1.3,
                        color: AppTheme.mutedText,
                      ),
                    ),
                    SizedBox(height: widget.isVeryShort ? 6 : (widget.isShort ? 8 : 10)),

                    // Row 3: Full-width "Get Started →" filled button (min height 50 px, 48 on ultra-compact)
                    SizedBox(
                      width: double.infinity,
                      height: widget.isVeryShort ? 48 : 50,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: widget.buttonColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: widget.onTap,
                        child: Text(
                          'Get Started →',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: widget.isVeryShort ? 13.5 : 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),

                    // Small "View source PDF →" text link under button
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          InkWell(
                            onTap: () => context.push(
                              '/pdf-viewer',
                              extra: {
                                'path': widget.pdfPath,
                                'title': widget.title,
                              },
                            ),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              child: Text(
                                'View source PDF →',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: widget.buttonColor,
                                ),
                              ),
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
        ),
      ),
    );
  }
}

/// Feature item widget with 34 px icon circle and max 2 lines caption (never truncated)
class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const _FeatureItem({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: Color(0xFFF0F5FD),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: AppTheme.mutedText,
              height: 1.15,
            ),
          ),
        ),
      ],
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

/// Custom painter for faint ambient curves at bottom (soft blue tints only)
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

/// About Screen retained for /about route compatibility
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const StwNeoBrand(subtitle: 'About'),
      ),
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
            'STW Neo: Neonatal STW Decision Support',
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
