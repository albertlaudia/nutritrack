import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/ai/ai_gateway.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../dashboard/domain/food_log_entry.dart';
import '../widgets/camera_review_sheet.dart';

enum CameraSource { camera, gallery }

/// State machine for the camera screen flow:
///
///   permission → initializing → ready
///       ↘ denied / restricted → permission
///   ready → capturing → analyzing → review
///       ↘ error → ready
///   review → saving → done (pop)
///
/// One enum tracks the visible state; subclasses handle each phase.
enum CameraPhase {
  permission,    // Asking for camera permission
  initializing,  // Camera plugin warming up
  ready,         // Live preview visible
  capturing,     // Photo taken, flashing shutter
  analyzing,     // AI vision call in flight
  review,        // Results on screen, awaiting confirmation
  error,         // Something failed; show retry UI
}

/// Manages the device's available cameras. Cached after first request.
final availableCamerasProvider = FutureProvider<List<CameraDescription>>((ref) async {
  return availableCameras();
});

/// Camera controller lifecycle is owned here so the screen widget stays simple.
/// The provider exposes a `ready` flag that flips once the controller is bound
/// to a preview texture — the UI uses it to fade in the live view.
class CameraControllerState {
  CameraControllerState({
    required this.controller,
    required this.lensDirection,
  });
  final CameraController controller;
  final CameraDescription? lensDirection;
  bool get isReady => controller.value.isInitialized && !controller.value.isPreviewPaused;
  bool get isTakingPicture => controller.value.isTakingPicture;
}

/// Riverpod-managed camera controller. Disposed automatically.
final cameraControllerProvider =
    StateNotifierProvider<CameraControllerNotifier, CameraControllerState?>((ref) {
  return CameraControllerNotifier(ref);
});

class CameraControllerNotifier extends StateNotifier<CameraControllerState?> {
  CameraControllerNotifier(this._ref) : super(null);
  final Ref _ref;

  Future<void> initialize() async {
    final cameras = await _ref.read(availableCamerasProvider.future);
    if (cameras.isEmpty) {
      throw CameraException('NoCameraAvailable', 'No camera detected on this device.');
    }
    // Prefer the back camera; fall back to whatever is available.
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize();
    state = CameraControllerState(
      controller: controller,
      lensDirection: back,
    );
  }

