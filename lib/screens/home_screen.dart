import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/logger.dart';
import '../models/contact_model.dart';
import '../models/medical_info_model.dart';
import '../models/user_model.dart';
import '../providers/app_state.dart';
import '../services/local_storage_service.dart';
import '../services/sos_service.dart';
import '../services/stealth_mode_service.dart';
import '../widgets/sos_button.dart';
import '../widgets/action_grid.dart';
import '../widgets/evidence_overview.dart';
import '../widgets/profile_header.dart';
import '../widgets/medical_info_section.dart';
import '../widgets/app_settings_section.dart';
import '../widgets/stealth_mode_section.dart';
import '../widgets/about_section.dart';
import '../widgets/journey_overview.dart';
import '../widgets/rtdb_status_card.dart';
import 'sos_active_screen.dart';
import 'profile_screen.dart';
import 'nearby_help_screen.dart';

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
  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  int _stealthTapCount = 3; // loaded from SharedPreferences

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sosService.setAppState(context.read<AppState>());
      // Listen for hardware/bracelet SOS triggers to add notifications
      _listenForExternalSosTriggers();
    });
    // Live clock — tick every second
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // Load stealth tap count from SharedPreferences
    _loadStealthTapCount();
    // Seed initial notifications
    _notifications.addAll([
      _NotifItem(
        id: 'shield_active',
        icon: Icons.shield_rounded,
        color: AppColors.primary,
        title: 'SheShield is active',
        body: 'Your safety shield is armed and monitoring.',
        time: DateTime.now(),
      ),
      _NotifItem(
        id: 'location_ok',
        icon: Icons.location_on_rounded,
        color: AppColors.info,
        title: 'Location access granted',
        body: 'GPS is active for emergency response.',
        time: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
    ]);
    AppLogger.serviceEvent('HomeScreen', 'Initialized');
  }

  Future<void> _loadStealthTapCount() async {
    final count = await LocalStorageService.loadStealthTapCount();
    if (mounted) setState(() => _stealthTapCount = count);
  }

  /// Watch AppState SOS state changes to add notifications for external triggers
  /// (hardware, bracelet) that bypass the button handler.
  void _listenForExternalSosTriggers() {
    final appState = context.read<AppState>();
    appState.addListener(_onAppStateChanged);
  }

  SosState _lastSosState = SosState.idle;

  void _onAppStateChanged() {
    if (!mounted) return;
    final appState = context.read<AppState>();
    final newState = appState.sosState;

    if (newState == SosState.active && _lastSosState != SosState.active) {
      // SOS became active — if the screen isn't already open, open it
      if (!_sosScreenOpen) {
        _addNotification(_NotifItem(
          id: 'sos_external_${DateTime.now().millisecondsSinceEpoch}',
          icon: Icons.warning_rounded,
          color: AppColors.danger,
          title: '🚨 SOS Triggered',
          body: 'Emergency alert sent. Contacts notified.',
          time: DateTime.now(),
        ));
        _openSosScreen();
      }
    } else if (newState == SosState.idle && _lastSosState == SosState.active) {
      _addNotification(_NotifItem(
        id: 'sos_resolved_${DateTime.now().millisecondsSinceEpoch}',
        icon: Icons.check_circle_rounded,
        color: AppColors.safe,
        title: 'SOS Resolved',
        body: 'Emergency alert has been cancelled.',
        time: DateTime.now(),
      ));
    }

    // Stealth session activated
    if (appState.isStealthSessionActive && !_lastStealthActive) {
      _addNotification(_NotifItem(
        id: 'stealth_${DateTime.now().millisecondsSinceEpoch}',
        icon: Icons.visibility_off_rounded,
        color: AppColors.danger,
        title: '🛡 Stealth Emergency Active',
        body: 'Silent alert sent. Live tracking started.',
        time: DateTime.now(),
      ));
    }

    _lastSosState = newState;
    _lastStealthActive = appState.isStealthSessionActive;
  }

  bool _lastStealthActive = false;

  @override
  void dispose() {
    _clockTimer?.cancel();
    // Remove AppState listener
    try {
      context.read<AppState>().removeListener(_onAppStateChanged);
    } catch (_) {}
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

  // ── Dynamic notification list ──────────────────────────────────────────────
  final List<_NotifItem> _notifications = [];

  void _addNotification(_NotifItem item) {
    setState(() {
      _notifications.insert(0, item); // newest first
    });
  }

  int get _unreadCount => _notifications.where((n) => !n.read).length;

  bool _sosScreenOpen = false;

  // ========== SOS TRIGGER HANDLER ==========
  void _handleSosTriggered() {
    if (_sosScreenOpen) return;

    AppLogger.i('SOS Button pressed - triggering SOS');

    _sosService.triggerSOS(
      triggerSource: 'button',
      currentBPM: context.read<AppState>().braceletData.bpm,
    );
    context.read<AppState>().setSosState(SosState.active);

    // Add SOS notification
    _addNotification(_NotifItem(
      id: 'sos_${DateTime.now().millisecondsSinceEpoch}',
      icon: Icons.warning_rounded,
      color: AppColors.danger,
      title: '🚨 SOS Triggered',
      body: 'Emergency alert sent. Contacts notified.',
      time: DateTime.now(),
    ));

    _openSosScreen();
  }

  void _openSosScreen() {
    if (_sosScreenOpen) return;
    _sosScreenOpen = true;

    Navigator.of(context)
        .push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SosActiveScreen(),
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final slide = Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ));
          return SlideTransition(position: slide, child: child);
        },
      ),
    )
        .whenComplete(() {
      _sosScreenOpen = false;
      // Add cancelled notification only if SOS was actually active
      if (context.read<AppState>().sosState != SosState.active) {
        _addNotification(_NotifItem(
          id: 'sos_cancelled_${DateTime.now().millisecondsSinceEpoch}',
          icon: Icons.check_circle_rounded,
          color: AppColors.safe,
          title: 'SOS Cancelled',
          body: 'Emergency alert has been cancelled.',
          time: DateTime.now(),
        ));
      }
    });
  }

  // ========== STEALTH CARD TRIGGER ==========
  Future<void> _handleStealthCardTrigger() async {
    final appState = context.read<AppState>();
    if (!appState.isStealthModeActive) {
      // Stealth mode is off — navigate to settings tab
      _selectTab(4);
      return;
    }

    if (appState.isStealthSessionActive) return; // already active

    final contacts = appState.emergencyContacts;
    final sessionId = 'stealth_${DateTime.now().millisecondsSinceEpoch}';
    appState.setStealthSessionActive(true, sessionId: sessionId);

    // Notification for stealth activation
    _addNotification(_NotifItem(
      id: 'stealth_${DateTime.now().millisecondsSinceEpoch}',
      icon: Icons.visibility_off_rounded,
      color: AppColors.danger,
      title: '🛡 Stealth Emergency Active',
      body: 'Silent alert sent. Live tracking started.',
      time: DateTime.now(),
    ));

    await StealthModeService().activate(
      triggerSource: 'tap_pattern',
      contacts: contacts,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.shield_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Stealth emergency activated silently'),
          ]),
          backgroundColor: AppColors.danger,
          duration: Duration(seconds: 3),
        ),
      );
    }
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

  /// Builds the AppBar avatar — shows profile photo if set, else initials circle.
  Widget _buildAppBarAvatar() {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;
    final name = user?.displayName ?? 'U';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
      ),
      child: ClipOval(
        child: hasPhoto
            ? Image.network(photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                      child: Text(initial,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ))
            : Center(
                child: Text(initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
      ),
    );
  }

  MedicalInfoModel _buildMedicalInfo() {
    final currentUser = FirebaseAuth.instance.currentUser;
    // MedicalInfoSection loads from SharedPreferences itself — pass empty defaults
    return MedicalInfoModel(
      userId: currentUser?.uid ?? 'local-user',
      bloodGroup: '',
      allergies: const [],
      medicalConditions: const [],
      doctorName: '',
      doctorContact: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                        _formatAppBarDate(now),
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
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_rounded),
                if (_unreadCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        _unreadCount > 9 ? '9+' : '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => _showNotificationsPanel(context),
          ),
          // Profile icon — shows actual user photo if available
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ProfileScreen()),
                );
                AppLogger.d('Profile button pressed');
              },
              child: _buildAppBarAvatar(),
            ),
          ),
        ],
      ),

      // ========== BODY ==========
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomeTab(context, _now,
                '${_now.hour % 12 == 0 ? 12 : _now.hour % 12}:${_now.minute.toString().padLeft(2, '0')} ${_now.hour >= 12 ? 'PM' : 'AM'}'),
            const JourneyOverview(),
            EvidenceOverview(),
            const _ContactsTab(),
            _buildSettingsTab(
                context, _buildCurrentUser(), _buildMedicalInfo()),
          ],
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
                // ── Live IoT / Raspberry Pi status card ──────────────────────
                const RtdbStatusCard(),
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
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const NearbyHelpScreen(),
                        ));
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
                      onStealth: _handleStealthCardTrigger,
                      isJourneyModeActive: appState.isJourneyModeActive,
                      isStealthModeActive: appState.isStealthModeActive,
                      stealthTapCount: _stealthTapCount,
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
            onEdit: () {},
            onSaved: (_) {}, // persistence handled inside MedicalInfoSection
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
              if (mounted) setState(() => _stealthTapCount = tapCount);
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

  /// Returns a live formatted date string like "Tuesday, 5 May"
  static String _formatAppBarDate(DateTime dt) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
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
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]}';
  }

  void _showNotificationsPanel(BuildContext ctx) {
    // Mark all as read when panel opens
    setState(() {
      for (final n in _notifications) {
        n.read = true;
      }
    });

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          builder: (_, controller) => Container(
            decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(children: [
                  Text('Notifications',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  if (_notifications.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('${_notifications.length}',
                          style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700)),
                    ),
                  const Spacer(),
                  if (_notifications.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() => _notifications.clear());
                        setSheetState(() {});
                      },
                      child: const Text('Clear all'),
                    ),
                  TextButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      child: const Text('Close')),
                ]),
              ),
              Expanded(
                child: _notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none_rounded,
                                size: 48,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text('No notifications',
                                style: Theme.of(ctx)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final n = _notifications[i];
                          return Dismissible(
                            key: Key(n.id),
                            direction: DismissDirection.horizontal,
                            background: Container(
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 20),
                              child: const Icon(Icons.delete_outline_rounded,
                                  color: AppColors.danger),
                            ),
                            secondaryBackground: Container(
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete_outline_rounded,
                                  color: AppColors.danger),
                            ),
                            onDismissed: (_) {
                              setState(() => _notifications.removeAt(i));
                              setSheetState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: Theme.of(ctx).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border)),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                            color:
                                                n.color.withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: Icon(n.icon,
                                            color: n.color, size: 20)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Row(children: [
                                            Expanded(
                                                child: Text(n.title,
                                                    style: Theme.of(ctx)
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700))),
                                            Text(_timeAgo(n.time),
                                                style: Theme.of(ctx)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                        color: AppColors
                                                            .textSecondary)),
                                          ]),
                                          const SizedBox(height: 4),
                                          Text(n.body,
                                              style: Theme.of(ctx)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                      color: AppColors
                                                          .textSecondary)),
                                        ])),
                                  ]),
                            ),
                          );
                        },
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  /// Returns relative time string like "Just now", "2m ago", "1h ago"
  static String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// =============================================================================
