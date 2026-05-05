import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// StealthModeSection displays stealth mode setup with tap count options
class StealthModeSection extends StatefulWidget {
  final Function(int) onTapCountChanged;

  const StealthModeSection({
    Key? key,
    required this.onTapCountChanged,
  }) : super(key: key);

  @override
  State<StealthModeSection> createState() => _StealthModeSectionState();
}

class _StealthModeSectionState extends State<StealthModeSection> {
  int _selectedTaps = 3;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== SECTION TITLE ==========
            Text(
              'Stealth Mode Setup',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),

            const SizedBox(height: 12),

            // ========== DESCRIPTION ==========
            Text(
              'In stealth mode, the app looks like a normal calculator. A secret tap pattern activates emergency recording.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withOpacity(0.7),
                    height: 1.5,
                  ),
            ),

            const SizedBox(height: 20),

            // ========== TAP COUNT OPTIONS ==========
            Text(
              'Secret taps to activate:',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),

            const SizedBox(height: 12),

            // ========== TAP BUTTONS ==========
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _TapButton(
                  label: '2 taps',
                  isSelected: _selectedTaps == 2,
                  onTap: () {
                    setState(() => _selectedTaps = 2);
                    widget.onTapCountChanged(2);
                  },
                ),
                _TapButton(
                  label: '3 taps',
                  isSelected: _selectedTaps == 3,
                  onTap: () {
                    setState(() => _selectedTaps = 3);
                    widget.onTapCountChanged(3);
                  },
                ),
                _TapButton(
                  label: '4 taps',
                  isSelected: _selectedTaps == 4,
                  onTap: () {
                    setState(() => _selectedTaps = 4);
                    widget.onTapCountChanged(4);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper widget for tap count button
class _TapButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TapButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? AppColors.primary : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.grey[600],
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: isSelected ? Colors.white : Colors.grey[600],
        ),
      ),
    );
  }
}
