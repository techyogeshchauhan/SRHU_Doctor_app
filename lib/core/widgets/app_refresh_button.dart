import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/app_reload.dart';

/// Small, clean, and unobtrusive Refresh button for the corner of the application.
/// Available on Web and when installed as a PWA.
class AppRefreshButton extends StatefulWidget {
  const AppRefreshButton({
    super.key,
    this.size = 34.0,
    this.iconSize = 17.0,
    this.tooltip = 'Refresh application',
    this.onRefresh,
  });

  final double size;
  final double iconSize;
  final String tooltip;
  final VoidCallback? onRefresh;

  @override
  State<AppRefreshButton> createState() => _AppRefreshButtonState();
}

class _AppRefreshButtonState extends State<AppRefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  bool _isRefreshing = false;

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await _animCtrl.forward(from: 0.0);

    if (widget.onRefresh != null) {
      widget.onRefresh!();
    } else {
      reloadApplication();
    }

    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleRefresh,
            borderRadius: BorderRadius.circular(widget.size / 2),
            splashColor: const Color(0x1F1F5FBF),
            highlightColor: const Color(0x0F1F5FBF),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xEBFFFFFF),
                border: Border.all(
                  color: const Color(0xFFD4E3F8),
                  width: 1.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C0B2A5B),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: RotationTransition(
                turns: _animCtrl,
                child: Icon(
                  Icons.refresh_rounded,
                  size: widget.iconSize,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
