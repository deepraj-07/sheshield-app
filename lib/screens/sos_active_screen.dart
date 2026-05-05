import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../models/contact_model.dart';
import '../providers/app_state.dart';

class SosActiveScreen extends StatefulWidget {
  const SosActiveScreen({super.key});

  @override
  State<SosActiveScreen> createState() => _SosActiveScreenState();
}

class _SosActiveScreenState extends State<SosActiveScreen> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  int _completedStepCount = 1;

  static const int _totalSteps = 6;

  @override
  void initState() {
    super.initState();
    final triggeredAt = context.read<AppState>().sosTriggeredAt ?? DateTime.now();
    _elapsed = DateTime.now().difference(triggeredAt);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final activeAt = context.read<AppState>().sosTriggeredAt ?? triggeredAt;
      setState(() {
        _elapsed = DateTime.now().difference(activeAt);
        if (_completedStepCount < _totalSteps) {
          _completedStepCount++;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cancelSos() async {
    if (!mounted) return;
    context.read<AppState>().setSosState(SosState.idle);
    Navigator.of(context).pop();
  }

  void _callPolice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calling police (100)...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final contacts = appState.emergencyContacts;
    final notifiedContacts = contacts.isNotEmpty
        ? contacts.take(2).toList(growable: false)
        : <ContactModel>[
            ContactModel(
              contactId: '1',
              userId: 'local',
              name: 'Anjali Sharma',
              phoneNumber: '+91 98765 11111',
              relationship: 'Family',
              createdAt: DateTime.now(),
            ),
            ContactModel(
              contactId: '2',
              userId: 'local',
              name: 'Meera Singh',
              phoneNumber: '+91 98765 22222',
              relationship: 'Friend',
              createdAt: DateTime.now(),
            ),
          ];

    final steps = [
      'GPS Location captured',
      'SMS sent to ${notifiedContacts.length} contacts',
      'Video recording started',
      'Evidence collection active',
      'Uploading to secure server...',
      'Nearby help found (3)',
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _cancelSos();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.danger,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 28),
              Text(
                'EMERGENCY ACTIVE',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 190,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 156,
                      height: 156,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                          width: 2,
                        ),
                      ),
                    ),
                    Container(
                      width: 138,
                      height: 138,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                    ),
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SOS',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -2,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Active since ${_elapsed.inSeconds}s',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F7FB),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionCard(
                          child: Column(
                            children: [
                              for (final step in steps)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: steps.indexOf(step) < _completedStepCount
                                              ? const Color(0xFF22C55E)
                                              : const Color(0xFFE5E7EB),
                                        ),
                                        child: Icon(
                                          steps.indexOf(step) < _completedStepCount ? Icons.check_rounded : Icons.circle,
                                          color: steps.indexOf(step) < _completedStepCount ? Colors.white : const Color(0xFFCBD5E1),
                                          size: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          step,
                                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                color: steps.indexOf(step) < _completedStepCount
                                                    ? AppColors.textPrimary
                                                    : const Color(0xFF9CA3AF),
                                                fontWeight: steps.indexOf(step) < _completedStepCount
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _SectionCard(
                          title: 'Contacts Notified',
                          child: Column(
                            children: [
                              for (final contact in notifiedContacts)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: AppColors.primary,
                                        child: Text(
                                          contact.name.isNotEmpty ? contact.name[0] : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              contact.name,
                                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              contact.formattedPhoneNumber,
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD1FAE5),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          'Notified',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: const Color(0xFF16A34A),
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _callPolice,
                            icon: const Icon(Icons.call_rounded),
                            label: const Text('CALL POLICE (100)'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFB91C1C),
                              side: const BorderSide(color: Color(0xFFB91C1C), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _cancelSos,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFEE2E2),
                              foregroundColor: const Color(0xFFB91C1C),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('CANCEL SOS'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;

  const _SectionCard({this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
          ],
          child,
        ],
      ),
    );
  }
}