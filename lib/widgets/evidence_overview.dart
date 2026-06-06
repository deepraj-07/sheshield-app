import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../models/sos_event_model.dart';
import '../providers/app_state.dart';
import '../screens/report_detail.dart';
import '../services/email_service.dart';
import '../services/evidence_service.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';

enum _Filter { all, thisWeek, thisMonth }

class EvidenceOverview extends StatefulWidget {
  const EvidenceOverview({super.key});

  @override
  State<EvidenceOverview> createState() => _EvidenceOverviewState();
}

class _EvidenceOverviewState extends State<EvidenceOverview> {
  final EvidenceService _evidenceService = EvidenceService();
  final FirebaseService _fs = FirebaseService();

  _Filter _activeFilter = _Filter.all;

  // ── Real-time Firestore stream ─────────────────────────────────────────────
  // Listens to ALL sos_events for this user — updates instantly when any
  // device (app button, IoT hardware, bracelet) triggers an SOS.
  Stream<List<SosEventModel>>? _stream;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _streamSub;

  // ── Busy flag for delete/share actions ────────────────────────────────────
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  // ── Stream setup ──────────────────────────────────────────────────────────

  Future<void> _initStream() async {
    await _fs.init();
    final userId = _fs.auth.currentUser?.uid;
    if (userId == null || !mounted) return;

    // Real-time stream — ordered by timestamp descending.
    // Includes ALL SOS events for this user regardless of trigger source
    // (app button, IoT hardware, bracelet) — updates instantly.
    final query = _fs.firestore
        .collection(AppConstants.firestoreSosEventsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(200);

    setState(() {
      _stream = query.snapshots().handleError((e) {
        // If composite index is missing, fall back to unordered query
        // and sort client-side
        if (e.toString().contains('index') ||
            e.toString().contains('FAILED_PRECONDITION')) {
          _fallbackStream(userId);
        }
      }).map((snap) =>
          snap.docs.map((d) => SosEventModel.fromFirestore(d)).toList());
    });
  }

  /// Fallback: fetch without orderBy (no composite index needed), sort client-side.
  void _fallbackStream(String userId) {
    final query = _fs.firestore
        .collection(AppConstants.firestoreSosEventsCollection)
        .where('userId', isEqualTo: userId)
        .limit(200);

    if (!mounted) return;
    setState(() {
      _stream = query.snapshots().map((snap) {
        final list =
            snap.docs.map((d) => SosEventModel.fromFirestore(d)).toList();
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return list;
      });
    });
  }

  // ── Filters ───────────────────────────────────────────────────────────────

  List<SosEventModel> _applyFilter(List<SosEventModel> all) {
    final now = DateTime.now();
    switch (_activeFilter) {
      case _Filter.thisWeek:
        final weekAgo = now.subtract(const Duration(days: 7));
        return all.where((r) => r.timestamp.isAfter(weekAgo)).toList();
      case _Filter.thisMonth:
        return all
            .where((r) =>
                r.timestamp.month == now.month && r.timestamp.year == now.year)
            .toList();
      case _Filter.all:
        return all;
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _openReport(SosEventModel report) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReportDetailScreen(
          reportId: report.eventId,
          preloadedReport: report,
        ),
      ),
    );
    // No manual refresh needed — stream updates automatically
  }

