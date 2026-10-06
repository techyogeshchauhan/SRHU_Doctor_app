import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/app_branding.dart';
import '../../../core/widgets/app_refresh_button.dart';

/// Full-screen in-app PDF viewer for the ICMR/DHR STW documents.
///
/// Supports smooth pinch-to-zoom, double-tap zoom, scrolling, landscape mode,
/// offline rendering from assets, error handling with retry, and external sharing.
class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({
    super.key,
    required this.assetPath,
    required this.title,
    this.customViewerBuilder,
  });

  final String assetPath;
  final String title;

  /// Optional custom viewer builder used primarily for widget tests.
  final Widget Function(BuildContext context)? customViewerBuilder;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  PdfControllerPinch? _controller;
  bool _isSharing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Allow both portrait and landscape orientations for comfortable reading
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initController();
  }

  void _initController() {
    if (widget.customViewerBuilder != null) return;
    setState(() {
      _errorMessage = null;
    });
    try {
      _controller = PdfControllerPinch(
        document: PdfDocument.openAsset(widget.assetPath),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  void _retry() {
    _controller?.dispose();
    _controller = null;
    _initController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    // Restore default portrait-first orientation preferences
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  Future<void> _shareOrOpenExternally() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final byteData = await rootBundle.load(widget.assetPath);
      final filename = widget.assetPath.split('/').last;

      if (kIsWeb) {
        await Share.shareXFiles(
          [
            XFile.fromData(
              byteData.buffer.asUint8List(),
              mimeType: 'application/pdf',
              name: filename,
            ),
          ],
          text: widget.title,
          subject: widget.title,
        );
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
            content: Text('Unable to share or open document: $e'),
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
      appBar: AppBar(
        title: StwNeoBrand(subtitle: widget.title),
        actions: [
          const AppRefreshButton(),
          const SizedBox(width: 4),
          Semantics(
            button: true,
            label: 'Open in another app or share PDF',
            child: IconButton(
              tooltip: 'Open in another app / Share',
              icon: _isSharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_outlined),
              onPressed: _isSharing ? null : _shareOrOpenExternally,
            ),
          ),
        ],
      ),
      body: widget.customViewerBuilder != null
          ? widget.customViewerBuilder!(context)
          : _buildPdfViewer(),
    );
  }

  Widget _buildPdfViewer() {
    if (_errorMessage != null) {
      return _buildErrorState(_errorMessage!);
    }

    if (_controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryTeal),
      );
    }

    return PdfViewPinch(
      controller: _controller!,
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryTeal),
        ),
        pageLoaderBuilder: (_) => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryTeal),
        ),
        errorBuilder: (context, error) => _buildErrorState(error.toString()),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFDC2626),
                size: 22,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to display PDF',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Could not load ${widget.title}. You can try again or open it in an external PDF reader.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(110, 48),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _shareOrOpenExternally,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Open in App'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(130, 48),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
