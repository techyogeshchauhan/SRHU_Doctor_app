import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'core/widgets/responsive.dart';
import 'features/clinical_workflow/ui/workflow_screen.dart';
import 'features/condition_selection/ui/condition_selection_screen.dart';
import 'features/home/home_screen.dart';
import 'features/landing/ui/landing_screen.dart';
import 'features/rd/ui/rd_screen.dart';
import 'features/references/ui/pdf_viewer_screen.dart';
import 'features/references/ui/references_screen.dart';
import 'features/rop/ui/rop_screen.dart';

GoRouter buildRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const LandingScreen(),
        ),
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const HomeScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(CurveTween(curve: Curves.easeOutCubic)
                      .animate(animation)),
                  child: child,
                ),
              );
            },
          ),
        ),
        GoRoute(
          path: '/conditions',
          builder: (_, __) => const ConditionSelectionScreen(),
        ),
        GoRoute(path: '/workflow', builder: (_, __) => const WorkflowScreen()),
        GoRoute(path: '/rd', builder: (_, __) => const RdScreen()),
        GoRoute(path: '/rop', builder: (_, __) => const RopScreen()),
        GoRoute(
          path: '/rop/reference',
          builder: (_, __) => const RopReferenceScreen(),
        ),
        GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
        GoRoute(
          path: '/references',
          builder: (_, __) => const ReferencesScreen(),
        ),
        GoRoute(
          path: '/pdf-viewer',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final path = state.uri.queryParameters['path'] ??
                extra?['path'] as String? ??
                '';
            final title = state.uri.queryParameters['title'] ??
                extra?['title'] as String? ??
                'STW Document';
            return PdfViewerScreen(
              assetPath: path,
              title: title,
            );
          },
        ),
      ],
    );

class NeonatalStwApp extends StatefulWidget {
  const NeonatalStwApp({super.key});

  @override
  State<NeonatalStwApp> createState() => _NeonatalStwAppState();
}

class _NeonatalStwAppState extends State<NeonatalStwApp> {
  final _router = buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'STW Neo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      routerConfig: _router,
      // Centred column on wide windows (desktop web, iPad landscape).
      builder: (context, child) => AppShell(child: child!),
    );
  }
}
