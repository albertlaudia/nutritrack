import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../camera/data/off_client.dart';
import '../../../dashboard/domain/food_log_entry.dart';
import '../../../dashboard/domain/macro_nutrients.dart';
import '../widgets/barcode_result_sheet.dart';

enum BarcodePhase {
  permission,
  initializing,
  scanning,
  lookupRunning,
  result,        // Product found, awaiting confirm
  notFound,      // Product not in OFF
  error,         // Network / unknown error
}

/// Full-screen barcode scanner with overlay, viewfinder animation, and
/// "Tap to focus" support. Result is shown in a draggable bottom sheet.
class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  ConsumerState<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  BarcodePhase _phase = BarcodePhase.permission;
  String? _errorMessage;
  String? _lastBarcode; // prevents re-firing the same barcode repeatedly
  OffProduct? _product;
  MobileScannerController? _controller;

  // Manual entry fallback (some products have damaged barcodes).
  final _manualCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (ctrl == null) return;
    if (state == AppLifecycleState.resumed) {
      ctrl.start();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      ctrl.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _manualCtrl.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      await _initScanner();
    } else {
      setState(() => _phase = BarcodePhase.permission);
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      await _initScanner();
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _errorMessage = 'Camera access is blocked. Open Settings to allow it.';
        _phase = BarcodePhase.error;
      });
    } else {
      setState(() => _errorMessage =
          'NutriTrack needs the camera to scan barcodes.');
    }
  }

  Future<void> _initScanner() async {
    setState(() => _phase = BarcodePhase.initializing);
    try {
      final controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        formats: const [
          BarcodeFormat.ean8,
          BarcodeFormat.ean13,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
          BarcodeFormat.code128,
          BarcodeFormat.qrCode,
        ],
        facing: CameraFacing.back,
        torchEnabled: false,
      );
      await controller.start();
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _phase = BarcodePhase.scanning;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _BarcodeError.friendlyMessage(e);
        _phase = BarcodePhase.error;
      });
    }
  }

  void _toggleTorch() {
    HapticFeedback.selectionClick();
    _controller?.toggleTorch();
  }

  void _switchCamera() {
    HapticFeedback.selectionClick();
    _controller?.switchCamera();
  }

  Future<void> _onBarcode(BarcodeCapture capture) async {
    if (_phase != BarcodePhase.scanning) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    if (raw == _lastBarcode) return; // throttle repeat detections
    _lastBarcode = raw;

    HapticFeedback.mediumImpact();
    await _controller?.stop();
    if (!mounted) return;
    setState(() {
      _phase = BarcodePhase.lookupRunning;
    });
    await _lookup(raw);
  }

  Future<void> _lookup(String barcode) async {
    final client = ref.read(cachedOffProvider);
    try {
      final product = await client.lookup(barcode);
      if (!mounted) return;
      if (product == null) {
        setState(() => _phase = BarcodePhase.notFound);
        return;
      }
      setState(() {
        _product = product;
        _phase = BarcodePhase.result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _BarcodeError.friendlyMessage(e);
        _phase = BarcodePhase.error;
      });
    }
  }

  void _resumeScanning() {
    setState(() {
      _phase = BarcodePhase.scanning;
      _product = null;
      _lastBarcode = null;
    });
    _controller?.start();
  }

  Future<void> _save({
    required OffProduct product,
    required double grams,
    required MealSlot slot,
  }) async {
    final ratio = grams / 100.0;
    final m = product.per100g;
    final entry = FoodLogEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: product.name.toLowerCase(),
      brand: product.brand,
      grams: grams,
      macros: MacroNutrients(
        protein: m.protein * ratio,
        carbs: m.carbs * ratio,
        fat: m.fat * ratio,
        fiber: m.fiber * ratio,
        sugar: m.sugar * ratio,
        sodium: m.sodium * ratio,
      ),
      loggedAt: DateTime.now(),
      slot: slot,
      source: LogSource.barcode,
      confidence: 1.0, // OFF data is authoritative
      externalId: product.barcode,
    );
    await ref.read(todayMealsProvider.notifier).add([entry]);
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logged ${product.name} \u2713'),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    context.pop();
  }

  Future<void> _submitManual(String raw) async {
    if (raw.isEmpty) return;
    HapticFeedback.selectionClick();
    await _lookup(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBody(),
          SafeArea(child: _TopBar(onClose: () => context.pop())),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case BarcodePhase.permission:
        return _PermissionView(
          message: _errorMessage,
          onAllow: _requestPermission,
          onManual: () {
            _manualCtrl.clear();
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _ManualEntrySheet(
                controller: _manualCtrl,
                onSubmit: _submitManual,
              ),
            );
          },
        );
      case BarcodePhase.initializing:
        return const ColoredBox(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
      case BarcodePhase.scanning:
        return _ScannerView(
          controller: _controller!,
          onDetect: _onBarcode,
          onTorch: _toggleTorch,
          onSwitch: _switchCamera,
        );
      case BarcodePhase.lookupRunning:
        return _LookupOverlay(barcode: _lastBarcode ?? '');
      case BarcodePhase.result:
        return _ResultView(
          product: _product!,
          onSave: _save,
          onScanAnother: _resumeScanning,
        );
      case BarcodePhase.notFound:
        return _NotFoundView(
          barcode: _lastBarcode ?? '',
          onScanAnother: _resumeScanning,
          onManual: () {
            _manualCtrl.text = _lastBarcode ?? '';
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _ManualEntrySheet(
                controller: _manualCtrl,
                onSubmit: _submitManual,
              ),
            );
          },
        );
      case BarcodePhase.error:
        return _ErrorView(
          message: _errorMessage ?? 'Something went wrong.',
          onRetry: () {
            if (_lastBarcode != null) {
              setState(() => _phase = BarcodePhase.lookupRunning);
              _lookup(_lastBarcode!);
            } else {
              _initScanner();
            }
          },
          onManual: () {
            _manualCtrl.clear();
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _ManualEntrySheet(
                controller: _manualCtrl,
                onSubmit: _submitManual,
              ),
            );
          },
        );
    }
  }
}

