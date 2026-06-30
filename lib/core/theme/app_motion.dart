import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppMotion {
  AppMotion._();

  static const Duration instant = Duration(milliseconds: 80);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration slower = Duration(milliseconds: 600);

  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve playful = Cubic(0.34, 1.56, 0.64, 1.0);
  static const Curve standard = Curves.easeInOutCubic;

  static CustomTransitionPage<T> sharedAxisPage<T>(Widget page) {
    return CustomTransitionPage<T>(
      child: page,
      transitionDuration: slow,
      reverseTransitionDuration: fast,
      transitionsBuilder: (context, anim, secondaryAnim, child) {
        final scale = Tween<double>(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(parent: anim, curve: emphasized),
        );
        final fade = CurvedAnimation(parent: anim, curve: emphasizedDecelerate);
        return FadeTransition(opacity: fade, child: ScaleTransition(scale: scale, child: child));
      },
    );
  }

  /// Vertical slide-up transition (Material 3 expressive) for modal-ish routes
  /// like the camera screen — the user feels they are descending into the
  /// camera rather than sliding from a side.
  static CustomTransitionPage<T> verticalSharedAxisPage<T>(Widget page) {
    return CustomTransitionPage<T>(
      child: page,
      transitionDuration: slow,
      reverseTransitionDuration: fast,
      transitionsBuilder: (context, anim, secondaryAnim, child) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: emphasizedDecelerate));
        final fade = CurvedAnimation(parent: anim, curve: emphasizedDecelerate);
        return SlideTransition(
          position: slide,
          child: FadeTransition(opacity: fade, child: child),
        );
      },
    );
  }
}
