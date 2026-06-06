import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../models/user_model.dart';
import '../providers/app_state.dart';
import '../services/biometric_service.dart';
import '../services/iot_settings_service.dart';
import '../services/local_storage_service.dart';

/// AppSettingsSection
/// Each toggle:
///   1. Updates local widget state (instant UI feedback)
///   2. Persists to SharedPreferences (survives restarts)
///   3. Updates AppState (so other widgets react)
///   4. Writes to Firebase RTDB app_settings/ (so RPi reacts)
class AppSettingsSection extends StatefulWidget {
  final UserModel user;
  final Function(String, bool) onSettingChanged;

  const AppSettingsSection({
    Key? key,
    required this.user,
    required this.onSettingChanged,
  }) : super(key: key);

  @override
  State<AppSettingsSection> createState() => _AppSettingsSectionState();
}

class _AppSettingsSectionState extends State<AppSettingsSection> {
  bool _sosVoiceCommands = false;
  bool _aiAudioDetection = false;
  bool _autoVideoRecord = false;
  bool _journeyModeAlerts = false;
  bool _stealthMode = false;
  bool _biometricLogin = false;
  bool _loaded = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBiometric();
  }

  Future<void> _loadSettings() async {
    final s = await LocalStorageService.loadSettings();
    if (!mounted) return;
    setState(() {
      _sosVoiceCommands = s.sosVoiceCommands;
      _aiAudioDetection = s.aiAudioDetection;
      _autoVideoRecord = s.autoVideoRecord;
      _journeyModeAlerts = s.journeyModeAlerts;
      _stealthMode = s.stealthMode;
      _biometricLogin = s.biometricLogin;
      _loaded = true;
    });

    // Sync all IoT settings to RTDB on load (ensures RPi is in sync)
    IotSettingsService.syncAll(
      voiceTrigger: s.sosVoiceCommands,
      audioDetection: s.aiAudioDetection,
      autoVideo: s.autoVideoRecord,
    );
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    if (mounted) setState(() => _biometricAvailable = available);
  }

  // ── Toggle handler ─────────────────────────────────────────────────────────

  void _toggle(String key, bool value) {
    setState(() {
      switch (key) {
        case 'sosVoiceCommands':
          _sosVoiceCommands = value;
          LocalStorageService.saveVoiceCommands(value);
          IotSettingsService.setVoiceTrigger(value);
          context.read<AppState>().setVoiceTriggerEnabled(value);
        case 'aiAudioDetection':
          _aiAudioDetection = value;
          LocalStorageService.saveAiAudio(value);
          IotSettingsService.setAudioDetection(value);
          context.read<AppState>().setAudioTriggerEnabled(value);
        case 'autoVideoRecord':
          _autoVideoRecord = value;
          LocalStorageService.saveAutoVideo(value);
          IotSettingsService.setAutoVideo(value);
        case 'journeyModeAlerts':
          _journeyModeAlerts = value;
          LocalStorageService.saveJourneyAlerts(value);
          context.read<AppState>().setJourneyModeActive(value);
        case 'stealthMode':
          _stealthMode = value;
          LocalStorageService.saveStealthMode(value);
          context.read<AppState>().setStealthModeActive(value);
        case 'biometricLogin':
          _biometricLogin = value;
          LocalStorageService.saveBiometricLogin(value);
      }
    });
    widget.onSettingChanged(key, value);
  }

  // ── Biometric toggle — verify before enabling ──────────────────────────────

  Future<void> _handleBiometricToggle(bool value) async {
    if (value) {
      // Verify biometric works before enabling
      if (!_biometricAvailable) {
        _showSnack(
            'No biometric enrolled on this device. Set up fingerprint or Face ID in phone settings.');
        return;
      }
      final ok = await BiometricService.authenticate(
        reason: 'Verify your biometric to enable this feature',
      );
      if (!ok) {
        _showSnack('Biometric verification failed. Feature not enabled.');
        return;
      }
    }
    _toggle('biometricLogin', value);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
            height: 60, child: Center(child: CircularProgressIndicator())),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('App Settings',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),

            // ── SOS Voice Commands ─────────────────────────────────────────
            _SettingToggleRow(
              icon: Icons.mic_rounded,
              title: 'SOS Voice Commands',
              subtitle: _sosVoiceCommands
                  ? 'Active — RPi listening for: help, bachao, danger'
                  : 'Trigger SOS with voice keywords',
              value: _sosVoiceCommands,
              activeColor: AppColors.safe,
              onChanged: (v) => _toggle('sosVoiceCommands', v),
            ),
            const SizedBox(height: 16),

            // ── AI Audio Detection ─────────────────────────────────────────
            _SettingToggleRow(
              icon: Icons.hearing_rounded,
              title: 'AI Audio Detection',
              subtitle: _aiAudioDetection
                  ? 'Active — RPi detecting screams & distress sounds'
                  : 'Detect screams and distress sounds via IoT',
              value: _aiAudioDetection,
              activeColor: AppColors.safe,
              onChanged: (v) => _toggle('aiAudioDetection', v),
            ),
            const SizedBox(height: 16),

            // ── Auto Video Record ──────────────────────────────────────────
            _SettingToggleRow(
              icon: Icons.videocam_rounded,
              title: 'Auto Video Record',
              subtitle: _autoVideoRecord
                  ? 'Active — RPi will record 30s on SOS trigger'
                  : '30s recording from IoT camera on SOS trigger',
              value: _autoVideoRecord,
              activeColor: AppColors.safe,
              onChanged: (v) => _toggle('autoVideoRecord', v),
            ),
            const SizedBox(height: 16),

            // ── Journey Mode Alerts ────────────────────────────────────────
            _SettingToggleRow(
              icon: Icons.navigation_rounded,
              title: 'Journey Mode Alerts',
              subtitle: 'Notify contacts if you deviate from route',
              value: _journeyModeAlerts,
              onChanged: (v) => _toggle('journeyModeAlerts', v),
            ),
            const SizedBox(height: 16),

            // ── Stealth Mode ───────────────────────────────────────────────
            _SettingToggleRow(
              icon: Icons.visibility_off_rounded,
              title: 'Stealth Mode',
              subtitle: 'Hidden calculator disguise',
              value: _stealthMode,
              onChanged: (v) => _toggle('stealthMode', v),
            ),
            const SizedBox(height: 16),

            // ── Biometric Login ────────────────────────────────────────────
            _SettingToggleRow(
              icon: Icons.fingerprint_rounded,
              title: 'Biometric Login',
              subtitle: _biometricAvailable
                  ? (_biometricLogin
                      ? 'Enabled — fingerprint / Face ID active'
                      : 'Use fingerprint or Face ID to unlock app')
                  : 'No biometric enrolled on this device',
              value: _biometricLogin,
              enabled: _biometricAvailable,
              onChanged: (v) => _handleBiometricToggle(v),
            ),

            // Biometric unavailable hint
            if (!_biometricAvailable) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: Text(
                  'Set up fingerprint or Face ID in your phone\'s security settings first.',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Toggle row widget
// =============================================================================

class _SettingToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final Color? activeColor;
  final Function(bool) onChanged;

  const _SettingToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        value && activeColor != null ? activeColor! : AppColors.primary;
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: value ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    subtitle,
                    key: ValueKey(subtitle),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: value && activeColor != null
                              ? activeColor!.withValues(alpha: 0.85)
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                        ),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeTrackColor: value
                ? (activeColor ?? const Color(0xFF34C759)) // iOS green
                : null,
            activeThumbColor: Colors.white,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
