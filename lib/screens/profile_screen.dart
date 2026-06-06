import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/logger.dart';
import '../models/user_model.dart';
import '../models/medical_info_model.dart';
import '../widgets/profile_header.dart';
import '../widgets/medical_info_section.dart';
import '../widgets/app_settings_section.dart';
import '../widgets/stealth_mode_section.dart';
import '../widgets/about_section.dart';

/// ProfileScreen displays user information, medical details, and app settings
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserModel _user;
  late MedicalInfoModel _medicalInfo;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _user = UserModel(
        userId: currentUser.uid,
        email: currentUser.email ?? '',
        displayName: currentUser.displayName ?? 'User',
        avatarUrl: currentUser.photoURL,
        createdAt: currentUser.metadata.creationTime ?? DateTime.now(),
      );
    }
    _medicalInfo = MedicalInfoModel(
      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
      bloodGroup: 'B+',
      doctorName: 'Dr. Mehta',
      doctorContact: '+91 98800 11234',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              // ========== PROFILE HEADER ==========
              ProfileHeader(
                user: _user,
                onEditProfile: () {
                  AppLogger.d('Edit profile pressed');
                  // Navigate to edit profile screen
                },
              ),

              const SizedBox(height: 24),

              // ========== MEDICAL INFORMATION ==========
              MedicalInfoSection(
                medicalInfo: _medicalInfo,
                onEdit: () {},
                onSaved: (updated) => setState(() => _medicalInfo = updated),
              ),

              const SizedBox(height: 24),

              // ========== APP SETTINGS ==========
              AppSettingsSection(
                user: _user,
                onSettingChanged: (settingName, value) {
                  AppLogger.d('Setting $settingName changed to $value');
                  // Update in Firebase
                },
              ),

              const SizedBox(height: 24),

              // ========== STEALTH MODE SETUP ==========
              StealthModeSection(
                onTapCountChanged: (tapCount) {
                  AppLogger.d('Stealth mode tap count: $tapCount');
                },
              ),

              const SizedBox(height: 24),

              // ========== ABOUT ==========
              const AboutSection(),

              const SizedBox(height: 32),

              // ========== LOGOUT BUTTON ==========
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      _showLogoutDialog();
                    },
                    child: Text(
                      'Logout',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close profile screen
              // Navigation to login will be handled by AuthProvider
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
