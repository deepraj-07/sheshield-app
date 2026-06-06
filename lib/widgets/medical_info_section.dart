import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/medical_info_model.dart';
import '../services/local_storage_service.dart';

/// MedicalInfoSection — displays medical info and opens an edit bottom sheet.
class MedicalInfoSection extends StatefulWidget {
  final MedicalInfoModel medicalInfo;
  final VoidCallback onEdit;
  final ValueChanged<MedicalInfoModel>? onSaved;

  const MedicalInfoSection({
    Key? key,
    required this.medicalInfo,
    required this.onEdit,
    this.onSaved,
  }) : super(key: key);

  @override
  State<MedicalInfoSection> createState() => _MedicalInfoSectionState();
}

class _MedicalInfoSectionState extends State<MedicalInfoSection> {
  late MedicalInfoModel _info;

  @override
  void initState() {
    super.initState();
    _info = widget.medicalInfo;
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final data = await LocalStorageService.loadMedicalInfo();
    // Only override if storage has actual data (not empty)
    final storedBlood = data['bloodGroup'] as String;
    if (storedBlood.isNotEmpty || (data['allergies'] as List).isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _info = _info.copyWith(
          bloodGroup: storedBlood.isNotEmpty ? storedBlood : _info.bloodGroup,
          allergies: (data['allergies'] as List<dynamic>).cast<String>(),
          medicalConditions:
              (data['conditions'] as List<dynamic>).cast<String>(),
          doctorName: (data['doctorName'] as String).isNotEmpty
              ? data['doctorName'] as String
              : _info.doctorName,
          doctorContact: (data['doctorPhone'] as String).isNotEmpty
              ? data['doctorPhone'] as String
              : _info.doctorContact,
        );
      });
    }
  }

  void _openEditSheet() async {
    final updated = await showModalBottomSheet<MedicalInfoModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MedicalEditSheet(info: _info),
    );
    if (updated != null) {
      setState(() => _info = updated);
      // Persist to SharedPreferences
      await LocalStorageService.saveMedicalInfo(
        bloodGroup: updated.bloodGroup,
        allergies: updated.allergies,
        conditions: updated.medicalConditions,
        doctorName: updated.doctorName,
        doctorPhone: updated.doctorContact,
      );
      widget.onSaved?.call(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.medical_information_rounded,
                  color: AppColors.danger, size: 20),
              const SizedBox(width: 8),
              Text('Medical Information',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: _openEditSheet,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.edit_rounded,
                        size: 13, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('Edit',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _InfoRow(
                icon: Icons.bloodtype_rounded,
                color: AppColors.danger,
                label: 'Blood Group',
                value: _info.bloodGroup.isEmpty ? 'Not set' : _info.bloodGroup),
            const Divider(height: 20),
            _InfoRow(
                icon: Icons.warning_amber_rounded,
                color: AppColors.warning,
                label: 'Allergies',
                value: _info.allergies.isEmpty
                    ? 'None'
                    : _info.allergies.join(', ')),
            const Divider(height: 20),
            _InfoRow(
                icon: Icons.local_hospital_rounded,
                color: AppColors.info,
                label: 'Medical Conditions',
                value: _info.medicalConditions.isEmpty
                    ? 'None'
                    : _info.medicalConditions.join(', ')),
            const Divider(height: 20),
            _InfoRow(
                icon: Icons.person_rounded,
                color: AppColors.safe,
                label: 'Doctor',
                value: _info.doctorName.isEmpty
                    ? 'Not set'
                    : '${_info.doctorName}${_info.doctorContact.isNotEmpty ? '\n${_info.doctorContact}' : ''}'),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 12),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500)),
      ])),
    ]);
  }
}

// =============================================================================
// Edit bottom sheet
// =============================================================================

class _MedicalEditSheet extends StatefulWidget {
  final MedicalInfoModel info;
  const _MedicalEditSheet({required this.info});

  @override
  State<_MedicalEditSheet> createState() => _MedicalEditSheetState();
}

class _MedicalEditSheetState extends State<_MedicalEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _bloodCtrl;
  late TextEditingController _allergiesCtrl;
  late TextEditingController _conditionsCtrl;
  late TextEditingController _doctorNameCtrl;
  late TextEditingController _doctorPhoneCtrl;

  static const _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];
  String _selectedBloodGroup = 'O+';

  @override
  void initState() {
    super.initState();
    _selectedBloodGroup = _bloodGroups.contains(widget.info.bloodGroup)
        ? widget.info.bloodGroup
        : 'O+';
    _bloodCtrl = TextEditingController(text: widget.info.bloodGroup);
    _allergiesCtrl =
        TextEditingController(text: widget.info.allergies.join(', '));
    _conditionsCtrl =
        TextEditingController(text: widget.info.medicalConditions.join(', '));
    _doctorNameCtrl = TextEditingController(text: widget.info.doctorName);
    _doctorPhoneCtrl = TextEditingController(text: widget.info.doctorContact);
  }

  @override
  void dispose() {
    _bloodCtrl.dispose();
    _allergiesCtrl.dispose();
    _conditionsCtrl.dispose();
    _doctorNameCtrl.dispose();
    _doctorPhoneCtrl.dispose();
    super.dispose();
  }

  List<String> _splitTags(String raw) =>
      raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final updated = widget.info.copyWith(
      bloodGroup: _selectedBloodGroup,
      allergies: _splitTags(_allergiesCtrl.text),
      medicalConditions: _splitTags(_conditionsCtrl.text),
      doctorName: _doctorNameCtrl.text.trim(),
      doctorContact: _doctorPhoneCtrl.text.trim(),
    );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Handle
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(999)))),
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.medical_information_rounded,
                    color: AppColors.danger, size: 22),
                const SizedBox(width: 10),
                Text('Edit Medical Info',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 20),

              // Blood group
              Text('Blood Group',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _bloodGroups.map((bg) {
                  final selected = _selectedBloodGroup == bg;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedBloodGroup = bg),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.danger
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: selected
                                ? AppColors.danger
                                : Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.4)),
                      ),
                      child: Text(bg,
                          style: TextStyle(
                              color: selected ? Colors.white : null,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Allergies
              TextFormField(
                controller: _allergiesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Allergies',
                  hintText: 'Dust, Pollen, Penicillin…',
                  prefixIcon: Icon(Icons.warning_amber_rounded),
                  helperText: 'Separate multiple entries with commas',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 14),

              // Medical conditions
              TextFormField(
                controller: _conditionsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Medical Conditions',
                  hintText: 'Diabetes, Asthma, None…',
                  prefixIcon: Icon(Icons.local_hospital_rounded),
                  helperText: 'Separate multiple entries with commas',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 14),

              // Doctor name
              TextFormField(
                controller: _doctorNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Doctor Name',
                  hintText: 'Dr. Sharma',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 14),

              // Doctor phone
              TextFormField(
                controller: _doctorPhoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Doctor Phone',
                  hintText: '+91 98800 00000',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save Medical Info',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
