import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../shared/providers/core_providers.dart';
import 'router.dart';

class NutriTrackApp extends ConsumerWidget {
  const NutriTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isarInit = ref.watch(isarInitProvider);
    final router = ref.watch(routerProvider);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    return MaterialApp.router(
      title: 'NutriTrack',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (context, child) {
        return isarInit.when(
          data: (_) => child ?? const SizedBox.shrink(),
          loading: () => const _BootSplash(),
          error: (e, _) => _BootError(error: e.toString()),
        );
      },
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brand,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🥗', style: TextStyle(fontSize: 56)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'NutriTrack',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white.withOpacity(0.7),
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BootError extends StatelessWidget {
  const _BootError({required this.error});
  final String error;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Boot failed: $error', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}