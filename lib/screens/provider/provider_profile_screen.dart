import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/provider_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../models/provider_model.dart';
import '../role_selection_screen.dart';

class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({super.key});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  ProviderModel? _profile;
  bool _loading = true;
  bool _saving = false;
  File? _pendingPhoto;

  // edit controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _specCtrl;
  late TextEditingController _facilityCtrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl     = TextEditingController();
    _phoneCtrl    = TextEditingController();
    _specCtrl     = TextEditingController();
    _facilityCtrl = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _specCtrl.dispose();
    _facilityCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await context.read<ProviderService>().getProviderProfile();
    if (mounted) {
      setState(() {
        _profile      = profile;
        _loading      = false;
        _nameCtrl.text     = profile?.name ?? '';
        _phoneCtrl.text    = profile?.phone ?? '';
        _specCtrl.text     = profile?.specialization ?? '';
        _facilityCtrl.text = profile?.facility ?? '';
      });
    }
  }

  Future<void> _pickPhoto() async {
    final ps = context.read<ProfileService>();
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Take photo'),
            onTap: () => Navigator.pop(context, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(context, 'gallery'),
          ),
        ]),
      ),
    );
    if (choice == null) return;
    final file = choice == 'camera'
        ? await ps.pickFromCamera()
        : await ps.pickFromGallery();
    if (file != null && mounted) setState(() => _pendingPhoto = file);
  }

  Future<void> _saveProfile() async {
    final ps = context.read<ProfileService>();
    setState(() => _saving = true);
    try {
      String? newPhotoUrl;
      if (_pendingPhoto != null) {
        newPhotoUrl = await ps.uploadPhoto(_pendingPhoto!);
      }
      await ps.updateProviderProfile(
        name:           _nameCtrl.text.trim(),
        phone:          _phoneCtrl.text.trim(),
        specialization: _specCtrl.text.trim(),
        facility:       _facilityCtrl.text.trim(),
        photoUrl:       newPhotoUrl,
      );
      await _loadProfile();
      if (mounted) setState(() { _editing = false; _pendingPhoto = null; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    await context.read<AuthService>().logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Profile',
                            style: Theme.of(context).textTheme.headlineLarge),
                        const Spacer(),
                        if (!_editing)
                          TextButton.icon(
                            onPressed: () => setState(() => _editing = true),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Edit'),
                          )
                        else
                          TextButton(
                            onPressed: () => setState(() {
                              _editing = false;
                              _pendingPhoto = null;
                              _nameCtrl.text     = _profile?.name ?? '';
                              _phoneCtrl.text    = _profile?.phone ?? '';
                              _specCtrl.text     = _profile?.specialization ?? '';
                              _facilityCtrl.text = _profile?.facility ?? '';
                            }),
                            child: const Text('Cancel'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Avatar ──
                    Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: _editing ? _pickPhoto : null,
                            child: CircleAvatar(
                              radius: 52,
                              backgroundImage: _pendingPhoto != null
                                  ? FileImage(_pendingPhoto!) as ImageProvider
                                  : (_profile?.photoUrl != null
                                      ? NetworkImage(_profile!.photoUrl!)
                                      : null),
                              backgroundColor:
                                  AppColors.accent.withValues(alpha: 0.15),
                              child: (_pendingPhoto == null &&
                                      _profile?.photoUrl == null)
                                  ? const Icon(Icons.medical_services,
                                      color: AppColors.accent, size: 44)
                                  : null,
                            ),
                          ),
                          if (_editing)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickPhoto,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!_editing) ...[
                      Center(
                        child: Column(children: [
                          Text('Dr. ${_profile?.name ?? ''}',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          if (_profile?.specialization?.isNotEmpty == true)
                            Text(_profile!.specialization!,
                                style: const TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500)),
                        ]),
                      ),
                      const SizedBox(height: 28),
                      _InfoCard(items: [
                        _InfoItem(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: _profile?.email ?? ''),
                        if (_profile?.phone?.isNotEmpty == true)
                          _InfoItem(
                              icon: Icons.phone_outlined,
                              label: 'Phone',
                              value: _profile!.phone!),
                        if (_profile?.facility?.isNotEmpty == true)
                          _InfoItem(
                              icon: Icons.business_outlined,
                              label: 'Facility',
                              value: _profile!.facility!),
                      ]),
                    ] else ...[
                      const SizedBox(height: 16),
                      _field(_nameCtrl,     'Name',           Icons.person_outline),
                      _field(_phoneCtrl,    'Phone',          Icons.phone_outlined,
                          type: TextInputType.phone),
                      _field(_specCtrl,     'Specialization', Icons.local_hospital_outlined),
                      _field(_facilityCtrl, 'Facility',       Icons.business_outlined),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14)),
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Save Changes',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 16)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (!_editing)
                      ListTile(
                        tileColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        leading:
                            const Icon(Icons.logout, color: AppColors.danger),
                        title: const Text('Sign Out',
                            style: TextStyle(color: AppColors.danger)),
                        onTap: _signOut,
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  const _InfoItem({required this.icon, required this.label, required this.value});
}

class _InfoCard extends StatelessWidget {
  final List<_InfoItem> items;
  const _InfoCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(item.icon, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.label,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                          Text(item.value,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i < items.length - 1) const Divider(height: 1, indent: 48),
            ],
          );
        }).toList(),
      ),
    );
  }
}


