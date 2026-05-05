import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../models/sos_event_model.dart';
import '../screens/report_detail.dart';
import '../services/evidence_service.dart';
import '../services/firebase_service.dart';

class EvidenceOverview extends StatefulWidget {
  const EvidenceOverview({super.key});

  @override
  State<EvidenceOverview> createState() => _EvidenceOverviewState();
}

class _EvidenceOverviewState extends State<EvidenceOverview> {
  final EvidenceService _evidenceService = EvidenceService();
  late Future<List<SosEventModel>> _reportsFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reportsFuture = _fetchReports();
  }

  Future<List<SosEventModel>> _fetchReports() async {
    final fs = FirebaseService();
    await fs.init();
    final userId = fs.auth.currentUser?.uid;
    if (userId == null) return [];
    final snap = await fs.firestore
        .collection(AppConstants.firestoreSosEventsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .get();
    return snap.docs.map((d) => SosEventModel.fromFirestore(d)).toList(growable: false);
  }

  void _refresh() {
    setState(() => _reportsFuture = _fetchReports());
  }

  Future<void> _openReport(SosEventModel report) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ReportDetailScreen(reportId: report.eventId)),
    );
    if (deleted == true) _refresh();
  }

  Future<void> _reportToAuthorities(SosEventModel report) async {
    final confirmed = await _confirm(
      title: 'Report incident?',
      message: 'This will generate the evidence PDF if needed and open an email draft.',
      confirmLabel: 'Report',
    );
    if (!confirmed) return;

    await _runAction('Preparing report...', () async {
      final pdfUrl = await _evidenceService.getOrCreatePdfReportUrl(report);
      final subject = Uri.encodeComponent('SheShield SOS Report ${report.eventId}');
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
        throw StateError('No email app is available to create the report draft.');
      }
      _refresh();
    });
  }

  Future<void> _deleteReport(SosEventModel report) async {
    final confirmed = await _confirm(
      title: 'Delete report?',
      message: 'This removes the SOS record and its stored evidence files. This action cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;

    await _runAction('Deleting report...', () async {
      await _evidenceService.deleteReport(report);
      _refresh();
    });
  }

  Future<void> _runAction(String progressMessage, Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    _showSnack(progressMessage);
    try {
      await action();
    } catch (e) {
      if (mounted) _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: destructive ? FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)) : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SosEventModel>>(
      future: _reportsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
        }
        final reports = snapshot.data ?? [];
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Evidence Reports',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _StatCard(title: 'Total SOS', value: '${reports.length}', color: AppColors.primary),
                  const SizedBox(width: 8),
                  _StatCard(
                    title: 'This Month',
                    value: '${reports.where((r) => r.timestamp.month == DateTime.now().month).length}',
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 8),
                  _StatCard(
                    title: 'Verified',
                    value: '${reports.where((r) => r.sha256Hash != null).length}',
                    color: AppColors.safe,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ToggleButtons(
                onPressed: (_) {},
                isSelected: const [true, false, false],
                borderRadius: BorderRadius.circular(999),
                selectedColor: Colors.white,
                fillColor: AppColors.primary,
                children: const [
                  Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('All')),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('This Week')),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('This Month')),
                ],
              ),
              const SizedBox(height: 14),
              if (reports.isEmpty) ...[
                const SizedBox(height: 40),
                Center(child: Text('No reports yet', style: Theme.of(context).textTheme.bodyLarge)),
              ] else ...[
                for (final r in reports) ...[
                  _ReportCard(
                    report: r,
                    busy: _busy,
                    onOpen: () => _openReport(r),
                    onReport: () => _reportToAuthorities(r),
                    onDelete: () => _deleteReport(r),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final SosEventModel report;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onReport;
  final VoidCallback onDelete;

  const _ReportCard({
    required this.report,
    required this.busy,
    required this.onOpen,
    required this.onReport,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final verified = report.sha256Hash != null && report.sha256Hash!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  report.eventId,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                ),
              ),
              if (verified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.safeLight, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    'Verified',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.safeDark),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${report.timestamp.day} ${_month(report.timestamp.month)} ${report.timestamp.year} - ${_formatTime(report.timestamp)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(report.address ?? 'Current Location', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: busy ? null : onOpen,
                  child: const Text('View Report'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Report incident',
                onPressed: busy ? null : onReport,
                icon: const Icon(Icons.report_rounded),
              ),
              IconButton(
                tooltip: 'Delete report',
                onPressed: busy ? null : onDelete,
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _month(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m - 1];
  }

  static String _formatTime(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute $ampm';
  }
}
