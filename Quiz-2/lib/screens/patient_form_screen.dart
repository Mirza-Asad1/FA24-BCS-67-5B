import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../database/database_helper.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';
import '../widgets/animations.dart';
import '../widgets/patient_avatar.dart';

class PatientFormScreen extends StatefulWidget {
  final Patient? patient; // null = add, not null = edit
  const PatientFormScreen({super.key, this.patient});

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  static const _genders = ['Male', 'Female', 'Other'];

  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper.instance;

  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _condition;
  late final TextEditingController _notes;

  String _gender = 'Male';
  String _blood = 'O+';
  String? _imagePath;
  bool _imageChanged = false;
  bool _saving = false;

  bool get _isEdit => widget.patient != null;

  @override
  void initState() {
    super.initState();
    final p = widget.patient;
    _name = TextEditingController(text: p?.name ?? '');
    _age = TextEditingController(text: p == null ? '' : '${p.age}');
    _phone = TextEditingController(text: p?.phone ?? '');
    _email = TextEditingController(text: p?.email ?? '');
    _address = TextEditingController(text: p?.address ?? '');
    _condition = TextEditingController(text: p?.condition ?? '');
    _notes = TextEditingController(text: p?.notes ?? '');
    _gender = p?.gender ?? 'Male';
    _blood = p?.bloodGroup ?? 'O+';
    _imagePath = p?.imagePath;
  }

  @override
  void dispose() {
    for (final c in [_name, _age, _phone, _email, _address, _condition, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final x = await ImagePicker()
        .pickImage(source: source, imageQuality: 80, maxWidth: 1024);
    if (x != null) {
      setState(() {
        _imagePath = x.path;
        _imageChanged = true;
      });
    }
  }

  void _showImageOptions() {
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
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded,
                    color: AppColors.primary),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_imagePath != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.danger),
                  title: const Text('Remove photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _imagePath = null;
                      _imageChanged = true;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    String? image = _imagePath;
    if (_imageChanged) {
      final old = widget.patient?.imagePath;
      if (old != null) await _db.deleteFile(old);
      if (image != null) image = await _db.saveFile(image);
    }

    final patient = Patient(
      id: widget.patient?.id,
      name: _name.text.trim(),
      age: int.parse(_age.text.trim()),
      gender: _gender,
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      address: _address.text.trim(),
      bloodGroup: _blood,
      condition: _condition.text.trim(),
      notes: _notes.text.trim(),
      imagePath: image,
      createdAt: widget.patient?.createdAt,
    );

    if (_isEdit) {
      await _db.updatePatient(patient);
    } else {
      await _db.insertPatient(patient);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Patient' : 'Add Patient',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        flexibleSpace:
            Container(decoration: const BoxDecoration(gradient: AppColors.gradient)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            FadeSlideIn(
              child: Center(
                child: GestureDetector(
                  onTap: _showImageOptions,
                  child: Stack(
                    children: [
                      Hero(
                        tag: 'avatar_${widget.patient?.id ?? 'new'}',
                        child: PatientAvatar(
                          name: _name.text.isEmpty ? '+' : _name.text,
                          imagePath: _imagePath,
                          size: 108,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FadeSlideIn(index: 1, child: _title('Personal information')),
            FadeSlideIn(
              index: 1,
              child: _field(_name, 'Full name', Icons.person_rounded,
                  caps: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Please enter the patient name'
                      : null),
            ),
            FadeSlideIn(
              index: 2,
              child: Row(
                children: [
                  Expanded(
                    child: _field(_age, 'Age', Icons.cake_rounded,
                        keyboard: TextInputType.number, validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n < 0 || n > 120) return 'Invalid age';
                      return null;
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _field(_phone, 'Phone', Icons.phone_rounded,
                        keyboard: TextInputType.phone, validator: (v) {
                      if (v == null || v.trim().length < 7) {
                        return 'Enter a valid phone';
                      }
                      return null;
                    }),
                  ),
                ],
              ),
            ),
            FadeSlideIn(
              index: 3,
              child: Wrap(
                spacing: 10,
                children: _genders
                    .map((g) => ChoiceChip(
                          label: Text(g),
                          selected: _gender == g,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                              color: _gender == g
                                  ? Colors.white
                                  : AppColors.textDark,
                              fontWeight: FontWeight.w500),
                          showCheckmark: false,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: Colors.grey.shade200)),
                          onSelected: (_) => setState(() => _gender = g),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),
            FadeSlideIn(index: 4, child: _title('Contact')),
            FadeSlideIn(
              index: 4,
              child: _field(_email, 'Email (optional)', Icons.email_rounded,
                  keyboard: TextInputType.emailAddress),
            ),
            FadeSlideIn(
              index: 5,
              child: _field(_address, 'Address (optional)',
                  Icons.location_on_rounded,
                  caps: TextCapitalization.sentences),
            ),
            const SizedBox(height: 8),
            FadeSlideIn(index: 6, child: _title('Medical details')),
            FadeSlideIn(
              index: 6,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _bloodGroups
                    .map((b) => ChoiceChip(
                          label: Text(b),
                          selected: _blood == b,
                          selectedColor: AppColors.danger,
                          labelStyle: TextStyle(
                              color: _blood == b
                                  ? Colors.white
                                  : AppColors.textDark,
                              fontWeight: FontWeight.w600),
                          showCheckmark: false,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: Colors.grey.shade200)),
                          onSelected: (_) => setState(() => _blood = b),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              index: 7,
              child: _field(_condition, 'Condition / Diagnosis',
                  Icons.monitor_heart_rounded,
                  caps: TextCapitalization.sentences),
            ),
            FadeSlideIn(
              index: 8,
              child: _field(_notes, 'Doctor notes (optional)',
                  Icons.edit_note_rounded,
                  lines: 4, caps: TextCapitalization.sentences),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 9,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : Icon(_isEdit
                        ? Icons.check_circle_rounded
                        : Icons.save_rounded),
                label: Text(_isEdit ? 'Update Patient' : 'Save Patient'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(t,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark)),
      );

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
    int lines = 1,
    TextCapitalization caps = TextCapitalization.none,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        maxLines: lines,
        validator: validator,
        onChanged: onChanged,
        textCapitalization: caps,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary),
        ),
      ),
    );
  }
}
