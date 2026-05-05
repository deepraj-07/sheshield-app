import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/medical_info_model.dart';

/// MedicalInfoSection displays blood group, allergies, medical conditions, and doctor contact
class MedicalInfoSection extends StatelessWidget {
  final MedicalInfoModel medicalInfo;
  final VoidCallback onEdit;

  const MedicalInfoSection({
    Key? key,
    required this.medicalInfo,
    required this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== SECTION TITLE ==========
            Text(
              'Medical Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),

            const SizedBox(height: 16),

            // ========== BLOOD GROUP ==========
            _InfoRow(
              label: 'Blood Group',
              value: medicalInfo.bloodGroup,
              icon: Icons.favorite_outline,
            ),

            const SizedBox(height: 16),

            // ========== ALLERGIES ==========
            _InfoRow(
              label: 'Allergies',
              value: medicalInfo.allergies.isEmpty
                  ? 'None'
                  : medicalInfo.allergies.join(', '),
              icon: Icons.warning_amber_outlined,
            ),

            const SizedBox(height: 16),

            // ========== MEDICAL CONDITIONS ==========
            _InfoRow(
              label: 'Medical Conditions',
              value: medicalInfo.medicalConditions.isEmpty
                  ? 'None'
                  : medicalInfo.medicalConditions.join(', '),
              icon: Icons.local_hospital_outlined,
            ),

            const SizedBox(height: 16),

            // ========== DOCTOR CONTACT ==========
            _InfoRow(
              label: 'Doctor Contact',
              value: medicalInfo.doctorContact.isEmpty
                  ? 'Not set'
                  : '${medicalInfo.doctorName}\n${medicalInfo.doctorContact}',
              icon: Icons.person_outline,
            ),

            const SizedBox(height: 16),

            // ========== EDIT BUTTON ==========
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit Medical Info'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper widget to display info rows
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.color
                          ?.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
