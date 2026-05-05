import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/bracelet_model.dart';

/// BraceletCard displays real-time bracelet data.
/// Shows: Heart rate (BPM), battery percentage, connection status.
class BraceletCard extends StatelessWidget {
  /// Current bracelet data
  final BraceletModel braceletData;

  /// Optional callback when card is tapped
  final VoidCallback? onTap;

  const BraceletCard({
    Key? key,
    required this.braceletData,
    this.onTap,
  }) : super(key: key);

  // ========== HELPERS ==========
  Color get _statusColor {
    if (!braceletData.isConnected) return AppColors.danger;
    if (braceletData.isCriticalBattery) return AppColors.warning;
    return AppColors.safe;
  }

  String get _statusText {
    if (!braceletData.isConnected) return 'Disconnected';
    return 'Connected';
  }

  String get _bpmStatusText {
    if (braceletData.bpm == 0) return 'N/A';
    if (braceletData.isNormalHeartRate) return 'Normal';
    if (braceletData.isElevatedHeartRate) return 'Elevated';
    if (braceletData.isCriticalHeartRate) return 'Critical';
    return 'Low';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withOpacity(0.05),
              blurRadius: 12,
            ),
          ],
        ),
        child: Column(
          children: [
            // ========== HEADER ==========
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Title
                Expanded(
                  child: Text(
                    'Band',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Connection status indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _statusColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _statusText,
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: _statusColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ========== METRICS ROW ==========
            Row(
              children: [
                // ========== HEART RATE ==========
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_rounded,
                          color: AppColors.danger,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(scale: animation, child: child);
                          },
                          child: Text(
                            braceletData.bpm.toString(),
                            key: ValueKey(braceletData.bpm),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.danger,
                                ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'BPM',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _bpmStatusText,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // ========== BATTERY ==========
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          braceletData.batteryPercentage > 50
                              ? Icons.battery_full_rounded
                              : braceletData.batteryPercentage > 20
                                  ? Icons.battery_std_rounded
                                  : Icons.battery_alert_rounded,
                          color: braceletData.isCriticalBattery
                              ? AppColors.danger
                              : braceletData.isLowBattery
                                  ? AppColors.warning
                                  : AppColors.safe,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${braceletData.batteryPercentage}%',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Battery',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          braceletData.getBatteryStatus(),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ========== LAST UPDATE TIME ==========
            if (braceletData.lastUpdateTime != null)
              Text(
                'Last update: ${braceletData.lastUpdateTime?.toString().split('.')[0]}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
