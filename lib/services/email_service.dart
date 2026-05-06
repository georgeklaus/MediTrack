import 'dart:convert';
import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// ─── EmailJS configuration ────────────────────────────────────────────────────
const _kServiceId = 'service_pslasoo';
const _kPublicKey  = '0nk4CLQ4WcVN3z0TQ';

// ─── Two generic templates ────────────────────────────────────────────────────
// template_gz4qiv9 (Welcome)        → registration emails (patient welcome + provider pending)
// template_ngfrwwj (Password Reset) → appointment emails (booked patient, booked provider, confirmed)
const _kTplRegistration = 'template_gz4qiv9';
const _kTplAppointment  = 'template_ngfrwwj';

/// Thin wrapper around the EmailJS REST API for sending transactional emails.
/// All send calls are fire-and-forget — failures are swallowed so they never
/// break the core app flow.
class EmailService {
  static final EmailService instance = EmailService._();
  EmailService._();

  final _db = FirebaseFirestore.instance;
  static const _endpoint = 'https://api.emailjs.com/api/v1.0/email/send';

  // ── Internal helpers ─────────────────────────────────────────────────────

  Future<void> _send(String templateId, Map<String, String> params) async {
    try {
      final body = jsonEncode({
        'service_id': _kServiceId,
        'template_id': templateId,
        'user_id': _kPublicKey,
        'template_params': params,
      });
      dev.log('[EmailService] Sending → template: $templateId, to: ${params['to_email']}');
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      dev.log('[EmailService] Response ${response.statusCode}: ${response.body}');
    } catch (e) {
      dev.log('[EmailService] ERROR: $e');
    }
  }

  Future<Map<String, dynamic>?> _userData(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  String _fmt(DateTime dt) =>
      DateFormat('EEE, MMMM d, yyyy \'at\' h:mm a').format(dt);

  // ── Registration ─────────────────────────────────────────────────────────

  /// Sent to a patient immediately after they create an account.
  Future<void> sendPatientWelcome({
    required String name,
    required String email,
  }) =>
      _send(_kTplRegistration, {
        'to_name':         name,
        'to_email':        email,
        'email_subject':   'Welcome to MediTrack, $name!',
        'header_color':    '#2196F3',
        'header_subtitle': 'Your Health, Managed Simply',
        'email_title':     'Welcome, $name! 🎉',
        'email_body':
            'Your MediTrack account has been successfully created. '
            'You can now book appointments with verified medical providers, '
            'access your medical records and documents, track your medications, '
            'and receive appointment confirmations — all from the app.',
      });

  /// Sent to a medical provider after registration while awaiting approval.
  Future<void> sendProviderPendingVerification({
    required String name,
    required String email,
  }) =>
      _send(_kTplRegistration, {
        'to_name':         name,
        'to_email':        email,
        'email_subject':   'MediTrack – Provider Account Pending Verification',
        'header_color':    '#FF9800',
        'header_subtitle': 'Medical Provider Portal',
        'email_title':     'Thank you for registering, $name!',
        'email_body':
            'Your application to join MediTrack as a Medical Provider has been received '
            'and is currently pending verification. Administration is reviewing your credentials — '
            'this typically takes 1–2 business days. '
            'You will receive another email once your account is approved. '
            'You can also open the app and tap "Check Approval Status" at any time.',
      });

  // ── Appointments ─────────────────────────────────────────────────────────

  /// Emails both the patient (confirmation) and provider (notification) when
  /// an appointment is booked.
  Future<void> sendAppointmentBooked({
    required String patientName,
    required String patientEmail,
    required String providerId,
    required String providerName,
    required DateTime dateTime,
    required String reason,
  }) async {
    final providerData = await _userData(providerId);
    final providerEmail = providerData?['email'] as String?;
    final dtStr = _fmt(dateTime);
    final reasonStr = reason.trim().isEmpty ? 'Not specified' : reason.trim();

    await Future.wait([
      // Confirmation to patient
      _send(_kTplAppointment, {
        'to_name':         patientName,
        'to_email':        patientEmail,
        'email_subject':   'Appointment Request Sent – MediTrack',
        'header_color':    '#2196F3',
        'header_subtitle': 'Appointment Request',
        'email_intro':     'Your appointment request has been sent successfully. Here are the details:',
        'row1_label':      'Doctor',
        'row1_value':      'Dr. $providerName',
        'date_time':       dtStr,
        'row3_label':      'Reason',
        'row3_value':      reasonStr,
        'status_bg':       '#fff3e0',
        'status_color':    '#FF9800',
        'status_label':    'Pending Confirmation',
        'email_footer':    'You will receive another email once Dr. $providerName confirms your appointment.',
      }),
      // Notification to provider
      if (providerEmail != null)
        _send(_kTplAppointment, {
          'to_name':         'Dr. $providerName',
          'to_email':        providerEmail,
          'email_subject':   'New Appointment Request – MediTrack',
          'header_color':    '#1565C0',
          'header_subtitle': 'New Appointment Request',
          'email_intro':     'A patient has requested an appointment with you. Here are the details:',
          'row1_label':      'Patient',
          'row1_value':      patientName,
          'date_time':       dtStr,
          'row3_label':      'Reason',
          'row3_value':      reasonStr,
          'status_bg':       '#fff3e0',
          'status_color':    '#FF9800',
          'status_label':    'Awaiting Your Confirmation',
          'email_footer':    'Please open the MediTrack app to confirm or decline this appointment.',
        }),
    ]);
  }

  /// Emails the patient when the provider confirms the appointment.
  Future<void> sendAppointmentConfirmed({
    required String patientId,
    required String providerName,
    required DateTime dateTime,
  }) async {
    final data = await _userData(patientId);
    final patientEmail = data?['email'] as String?;
    final patientName  = data?['name']  as String? ?? 'Patient';
    if (patientEmail == null) return;

    await _send(_kTplAppointment, {
      'to_name':         patientName,
      'to_email':        patientEmail,
      'email_subject':   'Appointment Confirmed – MediTrack',
      'header_color':    '#4CAF50',
      'header_subtitle': 'Appointment Confirmed',
      'email_intro':     'Great news! Your appointment has been confirmed. Here are the details:',
      'row1_label':      'Doctor',
      'row1_value':      'Dr. $providerName',
      'date_time':       _fmt(dateTime),
      'row3_label':      'Status',
      'row3_value':      'Confirmed ✓',
      'status_bg':       '#e8f5e9',
      'status_color':    '#4CAF50',
      'status_label':    'Confirmed',
      'email_footer':    'Please arrive a few minutes early. You can view full details in the MediTrack app.',
    });
  }
}
