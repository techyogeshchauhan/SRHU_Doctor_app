import 'dart:io' show File;
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart'
    show
        GestureBinding,
        PointerScrollEvent,
        PointerSignalEvent,
        kDefaultMouseScrollToScaleFactor;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/widgets/app_branding.dart';
import '../../../core/widgets/app_refresh_button.dart';
import '../../../core/widgets/back_to_home_button.dart';
import 'pdf_web_helper.dart';

/// Debug flag that draws a red border at (0, 0, 1, 1) to verify
/// that the overlay matches the page edges exactly.
const bool kDebugHighlights = false;

/// Represents a specific region on a PDF page to be highlighted.
class HighlightTarget {
  final String document;
  final int page;
  final List<Rect> normalizedBboxes;
  final String? sectionTitle;
  final String? regionId;

  const HighlightTarget({
    required this.document,
    required this.page,
    required this.normalizedBboxes,
    this.sectionTitle,
    this.regionId,
  });
}

/// Full-screen in-app STW reference viewer.
///
/// Uses high-resolution pre-rendered page images (WebP) for pixel-perfect
/// alignment of search highlights across Web, PWA, Android, and iOS.
/// Retains the original PDF for downloading and external viewing.
class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({
    super.key,
    required this.assetPath,
    required this.title,
    this.customViewerBuilder,
    this.highlightTarget,
    this.debugHighlights = kDebugHighlights,
  });

  final String assetPath;
  final String title;

  /// Optional custom viewer builder used primarily for widget tests.
  final Widget Function(BuildContext context)? customViewerBuilder;

  /// Optional highlight target to visually accentuate a retrieved STW section.
  final HighlightTarget? highlightTarget;

  /// If true, draws a red border around the page edge to verify bounds.
  final bool debugHighlights;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TransformationController _transformController =
      TransformationController();

  bool _isSharing = false;
  bool _showBanner = true;
  bool _showHighlight = true;
  bool _hasAutoScrolled = false;

  /// Ctrl/⌘ held: the mouse wheel zooms instead of scrolling.
  bool _wheelZooms = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Canonical page aspect ratio for the ICMR STW documents:
  // Rendered at 1600 x 3105 px -> 1600 / 3105 ≈ 0.515298
  static const double kPageAspectRatio = 1600.0 / 3105.0;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.6)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.6, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
    ]).animate(_pulseController);

    if (widget.highlightTarget != null) {
      _pulseController.forward();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleAutoScroll();
      });
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _pulseController.dispose();
    _scrollController.dispose();
    _transformController.dispose();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  String _resolvePageImagePath() {
    final docName =
        widget.highlightTarget?.document ?? widget.assetPath.split('/').last;
    final pageNum = widget.highlightTarget?.page ?? 1;

    // Use pre-rendered WebP page image
    return 'assets/pages/$docName/$pageNum.webp';
  }

  void _scheduleAutoScroll({int delayMs = 150}) {
    if (!mounted || widget.highlightTarget == null) return;
    final bboxes = widget.highlightTarget!.normalizedBboxes;
    if (bboxes.isEmpty) return;

    Future.delayed(Duration(milliseconds: delayMs), () {
      if (!mounted || !_scrollController.hasClients) return;

      final targetBbox = bboxes.first;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final viewportHeight = _scrollController.position.viewportDimension;
      final totalRenderedHeight = maxScroll + viewportHeight;

      // Vertical center of target highlight in rendered pixel coordinates
      final targetCenterY =
          (targetBbox.top + targetBbox.height / 2.0) * totalRenderedHeight;
      final desiredOffset =
          (targetCenterY - viewportHeight / 2.0).clamp(0.0, maxScroll);

      _scrollController.animateTo(
        desiredOffset,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
      );
      _hasAutoScrolled = true;
    });
  }

  Future<void> _shareOrDownloadPdf() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final byteData = await rootBundle.load(widget.assetPath);
      final filename = widget.assetPath.split('/').last;

      if (kIsWeb) {
        openOrDownloadPdf(byteData.buffer.asUint8List(), filename);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloading $filename...'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

        await Share.shareXFiles(
          [
            XFile(
              file.path,
              mimeType: 'application/pdf',
              name: filename,
            ),
          ],
          text: widget.title,
          subject: widget.title,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open document: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: StwNeoBrand(subtitle: widget.title),
        actions: [
          if (widget.highlightTarget != null)
            IconButton(
              tooltip: _showHighlight ? 'Hide Highlight' : 'Show Highlight',
              icon: Icon(
                _showHighlight
                    ? Icons.highlight_rounded
                    : Icons.highlight_outlined,
                color:
                    _showHighlight ? const Color(0xFFF59E0B) : Colors.white70,
              ),
              onPressed: () {
                setState(() => _showHighlight = !_showHighlight);
              },
            ),
          const BackToHomeButton(compact: true),
          const AppRefreshButton(),
          const SizedBox(width: 4),
          Semantics(
            button: true,
            label: kIsWeb ? 'Download PDF' : 'Share PDF',
            child: IconButton(
              tooltip: kIsWeb ? 'Download PDF' : 'Share / Open PDF',
              icon: _isSharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      kIsWeb ? Icons.download_rounded : Icons.share_outlined),
              onPressed: _isSharing ? null : _shareOrDownloadPdf,
            ),
          ),
        ],
      ),
      body: widget.customViewerBuilder != null
          ? widget.customViewerBuilder!(context)
          : _buildImageViewer(),
    );
  }

  bool _onKey(KeyEvent _) {
    final keys = HardwareKeyboard.instance;
    final zooms = keys.isControlPressed || keys.isMetaPressed;
    if (zooms != _wheelZooms && mounted) setState(() => _wheelZooms = zooms);
    return false; // never consume the key
  }

  /// Mouse wheel scrolls the page up and down; Ctrl/⌘ + wheel zooms.
  ///
  /// [InteractiveViewer] zooms on every wheel event it sees (it does not use
  /// the pointer-signal resolver), so its wheel zoom is switched off via
  /// `scaleFactor` unless Ctrl/⌘ is held. This handler sits on the page,
  /// deepest in the tree, so it claims the event before the scroll view: a
  /// plain wheel scrolls; with Ctrl/⌘ it claims the event without scrolling
  /// so the page does not move while zooming.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (_wheelZooms) {
      GestureBinding.instance.pointerSignalResolver.register(event, (_) {});
      return;
    }
    if (!_scrollController.hasClients) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      if (!_scrollController.hasClients) return;
      // Same on-screen distance at any zoom level.
      final scale = _transformController.value.getMaxScaleOnAxis();
      final dy = (e as PointerScrollEvent).scrollDelta.dy / scale;
      if (dy != 0) _scrollController.position.pointerScroll(dy);
    });
  }

  Widget _buildImageViewer() {
    final imagePath = _resolvePageImagePath();

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        // On wide screens (e.g. desktop/web), cap max width to comfortable reading width
        final renderedWidth = math.min(screenWidth, 1000.0);
        final renderedHeight = renderedWidth / kPageAspectRatio;

        return Stack(
          children: [
            // Scrollable & zoomable page container
            InteractiveViewer(
              transformationController: _transformController,
              minScale: 1.0,
              maxScale: 3.5,
              panEnabled: true,
              scaleEnabled: true,
              // Wheel zoom only with Ctrl/⌘ (see _onPointerSignal); pinch
              // and trackpad zoom are unaffected.
              scaleFactor: _wheelZooms
                  ? kDefaultMouseScrollToScaleFactor
                  : double.infinity,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                // Mouse wheel scrolls the page; Ctrl/⌘ + wheel zooms.
                child: Listener(
                  onPointerSignal: _onPointerSignal,
                  child: Center(
                    child: Container(
                      width: renderedWidth,
                      height: renderedHeight,
                      color: Colors.white,
                      child: Stack(
                        children: [
                          // 1. Page image
                          Positioned.fill(
                            child: Image.asset(
                              imagePath,
                              fit: BoxFit.fill,
                              frameBuilder: (context, child, frame, wasSync) {
                                if (frame != null && !_hasAutoScrolled) {
                                  _scheduleAutoScroll(delayMs: 100);
                                }
                                return child;
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.broken_image_outlined,
                                          size: 48,
                                          color: Colors.redAccent,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Unable to load page image: $imagePath',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // 2. High-precision Highlight Overlay
                          if (widget.highlightTarget != null && _showHighlight)
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, _) {
                                  return CustomPaint(
                                    painter: _CuratedHighlightPainter(
                                      normalizedBboxes: widget
                                          .highlightTarget!.normalizedBboxes,
                                      pulseValue: _pulseAnimation.value,
                                      debugEdges: widget.debugHighlights,
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 3. Top Floating Clinical Banner
            if (widget.highlightTarget != null && _showBanner)
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFFFFBEB),
                  shadowColor: Colors.black38,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFF59E0B),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.highlight_alt_rounded,
                          color: Color(0xFFB45309),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.highlightTarget!.sectionTitle ??
                                    'Highlighted STW Section',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF78350F),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Page ${widget.highlightTarget!.page} • Tap icon above to toggle overlay',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Color(0xFFB45309),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Dismiss Banner (keeps highlight visible)',
                          onPressed: () {
                            // Dismiss only the floating banner; the highlight remains visible on the page
                            setState(() => _showBanner = false);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Custom painter for curated region highlights with pulse effect and debug edges.
class _CuratedHighlightPainter extends CustomPainter {
  final List<Rect> normalizedBboxes;
  final double pulseValue;
  final bool debugEdges;

  _CuratedHighlightPainter({
    required this.normalizedBboxes,
    required this.pulseValue,
    required this.debugEdges,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Debug flag: draw red border at (0,0,1,1) to verify overlay matches page edges
    if (debugEdges) {
      final debugPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        debugPaint,
      );
    }

    if (normalizedBboxes.isEmpty) return;

    // Style specifications:
    // Amber fill at 30-35% opacity
    final fillAlpha = (0.30 + (0.05 * pulseValue)).clamp(0.0, 1.0);
    final fillPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: fillAlpha)
      ..style = PaintingStyle.fill;

    // 2px solid border with rounded corners
    final borderPaint = Paint()
      ..color = const Color(0xFFD97706)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Small padding around the box (2.5 px scaled)
    const double padding = 2.5;

    for (final bbox in normalizedBboxes) {
      final left = (bbox.left * size.width) - padding;
      final top = (bbox.top * size.height) - padding;
      final width = (bbox.width * size.width) + (2 * padding);
      final height = (bbox.height * size.height) + (2 * padding);

      final rect = Rect.fromLTWH(
        left.clamp(0.0, size.width),
        top.clamp(0.0, size.height),
        width.clamp(0.0, size.width),
        height.clamp(0.0, size.height),
      );

      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
      canvas.drawRRect(rrect, fillPaint);
      canvas.drawRRect(rrect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CuratedHighlightPainter oldDelegate) =>
      oldDelegate.pulseValue != pulseValue ||
      oldDelegate.normalizedBboxes != normalizedBboxes ||
      oldDelegate.debugEdges != debugEdges;
}