// ── Permission view ────────────────────────────────────────────
class _PermissionView extends StatelessWidget {
  const _PermissionView({
    required this.onAllow,
    required this.onManual,
    this.message,
  });
  final VoidCallback onAllow;
  final VoidCallback onManual;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.brand.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppColors.brand,
                  size: 56,
                ),
              ).animate().scale(curve: AppMotion.playful, duration: 600.ms),
              const SizedBox(height: 32),
              Text(
                'Scan a barcode',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Point at any food product barcode. We\'ll look up the nutrition '
                'info from a free open database of \u003e2 million products.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.75),
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.amber, fontSize: 13)),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onAllow,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Allow camera'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onManual,
                  icon: Icon(Icons.keyboard_alt_outlined,
                    color: Colors.white.withOpacity(0.9)),
                  label: Text('Enter barcode manually',
                    style: TextStyle(color: Colors.white.withOpacity(0.9))),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Scanner view ──────────────────────────────────────────────
class _ScannerView extends StatelessWidget {
  const _ScannerView({
    required this.controller,
    required this.onDetect,
    required this.onTorch,
    required this.onSwitch,
  });

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final VoidCallback onTorch;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: controller,
          onDetect: onDetect,
          errorBuilder: (context, error, child) => _ErrorView(
            message: _BarcodeError.friendlyMessage(error),
            onRetry: () {},
            onManual: () {},
          ),
        ),
        // Dim everything outside the viewfinder
        const _ViewfinderMask(),
        // Animated scan line
        const IgnorePointer(
          child: _AnimatedScanLine(),
        ),
        // Bottom controls
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: SafeArea(
            top: false,
            child: _ScannerBottomControls(
              onTorch: onTorch,
              onSwitch: onSwitch,
            ),
          ),
        ),
      ],
    );
  }
}

