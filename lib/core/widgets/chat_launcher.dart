import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

/// Floating "STW Clinical Assistant" button shown above every screen.
///
/// Sits in `MaterialApp.router`'s builder, so it is outside the pages: it
/// navigates with [router] directly and hides itself on the chat screen and
/// while the keyboard is open (so it never covers a text field). It can be
/// dragged anywhere and snaps to the nearer side, in case it covers a
/// screen's own buttons.
class ChatLauncher extends StatefulWidget {
  const ChatLauncher({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  /// Paths where the button is not shown.
  static const hiddenOn = {'/chat'};

  static const size = 56.0;

  @override
  State<ChatLauncher> createState() => _ChatLauncherState();
}

class _ChatLauncherState extends State<ChatLauncher> {
  /// Distance from the right (or left, when [_left]) and bottom edges.
  /// The default clears the action bars at the bottom of most screens.
  double _bottom = 96;
  var _left = false;
  double? _dragX;

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_onRoute);
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  /// The router can notify while a frame is being built; refresh after it.
  void _onRoute() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });

  /// Path of the page on top, including pages opened with `push`.
  String get _path {
    try {
      final config = widget.router.routerDelegate.currentConfiguration;
      final last = config.isEmpty ? null : config.last;
      return (last is ImperativeRouteMatch ? last.matches : config).uri.path;
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final visible =
        !ChatLauncher.hiddenOn.contains(_path) && mq.viewInsets.bottom == 0;
    const margin = 16.0;
    final maxBottom =
        mq.size.height - mq.padding.top - ChatLauncher.size - margin;
    final bottom = _bottom.clamp(margin + mq.padding.bottom, maxBottom);
    final x =
        _dragX ?? (_left ? margin : mq.size.width - ChatLauncher.size - margin);

    return Stack(
      children: [
        widget.child,
        if (visible)
          Positioned(
            left: x,
            bottom: bottom,
            child: GestureDetector(
              onPanStart: (_) => setState(() => _dragX = x),
              onPanUpdate: (d) => setState(() {
                _dragX = (_dragX! + d.delta.dx).clamp(
                  0.0,
                  mq.size.width - ChatLauncher.size,
                );
                _bottom = (bottom - d.delta.dy).toDouble();
              }),
              onPanEnd: (_) => setState(() {
                _left = (_dragX! + ChatLauncher.size / 2) < mq.size.width / 2;
                _dragX = null;
              }),
              child: Semantics(
                button: true,
                label: 'Open STW Clinical Assistant',
                excludeSemantics: true,
                child: Material(
                  color: AppTheme.primaryNavy,
                  elevation: 6,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const Key('chat-launcher'),
                    onTap: () => widget.router.push('/chat'),
                    child: const SizedBox.square(
                      dimension: ChatLauncher.size,
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
