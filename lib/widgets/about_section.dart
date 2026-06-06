import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// AboutSection — App Version, How It Works, Privacy Policy
class AboutSection extends StatelessWidget {
  const AboutSection({Key? key}) : super(key: key);

  static const _appVersion = '1.0.0';
  static const _buildNumber = '1';

  @override
  Widget build(BuildContext context) {
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
            Text('About',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),

            // App Version
            _AboutRow(
              icon: Icons.info_outline_rounded,
              label: 'App Version',
              value: 'v$_appVersion ($_buildNumber)',
              onTap: () => _showVersionDialog(context),
            ),
            const Divider(height: 1, indent: 36),
            const SizedBox(height: 4),

            // How It Works
            _AboutRow(
              icon: Icons.help_outline_rounded,
              label: 'How It Works',
              value: 'See guide',
              onTap: () => _showHowItWorksDialog(context),
            ),
            const Divider(height: 1, indent: 36),
            const SizedBox(height: 4),

            // Privacy Policy
            _AboutRow(
              icon: Icons.lock_outline_rounded,
              label: 'Privacy Policy',
              value: 'View',
              onTap: () => _showPrivacyPolicyDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showVersionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.shield_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          const Text('SheShield'),
        ]),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VersionRow('Version', 'v$_appVersion'),
              _VersionRow('Build', _buildNumber),
              _VersionRow('Platform', 'Android'),
              _VersionRow('Developer', 'SheShield Team'),
              _VersionRow('Release', 'May 2026'),
              const SizedBox(height: 12),
              Text(
                  'Built with Flutter & Firebase.\nPowered by Raspberry Pi IoT integration.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _showHowItWorksDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.help_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('How SheShield Works',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 20),
            _HowItWorksStep(
              number: '1',
              color: AppColors.primary,
              title: 'Hold SOS Button',
              desc:
                  'Press and hold the SOS button for 1 second to trigger an emergency alert. The app immediately notifies your emergency contacts with your live GPS location.',
            ),
            _HowItWorksStep(
              number: '2',
              color: AppColors.danger,
              title: 'Automatic Alerts',
              desc:
                  'SMS messages are sent to all your emergency contacts with a Google Maps link to your exact location. The alert is also logged to our secure cloud.',
            ),
            _HowItWorksStep(
              number: '3',
              color: AppColors.info,
              title: 'IoT Integration',
              desc:
                  'Your Raspberry Pi device monitors your environment 24/7. It can detect distress sounds (AI audio detection), trigger SOS via voice commands, and record 30-second video evidence automatically.',
            ),
            _HowItWorksStep(
              number: '4',
              color: AppColors.safe,
              title: 'Journey Mode',
              desc:
                  'Plan your route and enable Journey Mode. The app monitors your path in real time — if you deviate more than 200m or stop for more than 5 minutes, your contacts are automatically alerted.',
            ),
            _HowItWorksStep(
              number: '5',
              color: AppColors.warning,
              title: 'Evidence Collection',
              desc:
                  'All SOS events are stored as tamper-proof evidence with GPS coordinates, timestamps, and video. You can view and export reports from the Evidence tab.',
            ),
            _HowItWorksStep(
              number: '6',
              color: AppColors.primary,
              title: 'Biometric Security',
              desc:
                  'Enable biometric login to protect the app with your fingerprint or Face ID. Only you can access your safety data.',
              isLast: true,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Got it'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.lock_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Privacy Policy',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 6),
            Text('Last updated: May 2026',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 20),
            _PolicySection('1. Data We Collect',
                'SheShield collects your GPS location, emergency contact details, medical information, and SOS event logs. This data is used solely to provide emergency safety services.'),
            _PolicySection('2. How We Use Your Data',
                'Your location is shared with emergency contacts only during an active SOS event. Medical information is stored locally on your device and is never shared without your consent. SOS event logs are stored in Firebase for evidence purposes.'),
            _PolicySection('3. IoT Device Data',
                'If you use the Raspberry Pi integration, audio and video data captured by the device is processed locally. Video evidence is uploaded to Firebase Storage only during an active SOS event and is accessible only to you.'),
            _PolicySection('4. Data Storage',
                'Your data is stored using Firebase (Google Cloud) with industry-standard encryption. Local settings and contacts are stored on your device using Android SharedPreferences.'),
            _PolicySection('5. Biometric Data',
                'Biometric authentication (fingerprint/Face ID) is handled entirely by your device\'s operating system. SheShield never stores or transmits biometric data.'),
            _PolicySection('6. Third-Party Services',
                'We use Firebase (Google) for authentication, database, and storage. We use OpenStreetMap and Nominatim for mapping services. We use OSRM for route calculation. None of these services receive your personal data beyond what is necessary for their function.'),
            _PolicySection('7. Your Rights',
                'You can delete your account and all associated data at any time from the Settings screen. You can export your SOS evidence reports from the Evidence tab.'),
            _PolicySection('8. Contact',
                'For privacy concerns, contact us at privacy@sheshield.app'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('I Understand'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// =============================================================================
// Helper widgets
// =============================================================================

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _AboutRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500))),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: AppColors.textSecondary),
        ]),
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  final String label;
  final String value;
  const _VersionRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13))),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  final String number;
  final Color color;
  final String title;
  final String desc;
  final bool isLast;

  const _HowItWorksStep({
    required this.number,
    required this.color,
    required this.title,
    required this.desc,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
              child: Text(number,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14))),
        ),
        if (!isLast)
          Container(width: 2, height: 40, color: color.withValues(alpha: 0.2)),
      ]),
      const SizedBox(width: 14),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Text(desc,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey[600], height: 1.4)),
          ]),
        ),
      ),
    ]);
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String content;
  const _PolicySection(this.title, this.content);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 4),
        Text(content,
            style:
                TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5)),
      ]),
    );
  }
}
