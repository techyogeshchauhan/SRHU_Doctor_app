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

  /// "Ping" around the highlight when the page opens (three pulses).
  late final AnimationController _pulseController;

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
      duration: const Duration(milliseconds: 900),
    );

    if (widget.highlightTarget != null) {
      _pulseController.repeat(count: 3);
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
                    _showHighlight ? const Color(0xFFEF4444) : Colors.white70,
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
                                animation: _pulseController,
                                builder: (context, _) {
                                  return CustomPaint(
                                    painter: _CuratedHighlightPainter(
                                      normalizedBboxes: widget
                                          .highlightTarget!.normalizedBboxes,
                                      ping: _pulseController.isAnimating
                                          ? _pulseController.value
                                          : null,
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
                  color: const Color(0xFFFEF2F2),
                  shadowColor: Colors.black38,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFDC2626),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.highlight_alt_rounded,
                          color: Color(0xFFDC2626),
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
                                  color: Color(0xFF7F1D1D),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Page ${widget.highlightTarget!.page} • Highlighted in red • Tap icon above to toggle',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF991B1B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Color(0xFFDC2626),
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

/// Marks the referenced STW box: the rest of the page is dimmed and the box
/// is framed by a red rectangle with a white edge, so it shows on any
/// background. [ping] (0–1) draws an expanding frame while the page opens.
class _CuratedHighlightPainter extends CustomPainter {
  final List<Rect> normalizedBboxes;
  final double? ping;
  final bool debugEdges;

  _CuratedHighlightPainter({
    required this.normalizedBboxes,
    required this.ping,
    required this.debugEdges,
  });

  static const _red = Color(0xFFDC2626);

  /// Red rectangle just outside [box] (page pixels), kept on the page so
  /// all four sides stay visible for boxes at the page edge.
  static RRect _frame(Rect box, Size page, double stroke) {
    final edge = stroke / 2 + 2;
    final r = box.inflate(stroke + 3);
    return RRect.fromRectAndRadius(
      Rect.fromLTRB(
        math.max(r.left, edge),
        math.max(r.top, edge),
        math.min(r.right, page.width - edge),
        math.min(r.bottom, page.height - edge),
      ),
      const Radius.circular(3),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Debug flag: red border at (0,0,1,1) to verify the overlay matches the
    // page edges.
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

    final stroke = (size.width * 0.007).clamp(3.0, 7.0);
    final frames = [
      for (final b in normalizedBboxes)
        _frame(
          Rect.fromLTWH(
            b.left * size.width,
            b.top * size.height,
            b.width * size.width,
            b.height * size.height,
          ),
          size,
          stroke,
        ),
    ];

    // Dim everything outside the frames.
    final holes = Path();
    for (final r in frames) {
      holes.addRRect(r);
    }
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        holes,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );

    final halo = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 4;
    final border = Paint()
      ..color = _red
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    for (final r in frames) {
      canvas.drawRRect(r, halo);
      canvas.drawRRect(r, border);

      final t = ping;
      if (t != null) {
        canvas.drawRRect(
          r.inflate(t * stroke * 4),
          Paint()
            ..color = _red.withValues(alpha: (1 - t) * 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke * 0.8,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CuratedHighlightPainter oldDelegate) =>
      oldDelegate.ping != ping ||
      oldDelegate.normalizedBboxes != normalizedBboxes ||
      oldDelegate.debugEdges != debugEdges;
}