  Future<void> switchCamera() async {
    final cameras = await _ref.read(availableCamerasProvider.future);
    if (cameras.length < 2) return;
    final current = state?.lensDirection;
    final next = cameras.firstWhere(
      (c) => c.lensDirection != current?.lensDirection,
      orElse: () => cameras.first,
    );
    await state?.controller.dispose();
    final controller = CameraController(
      next,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize();
    state = CameraControllerState(controller: controller, lensDirection: next);
  }

  Future<File> takePicture() async {
    final ctrl = state?.controller;
    if (ctrl == null || !state!.isReady) {
      throw CameraException('NotReady', 'Camera is not ready yet.');
    }
    HapticFeedback.mediumImpact();
    final xfile = await ctrl.takePicture();
    return File(xfile.path);
  }

  @override
  void dispose() {
    state?.controller.dispose();
    super.dispose();
  }
}

/// Camera screen — full Snap → Recognize → Review → Save flow.
///
/// Used as `/camera` route. Pops back to dashboard after a successful save.
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  CameraPhase _phase = CameraPhase.permission;
  String? _errorMessage;
  File? _capturedFile;
  List<FoodLogEntry> _recognized = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause/resume the camera when the app is backgrounded — keeps the
    // camera LED from staying on and frees the sensor for other apps.
    final camState = ref.read(cameraControllerProvider);
    if (camState == null) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      camState.controller.pausePreview();
    } else if (state == AppLifecycleState.resumed && _phase == CameraPhase.ready) {
      camState.controller.resumePreview();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _checkPermission();
  }

  Future<void> _checkPermission() async {
    setState(() {
      _phase = CameraPhase.permission;
      _errorMessage = null;
    });
    final status = await Permission.camera.status;
    _cameraStatus = status;
    if (status.isGranted) {
      await _initCamera();
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _errorMessage = 'Camera access is blocked. Open Settings to allow it.';
        _phase = CameraPhase.error;
      });
    } else {
      setState(() => _phase = CameraPhase.permission);
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      await _initCamera();
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _errorMessage = 'Camera access is blocked. Open Settings to allow it.';
        _phase = CameraPhase.error;
      });
    } else {
      // User just denied — show explanation but stay on permission phase.
      setState(() => _errorMessage = 'NutriTrack needs the camera to recognize meals.');
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _phase = CameraPhase.initializing;
      _errorMessage = null;
    });
    try {
      await ref.read(cameraControllerProvider.notifier).initialize();
      if (!mounted) return;
      setState(() => _phase = CameraPhase.ready);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _CameraError.friendlyMessage(e);
        _phase = CameraPhase.error;
      });
    }
  }

  Future<void> _onShutter() async {
    if (_phase != CameraPhase.ready) return;
    HapticFeedback.lightImpact();
    setState(() => _phase = CameraPhase.capturing);
    try {
      final file = await ref.read(cameraControllerProvider.notifier).takePicture();
      if (!mounted) return;
      setState(() {
        _capturedFile = file;
        _phase = CameraPhase.analyzing;
      });
      await _analyze(file);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _CameraError.friendlyMessage(e);
        _phase = CameraPhase.error;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    HapticFeedback.selectionClick();
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 2048,
      );
      if (xfile == null) return; // user cancelled
      final file = File(xfile.path);
      if (!mounted) return;
      setState(() {
        _capturedFile = file;
        _phase = CameraPhase.analyzing;
      });
      await _analyze(file);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _CameraError.friendlyMessage(e);
        _phase = CameraPhase.error;
      });
    }
  }

  Future<void> _analyze(File file) async {
    final ai = ref.read(aiGatewayProvider);
    try {
      final entries = await ai.recognizeFromImage(image: file);
      if (!mounted) return;
      if (entries.isEmpty) {
        setState(() {
          _errorMessage = 'No food detected. Try a clearer angle or better lighting.';
          _phase = CameraPhase.error;
        });
        return;
      }
      setState(() {
        _recognized = entries;
        _phase = CameraPhase.review;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is AIException
            ? e.message
            : _CameraError.friendlyMessage(e);
        _phase = CameraPhase.error;
      });
    }
  }

  void _retake() {
    setState(() {
      _capturedFile = null;
      _recognized = [];
      _errorMessage = null;
      _phase = CameraPhase.ready;
    });
  }

  Future<void> _save(List<FoodLogEntry> entries) async {
    setState(() => _saving = true);
    try {
      await ref.read(todayMealsProvider.notifier).add(entries);
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      // Show success briefly, then pop.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logged ${entries.length} item${entries.length == 1 ? '' : 's'} \u2713',
          ),
          duration: const Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      // Pop back to dashboard; the stream will emit the new entries.
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = 'Could not save: ${e.toString().split('\n').first}';
        _phase = CameraPhase.error;
      });
    }
  }

  Future<void> _switchCamera() async {
    HapticFeedback.selectionClick();
    try {
      await ref.read(cameraControllerProvider.notifier).switchCamera();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _CameraError.friendlyMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Live preview or phase-specific UI
          _buildBody(),
          // Top bar always on top
          SafeArea(child: _TopBar(onClose: () => context.pop())),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case CameraPhase.permission:
        return _PermissionPrompt(
          onAllow: _requestPermission,
          onPickFromGallery: _pickFromGallery,
          message: _errorMessage,
        );
      case CameraPhase.initializing:
      case CameraPhase.ready:
      case CameraPhase.capturing:
        return _LivePreview(
          phase: _phase,
          onShutter: _onShutter,
          onSwitchCamera: _switchCamera,
          onPickFromGallery: _pickFromGallery,
        );
      case CameraPhase.analyzing:
        return _AnalyzingOverlay(image: _capturedFile!);
      case CameraPhase.review:
        return _ReviewOverlay(
          image: _capturedFile!,
          entries: _recognized,
          saving: _saving,
          onConfirm: _save,
          onRetake: _retake,
        );
      case CameraPhase.error:
        return _ErrorOverlay(
          message: _errorMessage ?? 'Something went wrong.',
          onRetry: _phase == CameraPhase.permission
              ? _checkPermission
              : () {
                  if (_capturedFile != null) {
                    setState(() => _phase = CameraPhase.analyzing);
                    _analyze(_capturedFile!);
                  } else {
                    _initCamera();
                  }
                },
          onGallery: _pickFromGallery,
        );
    }
  }
}

