import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/utils/logger.dart';
import '../core/constants/app_constants.dart';
import '../models/sos_event_model.dart';
import 'firebase_service.dart';

/// EvidenceService
/// - Generates SHA-256 of video files in an isolate
/// - Uploads video to Firebase Storage
/// - Saves metadata to Firestore under collection `evidence`
class EvidenceService {
  static final EvidenceService _instance = EvidenceService._internal();
  factory EvidenceService() => _instance;
  EvidenceService._internal();

  final FirebaseService _firebaseService = FirebaseService();

  /// Generates SHA-256 hash of the provided file using an isolate.
  /// Returns hex digest string on success.
  Future<String> generateHash(File file) async {
    AppLogger.i('EvidenceService: Starting hash generation for ${file.path}');
    try {
      if (!file.existsSync()) {
        throw Exception('File not found: ${file.path}');
      }

      // Use compute to run hashing in an isolate. We pass the file path string.
      final hash = await compute(_computeSha256ForPath, file.path);
      AppLogger.i(
          'EvidenceService: Hash generated (${hash.substring(0, 16)}...) for ${file.path}');
      return hash;
    } catch (e, st) {
      AppLogger.e('EvidenceService: generateHash failed', e, st);
      rethrow;
    }
  }

  /// Uploads the video file to Firebase Storage under `evidence/{id}.mp4`.
  /// Returns the download URL on success.
  Future<String> uploadVideo(File file) async {
    final String incidentId =
        'evidence_${DateTime.now().millisecondsSinceEpoch}';
    AppLogger.i('EvidenceService: Uploading video for incident $incidentId');
    try {
      if (!file.existsSync()) {
        throw Exception('File does not exist: ${file.path}');
      }

      await _firebaseService.init();

      final ref = _firebaseService.storage
          .ref()
          .child('${AppConstants.firebaseEvidencePath}/$incidentId.mp4');

      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      AppLogger.i('EvidenceService: Uploaded video to $downloadUrl');
      return downloadUrl;
    } catch (e, st) {
      AppLogger.e('EvidenceService: uploadVideo failed', e, st);
      rethrow;
    }
  }

  /// Full evidence upload workflow: generate hash, upload video, and save metadata.
  /// Accepts a local video file and location coordinates.
  /// Returns a map with keys: videoUrl, hash, incidentId
  Future<Map<String, dynamic>> uploadEvidence(
    File video, {
    required double latitude,
    required double longitude,
    required String triggerType,
    String? sosEventId,
  }) async {
    AppLogger.i('EvidenceService: Starting uploadEvidence workflow');
    try {
      // 1. Generate hash (isolate)
      final hash = await generateHash(video);

      // 2. Upload to Firebase Storage under deterministic incidentId
      final incidentId = 'evidence_${DateTime.now().millisecondsSinceEpoch}';
      await _firebaseService.init();
      final ref = _firebaseService.storage
          .ref()
          .child('${AppConstants.firebaseEvidencePath}/$incidentId.mp4');
      final uploadTask = ref.putFile(video);
      final snapshot = await uploadTask.whenComplete(() {});
      final videoUrl = await snapshot.ref.getDownloadURL();

      // 3. Save metadata to Firestore
      final metadata = {
        'incidentId': incidentId,
        'sosEventId': sosEventId,
        'timestamp': DateTime.now().toUtc(),
        'latitude': latitude,
        'longitude': longitude,
        'videoUrl': videoUrl,
        'hash': hash,
        'sha256Hash': hash,
        'triggerType': triggerType,
        'metadata': {},
      };

      await saveEvidence(metadata);

      AppLogger.i('EvidenceService: uploadEvidence completed for $incidentId');
      return {'videoUrl': videoUrl, 'hash': hash, 'incidentId': incidentId};
    } catch (e, st) {
      AppLogger.e('EvidenceService: uploadEvidence failed', e, st);
      rethrow;
    }
  }

