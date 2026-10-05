import 'package:flutter/material.dart';

import '../theme.dart';

/// Standard, reusable application branding widget for STW Neo with the primary ICMR logo.
///
/// Ensures consistent logo placement, sizing, typography, and visual identity across all screens:
/// - Leading: ICMR logo (`assets/images/icmr_logo.png`)
/// - Title: "STW" (Navy) + " Neo" (Primary Blue)
/// - Subtitle (optional): context-specific subtitle or guideline note
class StwNeoBrand extends StatelessWidget {
  const StwNeoBrand({
    super.key,
    this.subtitle,
    this.logoHeight = 26,
    this.titleSize = 16,
    this.subtitleSize = 10.5,
    this.subtitleMaxLines = 1,
    this.mainAxisSize = MainAxisSize.min,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final String? subtitle;
  final double logoHeight;
  final double titleSize;
  final double subtitleSize;
  final int subtitleMaxLines;
  final MainAxisSize mainAxisSize;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: mainAxisSize,
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Image.asset(
          'assets/images/icmr_logo.png',
          semanticLabel: 'STW Neo ICMR Logo',
          height: logoHeight,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'STW',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryNavy,
                          letterSpacing: -0.3,
                        ),
                      ),
                      TextSpan(
                        text: ' Neo',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryBlue,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (subtitle != null) ...[
                  Text(
                    subtitle!,
                    maxLines: subtitleMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: subtitleSize,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.mutedText,
                      height: 1.15,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
  }
}
