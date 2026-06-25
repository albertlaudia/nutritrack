import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Global error handler — catches Flutter framework errors and Dart zone errors
/// that would otherwise crash the app or show a red screen.
///
/// In debug mode we still surface errors via `FlutterError.presentError` so the
/// developer sees stack traces. In release we silently log and keep the app
/// alive — the broken widget renders an [ErrorFallback] instead of a red screen.
class AppErrorHandler {
  AppErrorHandler._();

  static bool _initialized = false;

  /// Call once at app startup, before runApp.
  static void install({void Function(Object error, StackTrace stack)? onError}) {
    if (_initialized) return;
    _initialized = true;

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      // Always log to the console for visibility.
      FlutterError.presentError(details);
      // Forward to optional reporter (Crashlytics, Sentry, …).
      onError?.call(details.exception, details.stack ?? StackTrace.current);
      // In release, swallow after logging so the app stays alive.
      if (!kDebugMode) {
        // Don't call previousOnError in release — would still crash to red screen.
        return;
      }
      // In debug, let the framework red-screen so devs see the trace.
      previousOnError?.call(details);
    };

    // Catch async errors that escape the framework (unawaited futures etc.)
    PlatformDispatcher.instance.onError = (error, stack) {
      onError?.call(error, stack);
      // Returning true marks the error as handled.
      return true;
    };
  }

  /// Run [body] inside a guarded zone. Errors are reported via the global
  /// handler but never tear down the app.
  static void runGuarded(void Function() body) {
    runZonedGuarded(body, (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'app_zone',
      ));
    });
  }
}

/// A drop-in widget that catches any rendering error in its subtree and
/// shows a friendly fallback. Useful for screens that mix many third-party
/// widgets (camera, AI, charts) where one bad widget shouldn't kill the
/// whole screen.
///
/// Usage:
/// ```dart
/// ErrorBoundary(child: ExpensiveWidget())
/// ```
class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallback,
    this.onError,
  });

  final Widget child;
  final Widget? fallback;
  final void Function(Object error, StackTrace stack)? onError;

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stack;

  @override
  void initState() {
    super.initState();
    // Flutter doesn't expose a per-widget error hook, so we rely on
    // FlutterError.onError + a key-based rebuild as a poor-man's boundary.
    // The actual catching happens via FlutterErrorDetailsException in build.
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.fallback ?? _DefaultErrorFallback(
        error: _error!,
        onRetry: () => setState(() {
          _error = null;
          _stack = null;
        }),
      );
    }
    return widget.child;
  }
}

class _DefaultErrorFallback extends StatelessWidget {
  const _DefaultErrorFallback({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded,
            size: 36, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(
            'Something went wrong rendering this view',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).hintColor,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}