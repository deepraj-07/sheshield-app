import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';

/// SafeStatusCard displays the current safety status.
/// Green card when safe, red card when SOS is active.
/// Animates smoothly on state changes.
class SafeStatusCard extends StatelessWidget {
  /// True if user is safe (no SOS active)
  final bool isSafe;

  /// Optional custom title text
  final String? customTitle;

  const SafeStatusCard({
    Key? key,
    required this.isSafe,
    this.customTitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final title = customTitle ?? (isSafe ? AppStrings.safeStatus : AppStrings.sosActive);
    final statusColor = isSafe ? AppColors.safe : AppColors.danger;
    const statusDuration = Duration(milliseconds: 300);

    return AnimatedContainer(
      duration: statusDuration,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ========== STATUS ICON ==========
          AnimatedSwitcher(
            duration: statusDuration,
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(
              isSafe ? Icons.check_circle_rounded : Icons.warning_rounded,
              key: ValueKey(isSafe),
              size: 32,
              color: AppColors.textOnPrimary,
            ),
          ),

          const SizedBox(width: 16),

          // ========== STATUS TEXT ==========
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textOnPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  isSafe
                      ? 'You are currently safe and secure'
                      : 'Emergency alert sent to contacts',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textOnPrimary.withOpacity(0.85),
                      ),
                ),
              ],
            ),
          ),

          // ========== PULSE INDICATOR ==========
          if (!isSafe)
            SizedBox(
              width: 24,
              height: 24,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulsing circle
                  ...List.generate(3, (index) {
                    return AnimatedBuilder(
                      animation: AlwaysStoppedAnimation(index * 0.33),
                      builder: (context, child) {
                        return Container(
                          width: 24 + (index * 8).toDouble(),
                          height: 24 + (index * 8).toDouble(),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.danger.withOpacity(
                                (1 - (index * 0.33)).clamp(0, 1),
                              ),
                              width: 1.5,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                  // Center dot
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.textOnPrimary,
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
