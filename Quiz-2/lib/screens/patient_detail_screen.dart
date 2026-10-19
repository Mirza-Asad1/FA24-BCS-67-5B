import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../database/database_helper.dart';
import '../models/patient.dart';
import '../models/patient_document.dart';
import '../theme/app_theme.dart';
import '../widgets/animations.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/patient_avatar.dart';
import 'patient_form_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final Patient patient;
  const PatientDetailScreen({super.key, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  final _db = DatabaseHelper.instance;
  late Patient _patient = widget.patient;
  List<PatientDocument> _docs = [];

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  Future<void> _loadDocs() async {
    final d = await _db.getDocuments(_patient.id!);
    if (!mounted) return;
    setState(() => _docs = d);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.primaryDark,
      ));
  }

  Future<void> _edit() async {
    final saved = await Navigator.push<bool>(
        context, slideUpRoute(PatientFormScreen(patient: _patient)));
    if (saved == true) {
      final fresh = await _db.getPatient(_patient.id!);
      if (fresh != null && mounted) {
        setState(() => _patient = fresh);
        _snack('Patient updated successfully');
      }
    }
  }

  Future<void> _deletePatient() async {
    final ok = await confirmDelete(
      context,
      title: 'Delete patient?',
      message:
          '${_patient.name} and all attached documents will be removed permanently.',
    );
    if (!ok) return;
    await _db.deletePatient(_patient);
    if (mounted) Navigator.pop(context);
  }

  // ---------------------------------------------------------- documents
  Future<void> _addImage(ImageSource source) async {
    final x = await ImagePicker()
        .pickImage(source: source, imageQuality: 85, maxWidth: 2048);
    if (x == null) return;
    final saved = await _db.saveFile(x.path);
    await _db.insertDocument(PatientDocument(
      patientId: _patient.id!,
      name: x.name,
      path: saved,
      isImage: true,
    ));
    await _loadDocs();
    if (mounted) _snack('Image added');
  }

  Future<void> _addFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;
    final f = result.files.single;
    final saved = await _db.saveFile(f.path!);
    final ext = (f.extension ?? '').toLowerCase();
    final isImg = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
    await _db.insertDocument(PatientDocument(
      patientId: _patient.id!,
      name: f.name,
      path: saved,
      isImage: isImg,
    ));
    await _loadDocs();
    if (mounted) _snack('Document added');
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 18),
              _option(ctx, Icons.photo_camera_rounded, 'Take a photo',
                  () => _addImage(ImageSource.camera)),
              _option(ctx, Icons.photo_library_rounded, 'Upload from gallery',
                  () => _addImage(ImageSource.gallery)),
              _option(ctx, Icons.upload_file_rounded,
                  'Upload a file (PDF, report...)', _addFile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _option(BuildContext ctx, IconData icon, String text, VoidCallback f) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(text),
      onTap: () {
        Navigator.pop(ctx);
        f();
      },
    );
  }

  Future<void> _openDoc(PatientDocument d) async {
    if (d.isImage) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: InteractiveViewer(
                  child: Image.file(File(d.path), fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final r = await OpenFilex.open(d.path);
      if (r.type != ResultType.done && mounted) {
        _snack('No app found to open this file');
      }
    }
  }

  Future<void> _deleteDoc(PatientDocument d) async {
    final ok = await confirmDelete(context,
        title: 'Delete document?', message: '"${d.name}" will be removed.');
    if (!ok) return;
    await _db.deleteDocument(d);
    await _loadDocs();
    if (mounted) _snack('Document deleted');
  }

  IconData _fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  // --------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final p = _patient;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOptions,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_photo_alternate_rounded),
        label: const Text('Add document'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 270,
            backgroundColor: AppColors.primaryDark,
            actions: [
              IconButton(
                  icon: const Icon(Icons.edit_rounded), onPressed: _edit),
              IconButton(
                  icon: const Icon(Icons.delete_rounded),
                  onPressed: _deletePatient),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(p.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.gradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 42),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Hero(
                          tag: 'avatar_${p.id}',
                          child: PatientAvatar(
                              name: p.name, imagePath: p.imagePath, size: 104),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _pill('${p.age} yrs'),
                            const SizedBox(width: 8),
                            _pill(p.gender),
                            const SizedBox(width: 8),
                            _pill(p.bloodGroup),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                FadeSlideIn(
                  child: _card('Contact', Icons.contact_phone_rounded, [
                    _row(Icons.phone_rounded, 'Phone', p.phone),
                    if (p.email.isNotEmpty)
                      _row(Icons.email_rounded, 'Email', p.email),
                    if (p.address.isNotEmpty)
                      _row(Icons.location_on_rounded, 'Address', p.address),
                  ]),
                ),
                FadeSlideIn(
                  index: 1,
                  child: _card('Medical', Icons.monitor_heart_rounded, [
                    _row(Icons.bloodtype_rounded, 'Blood group', p.bloodGroup),
                    _row(Icons.healing_rounded, 'Condition',
                        p.condition.isEmpty ? 'Not specified' : p.condition),
                    if (p.notes.isNotEmpty)
                      _row(Icons.edit_note_rounded, 'Notes', p.notes),
                    _row(Icons.event_rounded, 'Registered',
                        DateFormat('dd MMM yyyy').format(p.createdAt)),
                  ]),
                ),
                FadeSlideIn(index: 2, child: _documentsSection()),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(t,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      );

  Widget _card(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: AppColors.primaryDark.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: AppColors.primaryDark.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.folder_copy_rounded,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Text('Documents & images',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${_docs.length}',
                style: const TextStyle(
                    color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          if (_docs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No documents yet.\nTap "Add document" to upload reports or images.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textLight),
                ),
              ),
            )
          else
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: Column(
                children: [
                  for (var i = 0; i < _docs.length; i++)
                    FadeSlideIn(
                      key: ValueKey('doc_${_docs[i].id}'),
                      index: i,
                      offset: 16,
                      child: _docTile(_docs[i]),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _docTile(PatientDocument d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: () => _openDoc(d),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 52,
            height: 52,
            child: d.isImage && File(d.path).existsSync()
                ? Image.file(File(d.path), fit: BoxFit.cover)
                : Container(
                    color: AppColors.primary.withOpacity(0.15),
                    child: Icon(_fileIcon(d.name),
                        color: AppColors.primaryDark, size: 28),
                  ),
          ),
        ),
        title: Text(d.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        subtitle: Text(DateFormat('dd MMM yyyy, hh:mm a').format(d.addedAt),
            style:
                const TextStyle(color: AppColors.textLight, fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              color: AppColors.danger),
          onPressed: () => _deleteDoc(d),
        ),
      ),
    );
  }
}
