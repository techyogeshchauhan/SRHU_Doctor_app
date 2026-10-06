import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Layout breakpoints shared by every screen (logical pixels).
abstract final class Breakpoints {
  /// Mobile portrait (phones)
  static const double mobile = 320;
  
  /// Mobile landscape / small tablets
  static const double mobileLandscape = 576;
  
  /// Tablets portrait
  static const double tablet = 768;
  
  /// Tablets landscape / small desktop
  static const double tabletLandscape = 992;
  
  /// Desktop
  static const double desktop = 1200;
  
  /// Large desktop
  static const double desktopLarge = 1400;

  /// Widest the whole app gets. Wider windows (desktop browsers, iPad
  /// landscape) show it as a centred column.
  static const double shellMaxWidth = 1024;

  /// Forms, lists and summaries.
  static const double contentMaxWidth = 820;

  /// Phone-proportioned single-column screens (Landing, Home).
  static const double phoneMaxWidth = 560;
  
  /// Helper methods for responsive checks
  static bool isMobile(double width) => width < tablet;
  static bool isTablet(double width) => width >= tablet && width < desktop;
  static bool isDesktop(double width) => width >= desktop;
  static bool isMobileLandscape(double width) => 
      width >= mobileLandscape && width < tablet;
}

/// Centres the app in a [Breakpoints.shellMaxWidth] column on wide windows
/// so phone/tablet layouts keep their proportions on desktop. The
/// [MediaQuery] size is narrowed to match, so every width-based layout
/// decision below sees the column width, not the window width.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  /// Extra room before the frame appears, so tablets at ~1024 px stay
  /// full-bleed.
  static const double _frameThreshold = Breakpoints.shellMaxWidth + 80;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width <= _frameThreshold) return child;
    return ColoredBox(
      color: const Color(0xFFE6EDF7),
      child: Center(
        child: Container(
          width: Breakpoints.shellMaxWidth,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x1A0B2A5B),
                blurRadius: 32,
                spreadRadius: 2,
              ),
            ],
          ),
          child: MediaQuery(
            data: mq.copyWith(
              size: Size(Breakpoints.shellMaxWidth, mq.size.height),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Phone-proportioned column for single-screen layouts: at most [maxWidth]
/// wide and [maxHeight] tall, centred. When the viewport is shorter than
/// [minHeight] (a phone in landscape, a small browser window) the content
/// is laid out at [minHeight] and scrolls instead of overflowing.
class PhoneColumn extends StatelessWidget {
  const PhoneColumn({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.phoneMaxWidth,
    this.maxHeight = 940,
    this.minHeight = 560,
  });

  final Widget child;
  final double maxWidth;
  final double maxHeight;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = math.min(c.maxWidth, maxWidth);
        if (c.maxHeight < minHeight) {
          return SingleChildScrollView(
            child: Center(
              child: SizedBox(width: width, height: minHeight, child: child),
            ),
          );
        }
        return Center(
          child: SizedBox(
            width: width,
            height: math.min(c.maxHeight, maxHeight),
            child: child,
          ),
        );
      },
    );
  }
}

/// Centres [child] and limits it to [maxWidth] — used for bottom action
/// bars so buttons line up with the page content on wide screens.
class MaxWidth extends StatelessWidget {
  const MaxWidth({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.contentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}

/// Responsive padding that adapts to screen size
class ResponsivePadding extends StatelessWidget {
  const ResponsivePadding({
    super.key,
    required this.child,
    this.mobile = 16.0,
    this.tablet = 24.0,
    this.desktop = 32.0,
  });

  final Widget child;
  final double mobile;
  final double tablet;
  final double desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double padding;
        if (constraints.maxWidth < Breakpoints.tablet) {
          padding = mobile;
        } else if (constraints.maxWidth < Breakpoints.desktop) {
          padding = tablet;
        } else {
          padding = desktop;
        }
        
        return Padding(
          padding: EdgeInsets.all(padding),
          child: child,
        );
      },
    );
  }
}

/// Responsive spacing that adapts to screen size
class ResponsiveSpacing extends StatelessWidget {
  const ResponsiveSpacing({
    super.key,
    this.mobile = 8.0,
    this.tablet = 12.0,
    this.desktop = 16.0,
  });

  final double mobile;
  final double tablet;
  final double desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double spacing;
        if (constraints.maxWidth < Breakpoints.tablet) {
          spacing = mobile;
        } else if (constraints.maxWidth < Breakpoints.desktop) {
          spacing = tablet;
        } else {
          spacing = desktop;
        }
        
        return SizedBox(height: spacing, width: spacing);
      },
    );
  }
}

/// Helper to get responsive values based on screen size
class ResponsiveValue<T> {
  const ResponsiveValue({
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final T mobile;
  final T? tablet;
  final T? desktop;

  T getValue(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    
    if (width >= Breakpoints.desktop && desktop != null) {
      return desktop!;
    } else if (width >= Breakpoints.tablet && tablet != null) {
      return tablet!;
    }
    return mobile;
  }
}

/// Responsive grid that adapts columns based on screen size
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.spacing = 16.0,
  });

  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns;
        if (constraints.maxWidth < Breakpoints.tablet) {
          columns = mobileColumns;
        } else if (constraints.maxWidth < Breakpoints.desktop) {
          columns = tabletColumns;
        } else {
          columns = desktopColumns;
        }

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children.map((child) {
            final width = (constraints.maxWidth - (spacing * (columns - 1))) / columns;
            return SizedBox(
              width: width,
              child: child,
            );
          }).toList(),
        );
      },
    );
  }
}