  /// Saves provided metadata to Firestore under collection `evidence`.
  /// Expected keys in [data]: incidentId, timestamp, latitude, longitude, videoUrl, hash, triggerType
  Future<void> saveEvidence(Map<String, dynamic> data) async {
    AppLogger.i('EvidenceService: Saving evidence metadata');
    try {
      // Validate required fields
      final required = [
        'incidentId',
        'timestamp',
        'latitude',
        'longitude',
        'videoUrl',
        'hash',
        'triggerType'
      ];
      for (final key in required) {
        if (!data.containsKey(key) || data[key] == null) {
          throw ArgumentError('Missing required evidence field: $key');
        }
      }

      await _firebaseService.init();

      final collection = _firebaseService.firestore
          .collection(AppConstants.firebaseEvidencePath);

      final docId = data['incidentId'] as String;

      final payload = <String, dynamic>{
        'incidentId': docId,
        if (data['sosEventId'] != null) 'sosEventId': data['sosEventId'],
        'userId': _firebaseService.auth.currentUser?.uid,
        'timestamp': data['timestamp'] is DateTime
            ? (data['timestamp'] as DateTime).toUtc()
            : DateTime.parse(data['timestamp'].toString()).toUtc(),
        'latitude': data['latitude'],
        'longitude': data['longitude'],
        'videoUrl': data['videoUrl'],
        'hash': data['hash'],
        'sha256Hash': data['sha256Hash'] ?? data['hash'],
        'triggerType': data['triggerType'],
        'metadata': data['metadata'] ?? {},
        'createdAt': DateTime.now().toUtc(),
      };

      await collection.doc(docId).set(payload);
      AppLogger.i('EvidenceService: Evidence metadata saved for $docId');
    } catch (e, st) {
      AppLogger.e('EvidenceService: saveEvidence failed', e, st);
      rethrow;
    }
  }

  Future<String> getOrCreatePdfReportUrl(SosEventModel report) async {
    if (report.pdfReportUrl != null && report.pdfReportUrl!.isNotEmpty) {
      return report.pdfReportUrl!;
    }

    AppLogger.i('EvidenceService: Generating PDF for ${report.eventId}');
    await _firebaseService.init();
    final bytes = await _buildPdfReportBytes(report.toPdfPayload());
    final ref = _firebaseService.storage.ref().child(
        '${AppConstants.firebaseEvidencePath}/${report.eventId}/report.pdf');

    final snapshot = await ref
        .putData(
          bytes,
          SettableMetadata(
            contentType: 'application/pdf',
            customMetadata: {
              'sosEventId': report.eventId,
              'generatedAt': DateTime.now().toUtc().toIso8601String(),
            },
          ),
        )
        .whenComplete(() {});

    final url = await snapshot.ref.getDownloadURL();
    await _firebaseService.firestore
        .collection(AppConstants.firestoreSosEventsCollection)
        .doc(report.eventId)
        .set({'pdfReportUrl': url}, SetOptions(merge: true));
    await _updateEvidencePdfUrl(report, url);
    AppLogger.i('EvidenceService: PDF report uploaded for ${report.eventId}');
    return url;
  }

  Future<String> getVideoDownloadUrl(SosEventModel report) async {
    if (report.videoUrl != null && report.videoUrl!.isNotEmpty) {
      return report.videoUrl!;
    }

    await _firebaseService.init();
    final candidates = [
      '${AppConstants.firebaseEvidencePath}/${report.eventId}.mp4',
      '${AppConstants.firebaseEvidencePath}/${report.eventId}/video.mp4',
    ];

    for (final path in candidates) {
      try {
        return await _firebaseService.storage
            .ref()
            .child(path)
            .getDownloadURL();
      } catch (_) {
        // Try the next known evidence path.
      }
    }

    final evidenceDoc = await _findEvidenceDoc(report);
    final data = evidenceDoc?.data();
    final url = data?['videoUrl'];
    if (url is String && url.isNotEmpty) return url;

    throw StateError('No downloadable video evidence found.');
  }

  /// Returns all evidence documents linked to [report] from Firestore.
  /// Used by the UI to display downloadable evidence files.
  Future<List<Map<String, dynamic>>> getEvidenceFiles(
      SosEventModel report) async {
    await _firebaseService.init();
    final docs = await _findEvidenceDocs(report);
    return docs.map((d) => d.data()).toList();
  }