  Future<void> _shareReport(SosEventModel report) async {
    if (_busy) return;
    _setBusy(true);
    _showSnack('Sharing report…');
    try {
      final stored = await LocalStorageService.loadContacts();
      final emailContacts = stored
          .where((c) => c.email.trim().isNotEmpty)
          .map((c) => EmailContact(name: c.name, email: c.email.trim()))
          .toList();

      if (emailContacts.isNotEmpty) {
        final sent = await EmailService().sendEmergencyEmail(
          contacts: emailContacts,
          senderName: _fs.auth.currentUser?.displayName ?? 'SheShield User',
          latitude: report.latitude,
          longitude: report.longitude,
          address: report.address,
          triggerSource: 'Shared Report: ${report.eventId}',
        );
        if (sent > 0) {
          _showSnack('Report shared to $sent contact(s) via email.');
          return;
        }
      }

      // Fallback: open mail app
      final pdfUrl = await _evidenceService.getOrCreatePdfReportUrl(report);
      final subject =
          Uri.encodeComponent('SheShield SOS Report ${report.eventId}');
      final body = Uri.encodeComponent(
        'Incident ID: ${report.eventId}\n'
        'Time: ${report.timestamp.toIso8601String()}\n'
        'Location: ${report.mapsUrl}\n'
        'Address: ${report.address ?? 'Unavailable'}\n'
        'Evidence PDF: $pdfUrl\n'
        'Video: ${report.videoUrl ?? 'Unavailable'}\n'
        'SHA-256: ${report.sha256Hash ?? 'Unavailable'}',
      );
      final uri = Uri.parse('mailto:?subject=$subject&body=$body');
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showSnack('No email app and no email contacts configured.');
      }
    } catch (e) {
      _showSnack('Share failed: $e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _deleteReport(SosEventModel report) async {
    // 1. Confirm first — outside setState
    final confirmed = await _showDeleteConfirm(report.eventId);
    if (!confirmed) return;

    // 2. Now do the async work — no setState wrapping async
    _setBusy(true);
    _showSnack('Deleting…');
    try {
      await _evidenceService.deleteReport(report);
      // Stream auto-updates — no manual refresh needed
      _showSnack('Report deleted.');
    } catch (e) {
      _showSnack('Delete failed: $e');
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> _showDeleteConfirm(String eventId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete report?'),
        content: const Text(
            'This removes the SOS record and all stored evidence files. Cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _setBusy(bool value) {
    if (mounted) setState(() => _busy = value);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch AppState so we react to in-app SOS triggers too
    context.watch<AppState>();

    if (_stream == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<SosEventModel>>(
      stream: _stream,
      builder: (context, snapshot) {
        // ── Loading ──────────────────────────────────────────────────────────
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          );
        }

        // ── Error ────────────────────────────────────────────────────────────
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text('Could not load reports',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  TextButton(
                      onPressed: _initStream, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        // ── Data ─────────────────────────────────────────────────────────────
        final allReports = snapshot.data ?? [];
        final filtered = _applyFilter(allReports);
        final now = DateTime.now();
        final thisMonthCount = allReports
            .where((r) =>
                r.timestamp.month == now.month && r.timestamp.year == now.year)
            .length;
        final verifiedCount =
            allReports.where((r) => r.sha256Hash?.isNotEmpty == true).length;

        return RefreshIndicator(
          onRefresh: () async => _initStream(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Evidence Reports',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),

                // ── Live stat cards ──────────────────────────────────────────
                Row(
                  children: [
                    _StatCard(
                      value: '${allReports.length}',
                      label: 'Total SOS',
                      accentColor: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    _StatCard(
                      value: '$thisMonthCount',
                      label: 'This Month',
                      accentColor: AppColors.info,
                    ),
                    const SizedBox(width: 10),
                    _StatCard(
                      value: '$verifiedCount',
                      label: 'Verified',
                      accentColor: AppColors.safe,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Filter tabs ──────────────────────────────────────────────
                _FilterTabs(
                  active: _activeFilter,
                  onChanged: (f) => setState(() => _activeFilter = f),
                ),
                const SizedBox(height: 16),

                // ── Report list ──────────────────────────────────────────────
                if (filtered.isEmpty)
                  _EmptyState(filter: _activeFilter)
                else
                  ...filtered.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ReportCard(
                        report: r,
                        busy: _busy,
                        onOpen: () => _openReport(r),
                        onShare: () => _shareReport(r),
                        onDelete: () => _deleteReport(r),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Stat card
// =============================================================================

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color accentColor;

  const _StatCard({
    required this.value,
    required this.label,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 3,
              width: 32,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Filter tabs
// =============================================================================

class _FilterTabs extends StatelessWidget {
  final _Filter active;
  final ValueChanged<_Filter> onChanged;

  const _FilterTabs({required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _Tab(
            label: 'All',
            selected: active == _Filter.all,
            onTap: () => onChanged(_Filter.all),
          ),
          _Tab(
            label: 'This Week',
            selected: active == _Filter.thisWeek,
            onTap: () => onChanged(_Filter.thisWeek),
          ),
          _Tab(
            label: 'This Month',
            selected: active == _Filter.thisMonth,
            onTap: () => onChanged(_Filter.thisMonth),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Tab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Report card
// =============================================================================

class _ReportCard extends StatelessWidget {
  final SosEventModel report;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _ReportCard({
    required this.report,
    required this.busy,
    required this.onOpen,
    required this.onShare,
    required this.onDelete,
  });

  String _formatId(String id) {
    final clean = id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (clean.length >= 9) {
      return 'SSE-${clean.substring(0, 4)}-${clean.substring(4, 9)}';
    }
    return 'SSE-$clean';
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'pm' : 'am';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} • $hour:$min $ampm';
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final verified = report.sha256Hash?.isNotEmpty == true;
    final isNew = DateTime.now().difference(report.timestamp).inMinutes < 5;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── ID + badges ──────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatId(report.eventId),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 0.3,
                        ),
                  ),
                ),
                if (verified)
                  _Badge(
                    label: 'Verified',
                    icon: Icons.check_rounded,
                    bgColor: AppColors.safeLight,
                    textColor: AppColors.safeDark,
                    borderColor: AppColors.safe.withValues(alpha: 0.4),
                  ),
                if (isNew) ...[
                  const SizedBox(width: 6),
                  _Badge(
                    label: 'New',
                    bgColor: AppColors.primary.withValues(alpha: 0.12),
                    textColor: AppColors.primary,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),

            // ── Date/time ────────────────────────────────────────────────────
            Text(
              _formatDateTime(report.timestamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),

            // ── Location ─────────────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    report.address ?? 'Current Location',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Trigger chip + file icons ─────────────────────────────────────
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _capitalize(report.triggerSource ?? 'Button'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const Spacer(),
                _FileTypeIcon(
                    icon: Icons.mic_rounded, color: AppColors.primary),
                const SizedBox(width: 6),
                if (report.hasVideo) ...[
                  _FileTypeIcon(
                      icon: Icons.videocam_rounded, color: AppColors.info),
                  const SizedBox(width: 6),
                ],
                _FileTypeIcon(
                    icon: Icons.location_on_rounded, color: AppColors.safe),
              ],
            ),
            const SizedBox(height: 14),

            // ── Buttons ──────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: busy ? null : onOpen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'View Report',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ActionIconButton(
                  icon: Icons.share_rounded,
                  color: AppColors.primary,
                  onTap: busy ? null : onShare,
                ),
                const SizedBox(width: 6),
                _ActionIconButton(
                  icon: Icons.delete_outline_rounded,
                  color: AppColors.danger,
                  onTap: busy ? null : onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Small helpers
// =============================================================================

class _Badge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color bgColor;
  final Color textColor;
  final Color? borderColor;

  const _Badge({
    required this.label,
    this.icon,
    required this.bgColor,
    required this.textColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _FileTypeIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _FileTypeIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionIconButton({
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap != null ? color : AppColors.disabled,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final _Filter filter;

  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final msg = switch (filter) {
      _Filter.thisWeek => 'No reports this week',
      _Filter.thisMonth => 'No reports this month',
      _Filter.all => 'No SOS reports yet',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              msg,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'SOS events will appear here',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
