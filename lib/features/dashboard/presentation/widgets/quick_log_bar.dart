import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../domain/food_log_entry.dart';

/// The AI Quick-Log bar — tap once → camera. Hold → voice capture.
///
/// This is the single most-used interaction in the app. Tuned for one-thumb
/// operation; large hit target; haptic feedback on activation.
class QuickLogBar extends ConsumerStatefulWidget {
  const QuickLogBar({super.key});

  @override
  ConsumerState<QuickLogBar> createState() => _QuickLogBarState();
}

class _QuickLogBarState extends ConsumerState<QuickLogBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _holdCtrl;
  late final Animation<double> _holdGlow;

  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSub;
  bool _isRecording = false;
  String _liveTranscript = '';
  List<FoodLogEntry>? _pendingEntries;
  bool _saving = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _holdCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _holdGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _holdCtrl, curve: AppMotion.emphasized),
    );
  }

  @override
  void dispose() {
    _audioSub?.cancel();
    _recorder.dispose();
    _holdCtrl.dispose();
    super.dispose();
  }

  Future<void> _onTapCamera() async {
    HapticFeedback.lightImpact();
    context.push('/camera');
  }

  Future<void> _onTapBarcode() async {
    HapticFeedback.lightImpact();
    context.push('/barcode');
  }

  Future<void> _onHoldStart() async {
    HapticFeedback.mediumImpact();
    _holdCtrl.forward();
    setState(() {
      _isRecording = true;
      _liveTranscript = '';
      _pendingEntries = null;
    });

    try {
      if (!await _recorder.hasPermission()) return;

      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      final ai = ref.read(aiGatewayProvider);

      _audioSub = stream.listen(
        (chunk) => /* buffer is consumed by stream; we just pass through */ {},
        onError: (_) => _cancelRecording(),
      );

      // Hand the whole stream to AI gateway — it buffers + transcribes + parses.
      ai.parseFromVoice(audioStream: stream).listen((progress) async {
        if (!mounted) return;
        if (progress.transcript != null) {
          setState(() => _liveTranscript = progress.transcript!);
        }
        if (progress.items != null) {
          setState(() => _pendingEntries = progress.items);
        }
        if (progress.error != null) {
          setState(() => _lastError = progress.error as String?);
          HapticFeedback.heavyImpact();
        }
        if (progress.isFinal) {
          await _finalizeRecording();
        }
      });
    } catch (e) {
      _cancelRecording();
    }
  }

  Future<void> _onHoldEnd() async {
    if (!_isRecording) return;
    try {
      await _recorder.stop();
    } catch (_) {}
    _holdCtrl.reverse();
  }

  Future<void> _cancelRecording() async {
    try {
      await _recorder.cancel();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isRecording = false;
        _pendingEntries = null;
        _liveTranscript = '';
      });
    }
    _holdCtrl.reverse();
  }

  Future<void> _finalizeRecording() async {
    if (_pendingEntries == null || _pendingEntries!.isEmpty) {
      _cancelRecording();
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(todayMealsProvider.notifier).add(_pendingEntries!);
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _saving = false;
          _isRecording = false;
          _pendingEntries = null;
          _liveTranscript = '';
          _lastError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _lastError = 'Could not save: ${e.toString().split('\n').first}';
        });
        HapticFeedback.heavyImpact();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([_holdCtrl]),
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isRecording) _RecordingPanel(
                  transcript: _liveTranscript,
                  pendingCount: _pendingEntries?.length,
                  saving: _saving,
                  error: _lastError,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _BarButton(
                        icon: Icons.camera_alt_rounded,
                        label: 'Snap',
                        onTap: _onTapCamera,
                        gradient: AppColors.brandGradient,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BarButton(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'Scan',
                        onTap: _onTapBarcode,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C896), Color(0xFF4FC3F7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(width: 1, height: 32, color: AppColors.divider),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTapDown: (_) => _onHoldStart(),
                        onTapUp: (_) => _onHoldEnd(),
                        onTapCancel: _cancelRecording,
                        child: AnimatedBuilder(
                          animation: _holdGlow,
                          builder: (context, _) {
                            return Container(
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _isRecording
                                      ? [AppColors.error, const Color(0xFFFF8A8A)]
                                      : [AppColors.lavender, AppColors.sky],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: _isRecording
                                    ? [
                                        BoxShadow(
                                          color: AppColors.error.withValues(alpha: _holdGlow.value * 0.5),
                                          blurRadius: 24,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isRecording ? Icons.mic : Icons.mic_none_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _isRecording ? 'Listening…' : 'Hold to talk',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.gradient,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordingPanel extends StatefulWidget {
  const _RecordingPanel({
    required this.transcript,
    required this.pendingCount,
    required this.saving,
    this.error,
  });

  final String transcript;
  final int? pendingCount;
  final bool saving;
  final String? error;

  @override
  State<_RecordingPanel> createState() => _RecordingPanelState();
}

class _RecordingPanelState extends State<_RecordingPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    // Only animate the pulse while we are actually recording (pendingCount null
    // and not saving). Without the guard the dot keeps pulsing after a final
    // result is delivered, which looks broken.
    _maybeRunPulse();
  }

  void _maybeRunPulse() {
    if (widget.pendingCount == null && !widget.saving && widget.transcript.isEmpty) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      if (_pulse.isAnimating) _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant _RecordingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transcript != widget.transcript ||
        oldWidget.pendingCount != widget.pendingCount ||
        oldWidget.saving != widget.saving ||
        oldWidget.error != widget.error) {
      _maybeRunPulse();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                return Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.6 + _pulse.value * 0.4),
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.error ?? (widget.transcript.isEmpty
                        ? widget.saving ? 'Saving…' : 'Listening to you…'
                        : '"${widget.transcript}"'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: widget.error != null ? AppColors.error : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.pendingCount != null)
                    Text(
                      '✓ ${widget.pendingCount} item${widget.pendingCount == 1 ? '' : 's'} detected',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}