import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/record_service.dart';
import '../../services/appointment_service.dart';
import '../../services/document_service.dart';
import '../../models/health_record_model.dart';
import '../../models/medical_note_model.dart';
import '../../models/document_model.dart';
import '../../theme/app_theme.dart';
import 'add_record_screen.dart';

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Health Records'),
          backgroundColor: AppColors.background,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: "Doctor's Notes"),
              Tab(text: 'My Records'),
              Tab(text: 'Documents'),
            ],
          ),
        ),
        floatingActionButton: _RecordsFab(),
        body: const TabBarView(
          children: [
            _DoctorNotesTab(),
            _MyRecordsTab(),
            _DocumentsTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Doctor Notes tab — read-only, populated from medical_notes collection
// ---------------------------------------------------------------------------

class _DoctorNotesTab extends StatelessWidget {
  const _DoctorNotesTab();

  @override
  Widget build(BuildContext context) {
    final apptService = context.read<AppointmentService>();

    return StreamBuilder<List<MedicalNoteModel>>(
      stream: apptService.myMedicalNotesStream(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final notes = snap.data ?? [];
        if (notes.isEmpty) {
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
                  child: const Icon(Icons.medical_information_outlined,
                      color: AppColors.primary, size: 40),
                ),
                const SizedBox(height: 16),
                const Text("No doctor's notes yet",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                const Text('Notes from your doctor will appear here',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: notes.length,
          itemBuilder: (_, i) => _DoctorNoteCard(note: notes[i]),
        );
      },
    );
  }
}

class _DoctorNoteCard extends StatelessWidget {
  final MedicalNoteModel note;
  const _DoctorNoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showNoteDetail(context, note),
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.medical_information_outlined,
                  color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(note.diagnosis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: AppColors.textPrimary)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('View',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Dr. ${note.providerName}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  if (note.notes.isNotEmpty)
                    Text(note.notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy').format(note.date),
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoteDetail(BuildContext context, MedicalNoteModel note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NoteDetailSheet(note: note),
    );
  }
}

class _NoteDetailSheet extends StatelessWidget {
  final MedicalNoteModel note;
  const _NoteDetailSheet({required this.note});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text('Medical Note',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_outline,
                            size: 12, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text('Read-only',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.person_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('Dr. ${note.providerName}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 12),
                  const Icon(Icons.calendar_today,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(DateFormat('MMM d, yyyy').format(note.date),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  _NoteSection(
                    icon: Icons.medical_information_outlined,
                    title: 'Diagnosis',
                    content: note.diagnosis,
                    color: AppColors.danger,
                  ),
                  if (note.notes.isNotEmpty)
                    _NoteSection(
                      icon: Icons.notes_outlined,
                      title: 'Clinical Notes',
                      content: note.notes,
                      color: AppColors.primary,
                    ),
                  if (note.prescription.isNotEmpty)
                    _NoteSection(
                      icon: Icons.medication_outlined,
                      title: 'Prescription',
                      content: note.prescription,
                      color: AppColors.success,
                    ),
                  if (note.followUp.isNotEmpty)
                    _NoteSection(
                      icon: Icons.event_outlined,
                      title: 'Follow-up',
                      content: note.followUp,
                      color: AppColors.warning,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color color;

  const _NoteSection({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(content,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textPrimary, height: 1.5)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// My Records tab — patient's own self-entered records (add / delete)
// ---------------------------------------------------------------------------

class _MyRecordsTab extends StatelessWidget {
  const _MyRecordsTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final uid = auth.currentUser?.uid;
    final recordService = context.read<RecordService>();

    return uid == null
        ? const Center(child: Text('Not logged in'))
        : StreamBuilder<List<HealthRecordModel>>(
            stream: recordService.getRecords(uid),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final records = snap.data ?? [];
              if (records.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.folder_open_outlined,
                            color: AppColors.success, size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text('No personal records yet',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      const Text('Tap + to add your first record',
                          style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                itemCount: records.length,
                itemBuilder: (_, i) {
                  final r = records[i];
                  return _RecordCard(
                    record: r,
                    onDelete: () async {
                      final confirmed = await showDialog<bool>(
                            context: ctx,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: const Text('Delete Record'),
                              content: Text('Remove "${r.title}"?'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, true),
                                  child: const Text('Delete',
                                      style: TextStyle(
                                          color: AppColors.danger)),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (confirmed) {
                        await recordService.deleteRecord(r.id);
                      }
                    },
                  );
                },
              );
            },
          );
  }
}

class _RecordCard extends StatelessWidget {
  final HealthRecordModel record;
  final VoidCallback onDelete;

  const _RecordCard({required this.record, required this.onDelete});

  @override
  Widget build(BuildContext context) {
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
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.description_outlined,
                color: AppColors.success, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                if (record.description.isNotEmpty)
                  Text(record.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d, yyyy').format(record.date),
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.delete_outline,
                color: AppColors.danger, size: 20),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab-aware FAB: show Add Record on tab 1, Upload on tab 2, nothing on tab 0
// ---------------------------------------------------------------------------

class _RecordsFab extends StatefulWidget {
  const _RecordsFab();

  @override
  State<_RecordsFab> createState() => _RecordsFabState();
}

class _RecordsFabState extends State<_RecordsFab> {
  int _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ctrl = DefaultTabController.of(context);
    ctrl.addListener(() {
      if (mounted) setState(() => _index = ctrl.index);
    });
    _index = ctrl.index;
  }

  @override
  Widget build(BuildContext context) {
    if (_index == 0) return const SizedBox.shrink();
    if (_index == 1) {
      return FloatingActionButton(
        heroTag: 'records_fab',
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddRecordScreen())),
        backgroundColor: AppColors.primary,
        tooltip: 'Add personal record',
        child: const Icon(Icons.add, color: Colors.white),
      );
    }
    // tab 2 – upload document
    return FloatingActionButton.extended(
      heroTag: 'records_fab',
      onPressed: () => _showUploadSheet(context),
      backgroundColor: AppColors.primary,
      icon: const Icon(Icons.upload_file, color: Colors.white),
      label:
          const Text('Upload', style: TextStyle(color: Colors.white)),
    );
  }

  void _showUploadSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _UploadSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// Upload bottom sheet
// ---------------------------------------------------------------------------

const _kCategories = [
  'Lab Results',
  'X-Ray / Imaging',
  'Prescription',
  'Insurance',
  'Other',
];

class _UploadSheet extends StatefulWidget {
  const _UploadSheet();

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
    final service = context.read<DocumentService>();
    final ext = _picked!.extension?.toLowerCase() ?? '';
    final mime = ext == 'pdf'
        ? 'application/pdf'
        : (ext == 'doc' || ext == 'docx')
            ? 'application/msword'
            : 'image/$ext';

    setState(() {
      _uploading = true;
      _progress = 0;
      _error = null;
    });

    try {
      final stream = service.uploadDocument(
        file: file,
        fileName: _picked!.name,
        category: _category,
        mimeType: mime,
      );
      await for (final p in stream) {
        if (mounted) setState(() => _progress = p);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _error = 'Upload failed: $e';
        });
      }
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
          const Text('Upload Document',
              style: TextStyle(
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
            label: Text(
                _picked != null ? _picked!.name : 'Choose file (PDF / image / doc)'),
          ),
          if (_progress != null) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(value: _progress),
          ],
          if (_error != null) ...[  
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(
                    color: AppColors.danger, fontSize: 13)),
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

// ---------------------------------------------------------------------------
// Documents tab
// ---------------------------------------------------------------------------

class _DocumentsTab extends StatelessWidget {
  const _DocumentsTab();

  @override
  Widget build(BuildContext context) {
    final service = context.read<DocumentService>();
    return StreamBuilder<List<DocumentModel>>(
      stream: service.documentsStream(),
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
                const Text('No documents yet',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                const Text('Tap Upload to add a file',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: docs.length,
          itemBuilder: (_, i) => _DocumentCard(doc: docs[i], service: service),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Single document card
// ---------------------------------------------------------------------------

class _DocumentCard extends StatelessWidget {
  final DocumentModel doc;
  final DocumentService service;

  const _DocumentCard({required this.doc, required this.service});

  @override
  Widget build(BuildContext context) {
    final isImage = doc.isImage;
    final color = isImage ? Colors.teal : AppColors.primary;

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
                isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
                color: color,
                size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Badge(doc.category, color),
                    const SizedBox(width: 8),
                    Text(doc.sizeLabel,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM d, yyyy').format(doc.uploadedAt),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new,
                size: 20, color: AppColors.primary),
            tooltip: 'Open',
            onPressed: () async {
              final uri = Uri.parse(doc.url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri,
                    mode: LaunchMode.externalApplication);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 20, color: AppColors.danger),
            tooltip: 'Delete',
            onPressed: () async {
              final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: const Text('Delete document?'),
                      content: Text('Remove "${doc.name}"?'),
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
              if (ok) await service.deleteDocument(doc);
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
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }
}

