import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../core/constants/app_colors.dart';
import '../models/user_model.dart';
import '../services/local_storage_service.dart';

/// ProfileHeader — shows avatar (editable), name, email.
/// Tapping the camera icon opens gallery/camera picker.
class ProfileHeader extends StatefulWidget {
  final UserModel user;
  final VoidCallback onEditProfile;
  final ValueChanged<String>? onPhotoUpdated; // called with new URL

  const ProfileHeader({
    Key? key,
    required this.user,
    required this.onEditProfile,
    this.onPhotoUpdated,
  }) : super(key: key);

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  bool _uploading = false;
  String? _localAvatarUrl;
  String? _localDisplayName;
  late TextEditingController _nameCtrl;

  String? get _displayUrl => _localAvatarUrl ?? widget.user.avatarUrl;
  String get _displayName =>
      _localDisplayName ?? widget.user.displayName ?? 'User';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _displayName);
    _loadSavedName();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedName() async {
    final saved = await LocalStorageService.loadDisplayName();
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() {
        _localDisplayName = saved;
        _nameCtrl.text = saved;
      });
    }
  }

  Future<void> _saveName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _localDisplayName = trimmed;
    });
    // Persist locally
    await LocalStorageService.saveDisplayName(trimmed);
    // Update Firebase Auth display name
    try {
      await FirebaseAuth.instance.currentUser?.updateDisplayName(trimmed);
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name updated successfully')),
      );
    }
  }

  Future<void> _openEditProfileSheet() async {
    _nameCtrl.text = _displayName;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
                Text('Edit Profile',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    prefixIcon: Icon(Icons.person_rounded),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 8),
                Text('Email: ${widget.user.email}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _saveName(_nameCtrl.text);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Changes',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999)),
            ),
            Text('Change Profile Photo',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.photo_library_rounded,
                      color: AppColors.primary)),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: AppColors.info)),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            if (_displayUrl != null)
              ListTile(
                leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.danger)),
                title: const Text('Remove Photo',
                    style: TextStyle(color: AppColors.danger)),
                onTap: () => Navigator.pop(ctx, null),
              ),
          ],
        ),
      ),
    );

    // null means "remove photo" was tapped
    if (choice == null && _displayUrl != null) {
      await _removePhoto();
      return;
    }
    if (choice == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: choice, imageQuality: 80, maxWidth: 512, maxHeight: 512);
    if (picked == null) return;

    await _uploadPhoto(File(picked.path));
  }

  Future<void> _uploadPhoto(File file) async {
    setState(() => _uploading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not logged in');

      final ref = FirebaseStorage.instance.ref().child('avatars/$uid.jpg');
      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();

      await FirebaseAuth.instance.currentUser?.updatePhotoURL(url);
      setState(() => _localAvatarUrl = url);
      widget.onPhotoUpdated?.call(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _uploading = true);
    try {
      await FirebaseAuth.instance.currentUser?.updatePhotoURL(null);
      setState(() => _localAvatarUrl = ''); // empty = no photo
      widget.onPhotoUpdated?.call('');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _displayUrl != null && _displayUrl!.isNotEmpty;
    final initials = _displayName.characters.first.toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            // ── Avatar with camera overlay ──────────────────────────────
            Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary,
                  backgroundImage: hasPhoto ? NetworkImage(_displayUrl!) : null,
                  child: _uploading
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)
                      : (!hasPhoto
                          ? Text(initials,
                              style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white))
                          : null),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _uploading ? null : _pickPhoto,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // ── Name display (no inline editing — use Edit Profile button) ──
            Text(
              _displayName,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              widget.user.email,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            // ── Edit Profile button — opens edit sheet ───────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openEditProfileSheet,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit Profile'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: const BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
