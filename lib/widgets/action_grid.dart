import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// ActionGrid displays 6 quick action cards in a 2x3 grid.
/// Actions: Journey, Nearby, Evidence, Contacts, Band, Stealth
class ActionGrid extends StatelessWidget {
  /// Callback when Journey card is tapped
  final VoidCallback onJourney;

  /// Callback when Nearby card is tapped
  final VoidCallback onNearbyPolice;

  /// Callback when Evidence card is tapped
  final VoidCallback onEvidence;

  /// Callback when Contacts card is tapped
  final VoidCallback onEmergencyContacts;

  /// Callback when Band card is tapped
  final VoidCallback onBand;

  /// Callback when Stealth card is tapped
  final VoidCallback onStealth;

  /// Whether journey mode is currently active
  final bool isJourneyModeActive;

  const ActionGrid({
    Key? key,
    required this.onJourney,
    required this.onNearbyPolice,
    required this.onEvidence,
    required this.onEmergencyContacts,
    required this.onBand,
    required this.onStealth,
    this.isJourneyModeActive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.82,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // ========== JOURNEY ==========
        _ActionCard(
          icon: Icons.navigation_rounded,
          title: 'Journey',
          subtitle: 'Safe route',
          color: AppColors.primary,
          onTap: onJourney,
        ),

        // ========== NEARBY ==========
        _ActionCard(
          icon: Icons.local_police_rounded,
          title: 'Nearby',
          subtitle: 'Police & Help',
          color: AppColors.info,
          onTap: onNearbyPolice,
        ),

        // ========== EVIDENCE ==========
        _ActionCard(
          icon: Icons.description_rounded,
          title: 'Evidence',
          subtitle: 'Reports',
          color: const Color(0xFFD63384),
          onTap: onEvidence,
        ),

        // ========== CONTACTS ==========
        _ActionCard(
          icon: Icons.contacts_rounded,
          title: 'Contacts',
          subtitle: 'Trusted people',
          color: AppColors.safe,
          onTap: onEmergencyContacts,
        ),

        // ========== BAND ==========
        _ActionCard(
          icon: Icons.watch_rounded,
          title: 'Band',
          subtitle: 'Device',
          color: const Color(0xFF7C3AED),
          isActive: isJourneyModeActive,
          onTap: onBand,
        ),

        // ========== STEALTH ==========
        _ActionCard(
          icon: Icons.visibility_off_rounded,
          title: 'Stealth',
          subtitle: 'Hide alerts',
          color: AppColors.textPrimary,
          onTap: onStealth,
        ),
      ],
    );
  }
}

/// Individual action card component
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: isActive
              ? Border.all(color: color, width: 2)
              : Border.all(color: AppColors.border.withValues(alpha: 0.45), width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ========== ICON ==========
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 22,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ========== TITLE ==========
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontSize: 11,
                        ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 9,
                        ),
                  ),

                  // ========== ACTIVE INDICATOR ==========
                  if (isActive) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Active',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                              fontSize: 8,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