// Notification item model
// =============================================================================

class _NotifItem {
  final String id;
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final DateTime time;
  bool read;

  _NotifItem({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.time,
    this.read = false,
  });
}

// =============================================================================
// Contacts Tab — fully working add/delete contacts
// =============================================================================

class _ContactsTab extends StatefulWidget {
  const _ContactsTab();
  @override
  State<_ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<_ContactsTab> {
  List<_ContactData> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _loadContacts() async {
    final stored = await LocalStorageService.loadContacts();
    if (!mounted) return;
    final contacts = stored
        .map((s) => _ContactData(
              s.name,
              s.relation,
              s.phone,
              s.email,
              Color(s.colorValue),
            ))
        .toList();
    setState(() {
      _contacts = contacts;
      _loading = false;
    });
    _syncToAppState();
  }

  /// Sync contacts into AppState so SOS/stealth services can use them.
  void _syncToAppState() {
    if (!mounted) return;
    final appState = context.read<AppState>();
    final contactModels = _contacts
        .map((c) => ContactModel(
              contactId: '${c.name}_${c.phone}'.hashCode.toString(),
              userId: 'local',
              name: c.name,
              phoneNumber: c.phone,
              relationship: c.relation,
              createdAt: DateTime.now(),
            ))
        .toList();
    appState.setEmergencyContacts(contactModels);
  }

  Future<void> _persistContacts() async {
    final stored = _contacts
        .map((c) => StoredContact(
              id: '${c.name}_${c.phone}'.hashCode.toString(),
              name: c.name,
              relation: c.relation,
              phone: c.phone,
              email: c.email,
              colorValue: c.color.value,
            ))
        .toList();
    await LocalStorageService.saveContacts(stored);
    _syncToAppState();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _callContact(String phone) async {
    final digits = phone.replaceAll(' ', '');
    final uri = Uri.parse('tel:$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _addContact() async {
    final result = await showModalBottomSheet<_ContactData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddContactSheet(),
    );
    if (result != null) {
      setState(() => _contacts.add(result));
      _persistContacts();
    }
  }

  void _editContact(int index) async {
    final result = await showModalBottomSheet<_ContactData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddContactSheet(existing: _contacts[index]),
    );
    if (result != null) {
      setState(() => _contacts[index] = result);
      _persistContacts();
    }
  }

  void _deleteContact(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove contact?'),
        content:
            Text('Remove ${_contacts[index].name} from emergency contacts?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _contacts.removeAt(index));
      _persistContacts();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Emergency Contacts',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.18))),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
              _contacts.isEmpty
                  ? 'Add contacts to notify during an emergency.'
                  : '${_contacts.length} contact${_contacts.length == 1 ? '' : 's'} will be notified instantly during SOS.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.primary),
            )),
          ]),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _contacts.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.person_add_rounded,
                          size: 40, color: AppColors.primary)),
                  const SizedBox(height: 16),
                  Text('No contacts yet',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Tap "Add Contact" to get started',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
                ]))
              : ListView.separated(
                  itemCount: _contacts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _ContactCard(
                      data: _contacts[index],
                      index: index + 1,
                      onCall: () => _callContact(_contacts[index].phone),
                      onEdit: () => _editContact(index),
                      onDelete: () => _deleteContact(index)),
                ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _contacts.length >= 5 ? null : _addContact,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.person_add_rounded),
            label: Text(_contacts.length >= 5
                ? 'Max 5 contacts reached'
                : 'Add Contact'),
          ),
        ),
      ]),
    );
  }
}