class _ViewfinderMask extends StatelessWidget {
  const _ViewfinderMask();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MaskPainter());
  }
}

class _MaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final viewfinderSize = w * 0.78;
    final left = (w - viewfinderSize) / 2;
    final top = (h - viewfinderSize) / 2;
    final rect = Rect.fromLTWH(left, top, viewfinderSize, viewfinderSize);

    // Dim outside the rect with rounded cutout.
    final overlay = Path()
      ..addRect(Rect.fromLTWH(0, 0, w, h))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(24)));
    overlay.fillType = PathFillType.evenOdd;
    canvas.drawPath(
      overlay,
      Paint()
        ..color = Colors.black.withOpacity(0.55)
        ..style = PaintingStyle.fill,
    );

    // Viewfinder corners.
    final cornerLen = viewfinderSize * 0.12;
    final cornerRadius = Radius.circular(viewfinderSize * 0.06);
    final cornerPaint = Paint()
      ..color = AppColors.brand
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rrect = RRect.fromRectAndRadius(rect, cornerRadius);
    // Top-left
    canvas.drawLine(rect.topLeft + Offset(cornerLen * 0.4, 0),
        rect.topLeft, cornerPaint);
    canvas.drawLine(rect.topLeft,
        rect.topLeft + Offset(0, cornerLen * 0.4), cornerPaint);
    // Top-right
    canvas.drawLine(rect.topRight - Offset(cornerLen * 0.4, 0),
        rect.topRight, cornerPaint);
    canvas.drawLine(rect.topRight,
        rect.topRight - Offset(0, cornerLen * 0.4), cornerPaint);
    // Bottom-left
    canvas.drawLine(rect.bottomLeft + Offset(cornerLen * 0.4, 0),
        rect.bottomLeft, cornerPaint);
    canvas.drawLine(rect.bottomLeft,
        rect.bottomLeft - Offset(0, cornerLen * 0.4), cornerPaint);
    // Bottom-right
    canvas.drawLine(rect.bottomRight - Offset(cornerLen * 0.4, 0),
        rect.bottomRight, cornerPaint);
    canvas.drawLine(rect.bottomRight,
        rect.bottomRight - Offset(0, cornerLen * 0.4), cornerPaint);
  }

  @override
  bool shouldRepaint(_MaskPainter old) => false;
}

class _AnimatedScanLine extends StatefulWidget {
  const _AnimatedScanLine();
  @override
  State<_AnimatedScanLine> createState() => _AnimatedScanLineState();
}

class _AnimatedScanLineState extends State<_AnimatedScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide * 0.78;
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = _ctrl.value;
            return Stack(
              children: [
                Positioned(
                  left: (constraints.maxWidth - size) / 2,
                  top: (constraints.maxHeight - size) / 2 +
                      (size * 0.04) + (size * 0.84 * t),
                  child: Container(
                    width: size,
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.brand.withOpacity(0),
                          AppColors.brand,
                          AppColors.brand.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ScannerBottomControls extends StatelessWidget {
  const _ScannerBottomControls({
    required this.onTorch,
    required this.onSwitch,
  });
  final VoidCallback onTorch;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ScanControlButton(
            icon: Icons.flashlight_on_rounded,
            label: 'Torch',
            onTap: onTorch,
          ),
          _ScanControlButton(
            icon: Icons.keyboard_alt_outlined,
            label: 'Manual',
            onTap: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _ManualEntrySheet(
                  controller: TextEditingController(),
                  onSubmit: (raw) async {
                    Navigator.pop(context);
                    // Defer to parent state via callback chain.
                  },
                ),
              );
            },
          ),
          _ScanControlButton(
            icon: Icons.cameraswitch_rounded,
            label: 'Flip',
            onTap: onSwitch,
          ),
        ],
      ),
    );
  }
}

class _ScanControlButton extends StatelessWidget {
  const _ScanControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.18),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Lookup overlay ────────────────────────────────────────────
