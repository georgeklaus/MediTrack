import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/appointment_service.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';
import '../chat/chat_screen.dart';

class DoctorProfileViewScreen extends StatefulWidget {
  final String providerId;
  final Map<String, dynamic> providerData;

  const DoctorProfileViewScreen({
    super.key,
    required this.providerId,
    required this.providerData,
  });

  @override
  State<DoctorProfileViewScreen> createState() =>
      _DoctorProfileViewScreenState();
}

class _DoctorProfileViewScreenState extends State<DoctorProfileViewScreen> {
  Map<String, dynamic>? _availability;
  bool _loadingAvailability = true;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final doc = await FirebaseFirestore.instance
        .collection('availability')
        .doc(widget.providerId)
        .get();
    if (mounted) {
      setState(() {
        _availability = doc.data();
        _loadingAvailability = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.providerData;
    final name = data['name'] ?? '';
    final specialization = data['specialization'] ?? 'General';
    final facility = data['facility'] ?? '';
    final phone = data['phone'] ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Doctor Profile'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent, Color(0xFF00A3BA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.medical_services,
                        color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Dr. $name',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    specialization,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14),
                  ),
                  if (facility.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      facility,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Contact info
            if (phone.isNotEmpty)
              _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: phone),
            const SizedBox(height: 20),

            // Availability
            Text('Availability',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _loadingAvailability
                ? const Center(child: CircularProgressIndicator())
                : _availability == null
                    ? _emptyCard('No availability set yet.')
                    : _AvailabilityCard(availability: _availability!),
            const SizedBox(height: 28),

            // Book button
            ElevatedButton.icon(
              onPressed: () => _showBookingSheet(context, name),
              icon: const Icon(Icons.calendar_month),
              label: const Text('Book Appointment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final convId = await ChatService.instance
                    .getOrCreateConversation(
                  otherUid: widget.providerId,
                  otherName: 'Dr. $name',
                );
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        conversationId: convId,
                        otherUserId: widget.providerId,
                        otherUserName: 'Dr. $name',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Message Doctor'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(msg,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary)),
    );
  }

  void _showBookingSheet(BuildContext context, String providerName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BookingSheet(
        providerId: widget.providerId,
        providerName: providerName,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  final Map<String, dynamic> availability;

  const _AvailabilityCard({required this.availability});

  @override
  Widget build(BuildContext context) {
    final days =
        List<String>.from(availability['workingDays'] as List? ?? []);
    final start = availability['startTime'] as String? ?? '';
    final end = availability['endTime'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('$start – $end',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
            ].map((abbr) {
              const fullNames = {
                'Mon': 'Monday', 'Tue': 'Tuesday', 'Wed': 'Wednesday',
                'Thu': 'Thursday', 'Fri': 'Friday', 'Sat': 'Saturday',
                'Sun': 'Sunday',
              };
              final active = days.contains(fullNames[abbr]);
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  abbr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? AppColors.primary : Colors.grey,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Booking bottom sheet ─────────────────────────────────────────────────────

class _BookingSheet extends StatefulWidget {
  final String providerId;
  final String providerName;

  const _BookingSheet(
      {required this.providerId, required this.providerName});

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  final _reasonCtrl = TextEditingController();
  DateTime _dateTime =
      DateTime.now().add(const Duration(days: 1));
  bool _loading = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null) return;
    setState(() {
      _dateTime = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _book() async {
    setState(() => _loading = true);
    try {
      final authService = context.read<AuthService>();
      final apptService = context.read<AppointmentService>();
      final user = authService.currentUser!;
      final patientName =
          user.displayName ?? user.email ?? 'Patient';
      await apptService.bookWithProvider(
        patientId: user.uid,
        patientName: patientName,
        providerId: widget.providerId,
        providerName: widget.providerName,
        dateTime: _dateTime,
        reason: _reasonCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop(); // close sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Appointment request sent. Waiting for confirmation.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Book Appointment',
              style: Theme.of(context).textTheme.titleLarge),
          Text('Dr. ${widget.providerName}',
              style: const TextStyle(
                  color: AppColors.accent, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),
          // Date/time picker
          GestureDetector(
            onTap: _pickDateTime,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('EEE, MMM d, yyyy · h:mm a')
                        .format(_dateTime),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  const Icon(Icons.edit,
                      size: 16, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reasonCtrl,
            decoration: const InputDecoration(
              labelText: 'Reason for visit (optional)',
              prefixIcon: Icon(Icons.notes),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          _loading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: _book,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Send Appointment Request'),
                ),
        ],
      ),
    );
  }
}