class _AddContactSheet extends StatefulWidget {
  final _ContactData? existing; // non-null = edit mode

  const _AddContactSheet({this.existing});

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _relCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _colors = [
    AppColors.primary,
    AppColors.info,
    AppColors.safe,
    AppColors.warning,
    AppColors.danger
  ];
  int _colorIndex = 0;

  @override
  void initState() {
    super.initState();
    // Pre-fill fields if editing an existing contact
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _phoneCtrl.text = e.phone;
      _emailCtrl.text = e.email;
      _relCtrl.text = e.relation == 'Contact' ? '' : e.relation;
      _colorIndex = _colors.indexWhere((c) => c.value == e.color.value);
      if (_colorIndex < 0) _colorIndex = 0;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _relCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(999)))),
                  const SizedBox(height: 16),
                  Text(
                      widget.existing != null
                          ? 'Edit Contact'
                          : 'Add Emergency Contact',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: Icon(Icons.person_rounded),
                        border: OutlineInputBorder()),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Name is required'
                        : null,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Phone Number *',
                        prefixIcon: Icon(Icons.phone_rounded),
                        border: OutlineInputBorder(),
                        hintText: '+91 98765 00000'),
                    keyboardType: TextInputType.phone,
                    validator: (v) => v == null || v.trim().length < 7
                        ? 'Enter a valid phone number'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Email Address (for email alerts)',
                        prefixIcon: Icon(Icons.email_rounded),
                        border: OutlineInputBorder(),
                        hintText: 'contact@example.com'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return null; // optional
                      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                      if (!emailRegex.hasMatch(v.trim())) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _relCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Relationship (optional)',
                        prefixIcon: Icon(Icons.favorite_rounded),
                        border: OutlineInputBorder(),
                        hintText: 'Family, Friend, Partner…'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Text('Color:',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 12),
                    ...List.generate(
                        _colors.length,
                        (i) => GestureDetector(
                              onTap: () => setState(() => _colorIndex = i),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                    color: _colors[i],
                                    shape: BoxShape.circle,
                                    border: _colorIndex == i
                                        ? Border.all(
                                            color: Colors.white, width: 2)
                                        : null,
                                    boxShadow: _colorIndex == i
                                        ? [
                                            BoxShadow(
                                                color: _colors[i]
                                                    .withValues(alpha: 0.5),
                                                blurRadius: 6)
                                          ]
                                        : null),
                                child: _colorIndex == i
                                    ? const Icon(Icons.check_rounded,
                                        size: 14, color: Colors.white)
                                    : null,
                              ),
                            )),
                  ]),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          Navigator.pop(
                              context,
                              _ContactData(
                                  _nameCtrl.text.trim(),
                                  _relCtrl.text.trim().isEmpty
                                      ? 'Contact'
                                      : _relCtrl.text.trim(),
                                  _phoneCtrl.text.trim(),
                                  _emailCtrl.text.trim(),
                                  _colors[_colorIndex]));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: Text(
                          widget.existing != null
                              ? 'Save Changes'
                              : 'Save Contact',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
          ),
        ),
      ),
    );
  }
}

class _ContactData {
  final String name;
  final String relation;
  final String phone;
  final String email;
  final Color color;
  _ContactData(this.name, this.relation, this.phone, this.email, this.color);
}

class _ContactCard extends StatelessWidget {
  final _ContactData data;
  final int index;
  final VoidCallback? onDelete;
  final VoidCallback? onCall;
  final VoidCallback? onEdit;

  const _ContactCard({
    required this.data,
    required this.index,
    this.onDelete,
    this.onCall,
    this.onEdit,
  });

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
                if (data.email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    data.email,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.info,
                          fontSize: 10,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
                  icon: Icons.call_rounded,
                  color: AppColors.safe,
                  onTap: onCall),
              const SizedBox(height: 8),
              _ContactActionButton(
                  icon: Icons.edit_rounded,
                  color: AppColors.primary,
                  onTap: onEdit),
              const SizedBox(height: 8),
              _ContactActionButton(
                  icon: Icons.delete_outline_rounded,
                  color: AppColors.danger,
                  onTap: onDelete),
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
  final VoidCallback? onTap;

  const _ContactActionButton(
      {required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
