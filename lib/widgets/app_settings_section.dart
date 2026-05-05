import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/user_model.dart';

/// AppSettingsSection displays app settings with toggle switches
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
  late bool _sosVoiceCommands;
  late bool _aiAudioDetection;
  late bool _autoVideoRecord;
  late bool _journeyModeAlerts;
  late bool _stealthMode;
  late bool _biometricLogin;

  @override
  void initState() {
    super.initState();
    _sosVoiceCommands = widget.user.isVoiceTriggerEnabled;
    _aiAudioDetection = widget.user.isAudioTriggerEnabled;
    _autoVideoRecord = false; // Can be added to UserModel
    _journeyModeAlerts = widget.user.isJourneyModeAutoArm;
    _stealthMode = widget.user.isStealthModeEnabled;
    _biometricLogin = false; // Can be added to UserModel
  }

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
              'App Settings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),

            const SizedBox(height: 16),

            // ========== SOS VOICE COMMANDS ==========
            _SettingToggleRow(
              icon: Icons.mic_none,
              title: 'SOS Voice Commands',
              subtitle: 'Trigger with keywords: help, bachao, danger',
              value: _sosVoiceCommands,
              onChanged: (value) {
                setState(() => _sosVoiceCommands = value);
                widget.onSettingChanged('sosVoiceCommands', value);
              },
            ),

            const SizedBox(height: 16),

            // ========== AI AUDIO DETECTION ==========
            _SettingToggleRow(
              icon: Icons.volume_up_outlined,
              title: 'AI Audio Detection',
              subtitle: 'Detect screams and distress sounds',
              value: _aiAudioDetection,
              onChanged: (value) {
                setState(() => _aiAudioDetection = value);
                widget.onSettingChanged('aiAudioDetection', value);
              },
            ),

            const SizedBox(height: 16),

            // ========== AUTO VIDEO RECORD ==========
            _SettingToggleRow(
              icon: Icons.videocam_outlined,
              title: 'Auto Video Record',
              subtitle: '30s recording on SOS trigger',
              value: _autoVideoRecord,
              onChanged: (value) {
                setState(() => _autoVideoRecord = value);
                widget.onSettingChanged('autoVideoRecord', value);
              },
            ),

            const SizedBox(height: 16),

            // ========== JOURNEY MODE ALERTS ==========
            _SettingToggleRow(
              icon: Icons.navigation_outlined,
              title: 'Journey Mode Alerts',
              subtitle: 'Notify if you deviate from route',
              value: _journeyModeAlerts,
              onChanged: (value) {
                setState(() => _journeyModeAlerts = value);
                widget.onSettingChanged('journeyModeAlerts', value);
              },
            ),

            const SizedBox(height: 16),

            // ========== STEALTH MODE ==========
            _SettingToggleRow(
              icon: Icons.no_encryption_outlined,
              title: 'Stealth Mode',
              subtitle: 'Hidden calculator disguise',
              value: _stealthMode,
              onChanged: (value) {
                setState(() => _stealthMode = value);
                widget.onSettingChanged('stealthMode', value);
              },
            ),

            const SizedBox(height: 16),

            // ========== BIOMETRIC LOGIN ==========
            _SettingToggleRow(
              icon: Icons.fingerprint,
              title: 'Biometric Login',
              subtitle: 'Fingerprint / Face ID',
              value: _biometricLogin,
              onChanged: (value) {
                setState(() => _biometricLogin = value);
                widget.onSettingChanged('biometricLogin', value);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper widget for settings toggle row
class _SettingToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Function(bool) onChanged;

  const _SettingToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ========== ICON ==========
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 20,
          ),
        ),

        const SizedBox(width: 12),

        // ========== TEXT ==========
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.color
                          ?.withOpacity(0.6),
                    ),
              ),
            ],
          ),
        ),

        // ========== TOGGLE SWITCH ==========
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ],
    );
  }
}