  Future<void> markReportResolved(SosEventModel report) async {
    await _firebaseService.init();
    await _firebaseService.firestore
        .collection(AppConstants.firestoreSosEventsCollection)
        .doc(report.eventId)
        .set({
      'isResolved': true,
      'resolvedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteReport(SosEventModel report) async {
    await _firebaseService.init();
    await _deleteStorageUrl(report.videoUrl);
    await _deleteStorageUrl(report.pdfReportUrl);

    for (final path in [
      '${AppConstants.firebaseEvidencePath}/${report.eventId}.mp4',
      '${AppConstants.firebaseEvidencePath}/${report.eventId}/video.mp4',
      '${AppConstants.firebaseEvidencePath}/${report.eventId}/report.pdf',
    ]) {
      await _deleteStorageRef(_firebaseService.storage.ref().child(path));
    }

    final evidenceDocs = await _findEvidenceDocs(report);
    for (final doc in evidenceDocs) {
      await doc.reference.delete();
    }

    await _firebaseService.firestore
        .collection(AppConstants.firestoreSosEventsCollection)
        .doc(report.eventId)
        .delete();
  }

  Future<void> _updateEvidencePdfUrl(SosEventModel report, String url) async {
    final docs = await _findEvidenceDocs(report);
    for (final doc in docs) {
      await doc.reference.set({'pdfReportUrl': url}, SetOptions(merge: true));
    }
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findEvidenceDoc(
      SosEventModel report) async {
    final docs = await _findEvidenceDocs(report);
    return docs.isEmpty ? null : docs.first;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _findEvidenceDocs(
      SosEventModel report) async {
    final collection = _firebaseService.firestore
        .collection(AppConstants.firebaseEvidencePath);
    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    final seen = <String>{};

    Future<void> add(QuerySnapshot<Map<String, dynamic>> snap) async {
      for (final doc in snap.docs) {
        if (seen.add(doc.id)) docs.add(doc);
      }
    }

    await add(await collection
        .where('sosEventId', isEqualTo: report.eventId)
        .limit(10)
        .get());
    if (report.videoUrl != null && report.videoUrl!.isNotEmpty) {
      await add(await collection
          .where('videoUrl', isEqualTo: report.videoUrl)
          .limit(10)
          .get());
    }

    return docs;
  }

  Future<void> _deleteStorageUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      await _deleteStorageRef(_firebaseService.storage.refFromURL(url));
    } catch (e, st) {
      AppLogger.w('EvidenceService: Failed to delete storage URL', e, st);
    }
  }

  Future<void> _deleteStorageRef(Reference ref) async {
    try {
      await ref.delete();
    } catch (_) {
      // Missing files should not block report deletion.
    }
  }
}

// Top-level isolate entrypoint to compute SHA-256 from file path.
String _computeSha256ForPath(String path) {
  final file = File(path);
  final bytes = file.readAsBytesSync();
  final digest = crypto.sha256.convert(bytes);
  return digest.toString();
}

Future<Uint8List> _buildPdfReportBytes(Map<String, String> data) async {
  final doc = pw.Document();
  final labelStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold);

  pw.Widget row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 110, child: pw.Text(label, style: labelStyle)),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        pw.Text(
          'SheShield Evidence Report',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Generated: ${data['generatedAt']}'),
        pw.Divider(height: 28),
        row('Incident ID', data['eventId']!),
        row('User ID', data['userId']!),
        row('Timestamp', data['timestamp']!),
        row('Location', data['location']!),
        row('Address', data['address']!),
        row('Trigger', data['trigger']!),
        row('BPM', data['bpm']!),
        row('Contacts', data['contacts']!),
        row('Resolved', data['resolved']!),
        pw.SizedBox(height: 16),
        pw.Text('Digital Evidence',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        row('Video URL', data['videoUrl']!),
        row('SHA-256', data['sha256Hash']!),
        row('Maps URL', data['mapsUrl']!),
        if (data['notes']!.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text('Notes',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(data['notes']!),
        ],
        pw.Spacer(),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.green700),
            color: PdfColors.green50,
          ),
          child: pw.Text(
            'Integrity note: compare the SHA-256 hash above with the original evidence hash to verify the video has not been altered.',
          ),
        ),
      ],
    ),
  );

  return await doc.save();
}

extension on SosEventModel {
  Map<String, String> toPdfPayload() {
    return {
      'eventId': eventId,
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
      'location': '$latitude, $longitude',
      'address': address ?? 'Unavailable',
      'trigger': triggerSource ?? 'Unknown',
      'bpm': bpmAtTrigger?.toString() ?? 'Not captured',
      'contacts': contactsNotified.isEmpty
          ? 'None recorded'
          : contactsNotified.join(', '),
      'resolved': isResolved ? 'Yes' : 'No',
      'videoUrl': videoUrl ?? 'Unavailable',
      'sha256Hash': sha256Hash ?? 'Unavailable',
      'mapsUrl': mapsUrl,
      'notes': notes ?? '',
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