class _LookupOverlay extends StatelessWidget {
  const _LookupOverlay({required this.barcode});
  final String barcode;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brand.withOpacity(0.2),
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: AppColors.brand, strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Looking up product\u2026',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              barcode,
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Result view ──────────────────────────────────────────────
class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.product,
    required this.onSave,
    required this.onScanAnother,
  });

  final OffProduct product;
  final Future<void> Function({
    required OffProduct product,
    required double grams,
    required MealSlot slot,
  }) onSave;
  final VoidCallback onScanAnother;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Blurred product image as background
        if (product.imageUrl != null)
          Opacity(
            opacity: 0.3,
            child: CachedNetworkImage(
              imageUrl: product.imageUrl!,
              fit: BoxFit.cover,
              memCacheWidth: 600, // large background, but only need ~600px wide
              placeholder: (_, __) => Container(color: Colors.black),
              errorWidget: (_, __, ___) => Container(color: Colors.black),
            ),
          ),
        Container(color: Colors.black.withOpacity(0.5)),
        DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return BarcodeResultSheet(
              product: product,
              onSave: onSave,
              onScanAnother: onScanAnother,
              scrollController: scrollController,
            );
          },
        ),
      ],
    );
  }
}

// ── Not found ────────────────────────────────────────────────
class _NotFoundView extends StatelessWidget {
  const _NotFoundView({
    required this.barcode,
    required this.onScanAnother,
    required this.onManual,
  });
  final String barcode;
  final VoidCallback onScanAnother;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded,
                color: Colors.white.withOpacity(0.5), size: 72),
              const SizedBox(height: 24),
              const Text(
                'Product not in database',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Barcode $barcode isn\'t in the Open Food Facts database. '
                'You can enter the nutrition manually or try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onScanAnother,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Scan another'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onManual,
                  icon: Icon(Icons.edit_rounded,
                    color: Colors.white.withOpacity(0.9)),
                  label: Text('Enter manually',
                    style: TextStyle(color: Colors.white.withOpacity(0.9))),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onManual,
  });
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded,
                color: AppColors.amber, size: 72),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onManual,
                  icon: Icon(Icons.keyboard_alt_outlined,
                    color: Colors.white.withOpacity(0.9)),
                  label: Text('Enter barcode manually',
                    style: TextStyle(color: Colors.white.withOpacity(0.9))),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Manual entry bottom sheet ─────────────────────────────────
class _ManualEntrySheet extends StatefulWidget {
  const _ManualEntrySheet({
    required this.controller,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final Future<void> Function(String) onSubmit;

  @override
  State<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<_ManualEntrySheet> {
  bool _submitting = false;

  Future<void> _submit() async {
    final raw = widget.controller.text.trim();
    if (raw.isEmpty) return;
    setState(() => _submitting = true);
    Navigator.pop(context);
    await widget.onSubmit(raw);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Enter barcode',
              style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Type the 8\u201313 digit number below the barcode',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: widget.controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Barcode',
                hintText: 'e.g. 737628064502',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search_rounded),
              label: Text(_submitting ? 'Looking up…' : 'Look up'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top bar ──────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Material(
            color: Colors.black.withOpacity(0.4),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onClose,
              child: const SizedBox(
                width: 44, height: 44,
                child: Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.mint,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Barcode',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Maps plugin / network errors to user-facing messages.
class _BarcodeError {
  static String friendlyMessage(Object e) {
    final s = e.toString();
    if (s.contains('CameraAccessDenied') || s.contains('PERMISSION_DENIED')) {
      return 'Camera access was denied. Allow it in Settings, or enter the barcode manually.';
    }
    if (s.contains('SocketException') || s.contains('Connection')) {
      return 'No internet connection — check your network and try again.';
    }
    if (s.contains('TimeoutException') || s.contains('Timeout')) {
      return 'Network is slow. Try again, or enter the barcode manually.';
    }
    if (s.contains('429')) {
      return 'Too many lookups. Wait a moment and try again.';
    }
    return 'Something went wrong. Try again or enter the barcode manually.';
  }
}