// ── Permission prompt ─────────────────────────────────────────
class _PermissionPrompt extends StatelessWidget {
  const _PermissionPrompt({
    required this.onAllow,
    required this.onPickFromGallery,
    this.message,
  });
  final VoidCallback onAllow;
  final VoidCallback onPickFromGallery;
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
                  color: AppColors.brand.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.photo_camera_rounded,
                  color: AppColors.brand,
                  size: 56,
                ),
              ).animate().scale(curve: AppMotion.playful, duration: 600.ms),
              const SizedBox(height: 32),
              Text(
                'See food, log food',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Snap a meal and we\'ll identify each item, estimate portions, '
                'and log the macros. Nothing leaves your device without your OK.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.amber, fontSize: 13),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onAllow,
                  icon: const Icon(Icons.camera_alt_rounded),
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
                  onPressed: onPickFromGallery,
                  icon: Icon(Icons.photo_library_outlined,
                    color: Colors.white.withValues(alpha: 0.9)),
                  label: Text(
                    'Pick from gallery instead',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
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

// ── Live preview ─────────────────────────────────────────────
class _LivePreview extends ConsumerWidget {
  const _LivePreview({
    required this.phase,
    required this.onShutter,
    required this.onSwitchCamera,
    required this.onPickFromGallery,
  });

  final CameraPhase phase;
  final VoidCallback onShutter;
  final VoidCallback onSwitchCamera;
  final VoidCallback onPickFromGallery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camState = ref.watch(cameraControllerProvider);

    if (camState == null || !camState.isReady) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        Center(
          child: AspectRatio(
            aspectRatio: camState.controller.value.aspectRatio,
            child: CameraPreview(camState.controller),
          ),
        ),
        // Subtle scan-grid overlay to suggest AI focus
        const IgnorePointer(child: _ScanGrid()),
        // Bottom controls
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: SafeArea(
            top: false,
            child: _BottomControls(
              phase: phase,
              onShutter: onShutter,
              onSwitchCamera: onSwitchCamera,
              onPickFromGallery: onPickFromGallery,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanGrid extends StatelessWidget {
  const _ScanGrid();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ScanGridPainter());
  }
}

class _ScanGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    // Rule-of-thirds grid lines.
    final w = size.width, h = size.height;
    canvas.drawLine(Offset(w / 3, 0), Offset(w / 3, h), paint);
    canvas.drawLine(Offset(2 * w / 3, 0), Offset(2 * w / 3, h), paint);
    canvas.drawLine(Offset(0, h / 3), Offset(w, h / 3), paint);
    canvas.drawLine(Offset(0, 2 * h / 3), Offset(w, 2 * h / 3), paint);
  }

  @override
  bool shouldRepaint(_ScanGridPainter old) => false;
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.phase,
    required this.onShutter,
    required this.onSwitchCamera,
    required this.onPickFromGallery,
  });

  final CameraPhase phase;
  final VoidCallback onShutter;
  final VoidCallback onSwitchCamera;
  final VoidCallback onPickFromGallery;

  @override
  Widget build(BuildContext context) {
    final disabled = phase == CameraPhase.capturing;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Gallery button
          _CircleControl(
            icon: Icons.photo_library_outlined,
            onTap: disabled ? null : onPickFromGallery,
            tooltip: 'Gallery',
          ),
          // Shutter button
          GestureDetector(
            onTap: disabled ? null : onShutter,
            child: AnimatedContainer(
              duration: AppMotion.normal,
              width: disabled ? 70 : 78,
              height: disabled ? 70 : 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.4),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: disabled ? AppColors.brand.withValues(alpha: 0.5) : AppColors.brand,
                  ),
                  child: disabled
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 30),
                ),
              ),
            ),
          ),
          // Camera switch button
          _CircleControl(
            icon: Icons.cameraswitch_rounded,
            onTap: disabled ? null : onSwitchCamera,
            tooltip: 'Flip',
          ),
        ],
      ),
    );
  }
}

