import 'package:flutter/material.dart';

import '../theme.dart';

/// Reusable header branding with the primary ICMR logo.
///
/// - Logo: ICMR logo (`assets/images/icmr_logo.png`); scales down rather than
///   overflowing when the available width is narrow (e.g. app bars with
///   several actions).
/// - Subtitle (optional): screen name or guideline note. With [stacked] it
///   sits under the logo (app bars), otherwise beside it (Home).
/// - Title (optional, landing page only): "STW" (Navy) + " Neo" (Primary Blue).
class StwNeoBrand extends StatelessWidget {
  const StwNeoBrand({
    super.key,
    this.subtitle,
    this.logoHeight = 36,
    this.titleSize = 16,
    this.subtitleSize = 11.5,
    this.subtitleMaxLines = 1,
    this.mainAxisSize = MainAxisSize.min,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.showLogo = true,
    this.showTitle = false,
    this.stacked = true,
  });

  final String? subtitle;
  final double logoHeight;
  final double titleSize;
  final double subtitleSize;
  final int subtitleMaxLines;
  final MainAxisSize mainAxisSize;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  /// False where the ICMR logo is already shown nearby (landing page).
  final bool showLogo;

  /// The "STW Neo" wordmark; shown on the landing page only.
  final bool showTitle;

  /// Subtitle under the logo (true) or beside it (false).
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      'assets/images/icmr_logo.png',
      semanticLabel: 'ICMR Logo',
      height: logoHeight,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );

    final sub = subtitle == null
        ? null
        : Text(
            subtitle!,
            maxLines: subtitleMaxLines,
            overflow: TextOverflow.ellipsis,
            style: showTitle
                ? TextStyle(
                    fontFamily: 'Inter',
                    fontSize: subtitleSize,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.mutedText,
                    height: 1.15,
                  )
                : TextStyle(
                    fontFamily: 'Inter',
                    fontSize: subtitleSize,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryNavy,
                    height: 1.15,
                  ),
          );

    if (showLogo && stacked && !showTitle) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          logo,
          if (sub != null) ...[const SizedBox(height: 1), sub],
        ],
      );
    }

    final text = <Widget>[
      if (showTitle)
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
      if (sub != null) sub,
    ];

    return Row(
      mainAxisSize: mainAxisSize,
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        if (showLogo) Flexible(child: logo),
        if (showLogo && text.isNotEmpty) const SizedBox(width: 10),
        if (text.isNotEmpty)
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: text,
            ),
          ),
      ],
    );
  }
}
