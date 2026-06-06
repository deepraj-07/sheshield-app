import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../models/contact_model.dart';
import '../providers/app_state.dart';
import '../services/local_storage_service.dart';
import '../services/stealth_mode_service.dart';

/// StealthModeSection — full stealth emergency mode UI.
///
/// Features:
///   • Toggle to enable/disable stealth mode
///   • Tap count selector (2 / 3 / 4 taps) — persisted to SharedPreferences
///   • Hidden tap zone — tap the required number of times to trigger silently
///   • Live session status indicator when active
///   • Stop button to end the session
class StealthModeSection extends StatefulWidget {
  final Function(int) onTapCountChanged;

  const StealthModeSection({
    Key? key,
    required this.onTapCountChanged,
  }) : super(key: key);

  @override
  State<StealthModeSection> createState() => _StealthModeSectionState();
}

class _StealthModeSectionState extends State<StealthModeSection>
    with SingleTickerProviderStateMixin {
  int _selectedTaps = 3;
  int _tapCount = 0;
  DateTime? _lastTapTime;

  // Pulse animation for active session indicator
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  final StealthModeService _stealthService = StealthModeService();

  @override
  void initState() {
    super.initState();
    _loadTapCount();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTapCount() async {
    final saved = await LocalStorageService.loadStealthTapCount();
    if (mounted) {
      setState(() => _selectedTaps = saved);
    }
  }

  void _setTapCount(int count) {
    setState(() => _selectedTaps = count);
    LocalStorageService.saveStealthTapCount(count);
    widget.onTapCountChanged(count);
  }

  // ── Hidden tap trigger ─────────────────────────────────────────────────────

  void _onHiddenTap() {
    final appState = context.read<AppState>();
    if (!appState.isStealthModeActive) return; // only works when stealth is ON

    final now = DateTime.now();
    // Reset tap count if more than 2 seconds since last tap
    if (_lastTapTime != null && now.difference(_lastTapTime!).inSeconds > 2) {
      _tapCount = 0;
    }
    _lastTapTime = now;
    _tapCount++;

    if (_tapCount >= _selectedTaps) {
      _tapCount = 0;
      _lastTapTime = null;
      HapticFeedback.heavyImpact();
      _triggerStealthEmergency();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _triggerStealthEmergency() async {
    final appState = context.read<AppState>();
    if (appState.isStealthSessionActive) return; // already active

    // Get contacts from AppState
    final contacts = appState.emergencyContacts;

    // Mark session active in AppState immediately
    final sessionId = 'stealth_${DateTime.now().millisecondsSinceEpoch}';
    appState.setStealthSessionActive(true, sessionId: sessionId);

    // Activate stealth service in background
    await _stealthService.activate(
      triggerSource: 'tap_pattern',
      contacts: contacts.isNotEmpty ? contacts : _buildFallbackContacts(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.shield_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Stealth emergency activated silently'),
          ]),
          backgroundColor: AppColors.danger,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _stopStealthSession() async {
    final appState = context.read<AppState>();
    await _stealthService.deactivate();
    appState.setStealthSessionActive(false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stealth session ended'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  List<ContactModel> _buildFallbackContacts() => [];

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isStealthOn = appState.isStealthModeActive;
    final isSessionActive = appState.isStealthSessionActive;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSessionActive
                ? AppColors.danger.withValues(alpha: 0.5)
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: isSessionActive ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSessionActive
                  ? AppColors.danger.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isStealthOn ? AppColors.danger : AppColors.primary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isStealthOn
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: isStealthOn ? AppColors.danger : AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stealth Mode',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        isStealthOn
                            ? 'Active — tap zone enabled'
                            : 'Enable for silent emergency trigger',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: isStealthOn
                                  ? AppColors.danger.withValues(alpha: 0.8)
                                  : AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                // Stealth toggle is controlled from AppSettingsSection
                // Show read-only indicator here
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isStealthOn
                        ? AppColors.danger.withValues(alpha: 0.12)
                        : AppColors.textSecondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isStealthOn ? 'ON' : 'OFF',
                    style: TextStyle(
                      color: isStealthOn
                          ? AppColors.danger
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 12),

            // ── Active session banner ────────────────────────────────────
            if (isSessionActive) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Opacity(
                    opacity: _pulseAnim.value,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.4)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: AppColors.danger, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('STEALTH EMERGENCY ACTIVE',
                                  style: TextStyle(
                                      color: AppColors.danger,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      letterSpacing: 0.5)),
                              Text(
                                'Live tracking • SMS sent • IoT alerted',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        color: AppColors.danger
                                            .withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _stopStealthSession,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('STOP',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Description ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Tap the hidden zone below the required number of times to silently trigger emergency mode. No visible alert — works in background.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Tap count selector ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Secret tap count:',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Row(
                    children: [2, 3, 4].map((count) {
                      final selected = _selectedTaps == count;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => _setTapCount(count),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .outline
                                          .withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                '$count taps',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Hidden tap zone ──────────────────────────────────────────
            GestureDetector(
              onTap: _onHiddenTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isStealthOn
                      ? AppColors.danger.withValues(alpha: 0.06)
                      : AppColors.textSecondary.withValues(alpha: 0.04),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      size: 16,
                      color: isStealthOn
                          ? AppColors.danger.withValues(alpha: 0.6)
                          : AppColors.textSecondary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isStealthOn
                          ? 'Tap here $_selectedTaps times to trigger silently'
                          : 'Enable Stealth Mode to activate tap trigger',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isStealthOn
                                ? AppColors.danger.withValues(alpha: 0.6)
                                : AppColors.textSecondary
                                    .withValues(alpha: 0.4),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
