import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_colors.dart';
import '../providers/app_state.dart';

/// RtdbStatusCard — two separate rows:
///   1. App SOS status  — driven by AppState.sosState (always visible)
///   2. IoT device status — driven by RTDB timestamp + is_alert
///                          (only shown when RPi is actually live)
///
/// RTDB structure at `current_status`:
/// {
///   "status": "Safe",
///   "is_alert": false,
///   "video_url": "",
///   "bpm": 72,
///   "timestamp": 1234567890   ← milliseconds, updated every ~10s by RPi
/// }
class RtdbStatusCard extends StatefulWidget {
  const RtdbStatusCard({super.key});

  @override
  State<RtdbStatusCard> createState() => _RtdbStatusCardState();
}

class _RtdbStatusCardState extends State<RtdbStatusCard> {
  static const _rtdbUrl =
      'https://sheshield-bd387-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const _staleThresholdSec = 60; // device considered offline after 60s

  DatabaseReference? _ref;
  String _error = '';
  bool _timedOut = false; // true after 8s with no RTDB response

  @override
  void initState() {
    super.initState();
    _initRef();
    // If no RTDB data arrives within 8 seconds, show offline
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _ref != null) setState(() => _timedOut = true);
    });
  }

  void _initRef() {
    try {
      final db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _rtdbUrl,
      );
      _ref = db.ref('current_status');
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  static String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isSosActive = appState.isSosActive;

    return Column(
      children: [
        // ── Row 1: App SOS status ─────────────────────────────────────────
        _StatusRow(
          icon:
              isSosActive ? Icons.warning_amber_rounded : Icons.shield_rounded,
          color: isSosActive ? AppColors.danger : AppColors.safe,
          title: isSosActive ? 'SOS Active' : 'You are Safe',
          subtitle: isSosActive
              ? 'Emergency alert triggered from app'
              : 'App monitoring active — no active SOS',
          isAlert: isSosActive,
          trailing: null,
        ),

        const SizedBox(height: 10),

        // ── Row 2: IoT device status ──────────────────────────────────────
        if (_error.isNotEmpty || _ref == null)
          _StatusRow(
            icon: Icons.sensors_off_rounded,
            color: AppColors.textSecondary,
            title: 'IoT Device Offline',
            subtitle: 'Realtime Database not configured',
            isAlert: false,
            trailing: null,
          )
        else
          StreamBuilder<DatabaseEvent>(
            stream: _ref!.onValue,
            builder: (context, snapshot) {
              // Still connecting — but show offline after timeout
              if (snapshot.connectionState == ConnectionState.waiting) {
                if (_timedOut) {
                  return _StatusRow(
                    icon: Icons.sensors_off_rounded,
                    color: AppColors.textSecondary,
                    title: 'IoT Device Not Connected',
                    subtitle: 'Raspberry Pi is offline or unreachable',
                    isAlert: false,
                    trailing: null,
                  );
                }
                return _StatusRow(
                  icon: Icons.sensors_rounded,
                  color: AppColors.textSecondary,
                  title: 'Connecting to IoT device...',
                  subtitle: 'Waiting for Raspberry Pi signal',
                  isAlert: false,
                  trailing: const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              // Error / no data → device offline
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.snapshot.value == null) {
                return _StatusRow(
                  icon: Icons.sensors_off_rounded,
                  color: AppColors.textSecondary,
                  title: 'IoT Device Not Connected',
                  subtitle: 'No signal from Raspberry Pi',
                  isAlert: false,
                  trailing: null,
                );
              }

              // Parse RTDB data
              final raw = snapshot.data!.snapshot.value;
              final Map<String, dynamic> data =
                  Map<String, dynamic>.from(raw as Map);

              final bool iotAlert = data['is_alert'] == true;
              final String videoUrl = (data['video_url'] as String?) ?? '';
              final int? bpm = data['bpm'] as int?;

              // Stale check — device considered offline if no update in 60s
              final int? tsMs = data['timestamp'] as int?;
              final bool isDeviceLive = tsMs != null &&
                  DateTime.now()
                          .difference(DateTime.fromMillisecondsSinceEpoch(tsMs))
                          .inSeconds <
                      _staleThresholdSec;

              // Device hasn't written recently — show offline
              if (!isDeviceLive && !iotAlert) {
                return _StatusRow(
                  icon: Icons.sensors_off_rounded,
                  color: AppColors.textSecondary,
                  title: 'IoT Device Not Connected',
                  subtitle: tsMs != null
                      ? 'Last seen ${_timeAgo(DateTime.fromMillisecondsSinceEpoch(tsMs))}'
                      : 'Raspberry Pi not responding',
                  isAlert: false,
                  trailing: null,
                );
              }

              // Device is live or alert is active
              return Column(
                children: [
                  _StatusRow(
                    icon: iotAlert
                        ? Icons.warning_rounded
                        : Icons.sensors_rounded,
                    color: iotAlert ? AppColors.danger : AppColors.safe,
                    title:
                        iotAlert ? 'IoT Device Triggered' : 'IoT Device Online',
                    subtitle: iotAlert
                        ? 'Emergency detected by Raspberry Pi'
                        : 'Raspberry Pi monitoring active',
                    isAlert: iotAlert,
                    trailing: bpm != null
                        ? _BpmBadge(
                            bpm: bpm,
                            color: iotAlert ? AppColors.danger : AppColors.safe)
                        : _LiveDot(
                            color:
                                iotAlert ? AppColors.danger : AppColors.safe),
                  ),
                  // Video link — shown when alert active AND video URL exists
                  if (videoUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _VideoLink(videoUrl: videoUrl),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

// =============================================================================
// Single status row
// =============================================================================

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool isAlert;
  final Widget? trailing;

  const _StatusRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.isAlert,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isAlert ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: isAlert ? 0.55 : 0.28),
          width: isAlert ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color.withValues(alpha: 0.75),
                      ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// =============================================================================
// BPM badge
// =============================================================================

class _BpmBadge extends StatelessWidget {
  final int bpm;
  final Color color;
  const _BpmBadge({required this.bpm, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_rounded, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            '$bpm bpm',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Video link
// =============================================================================

class _VideoLink extends StatelessWidget {
  final String videoUrl;
  const _VideoLink({required this.videoUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(videoUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.videocam_rounded,
                color: AppColors.danger, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                videoUrl.contains('http')
                    ? 'Tap to view emergency video'
                    : 'Emergency video uploading...',
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (videoUrl.contains('http'))
              const Icon(Icons.open_in_new_rounded,
                  color: AppColors.danger, size: 14),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Pulsing live dot
// =============================================================================

class _LiveDot extends StatefulWidget {
  final Color color;
  const _LiveDot({required this.color});

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
