import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';

/// ActionGrid displays 6 quick action cards in a 2x3 grid.
///
/// The Stealth card supports a secret tap-count trigger:
/// when [isStealthModeActive] is true, tapping the card [stealthTapCount]
/// times within 2 seconds silently activates stealth emergency mode.
class ActionGrid extends StatefulWidget {
  final VoidCallback onJourney;
  final VoidCallback onNearbyPolice;
  final VoidCallback onEvidence;
  final VoidCallback onEmergencyContacts;
  final VoidCallback onBand;
  final VoidCallback onStealth;
  final bool isJourneyModeActive;

  /// Whether stealth mode is currently enabled (from AppState).
  final bool isStealthModeActive;

  /// Number of taps required to trigger stealth (2, 3, or 4).
  final int stealthTapCount;

  const ActionGrid({
    Key? key,
    required this.onJourney,
    required this.onNearbyPolice,
    required this.onEvidence,
    required this.onEmergencyContacts,
    required this.onBand,
    required this.onStealth,
    this.isJourneyModeActive = false,
    this.isStealthModeActive = false,
    this.stealthTapCount = 3,
  }) : super(key: key);

  @override
  State<ActionGrid> createState() => _ActionGridState();
}

class _ActionGridState extends State<ActionGrid> {
  int _stealthTapCount = 0;
  DateTime? _lastStealthTap;

  void _onStealthCardTap() {
    if (!widget.isStealthModeActive) {
      // Stealth mode is off — just run the normal callback (navigate to settings)
      widget.onStealth();
      return;
    }

    final now = DateTime.now();

    // Reset counter if more than 2 seconds since last tap
    if (_lastStealthTap != null &&
        now.difference(_lastStealthTap!).inSeconds > 2) {
      _stealthTapCount = 0;
    }
    _lastStealthTap = now;
    _stealthTapCount++;

    if (_stealthTapCount >= widget.stealthTapCount) {
      // Trigger stealth emergency
      _stealthTapCount = 0;
      _lastStealthTap = null;
      HapticFeedback.heavyImpact();
      widget.onStealth();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.78,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _ActionCard(
            icon: Icons.navigation_rounded,
            title: 'Journey',
            subtitle: 'Safe route',
            color: AppColors.primary,
            onTap: widget.onJourney),
        _ActionCard(
            icon: Icons.local_police_rounded,
            title: 'Nearby',
            subtitle: 'Police & Help',
            color: AppColors.info,
            onTap: widget.onNearbyPolice),
        _ActionCard(
            icon: Icons.description_rounded,
            title: 'Evidence',
            subtitle: 'Reports',
            color: const Color(0xFFD63384),
            onTap: widget.onEvidence),
        _ActionCard(
            icon: Icons.contacts_rounded,
            title: 'Contacts',
            subtitle: 'Trusted people',
            color: AppColors.safe,
            onTap: widget.onEmergencyContacts),
        _ActionCard(
            icon: Icons.watch_rounded,
            title: 'Band',
            subtitle: 'Device',
            color: AppColors.primary,
            isActive: widget.isJourneyModeActive,
            onTap: widget.onBand),
        // Stealth card — tap N times to trigger when stealth mode is ON
        _ActionCard(
            icon: widget.isStealthModeActive
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            title: 'Stealth',
            subtitle: widget.isStealthModeActive
                ? '${widget.stealthTapCount}× to arm'
                : 'Enable in settings',
            color: widget.isStealthModeActive
                ? AppColors.danger
                : AppColors.textSecondary,
            isActive: false, // badge hidden — border color shows active state
            onTap: _onStealthCardTap),
      ],
    );
  }
}

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
    // Use theme surface so cards match dark/light background correctly
    final cardColor = Theme.of(context).colorScheme.surface;
    final borderColor =
        Theme.of(context).colorScheme.outline.withValues(alpha: 0.35);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: isActive
              ? Border.all(color: color, width: 2)
              : Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
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
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                          fontSize: 9,
                        ),
                  ),
                  if (isActive) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
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
