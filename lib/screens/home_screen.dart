import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/logger.dart';
import '../models/medical_info_model.dart';
import '../models/user_model.dart';
import '../providers/app_state.dart';
import '../services/sos_service.dart';
import '../widgets/sos_button.dart';
import '../widgets/action_grid.dart';
import '../widgets/evidence_overview.dart';
import '../widgets/profile_header.dart';
import '../widgets/medical_info_section.dart';
import '../widgets/app_settings_section.dart';
import '../widgets/stealth_mode_section.dart';
import '../widgets/about_section.dart';
import '../widgets/journey_overview.dart';
import 'sos_active_screen.dart';
import 'profile_screen.dart';

/// HomeScreen is the central hub of the SheShield app.
///
/// Layout (top to bottom):
/// 1. AppBar with profile icon
/// 2. SafeStatusCard (animated green/red based on SOS state)
/// 3. Center SOS Button (3-sec hold to trigger)
/// 4. BraceletCard (BPM, battery, connection status)
/// 5. ActionGrid (2x3 quick actions)
/// 6. BottomNavigationBar (5 tabs)
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late SOSService _sosService;
  int _selectedIndex = 0;

  static const List<String> _tabTitles = [
    'Home',
    'Journey',
    'Evidence',
    'Contacts',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    _sosService = SOSService();
    AppLogger.serviceEvent('HomeScreen', 'Initialized');
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _selectedIndex) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  // ========== SOS TRIGGER HANDLER ==========
  void _handleSosTriggered() {
    AppLogger.i('SOS Button pressed - triggering SOS');

    // Trigger SOS service
    _sosService.triggerSOS(
      triggerSource: 'button',
      currentBPM: context.read<AppState>().braceletData.bpm,
    );

    // Update app state
    context.read<AppState>().setSosState(SosState.active);

    // Show the active SOS screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SosActiveScreen(),
      ),
    );
  }

  UserModel _buildCurrentUser() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return UserModel(
      userId: currentUser?.uid ?? 'local-user',
      email: currentUser?.email ?? '',
      displayName: currentUser?.displayName ?? 'User',
      avatarUrl: currentUser?.photoURL,
      isJourneyModeAutoArm: context.read<AppState>().isJourneyModeActive,
      isStealthModeEnabled: context.read<AppState>().isStealthModeActive,
      isVoiceTriggerEnabled: context.read<AppState>().isVoiceTriggerEnabled,
      isAudioTriggerEnabled: context.read<AppState>().isAudioTriggerEnabled,
      createdAt: currentUser?.metadata.creationTime ?? DateTime.now(),
    );
  }

  MedicalInfoModel _buildMedicalInfo() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return MedicalInfoModel(
      userId: currentUser?.uid ?? 'local-user',
      bloodGroup: 'B+',
      allergies: const ['Dust'],
      medicalConditions: const ['None'],
      doctorName: 'Dr. Mehta',
      doctorContact: '+91 98800 11234',
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeFormat =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'pm' : 'am'}';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentUser = _buildCurrentUser();
    final medicalInfo = _buildMedicalInfo();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      // ========== APP BAR ==========
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: _selectedIndex == 0
            ? Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'SheShield',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        'Wednesday, 1 Apr',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                            ),
                      ),
                    ],
                  ),
                ],
              )
            : Text(
                _tabTitles[_selectedIndex],
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
        actions: [
          // Light/Dark mode toggle
          IconButton(
            icon: Icon(
              isDarkMode
                  ? Icons.brightness_7_rounded
                  : Icons.brightness_4_rounded,
            ),
            onPressed: () {
              AppLogger.d('Theme toggle pressed');
              context.read<AppState>().toggleThemeMode();
            },
          ),
          // Notifications
          IconButton(
            icon: const Icon(Icons.notifications_rounded),
            onPressed: () {
              AppLogger.d('Notifications pressed');
            },
          ),
          // Profile icon
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.person_rounded),
              onPressed: () {
                // Navigate to profile screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
                AppLogger.d('Profile button pressed');
              },
            ),
          ),
        ],
      ),

      // ========== BODY ==========
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(
            key: ValueKey(_selectedIndex),
            child: switch (_selectedIndex) {
              1 => _buildJourneyTab(context),
              2 => _buildEvidenceTab(context),
              3 => _buildContactsTab(context),
              4 => _buildSettingsTab(context, currentUser, medicalInfo),
              _ => _buildHomeTab(context, now, timeFormat),
            },
          ),
        ),
      ),

      // ========== BOTTOM NAVIGATION BAR ==========
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.navigation_rounded),
            label: 'Journey',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.description_rounded),
            label: 'Evidence',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.groups_rounded),
            label: 'Contacts',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
        onTap: _selectTab,
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context, DateTime now, String timeFormat) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good ${now.hour < 12 ? 'Morning' : now.hour < 18 ? 'Afternoon' : 'Evening'},',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withValues(alpha: 0.7),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentUser?.displayName ?? 'User',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                Text(
                  timeFormat,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.38),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        color: AppColors.warningDark,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Band Disconnected',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warningDark,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Please reconnect your band',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppColors.warningDark,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SosButton(
                  onSosTriggered: _handleSosTriggered,
                  onCountdownUpdate: (progress) {},
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                Consumer<AppState>(
                  builder: (context, appState, _) {
                    return ActionGrid(
                      onJourney: () {
                        _selectTab(1);
                      },
                      onNearbyPolice: () {
                        AppLogger.d('Nearby Police tapped');
                      },
                      onEvidence: () {
                        _selectTab(2);
                      },
                      onEmergencyContacts: () {
                        _selectTab(3);
                      },
                      onBand: () {
                        AppLogger.d('Band tapped');
                      },
                      onStealth: () {
                        AppLogger.d('Stealth tapped');
                      },
                      isJourneyModeActive: appState.isJourneyModeActive,
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyTab(BuildContext context) {
    return const JourneyOverview();
  }

  Widget _buildEvidenceTab(BuildContext context) {
    return const EvidenceOverview();
  }

  Widget _buildContactsTab(BuildContext context) {
    final contacts = [
      _ContactData(
          'Anjali Sharma', 'Family', '+91 98765 11111', AppColors.primary),
      _ContactData('Meera Singh', 'Friend', '+91 98765 22222', AppColors.info),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emergency Contacts',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'These ${contacts.length} contacts will be notified instantly during an emergency.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: contacts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return _ContactCard(data: contact, index: index + 1);
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                AppLogger.d('Add Contact tapped');
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Contact'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab(
    BuildContext context,
    UserModel currentUser,
    MedicalInfoModel medicalInfo,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          ProfileHeader(
            user: currentUser,
            onEditProfile: () {
              AppLogger.d('Edit profile pressed');
            },
          ),
          const SizedBox(height: 24),
          MedicalInfoSection(
            medicalInfo: medicalInfo,
            onEdit: () {
              AppLogger.d('Edit medical info pressed');
            },
          ),
          const SizedBox(height: 24),
          AppSettingsSection(
            user: currentUser,
            onSettingChanged: (settingName, value) {
              AppLogger.d('Setting $settingName changed to $value');
            },
          ),
          const SizedBox(height: 24),
          StealthModeSection(
            onTapCountChanged: (tapCount) {
              AppLogger.d('Stealth mode tap count: $tapCount');
            },
          ),
          const SizedBox(height: 24),
          const AboutSection(),
          const SizedBox(height: 32),
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
                onPressed: _showLogoutDialog,
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
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _ContactData {
  final String name;
  final String relation;
  final String phone;
  final Color color;

  _ContactData(this.name, this.relation, this.phone, this.color);
}

class _ContactCard extends StatelessWidget {
  final _ContactData data;
  final int index;

  const _ContactCard({required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    final initial = data.name.isNotEmpty ? data.name[0] : '?';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: data.color,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
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
                        data.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '#$index',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  data.phone,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: data.color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    data.relation,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: data.color,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              _ContactActionButton(
                  icon: Icons.call_rounded, color: AppColors.safe),
              const SizedBox(height: 8),
              _ContactActionButton(
                  icon: Icons.message_rounded, color: AppColors.info),
              const SizedBox(height: 8),
              _ContactActionButton(
                  icon: Icons.delete_outline_rounded, color: AppColors.danger),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _ContactActionButton({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}
