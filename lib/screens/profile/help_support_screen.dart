import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _faqs = [
    _FaqItem(
      question: 'How do I add a medication?',
      answer:
          'Go to the Medications tab at the bottom of the screen. Tap the + button in the top right corner. Fill in the medication name, dosage, frequency, and start date, then tap Save.',
    ),
    _FaqItem(
      question: 'How do I book an appointment?',
      answer:
          'Open the Appointments tab. Tap the + button to add a new appointment. Enter the doctor\'s name, date, time, and any notes, then tap Save.',
    ),
    _FaqItem(
      question: 'How do I add a health record?',
      answer:
          'Navigate to the Records tab. Tap + to create a new record. Enter the title, type (e.g., Lab Result, Prescription), date, and notes. Tap Save to store it.',
    ),
    _FaqItem(
      question: 'How do I update my name?',
      answer:
          'Go to Profile → Account Information. Tap the edit (pencil) icon next to your name, type the new name, and tap Save.',
    ),
    _FaqItem(
      question: 'How do I change my password?',
      answer:
          'Go to Profile → Privacy & Security → Change Password. A password reset link will be sent to your registered email address.',
    ),
    _FaqItem(
      question: 'How do I turn off reminders?',
      answer:
          'Go to Profile → Notifications. Toggle off Medication Reminders or Appointment Reminders as needed.',
    ),
    _FaqItem(
      question: 'Is my health data private?',
      answer:
          'Yes. Your data is stored securely on Firebase with industry-standard encryption and is never shared with third parties.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF7B65F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.support_agent_outlined,
                      color: Colors.white, size: 32),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How can we help?',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Browse FAQs or get in touch with our team.',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // FAQ section
            _SectionLabel('Frequently Asked Questions'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                children: _faqs.asMap().entries.map((entry) {
                  final isLast = entry.key == _faqs.length - 1;
                  return Column(
                    children: [
                      Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          childrenPadding: const EdgeInsets.fromLTRB(
                              16, 0, 16, 14),
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.help_outline,
                                color: AppColors.primary, size: 18),
                          ),
                          title: Text(
                            entry.value.question,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          iconColor: AppColors.primary,
                          collapsedIconColor: AppColors.textSecondary,
                          children: [
                            Text(
                              entry.value.answer,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        const Divider(
                            height: 1, indent: 56, color: Color(0xFFF0F0F0)),
                    ],
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 28),

            // Contact section
            _SectionLabel('Contact Us'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.email_outlined,
                          color: AppColors.accent, size: 20),
                    ),
                    title: const Text(
                      'Email Support',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: AppColors.textPrimary),
                    ),
                    subtitle: const Text(
                      'support@meditrack.com',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    )),
                  ),
                  const Divider(height: 1, indent: 56, color: Color(0xFFF0F0F0)),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bug_report_outlined,
                          color: AppColors.warning, size: 20),
                    ),
                    title: const Text(
                      'Report a Problem',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: AppColors.textPrimary),
                    ),
                    subtitle: const Text(
                      'bugs@meditrack.com',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    )),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}
