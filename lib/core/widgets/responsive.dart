import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Layout breakpoints shared by every screen (logical pixels).
abstract final class Breakpoints {
  /// Widest the whole app gets. Wider windows (desktop browsers, iPad
  /// landscape) show it as a centred column.
  static const double shellMaxWidth = 1024;

  /// Forms, lists and summaries.
  static const double contentMaxWidth = 820;

  /// Phone-proportioned single-column screens (Landing, Home).
  static const double phoneMaxWidth = 560;
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
