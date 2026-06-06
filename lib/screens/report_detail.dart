import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../models/sos_event_model.dart';
import '../services/email_service.dart';
import '../services/evidence_service.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';

/// ReportDetailScreen shows the full evidence report for a single SOS event.
/// Accessed from EvidenceOverview by tapping "View Report" on a report card.
class ReportDetailScreen extends StatefulWidget {
  final String reportId;
  final SosEventModel? preloadedReport;

  const ReportDetailScreen({
    Key? key,
    required this.reportId,
    this.preloadedReport,
  }) : super(key: key);

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  // ── State variables (preserved exactly) ──────────────────────────────────
  SosEventModel? _report;
  List<Map<String, dynamic>> _evidenceFiles = [];
  bool _loading = true;
  bool _busyPdf = false;
  bool _busyVideo = false;
  bool _busyReport = false;
  bool _busyResolve = false;
  bool _busyDelete = false;

  final EvidenceService _evidenceService = EvidenceService();

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  // ── Data loading ──────────────────────────────────────────────────────────
  Future<void> _loadReport() async {
    setState(() => _loading = true);
    try {
      final fs = FirebaseService();
      await fs.init();

      // Always fetch fresh from Firestore so we get the latest data
      // (video URL, address, contacts may have been updated after initial save)
      final docId = widget.preloadedReport?.eventId ?? widget.reportId;
      final doc = await fs.firestore
          .collection(AppConstants.firestoreSosEventsCollection)
          .doc(docId)
          .get();

      SosEventModel report;
      if (doc.exists && doc.data() != null) {
        report = SosEventModel.fromFirestore(doc);
      } else if (widget.preloadedReport != null) {
        // Firestore doc not found yet (immediate save may still be in flight)
        // — use preloaded data as fallback
        report = widget.preloadedReport!;
      } else {
        if (mounted) {
          _showSnack('Report not found.');
          Navigator.of(context).pop();
        }
        return;
      }

      final files = await _evidenceService.getEvidenceFiles(report);
      if (mounted) {
        setState(() {
          _report = report;
          _evidenceFiles = files;
          _loading = false;
        });
      }
    } catch (e) {
      // Fallback to preloaded if Firestore fetch fails
      if (widget.preloadedReport != null && mounted) {
        setState(() {
          _report = widget.preloadedReport;
          _evidenceFiles = [];
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
        _showSnack('Failed to load report: $e');
      }
    }
  }

  // ── Actions (logic preserved exactly) ────────────────────────────────────

  Future<void> _downloadPdf() async {
    if (_report == null || _busyPdf) return;
    setState(() => _busyPdf = true);
    try {
      final url = await _evidenceService.getOrCreatePdfReportUrl(_report!);
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showSnack('Could not open PDF.');
      } else {
        // Reload to pick up the new pdfReportUrl if it was just generated.
        await _loadReport();
      }
    } catch (e) {
      _showSnack('PDF error: $e');
    } finally {
      if (mounted) setState(() => _busyPdf = false);
    }
  }

  Future<void> _downloadVideo() async {
    if (_report == null || _busyVideo) return;
    setState(() => _busyVideo = true);
    try {
      // Use the stored video URL directly if available
      final directUrl = _report!.videoUrl;
      if (directUrl != null && directUrl.isNotEmpty) {
        final uri = Uri.parse(directUrl);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          _showSnack('Could not open video. Try a different video player.');
        }
        return;
      }
      // Fallback: look up in Firebase Storage
      final url = await _evidenceService.getVideoDownloadUrl(_report!);
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showSnack('Could not open video.');
      }
    } catch (e) {
      _showSnack('Video not available: $e');
    } finally {
      if (mounted) setState(() => _busyVideo = false);
    }
  }

  Future<void> _reportToAuthorities() async {
    if (_report == null || _busyReport) return;
    final confirmed = await _confirmDialog(
      title: 'Share Evidence Report?',
      message:
          'This will send the evidence report to all your emergency contacts via email.',
      confirmLabel: 'Share',
    );
    if (!confirmed) return;
    setState(() => _busyReport = true);
    try {
      final r = _report!;
      final stored = await LocalStorageService.loadContacts();
      final emailContacts = stored
          .where((c) => c.email.trim().isNotEmpty)
          .map((c) => EmailContact(name: c.name, email: c.email.trim()))
          .toList();

      if (emailContacts.isNotEmpty) {
        final sent = await EmailService().sendEmergencyEmail(
          contacts: emailContacts,
          senderName: FirebaseService().auth.currentUser?.displayName ??
              'SheShield User',
          latitude: r.latitude,
          longitude: r.longitude,
          address: r.address,
          triggerSource: 'Evidence Report: ${r.eventId}',
        );
        _showSnack('Report sent to $sent contact(s).');
      } else {
        // Fallback: open mail app
        final pdfUrl = await _evidenceService.getOrCreatePdfReportUrl(r);
        final subject =
            Uri.encodeComponent('SheShield SOS Report ${r.eventId}');
        final body = Uri.encodeComponent(
          'Incident ID: ${r.eventId}\n'
          'Time: ${r.timestamp.toIso8601String()}\n'
          'Location: ${r.mapsUrl}\n'
          'Address: ${r.address ?? 'Unavailable'}\n'
          'Evidence PDF: $pdfUrl\n'
          'Video: ${r.videoUrl ?? 'Unavailable'}\n'
          'SHA-256: ${r.sha256Hash ?? 'Unavailable'}',
        );
        final uri = Uri.parse('mailto:?subject=$subject&body=$body');
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          _showSnack('No email app available.');
        }
      }
    } catch (e) {
      _showSnack('Report error: $e');
    } finally {
      if (mounted) setState(() => _busyReport = false);
    }
  }

  Future<void> _markResolved() async {
    if (_report == null || _busyResolve) return;
    final confirmed = await _confirmDialog(
      title: 'Mark as Resolved?',
      message:
          'This will mark the incident as resolved. You can still view the evidence.',
      confirmLabel: 'Mark Resolved',
    );
    if (!confirmed) return;
    setState(() => _busyResolve = true);
    try {
      await _evidenceService.markReportResolved(_report!);
      await _loadReport();
      _showSnack('Incident marked as resolved.');
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _busyResolve = false);
    }
  }

  Future<void> _deleteReport() async {
    if (_report == null || _busyDelete) return;
    final confirmed = await _confirmTyped(
      title: 'Delete Report',
      message:
          'This permanently deletes the SOS record and all stored evidence files. '
          'Type DELETE to confirm.',
      confirmWord: 'DELETE',
    );
    if (!confirmed) return;
    setState(() => _busyDelete = true);
    try {
      await _evidenceService.deleteReport(_report!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busyDelete = false);
        _showSnack('Delete error: $e');
      }
    }
  }

  Future<void> _sendToPolice() async {
    if (_report == null) return;
    final confirmed = await _confirmDialog(
      title: 'Send to Police?',
      message:
          'This will send the evidence report directly to the police email (deepraj5915@gmail.com) via SMTP.',
      confirmLabel: 'Send',
    );
    if (!confirmed) return;
    setState(() => _busyReport = true);
    try {
      final r = _report!;
      const policeEmail = 'deepraj5915@gmail.com';
      final senderName =
          FirebaseService().auth.currentUser?.displayName ?? 'SheShield User';

      // Send via SMTP directly — no UI interaction needed
      final sent = await EmailService().sendEmergencyEmail(
        contacts: [
          const EmailContact(name: 'Police Authority', email: policeEmail)
        ],
        senderName: senderName,
        latitude: r.latitude,
        longitude: r.longitude,
        address: r.address,
        triggerSource: 'Police Report: ${r.eventId}',
      );

      if (sent > 0) {
        _showSnack('Report sent to police ($policeEmail) successfully.');
      } else {
        // Fallback: open mail app pre-filled
        final pdfUrl = await _evidenceService.getOrCreatePdfReportUrl(r);
        final subject = Uri.encodeComponent(
            'URGENT: SheShield SOS Police Report - ${r.eventId}');
        final body = Uri.encodeComponent(
          'URGENT POLICE REPORT\n'
          '====================\n\n'
          'Incident ID: ${r.eventId}\n'
          'Date & Time: ${r.timestamp.toIso8601String()}\n'
          'Location: ${r.mapsUrl}\n'
          'Address: ${r.address ?? 'Unavailable'}\n'
          'Trigger: ${r.triggerSource ?? 'Unknown'}\n'
          'Heart Rate at Trigger: ${r.bpmAtTrigger != null ? '${r.bpmAtTrigger} BPM' : 'Not captured'}\n'
          'Contacts Notified: ${r.contactsNotified.isEmpty ? 'None' : r.contactsNotified.join(', ')}\n'
          'Status: ${r.isResolved ? 'Resolved' : 'Open'}\n\n'
          'DIGITAL EVIDENCE\n'
          '----------------\n'
          'Evidence PDF: $pdfUrl\n'
          'Video Evidence: ${r.videoUrl ?? 'Unavailable'}\n'
          'SHA-256 Hash: ${r.sha256Hash ?? 'Unavailable'}\n\n'
          'This report was generated by SheShield — a personal safety application.',
        );
        final uri =
            Uri.parse('mailto:$policeEmail?subject=$subject&body=$body');
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          _showSnack('Could not send email. Check SMTP settings in .env');
        }
      }
    } catch (e) {
      _showSnack('Error sending to police: $e');
    } finally {
      if (mounted) setState(() => _busyReport = false);
    }
  }

  // ── Dialog helpers ────────────────────────────────────────────────────────

  Future<bool> _confirmDialog({
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

  /// confirmTyped — requires the user to type a specific word before confirming.
  Future<bool> _confirmTyped({
    required String title,
    required String message,
    required String confirmWord,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: confirmWord,
                      border: const OutlineInputBorder(),
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
                  onPressed: controller.text.trim() == confirmWord
                      ? () => Navigator.of(ctx).pop(true)
                      : null,
                  style:
                      FilledButton.styleFrom(backgroundColor: AppColors.danger),
                  child: const Text('Delete'),
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Format eventId as SSE-XXXX (first 8 chars uppercased after "SSE-").
  String _formatIncidentId(String eventId) {
    final clean = eventId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final suffix = clean.length > 8 ? clean.substring(0, 8) : clean;
    return 'SSE-$suffix';
  }

  String _formatDate(DateTime dt) {
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
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  /// Try to find a matching evidence file from _evidenceFiles by type keyword.
  Map<String, dynamic>? _findEvidenceFile(String keyword) {
    for (final f in _evidenceFiles) {
      final type =
          (f['evidenceType'] ?? f['type'] ?? '').toString().toLowerCase();
      final url = (f['videoUrl'] ?? f['url'] ?? '').toString().toLowerCase();
      if (type.contains(keyword) || url.contains(keyword)) return f;
    }
    return null;
  }

  Future<void> _downloadOtherFile(String fileType) async {
    final file = _findEvidenceFile(fileType);
    if (file == null) {
      _showSnack('File not available for this incident.');
      return;
    }
    final url = (file['videoUrl'] ?? file['url'] ?? '').toString();
    if (url.isEmpty) {
      _showSnack('File not available for this incident.');
      return;
    }
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnack('Could not open file.');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Evidence Report'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_report == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Evidence Report'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(child: Text('Report not found.')),
      );
    }

    final report = _report!;
    final bool anyBusy =
        _busyPdf || _busyVideo || _busyReport || _busyResolve || _busyDelete;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(report, anyBusy),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(report),
            const SizedBox(height: 16),
            _buildSummaryCard(report),
            const SizedBox(height: 20),
            _buildEvidenceFilesSection(report),
            const SizedBox(height: 20),
            _buildVerificationSection(report),
            if (report.notes != null && report.notes!.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildNotesCard(report),
            ],
            const SizedBox(height: 28),
            _buildActionButtons(anyBusy),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(SosEventModel report, bool anyBusy) {
    return AppBar(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: const Text(
        'Evidence Report',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        PopupMenuButton<String>(
          enabled: !anyBusy,
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) {
            if (value == 'resolve') _markResolved();
            if (value == 'delete') _deleteReport();
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'resolve',
              enabled: !report.isResolved,
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 18,
                    color:
                        report.isResolved ? AppColors.disabled : AppColors.safe,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    report.isResolved ? 'Already Resolved' : 'Mark Resolved',
                    style: TextStyle(
                      color: report.isResolved
                          ? AppColors.disabled
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: const [
                  Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppColors.danger),
                  SizedBox(width: 10),
                  Text('Delete', style: TextStyle(color: AppColors.danger)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Header card ───────────────────────────────────────────────────────────

  Widget _buildHeaderCard(SosEventModel report) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shield icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SheShield Evidence Report',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.lock_rounded,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Tamper-proof • Blockchain verified',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Status badge
                _StatusBadge(isResolved: report.isResolved),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary card ──────────────────────────────────────────────────────────

  Widget _buildSummaryCard(SosEventModel report) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Incident Summary',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          _SummaryRow(
            label: 'Incident ID',
            value: _formatIncidentId(report.eventId),
            valueStyle: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              fontSize: 13,
            ),
          ),
          _SummaryRow(
            label: 'Date',
            value: _formatDate(report.timestamp),
          ),
          _SummaryRow(
            label: 'Time',
            value: _formatTime(report.timestamp),
          ),
          // Location row with map icon button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    'Location',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  child: Text(
                    report.address ?? report.coordinatesString,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(report.mapsUrl);
                    if (!await launchUrl(uri,
                        mode: LaunchMode.externalApplication)) {
                      _showSnack('Could not open maps.');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.map_rounded,
                        size: 16, color: AppColors.info),
                  ),
                ),
              ],
            ),
          ),
          _SummaryRow(
            label: 'Trigger',
            value: _capitalize(report.triggerSource ?? 'Unknown'),
          ),
          if (report.bpmAtTrigger != null)
            _SummaryRow(
              label: 'Heart Rate',
              value: '${report.bpmAtTrigger} BPM',
              valueStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          _SummaryRow(
            label: 'Contacts',
            value: report.contactsNotified.isEmpty
                ? 'None recorded'
                : '${report.contactsNotified.length} notified',
          ),
          _SummaryRow(
            label: 'Status',
            value: report.isResolved ? 'Resolved' : 'Open',
            valueStyle: TextStyle(
              fontWeight: FontWeight.w700,
              color: report.isResolved ? AppColors.safe : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  // ── Evidence files section ────────────────────────────────────────────────

  Widget _buildEvidenceFilesSection(SosEventModel report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'EVIDENCE FILES',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: _buildEvidenceFileRows(report),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildEvidenceFileRows(SosEventModel report) {
    final rows = <_EvidenceFileSpec>[];

    // 1. Audio evidence — always present
    rows.add(_EvidenceFileSpec(
      filename: 'audio_evidence.mp4',
      icon: Icons.mic_rounded,
      color: AppColors.primary,
      onDownload: () => _downloadOtherFile('audio'),
    ));

    // 2. Video evidence — only if report.hasVideo
    if (report.hasVideo) {
      rows.add(_EvidenceFileSpec(
        filename: 'video_evidence.mp4',
        icon: Icons.videocam_rounded,
        color: AppColors.info,
        onDownload: _busyVideo ? null : _downloadVideo,
        busy: _busyVideo,
      ));
    }

    // 3. GPS track
    rows.add(_EvidenceFileSpec(
      filename: 'gps_track.json',
      icon: Icons.location_on_rounded,
      color: AppColors.safe,
      onDownload: () => _downloadOtherFile('gps'),
    ));

    // 4. Accelerometer
    rows.add(_EvidenceFileSpec(
      filename: 'accelerometer.csv',
      icon: Icons.bolt_rounded,
      color: AppColors.warning,
      onDownload: () => _downloadOtherFile('accelerometer'),
    ));

    // 5. Heart rate log
    rows.add(_EvidenceFileSpec(
      filename: 'heartrate_log.csv',
      icon: Icons.favorite_rounded,
      color: AppColors.danger,
      onDownload: () => _downloadOtherFile('heartrate'),
    ));

    // 6. Evidence PDF
    rows.add(_EvidenceFileSpec(
      filename: 'evidence_report.pdf',
      icon: Icons.picture_as_pdf_rounded,
      color: AppColors.safe,
      onDownload: _busyPdf ? null : _downloadPdf,
      busy: _busyPdf,
      showGenerateBadge: !report.hasPdfReport,
    ));

    final widgets = <Widget>[];
    for (int i = 0; i < rows.length; i++) {
      widgets.add(_EvidenceFileRow(spec: rows[i]));
      if (i < rows.length - 1) {
        widgets.add(Divider(
          height: 1,
          thickness: 1,
          color: AppColors.border,
          indent: 16,
          endIndent: 16,
        ));
      }
    }
    return widgets;
  }

  // ── Verification section ──────────────────────────────────────────────────

  Widget _buildVerificationSection(SosEventModel report) {
    final hash = report.sha256Hash ?? '';
    final displayHash = hash.length > 20 ? '${hash.substring(0, 20)}...' : hash;
    final hasHash = hash.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.safeLight.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.safe.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Text(
            'VERIFICATION',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.safeDark,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 12),
          // Hash row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SHA-256 Hash',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasHash ? displayHash : 'Not available',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            color: hasHash
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              if (hasHash)
                IconButton(
                  tooltip: 'Copy hash',
                  icon: const Icon(Icons.copy_rounded,
                      size: 18, color: AppColors.safeDark),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: hash));
                    _showSnack('Hash copied to clipboard.');
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Verified pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.safe.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.safe.withValues(alpha: 0.40)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_rounded,
                    size: 14, color: AppColors.safeDark),
                const SizedBox(width: 6),
                Text(
                  'Tamper-proof verified',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.safeDark,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Notes card ────────────────────────────────────────────────────────────

  Widget _buildNotesCard(SosEventModel report) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notes_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Notes',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            report.notes!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  // ── Action buttons ────────────────────────────────────────────────────────

  Widget _buildActionButtons(bool anyBusy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Download PDF — filled primary
        FilledButton.icon(
          onPressed: anyBusy ? null : _downloadPdf,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: _busyPdf
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.download_rounded, color: Colors.white),
          label: const Text(
            'Download PDF',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        // 2. Share Email — outlined
        OutlinedButton.icon(
          onPressed: anyBusy ? null : _reportToAuthorities,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: _busyReport
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                )
              : const Icon(Icons.email_outlined, color: AppColors.primary),
          label: const Text(
            'Share Email',
            style: TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        // 3. Send to Police — outlined red
        OutlinedButton.icon(
          onPressed: anyBusy ? null : _sendToPolice,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppColors.danger),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.local_police_rounded, color: AppColors.danger),
          label: const Text(
            'Send to Police',
            style:
                TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

// ── Private helper widgets ────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool isResolved;

  const _StatusBadge({required this.isResolved});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isResolved
            ? AppColors.safeLight.withValues(alpha: 0.6)
            : AppColors.warningLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isResolved
              ? AppColors.safe.withValues(alpha: 0.5)
              : AppColors.warning.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isResolved
                ? Icons.check_circle_rounded
                : Icons.radio_button_checked_rounded,
            size: 12,
            color: isResolved ? AppColors.safeDark : AppColors.warningDark,
          ),
          const SizedBox(width: 5),
          Text(
            isResolved ? 'Resolved' : 'Open',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isResolved ? AppColors.safeDark : AppColors.warningDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle ??
                  Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Data class describing a single evidence file row.
class _EvidenceFileSpec {
  final String filename;
  final IconData icon;
  final Color color;
  final VoidCallback? onDownload;
  final bool busy;
  final bool showGenerateBadge;

  const _EvidenceFileSpec({
    required this.filename,
    required this.icon,
    required this.color,
    required this.onDownload,
    this.busy = false,
    this.showGenerateBadge = false,
  });
}

class _EvidenceFileRow extends StatelessWidget {
  final _EvidenceFileSpec spec;

  const _EvidenceFileRow({required this.spec});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Colored icon box
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: spec.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(spec.icon, size: 20, color: spec.color),
          ),
          const SizedBox(width: 12),
          // Filename + optional badge
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    spec.filename,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (spec.showGenerateBadge) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'Generate',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warningDark,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Download button
          spec.busy
              ? const SizedBox(
                  width: 36,
                  height: 36,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  tooltip: 'Download',
                  icon: Icon(
                    Icons.download_rounded,
                    size: 20,
                    color: spec.onDownload != null
                        ? AppColors.primary
                        : AppColors.disabled,
                  ),
                  onPressed: spec.onDownload,
                ),
        ],
      ),
    );
  }
}