class _CircleControl extends StatelessWidget {
  const _CircleControl({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: onTap == null ? 0.08 : 0.18),
      ),
      child: Icon(icon, color: Colors.white.withValues(alpha: onTap == null ? 0.4 : 1.0)),
    );
    if (onTap == null) return btn;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: btn,
        ),
      ),
    );
  }
}

// ── Analyzing overlay ─────────────────────────────────────────
class _AnalyzingOverlay extends StatelessWidget {
  const _AnalyzingOverlay({required this.image});
  final File image;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Faded photo so user remembers what they snapped
        Opacity(
          opacity: 0.4,
          child: Image.file(image, fit: BoxFit.cover),
        ),
        Container(color: Colors.black.withValues(alpha: 0.6)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brand.withValues(alpha: 0.2),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    color: AppColors.brand, strokeWidth: 3,
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat())
                  .scale(
                    begin: const Offset(0.95, 0.95),
                    end: const Offset(1.05, 1.05),
                    duration: 900.ms,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(height: 24),
              const Text(
                'Identifying food\u2026',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AI is examining your photo',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Review overlay ────────────────────────────────────────────
class _ReviewOverlay extends StatelessWidget {
  const _ReviewOverlay({
    required this.image,
    required this.entries,
    required this.saving,
    required this.onConfirm,
    required this.onRetake,
  });

  final File image;
  final List<FoodLogEntry> entries;
  final bool saving;
  final ValueChanged<List<FoodLogEntry>> onConfirm;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(image, fit: BoxFit.cover),
        // Bottom sheet for results — user can edit before saving.
        DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return CameraReviewSheet(
              entries: entries,
              saving: saving,
              onConfirm: onConfirm,
              onRetake: onRetake,
              scrollController: scrollController,
            );
          },
        ),
      ],
    );
  }
}

// ── Error overlay ─────────────────────────────────────────────
class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({
    required this.message,
    required this.onRetry,
    required this.onGallery,
  });
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onGallery;

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
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.amber,
                size: 72,
              ),
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
                  onPressed: onGallery,
                  icon: Icon(Icons.photo_library_outlined,
                    color: Colors.white.withValues(alpha: 0.9)),
                  label: Text('Pick from gallery',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
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

// ── Top bar (close button + title) ───────────────────────────
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
            color: Colors.black.withValues(alpha: 0.4),
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
              color: Colors.black.withValues(alpha: 0.5),
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
                  'AI Snap',
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

/// Maps any camera / OS error to a friendly message.
class _CameraError {
  static String friendlyMessage(Object e) {
    final s = e.toString();
    if (s.contains('CameraAccessDenied') ||
        s.contains('camera permission') ||
        s.contains('PERMISSION_DENIED')) {
      return 'Camera access was denied. Allow it in Settings, or pick a photo from your gallery.';
    }
    if (s.contains('CameraNotFound') || s.contains('NoCameraAvailable')) {
      return 'No camera detected on this device. Try picking a photo from your gallery instead.';
    }
    if (s.contains('Session') || s.contains('in use')) {
      return 'Camera is busy. Close other camera apps and try again.';
    }
    if (s.contains('timeout') || s.contains('TimeoutException')) {
      return 'Camera took too long to respond. Try again.';
    }
    return 'Something went wrong with the camera. Try again or use a photo from your gallery.';
  }
}