import 'package:flutter/material.dart';

import 'responsive.dart';

/// Extension methods for responsive design
extension ResponsiveContext on BuildContext {
  /// Get the current screen width
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Get the current screen height
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Check if current screen is mobile
  bool get isMobile => screenWidth < Breakpoints.tablet;

  /// Check if current screen is mobile in landscape
  bool get isMobileLandscape =>
      screenWidth >= Breakpoints.mobileLandscape &&
      screenWidth < Breakpoints.tablet;

  /// Check if current screen is tablet
  bool get isTablet =>
      screenWidth >= Breakpoints.tablet && screenWidth < Breakpoints.desktop;

  /// Check if current screen is desktop
  bool get isDesktop => screenWidth >= Breakpoints.desktop;

  /// Check if current screen is large desktop
  bool get isDesktopLarge => screenWidth >= Breakpoints.desktopLarge;

  /// Get responsive padding value
  double get responsivePadding {
    if (isMobile) return 16.0;
    if (isTablet) return 24.0;
    return 32.0;
  }

  /// Get responsive spacing value
  double get responsiveSpacing {
    if (isMobile) return 12.0;
    if (isTablet) return 16.0;
    return 20.0;
  }

  /// Get responsive font size multiplier
  double get fontSizeMultiplier {
    if (isMobile && screenWidth < Breakpoints.mobileLandscape) return 0.9;
    if (isDesktopLarge) return 1.1;
    return 1.0;
  }

  /// Get responsive value based on screen size
  T responsiveValue<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop && desktop != null) return desktop;
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }
}

/// Helper widget for responsive text that scales appropriately
class ResponsiveText extends StatelessWidget {
  const ResponsiveText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.mobileFontSize,
    this.tabletFontSize,
    this.desktopFontSize,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final double? mobileFontSize;
  final double? tabletFontSize;
  final double? desktopFontSize;

  @override
  Widget build(BuildContext context) {
    double? fontSize;

    if (mobileFontSize != null || tabletFontSize != null || desktopFontSize != null) {
      if (context.isDesktop && desktopFontSize != null) {
        fontSize = desktopFontSize;
      } else if (context.isTablet && tabletFontSize != null) {
        fontSize = tabletFontSize;
      } else if (mobileFontSize != null) {
        fontSize = mobileFontSize;
      }
    }

    return Text(
      text,
      style: style?.copyWith(fontSize: fontSize) ??
          TextStyle(fontSize: fontSize),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Helper widget for responsive sizing
class ResponsiveSize extends StatelessWidget {
  const ResponsiveSize({
    super.key,
    required this.child,
    this.mobileWidth,
    this.tabletWidth,
    this.desktopWidth,
    this.mobileHeight,
    this.tabletHeight,
    this.desktopHeight,
  });

  final Widget child;
  final double? mobileWidth;
  final double? tabletWidth;
  final double? desktopWidth;
  final double? mobileHeight;
  final double? tabletHeight;
  final double? desktopHeight;

  @override
  Widget build(BuildContext context) {
    double? width;
    double? height;

    if (context.isDesktop) {
      width = desktopWidth;
      height = desktopHeight;
    } else if (context.isTablet) {
      width = tabletWidth ?? mobileWidth;
      height = tabletHeight ?? mobileHeight;
    } else {
      width = mobileWidth;
      height = mobileHeight;
    }

    return SizedBox(
      width: width,
      height: height,
      child: child,
    );
  }
}

/// Responsive container with adaptive constraints
class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.mobileConstraints,
    this.tabletConstraints,
    this.desktopConstraints,
    this.padding,
    this.margin,
    this.decoration,
  });

  final Widget child;
  final BoxConstraints? mobileConstraints;
  final BoxConstraints? tabletConstraints;
  final BoxConstraints? desktopConstraints;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Decoration? decoration;

  @override
  Widget build(BuildContext context) {
    BoxConstraints? constraints;

    if (context.isDesktop && desktopConstraints != null) {
      constraints = desktopConstraints;
    } else if (context.isTablet && tabletConstraints != null) {
      constraints = tabletConstraints;
    } else {
      constraints = mobileConstraints;
    }

    return Container(
      constraints: constraints,
      padding: padding,
      margin: margin,
      decoration: decoration,
      child: child,
    );
  }
}

/// Responsive card that adapts its size and padding
class ResponsiveCard extends StatelessWidget {
  const ResponsiveCard({
    super.key,
    required this.child,
    this.mobilePadding = const EdgeInsets.all(12),
    this.tabletPadding = const EdgeInsets.all(16),
    this.desktopPadding = const EdgeInsets.all(20),
    this.margin,
    this.elevation,
    this.shape,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry mobilePadding;
  final EdgeInsetsGeometry tabletPadding;
  final EdgeInsetsGeometry desktopPadding;
  final EdgeInsetsGeometry? margin;
  final double? elevation;
  final ShapeBorder? shape;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    EdgeInsetsGeometry padding;

    if (context.isDesktop) {
      padding = desktopPadding;
    } else if (context.isTablet) {
      padding = tabletPadding;
    } else {
      padding = mobilePadding;
    }

    return Card(
      margin: margin,
      elevation: elevation,
      shape: shape,
      color: color,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Layout builder with named breakpoint callbacks
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final Widget Function(BuildContext context) mobile;
  final Widget Function(BuildContext context)? tablet;
  final Widget Function(BuildContext context)? desktop;

  @override
  Widget build(BuildContext context) {
    if (context.isDesktop && desktop != null) {
      return desktop!(context);
    } else if (context.isTablet && tablet != null) {
      return tablet!(context);
    }
    return mobile(context);
  }
}

/// Responsive row/column that switches based on screen size
class ResponsiveRowColumn extends StatelessWidget {
  const ResponsiveRowColumn({
    super.key,
    required this.children,
    this.breakpoint = Breakpoints.tablet,
    this.rowMainAxisAlignment = MainAxisAlignment.start,
    this.rowCrossAxisAlignment = CrossAxisAlignment.center,
    this.columnMainAxisAlignment = MainAxisAlignment.start,
    this.columnCrossAxisAlignment = CrossAxisAlignment.stretch,
    this.spacing = 8.0,
  });

  final List<Widget> children;
  final double breakpoint;
  final MainAxisAlignment rowMainAxisAlignment;
  final CrossAxisAlignment rowCrossAxisAlignment;
  final MainAxisAlignment columnMainAxisAlignment;
  final CrossAxisAlignment columnCrossAxisAlignment;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width >= breakpoint) {
      // Show as Row
      return Row(
        mainAxisAlignment: rowMainAxisAlignment,
        crossAxisAlignment: rowCrossAxisAlignment,
        children: _addSpacing(children, isRow: true),
      );
    } else {
      // Show as Column
      return Column(
        mainAxisAlignment: columnMainAxisAlignment,
        crossAxisAlignment: columnCrossAxisAlignment,
        children: _addSpacing(children, isRow: false),
      );
    }
  }

  List<Widget> _addSpacing(List<Widget> children, {required bool isRow}) {
    if (children.isEmpty) return children;

    final result = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(SizedBox(
          width: isRow ? spacing : 0,
          height: isRow ? 0 : spacing,
        ));
      }
    }
    return result;
  }
}
