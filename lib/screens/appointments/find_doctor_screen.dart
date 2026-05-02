import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import 'doctor_profile_view_screen.dart';

class FindDoctorScreen extends StatefulWidget {
  const FindDoctorScreen({super.key});

  @override
  State<FindDoctorScreen> createState() => _FindDoctorScreenState();
}

class _FindDoctorScreenState extends State<FindDoctorScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search by name or specialization',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'provider')
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              var docs = snap.data?.docs ?? [];
              if (_query.isNotEmpty) {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final spec =
                      (data['specialization'] ?? '').toString().toLowerCase();
                  return name.contains(_query) || spec.contains(_query);
                }).toList();
              }
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.medical_services_outlined,
                            color: AppColors.accent, size: 36),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No doctors found',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  return _DoctorCard(
                    uid: doc.id,
                    name: data['name'] ?? '',
                    specialization: data['specialization'] ?? 'General',
                    facility: data['facility'] ?? '',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DoctorProfileViewScreen(
                          providerId: doc.id,
                          providerData: data,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final String uid;
  final String name;
  final String specialization;
  final String facility;
  final VoidCallback onTap;

  const _DoctorCard({
    required this.uid,
    required this.name,
    required this.specialization,
    required this.facility,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.medical_services,
                  color: AppColors.accent, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dr. $name',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    specialization,
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                  if (facility.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      facility,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
