import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_strings.dart';

/// SOS Button widget - The primary emergency trigger.
/// Also listens to RTDB current_status/is_alert so hardware triggers
/// animate the button into active state automatically.
class SosButton extends StatefulWidget {
  final VoidCallback onSosTriggered;
  final ValueChanged<double>? onCountdownUpdate;

  const SosButton({
    Key? key,
    required this.onSosTriggered,
    this.onCountdownUpdate,
  }) : super(key: key);

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  bool _isHolding = false;
  double _holdProgress = 0.0;
  late Stopwatch _holdTimer;

  // Hardware trigger state — true when Pi sets is_alert=true
  bool _isHardwareActive = false;
  StreamSubscription<DatabaseEvent>? _rtdbSub;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _holdTimer = Stopwatch();
    _startRtdbListener();
  }

  // ── RTDB listener ──────────────────────────────────────────────────────────
  void _startRtdbListener() {
    try {
      final db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://sheshield-bd387-default-rtdb.asia-southeast1.firebasedatabase.app',
      );
      _rtdbSub = db.ref('current_status/is_alert').onValue.listen(
        (event) {
          if (!mounted) return;
          final bool isAlert = event.snapshot.value as bool? ?? false;
          // Only update visual state — never auto-trigger from RTDB here.
          // Hardware trigger is handled by SOSService directly.
          if (isAlert != _isHardwareActive) {
            setState(() => _isHardwareActive = isAlert);
          }
        },
        onError: (_) {}, // silent — RTDB optional
      );
    } catch (_) {
      // Firebase not ready yet or RTDB not configured — ignore
    }
  }

  // ── Animations ─────────────────────────────────────────────────────────────
  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: Duration(milliseconds: AppConstants.sosButtonPulseMs),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    _rtdbSub?.cancel();
    super.dispose();
  }

  // ── Hold detection ─────────────────────────────────────────────────────────
  void _onLongPressStart(LongPressStartDetails details) {
    _isHolding = true;
    _holdProgress = 0.0;
    _holdTimer.reset();
    _holdTimer.start();
    _scaleController.forward();
    HapticFeedback.lightImpact();
    _startCountdownTimer();
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _isHolding = false;
    _holdTimer.stop();
    _holdProgress = 0.0;
    _scaleController.reverse();
    setState(() {});
  }

  void _onLongPressCancel() {
    _isHolding = false;
    _holdTimer.stop();
    _holdProgress = 0.0;
    _scaleController.reverse();
    setState(() {});
  }

  void _startCountdownTimer() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_isHolding && mounted) {
        final elapsedMs = _holdTimer.elapsedMilliseconds;
        final progress =
            (elapsedMs / AppConstants.sosHoldDurationMs).clamp(0.0, 1.0);
        widget.onCountdownUpdate?.call(progress);
        setState(() => _holdProgress = progress);
        if (progress >= 1.0) {
          _triggerSOS();
        } else {
          _startCountdownTimer();
        }
      }
    });
  }

  void _triggerSOS() {
    _isHolding = false;
    _holdTimer.stop();
    _scaleController.reverse();
    HapticFeedback.heavyImpact();
    widget.onSosTriggered();
    setState(() => _holdProgress = 0.0);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Button is "active" if user is holding OR hardware triggered
    final bool isActive = _isHolding || _isHardwareActive;

    return GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: _onLongPressEnd,
      onLongPressCancel: _onLongPressCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _scaleAnimation]),
        builder: (context, child) {
          final scale =
              isActive ? _scaleAnimation.value : _pulseAnimation.value;
          return Transform.scale(
            scale: scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Outer glow ring
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: isActive ? 186 : 190,
                        height: isActive ? 186 : 190,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive
                                ? AppColors.danger.withValues(alpha: 0.14)
                                : AppColors.primaryLight
                                    .withValues(alpha: 0.16),
                            width: 9,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isActive
                                  ? AppColors.danger.withValues(alpha: 0.20)
                                  : AppColors.primaryLight
                                      .withValues(alpha: 0.20),
                              blurRadius: isActive ? 24 : 28,
                              spreadRadius: isActive ? 3 : 6,
                            ),
                          ],
                        ),
                      ),

                      // Main button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: isActive
                                ? [AppColors.danger, AppColors.dangerDark]
                                : AppColors.sosPulseGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isActive
                                      ? AppColors.danger
                                      : AppColors.primary)
                                  .withValues(alpha: 0.30),
                              blurRadius: isActive ? 16 : 20,
                              spreadRadius: isActive ? 1 : 3,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Progress ring (holding)
                            if (_isHolding)
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(7),
                                  child: CircularProgressIndicator(
                                    value: _holdProgress,
                                    strokeWidth: 5,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.18),
                                  ),
                                ),
                              ),

                            // Hardware active pulse ring
                            if (_isHardwareActive && !_isHolding)
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(7),
                                  child: CircularProgressIndicator(
                                    value: null, // indeterminate
                                    strokeWidth: 4,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.18),
                                  ),
                                ),
                              ),

                            // Label
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 8),
                                Text(
                                  'SOS',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -1,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isHardwareActive && !_isHolding
                                      ? 'HW ALERT'
                                      : _isHolding
                                          ? 'RELAYING...'
                                          : 'HOLD 1 SEC',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(
                                        color: Colors.white
                                            .withValues(alpha: 0.95),
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                      ),
                                ),
                                if (_isHolding)
                                  Text(
                                    '${(1.0 - _holdProgress).clamp(0.0, 1.0).toStringAsFixed(1)}s',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_isHolding)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: _holdProgress,
                            minHeight: 4,
                            backgroundColor:
                                AppColors.danger.withValues(alpha: 0.18),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.danger),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Keep holding to trigger emergency alert...',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  )
                else if (_isHardwareActive)
                  Text(
                    '🚨 Hardware alert active',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                    textAlign: TextAlign.center,
                  )
                else
                  Text(
                    AppStrings.holdForSos,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
