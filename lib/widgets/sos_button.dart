import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_strings.dart';

/// SOS Button widget - The primary emergency trigger.
/// 
/// Features:
/// - Large 160px circular button with gradient
/// - 3-second hold detection with animated countdown ring
/// - Glowing pulse animation when idle
/// - Heavy haptic feedback on trigger
/// - Displays countdown text and progress ring while holding
class SosButton extends StatefulWidget {
  /// Callback when SOS is triggered (after 3-second hold)
  final VoidCallback onSosTriggered;

  /// Optional callback during countdown (e.g., for UI updates)
  final ValueChanged<double>? onCountdownUpdate;

  const SosButton({
    Key? key,
    required this.onSosTriggered,
    this.onCountdownUpdate,
  }) : super(key: key);

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with TickerProviderStateMixin {
  // ========== ANIMATION CONTROLLERS ==========
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  // ========== STATE ==========
  bool _isHolding = false;
  double _holdProgress = 0.0; // 0.0 to 1.0
  late Stopwatch _holdTimer;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _holdTimer = Stopwatch();
  }

  void _setupAnimations() {
    // Pulse animation (continuous glow)
    _pulseController = AnimationController(
      duration: Duration(milliseconds: AppConstants.sosButtonPulseMs),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Scale animation (press down/up)
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
    super.dispose();
  }

  // ========== HOLD DETECTION ==========
  void _onLongPressStart(LongPressStartDetails details) {
    _isHolding = true;
    _holdProgress = 0.0;
    _holdTimer.reset();
    _holdTimer.start();

    // Animate scale down
    _scaleController.forward();

    // Haptic feedback
    HapticFeedback.lightImpact();

    // Start countdown timer
    _startCountdownTimer();
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _isHolding = false;
    _holdTimer.stop();
    _holdProgress = 0.0;

    // Animate scale back up
    _scaleController.reverse();

    setState(() {});
  }

  void _onLongPressCancel() {
    _isHolding = false;
    _holdTimer.stop();
    _holdProgress = 0.0;

    // Animate scale back up
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

        setState(() {
          _holdProgress = progress;
        });

        if (progress >= 1.0) {
          // SOS triggered!
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

    // Heavy haptic feedback
    HapticFeedback.heavyImpact();

    // Call SOS callback
    widget.onSosTriggered();

    // Reset after delay
    setState(() {
      _holdProgress = 0.0;
    });
  }

  // ========== BUILD UI ==========
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: _onLongPressEnd,
      onLongPressCancel: _onLongPressCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _scaleAnimation]),
        builder: (context, child) {
          // Use pulse animation only when not holding
          final scale = _isHolding ? _scaleAnimation.value : _pulseAnimation.value;

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
                      if (!_isHolding)
                        Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryLight.withValues(alpha: 0.16),
                              width: 9,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryLight.withValues(alpha: 0.20),
                                blurRadius: 28,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      if (_isHolding)
                        Container(
                          width: 186,
                          height: 186,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.14),
                              width: 9,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.danger.withValues(alpha: 0.20),
                                blurRadius: 24,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                        ),

                      // ========== BUTTON CONTAINER ==========
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _isHolding
                                ? [AppColors.danger, AppColors.dangerDark]
                                : AppColors.sosPulseGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isHolding ? AppColors.danger : AppColors.primary)
                                  .withValues(alpha: 0.30),
                                blurRadius: _isHolding ? 16 : 20,
                                spreadRadius: _isHolding ? 1 : 3,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                          // ========== PROGRESS RING (when holding) ==========
                          if (_isHolding)
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.all(7),
                                child: CircularProgressIndicator(
                                  value: _holdProgress,
                                  strokeWidth: 5,
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                                ),
                              ),
                            ),

                            // ========== CENTRAL CONTENT ==========
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                              // Icon
                              const SizedBox(height: 8),

                              Text(
                                'SOS',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1,
                                    ),
                              ),

                              const SizedBox(height: 2),

                              Text(
                                _isHolding ? 'RELAYING...' : 'HOLD 3 SEC',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.95),
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
                              ),

                                // Countdown or instructions
                                if (_isHolding)
                                  Text(
                                    '${(3.0 - (_holdProgress * 3)).toStringAsFixed(1)}s',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  )
                                else
                                  const SizedBox(height: 0),
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
                            backgroundColor: AppColors.danger.withValues(alpha: 0.18),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.danger,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Keep holding to trigger emergency alert...',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
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
