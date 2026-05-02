import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/provider_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await context.read<ProviderService>().getProviderProfile();
    if (mounted) setState(() { _profile = profile; _loading = false; });
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
                    Text('Profile',
                        style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 20),
                    // Avatar + name
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.medical_services,
                                color: AppColors.accent, size: 40),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Dr. ${_profile?.name ?? ''}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (_profile?.specialization != null)
                            Text(
                              _profile!.specialization!,
                              style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    _InfoCard(
                      items: [
                        _InfoItem(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: _profile?.email ?? ''),
                        if (_profile?.phone != null)
                          _InfoItem(
                              icon: Icons.phone_outlined,
                              label: 'Phone',
                              value: _profile!.phone!),
                        if (_profile?.facility != null)
                          _InfoItem(
                              icon: Icons.business_outlined,
                              label: 'Facility',
                              value: _profile!.facility!),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      leading: const Icon(Icons.logout, color: AppColors.danger),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                  color: AppColors.textSecondary, fontSize: 12)),
                          Text(item.value,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 15)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i < items.length - 1)
                const Divider(height: 1, indent: 48),
            ],
          );
        }).toList(),
      ),
    );
  }
}
