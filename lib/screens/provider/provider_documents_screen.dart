import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';

const _cloudName    = 'drhvwmzrg';
const _uploadPreset = 'Meditrack-proj';

// ---------------------------------------------------------------------------
// Simple inline service for provider documents (scoped by patient)
// ---------------------------------------------------------------------------

class _ProviderDocService {
  final FirebaseFirestore _db   = FirebaseFirestore.instance;
  final FirebaseAuth      _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  Stream<List<Map<String, dynamic>>> documentsStream(String patientId) {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('provider_documents')
        .where('providerId', isEqualTo: uid)
        .where('patientId',  isEqualTo: patientId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList());
  }

  Stream<double> upload({
    required File file,
    required String fileName,
    required String category,
    required String mimeType,
    required String patientId,
    required String patientName,
  }) async* {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    yield 0.1;
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload');
    final req = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder']        = 'meditrack/provider_docs/$uid'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    yield 0.3;
    final resp = await req.send();
    yield 0.8;
    final body = await resp.stream.bytesToString();
    if (resp.statusCode != 200) throw Exception('Upload failed: $body');

    final json     = jsonDecode(body) as Map<String, dynamic>;
    final url      = json['secure_url'] as String;
    final publicId = json['public_id'] as String;
    final fileSize = (json['bytes'] as num?)?.toInt() ?? file.lengthSync();

    await _db.collection('provider_documents').add({
      'providerId':  uid,
      'patientId':   patientId,
      'patientName': patientName,
      'name':        fileName,
      'category':    category,
      'url':         url,
      'publicId':    publicId,
      'mimeType':    mimeType,
      'sizeBytes':   fileSize,
      'uploadedAt':  FieldValue.serverTimestamp(),
    });
    yield 1.0;
  }

  Future<void> delete(String docId) =>
      _db.collection('provider_documents').doc(docId).delete();
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

const _kCategories = [
  'Lab Results',
  'X-Ray / Imaging',
  'Prescription',
  'Referral',
  'Other',
];

class ProviderDocumentsScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const ProviderDocumentsScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<ProviderDocumentsScreen> createState() =>
      _ProviderDocumentsScreenState();
}

class _ProviderDocumentsScreenState extends State<ProviderDocumentsScreen> {
  final _svc = _ProviderDocService();

  void _showUploadSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _UploadSheet(
        svc: _svc,
        patientId: widget.patientId,
        patientName: widget.patientName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${widget.patientName} — Files'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'provider_docs_fab',
        onPressed: _showUploadSheet,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.upload_file, color: Colors.white),
        label: const Text('Upload', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _svc.documentsStream(widget.patientId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cloud_upload_outlined,
                        color: AppColors.primary, size: 40),
                  ),
                  const SizedBox(height: 16),
                  const Text('No files uploaded yet',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('Tap Upload to add results or reports',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i];
              return _DocCard(doc: d, svc: _svc);
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Document card
// ---------------------------------------------------------------------------

class _DocCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  final _ProviderDocService svc;
  const _DocCard({required this.doc, required this.svc});

  String _sizeLabel(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    final mime     = (doc['mimeType'] as String?) ?? '';
    final isImage  = mime.startsWith('image/');
    final color    = isImage ? Colors.teal : AppColors.primary;
    final name     = (doc['name']     as String?) ?? '';
    final category = (doc['category'] as String?) ?? '';
    final sizeBytes= (doc['sizeBytes'] as num?)?.toInt() ?? 0;
    final ts       = doc['uploadedAt'] as Timestamp?;
    final date     = ts != null
        ? DateFormat('MMM d, yyyy').format(ts.toDate())
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
                isImage
                    ? Icons.image_outlined
                    : Icons.picture_as_pdf_outlined,
                color: color,
                size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Row(children: [
                  _Badge(category, color),
                  const SizedBox(width: 8),
                  Text(_sizeLabel(sizeBytes),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(width: 8),
                  Text(date,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ]),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new,
                size: 20, color: AppColors.primary),
            onPressed: () async {
              final url = (doc['url'] as String?) ?? '';
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 20, color: AppColors.danger),
            onPressed: () async {
              final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: const Text('Delete file?'),
                      content: Text('Remove "$name"?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete',
                              style: TextStyle(color: AppColors.danger)),
                        ),
                      ],
                    ),
                  ) ??
                  false;
              if (ok) await svc.delete(doc['id'] as String);
            },
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ---------------------------------------------------------------------------
// Upload sheet
// ---------------------------------------------------------------------------

class _UploadSheet extends StatefulWidget {
  final _ProviderDocService svc;
  final String patientId;
  final String patientName;

  const _UploadSheet({
    required this.svc,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<_UploadSheet> {
  String _category = _kCategories.first;
  PlatformFile? _picked;
  double? _progress;
  bool _uploading = false;
  String? _error;

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      withData: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _picked = result.files.first);
    }
  }

  Future<void> _upload() async {
    if (_picked == null || _picked!.path == null) return;
    final file = File(_picked!.path!);
    final ext  = _picked!.extension?.toLowerCase() ?? '';
    final mime = ext == 'pdf'
        ? 'application/pdf'
        : (ext == 'doc' || ext == 'docx')
            ? 'application/msword'
            : 'image/$ext';

    setState(() { _uploading = true; _progress = 0; _error = null; });

    try {
      final stream = widget.svc.upload(
        file: file,
        fileName: _picked!.name,
        category: _category,
        mimeType: mime,
        patientId: widget.patientId,
        patientName: widget.patientName,
      );
      await for (final p in stream) {
        if (mounted) setState(() => _progress = p);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _uploading = false; _error = 'Upload failed: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upload File for ${widget.patientName}',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: _kCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: _uploading
                ? null
                : (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _pick,
            icon: const Icon(Icons.attach_file),
            label: Text(_picked != null
                ? _picked!.name
                : 'Choose file (PDF / image / doc)'),
          ),
          if (_progress != null) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(value: _progress),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style:
                    const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_picked != null && !_uploading) ? _upload : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _uploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Upload',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
