import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

/// Reusable "Back to Home" button that navigates the user directly back
/// to the main condition-selection screen (/home) where the 14 conditions
/// list is displayed.
class BackToHomeButton extends StatelessWidget {
  const BackToHomeButton({
    super.key,
    this.compact = false,
    this.iconOnly = false,
  });

  /// In compact mode (e.g. app bar actions on phone), displays 'Home'
  /// instead of the full 'Back to Home' label.
  final bool compact;

  /// If true, renders an icon-only button without text label.
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      return Semantics(
        button: true,
        label: 'Back to Home',
        child: IconButton(
          tooltip: 'Home',
          icon: const Icon(
            Icons.home_rounded,
            size: 22,
            color: AppTheme.primaryNavy,
          ),
          onPressed: () => context.go('/home'),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Back to Home',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: TextButton.icon(
          style: TextButton.styleFrom(
            backgroundColor: AppTheme.tint,
            foregroundColor: AppTheme.primaryNavy,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: 6,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFD4E3F8), width: 1.2),
            ),
          ),
          onPressed: () => context.go('/home'),
          icon: const Icon(
            Icons.home_rounded,
            size: 17,
            color: AppTheme.primaryBlue,
          ),
          label: Text(
            compact ? 'Home' : 'Back to Home',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryNavy,
            ),
          ),
        ),
      ),
    );
  }
}
