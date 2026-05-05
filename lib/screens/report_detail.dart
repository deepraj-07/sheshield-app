import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../models/sos_event_model.dart';
import '../services/evidence_service.dart';
import '../services/firebase_service.dart';

class ReportDetailScreen extends StatefulWidget {
  final String reportId;

  const ReportDetailScreen({super.key, required this.reportId});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final EvidenceService _evidenceService = EvidenceService();

  SosEventModel? _report;
  List<Map<String, dynamic>> _evidenceFiles = [];
  bool _loading = true;

  // Per-action busy flags so each button shows its own spinner
  bool _busyPdf = false;
  bool _busyVideo = false;
  bool _busyReport = false;
  bool _busyResolve = false;
  bool _busyDelete = false;

  bool get _anyBusy =>
      _busyPdf || _busyVideo || _busyReport || _busyResolve || _busyDelete;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    try {
      final fs = FirebaseService();
      await fs.init();
      final doc = await fs.firestore
          .collection(AppConstants.firestoreSosEventsCollection)
          .doc(widget.reportId)
          .get();
      if (doc.exists) {
        _report = SosEventModel.fromFirestore(doc);
        _evidenceFiles = await _evidenceService.getEvidenceFiles(_report!);
      }
    } catch (e) {
      if (mounted) _showSnack('Unable to load report: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // PDF download / generate on-demand
  // ---------------------------------------------------------------------------

  Future<void> _downloadPdf() async {
    final report = _report;
    if (report == null || _busyPdf) return;
    setState(() => _busyPdf = true);
    _showSnack(report.hasPdfReport
        ? 'Opening PDF report...'
        : 'Generating PDF report…');
    try {
      final url = await _evidenceService.getOrCreatePdfReportUrl(report);
      await _openUrl(url);
      // Reload so pdfReportUrl is cached in the model for next time
      await _loadReport();
    } catch (e) {
      if (mounted) _showSnack('PDF failed: $e');
    } finally {
      if (mounted) setState(() => _busyPdf = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Video / evidence file download
  // ---------------------------------------------------------------------------

  Future<void> _downloadVideo() async {
    final report = _report;
    if (report == null || _busyVideo) return;
    setState(() => _busyVideo = true);
    _showSnack('Fetching video evidence URL…');
    try {
      final url = await _evidenceService.getVideoDownloadUrl(report);
      await _openUrl(url);
    } catch (e) {
      if (mounted) _showSnack('Video unavailable: $e');
    } finally {
      if (mounted) setState(() => _busyVideo = false);
    }
  }

  /// Download an arbitrary evidence file by its stored URL.
  Future<void> _downloadEvidenceFile(String url, String label) async {
    _showSnack('Opening $label…');
    try {
      await _openUrl(url);
    } catch (e) {
      if (mounted) _showSnack('Could not open file: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Report to authorities (email draft)
  // ---------------------------------------------------------------------------

  Future<void> _reportToAuthorities() async {
    final report = _report;
    if (report == null || _busyReport) return;

    final confirmed = await _confirm(
      title: 'Report to authorities?',
      message:
          'This generates the PDF evidence package and opens an email draft pre-filled with incident details. You can review and send it yourself.',
      confirmLabel: 'Continue',
    );
    if (!confirmed) return;

    setState(() => _busyReport = true);
    _showSnack('Preparing evidence package…');
    try {
      final pdfUrl = await _evidenceService.getOrCreatePdfReportUrl(report);
      final subject = Uri.encodeComponent(
          'SheShield SOS Incident Report – ${report.eventId}');
      final body = Uri.encodeComponent(
        'Incident ID : ${report.eventId}\n'
        'Date/Time   : ${report.timestamp.toIso8601String()}\n'
        'Location    : ${report.address ?? '${report.latitude}, ${report.longitude}'}\n'
        'Maps link   : ${report.mapsUrl}\n'
        'Trigger     : ${report.triggerSource ?? 'Unknown'}\n'
        '\n--- Evidence ---\n'
        'PDF Report  : $pdfUrl\n'
        'Video       : ${report.videoUrl ?? 'Unavailable'}\n'
        'SHA-256     : ${report.sha256Hash ?? 'Unavailable'}\n'
        '\nThis report was generated automatically by SheShield.',
      );
      final uri = Uri.parse('mailto:?subject=$subject&body=$body');
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError(
            'No email app found. Please install an email client and try again.');
      }
    } catch (e) {
      if (mounted) _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _busyReport = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Mark resolved
  // ---------------------------------------------------------------------------

  Future<void> _markResolved() async {
    final report = _report;
    if (report == null || report.isResolved || _busyResolve) return;

    final confirmed = await _confirm(
      title: 'Mark as resolved?',
      message:
          'Evidence is preserved. The incident status will be updated to Resolved.',
      confirmLabel: 'Mark resolved',
    );
    if (!confirmed) return;

    setState(() => _busyResolve = true);
    _showSnack('Updating status…');
    try {
      await _evidenceService.markReportResolved(report);
      await _loadReport();
      if (mounted) _showSnack('Marked as resolved.');
    } catch (e) {
      if (mounted) _showSnack('Update failed: $e');
    } finally {
      if (mounted) setState(() => _busyResolve = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Delete report (two-step confirmation)
  // ---------------------------------------------------------------------------

  Future<void> _deleteReport() async {
    final report = _report;
    if (report == null || _busyDelete) return;

    // Step 1 – warn
    final step1 = await _confirm(
      title: 'Delete this report?',
      message:
          'All evidence files (video, PDF) stored in Firebase will be permanently removed. '
          'This cannot be undone.',
      confirmLabel: 'Continue',
      destructive: true,
    );
    if (!step1) return;

    // Step 2 – type-to-confirm
    final step2 = await _confirmTyped(
      title: 'Confirm deletion',
      instruction: 'Type DELETE to confirm',
      expectedValue: 'DELETE',
    );
    if (!step2) return;

    setState(() => _busyDelete = true);
    _showSnack('Deleting report and evidence…');
    try {
      await _evidenceService.deleteReport(report);
      if (mounted) {
        _showSnack('Report deleted.');
        Navigator.of(context)
            .pop(true); // signal caller that report was deleted
      }
    } catch (e) {
      if (mounted) _showSnack('Delete failed: $e');
    } finally {
      if (mounted) setState(() => _busyDelete = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError(
          'Could not open URL. Check your default browser/app settings.');
    }
  }

  Future<void> _openMaps() async {
    final report = _report;
    if (report == null) return;
    final uri = Uri.parse(report.mapsUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnack('Could not open maps.');
    }
  }

  void _copyToClipboard(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    _showSnack('$label copied to clipboard.');
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Shows a dialog where the user must type [expectedValue] to proceed.
  Future<bool> _confirmTyped({
    required String title,
    required String instruction,
    required String expectedValue,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(instruction,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'DELETE',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: controller.text.trim() == expectedValue
                      ? () => Navigator.of(ctx).pop(true)
                      : null,
                  style:
                      FilledButton.styleFrom(backgroundColor: AppColors.danger),
                  child: const Text('Delete permanently'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return result ?? false;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final r = _report;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report')),
        body: const Center(child: Text('Report not found.')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(r),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderCard(report: r),
            const SizedBox(height: 14),
            _SummaryCard(report: r, onOpenMaps: _openMaps),
            const SizedBox(height: 14),
            _buildEvidenceFilesSection(r),
            const SizedBox(height: 14),
            _VerificationBox(
              report: r,
              onCopyHash: r.sha256Hash != null
                  ? () => _copyToClipboard(r.sha256Hash!, 'SHA-256 hash')
                  : null,
            ),
            if (r.notes != null && r.notes!.isNotEmpty) ...[
              const SizedBox(height: 14),
              _NotesCard(notes: r.notes!),
            ],
            const SizedBox(height: 20),
            _buildActionButtons(r),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(SosEventModel r) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      title: Text(
        'Evidence Report',
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      actions: [
        PopupMenuButton<String>(
          enabled: !_anyBusy,
          onSelected: (value) {
            switch (value) {
              case 'resolved':
                _markResolved();
              case 'delete':
                _deleteReport();
            }
          },
          itemBuilder: (context) => [
            if (!r.isResolved)
              PopupMenuItem(
                value: 'resolved',
                child: _busyResolve
                    ? const _MenuItemLoading(label: 'Marking resolved…')
                    : const ListTile(
                        leading: Icon(Icons.check_circle_outline_rounded),
                        title: Text('Mark resolved'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
              ),
            PopupMenuItem(
              value: 'delete',
              child: _busyDelete
                  ? const _MenuItemLoading(label: 'Deleting…')
                  : ListTile(
                      leading: Icon(Icons.delete_outline_rounded,
                          color: AppColors.danger),
                      title: Text('Delete report',
                          style: TextStyle(color: AppColors.danger)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
            ),
          ],
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }

  Widget _buildEvidenceFilesSection(SosEventModel r) {
    // Build the list of files to show:
    // 1. Video from SosEventModel (if present)
    // 2. Any extra files from the evidence collection
    // 3. PDF report (always shown – generates on demand if missing)
    final extraVideos = _evidenceFiles
        .where((e) => e['videoUrl'] != null && e['videoUrl'] != r.videoUrl)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Evidence Files',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              // Primary video
              if (r.hasVideo) ...[
                _FileRow(
                  name: 'video_evidence.mp4',
                  icon: Icons.videocam_rounded,
                  color: AppColors.info,
                  isLoading: _busyVideo,
                  onDownload: _anyBusy ? null : _downloadVideo,
                ),
                const Divider(height: 1),
              ],
              // Extra evidence videos from Firestore evidence collection
              for (final ev in extraVideos) ...[
                _FileRow(
                  name: _evidenceFileName(ev),
                  icon: Icons.videocam_rounded,
                  color: AppColors.info,
                  subtitle: _evidenceFileSubtitle(ev),
                  onDownload: _anyBusy
                      ? null
                      : () => _downloadEvidenceFile(
                            ev['videoUrl'] as String,
                            _evidenceFileName(ev),
                          ),
                ),
                const Divider(height: 1),
              ],
              // PDF report (generate on demand if not yet created)
              _FileRow(
                name: r.hasPdfReport
                    ? 'evidence_report.pdf'
                    : 'evidence_report.pdf  (tap to generate)',
                icon: Icons.picture_as_pdf_rounded,
                color: AppColors.safe,
                isLoading: _busyPdf,
                badge: r.hasPdfReport ? null : 'Generate',
                onDownload: _anyBusy ? null : _downloadPdf,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(SosEventModel r) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _anyBusy ? null : _downloadPdf,
                icon: _busyPdf
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded),
                label: Text(
                  _busyPdf
                      ? (r.hasPdfReport ? 'Opening…' : 'Generating…')
                      : (r.hasPdfReport
                          ? 'Download PDF'
                          : 'Generate & Download PDF'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.safeDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _anyBusy ? null : _reportToAuthorities,
              icon: _busyReport
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.safeDark),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('Report'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.safeDark,
                side: BorderSide(color: AppColors.safeDark),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        if (!r.isResolved) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _anyBusy ? null : _markResolved,
              icon: _busyResolve
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Mark as resolved'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _anyBusy ? null : _deleteReport,
            icon: _busyDelete
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.danger),
                  )
                : const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete report'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: BorderSide(color: AppColors.danger),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Utility helpers
  // ---------------------------------------------------------------------------

  String _evidenceFileName(Map<String, dynamic> ev) {
    final id = ev['incidentId'] as String? ?? 'evidence';
    return '$id.mp4';
  }

  String? _evidenceFileSubtitle(Map<String, dynamic> ev) {
    final ts = ev['timestamp'];
    if (ts == null) return null;
    DateTime? dt;
    if (ts is DateTime) dt = ts;
    try {
      dt = DateTime.parse(ts.toString());
    } catch (_) {}
    if (dt == null) return null;
    return '${dt.day} ${_month(dt.month)} ${dt.year}  ${_formatTime(dt)}';
  }

  static String _month(int m) {
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
    return months[m - 1];
  }

  static String _formatTime(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute $ampm';
  }
}

// =============================================================================
// Sub-widgets
// =============================================================================

class _HeaderCard extends StatelessWidget {
  final SosEventModel report;

  const _HeaderCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.shield_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SheShield Evidence Report',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: report.isResolved
                            ? AppColors.safeLight
                            : AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        report.isResolved ? 'Resolved' : 'Open',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: report.isResolved
                                  ? AppColors.safeDark
                                  : AppColors.dangerDark,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tamper-proof evidence package',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final SosEventModel report;
  final VoidCallback? onOpenMaps;

  const _SummaryCard({required this.report, this.onOpenMaps});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryRow(label: 'Incident ID', value: report.eventId),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Date',
            value:
                '${report.timestamp.day} ${_month(report.timestamp.month)} ${report.timestamp.year}',
          ),
          const SizedBox(height: 8),
          _SummaryRow(label: 'Time', value: _formatTime(report.timestamp)),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Location',
            value: report.address ?? report.coordinatesString,
            trailing: onOpenMaps != null
                ? IconButton(
                    onPressed: onOpenMaps,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    tooltip: 'Open in Maps',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: AppColors.primary,
                  )
                : null,
          ),
          const SizedBox(height: 8),
          _SummaryRow(
              label: 'Trigger',
              value: _capitalize(report.triggerSource ?? 'Button')),
          if (report.bpmAtTrigger != null) ...[
            const SizedBox(height: 8),
            _SummaryRow(
                label: 'Heart rate', value: '${report.bpmAtTrigger} bpm'),
          ],
          if (report.contactsNotified.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Notified',
              value: report.contactsNotified.join(', '),
            ),
          ],
          const SizedBox(height: 8),
          _SummaryRow(
              label: 'Status', value: report.isResolved ? 'Resolved' : 'Open'),
        ],
      ),
    );
  }

  static String _month(int m) {
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
    return months[m - 1];
  }

  static String _formatTime(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute $ampm';
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _VerificationBox extends StatelessWidget {
  final SosEventModel report;
  final VoidCallback? onCopyHash;

  const _VerificationBox({required this.report, this.onCopyHash});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.safeLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.safe.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded,
                  color: AppColors.safeDark, size: 16),
              const SizedBox(width: 6),
              Text(
                'INTEGRITY VERIFICATION',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.safeDark, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'SHA-256: ${report.sha256Hash ?? '—'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                ),
              ),
              if (onCopyHash != null)
                IconButton(
                  onPressed: onCopyHash,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  tooltip: 'Copy hash',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: AppColors.safeDark,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.safe,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Tamper-proof verified',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  final String notes;

  const _NotesCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notes',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(notes, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  )),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final String? badge;
  final String? subtitle;
  final VoidCallback? onDownload;

  const _FileRow({
    required this.name,
    required this.icon,
    required this.color,
    this.isLoading = false,
    this.badge,
    this.subtitle,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge!,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.warningDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
              ],
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: onDownload,
              icon: Icon(
                Icons.download_rounded,
                color: onDownload != null
                    ? AppColors.textSecondary
                    : AppColors.disabled,
              ),
              tooltip: 'Download',
            ),
        ],
      ),
    );
  }
}

/// Small loading indicator for popup menu items.
class _MenuItemLoading extends StatelessWidget {
  final String label;

  const _MenuItemLoading({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
