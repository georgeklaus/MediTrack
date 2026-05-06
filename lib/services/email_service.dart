import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// ─── EmailJS configuration ────────────────────────────────────────────────────
// 1. Create a free account at https://www.emailjs.com
// 2. Add an Email Service (Gmail recommended) and note the Service ID.
// 3. Create the 5 templates listed below and note each Template ID.
// 4. Go to Account → API Keys and copy your Public Key.
// 5. Replace the placeholder strings below with your real values.
const _kServiceId = 'YOUR_EMAILJS_SERVICE_ID';  // e.g. 'service_abc123'
const _kPublicKey = 'YOUR_EMAILJS_PUBLIC_KEY';   // e.g. 'xxxxxxxxxxxxxxxxxxx'

// ─── Template IDs (must match exactly what you create in EmailJS) ─────────────
// template_patient_welcome   → params: to_name, to_email
// template_provider_pending  → params: to_name, to_email
// template_appt_patient      → params: to_name, to_email, provider_name, date_time, reason
// template_appt_provider     → params: to_name, to_email, patient_name, date_time, reason
// template_appt_confirmed    → params: to_name, to_email, provider_name, date_time
const _kTplPatientWelcome  = 'template_patient_welcome';
const _kTplProviderPending = 'template_provider_pending';
const _kTplApptPatient     = 'template_appt_patient';
const _kTplApptProvider    = 'template_appt_provider';
const _kTplApptConfirmed   = 'template_appt_confirmed';

/// Thin wrapper around the EmailJS REST API for sending transactional emails.
/// All send calls are fire-and-forget — failures are swallowed so they never
/// break the core app flow.
class EmailService {
  // Singleton
  static final EmailService instance = EmailService._();
  EmailService._();

  final _db = FirebaseFirestore.instance;
  static const _endpoint = 'https://api.emailjs.com/api/v1.0/email/send';

  // ── Internal helpers ─────────────────────────────────────────────────────

  Future<void> _send(String templateId, Map<String, String> params) async {
    try {
      await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': _kServiceId,
          'template_id': templateId,
          'user_id': _kPublicKey,
          'template_params': params,
        }),
      );
    } catch (_) {
      // Email sending is non-critical; never propagate failures.
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
      _send(_kTplPatientWelcome, {
        'to_name': name,
        'to_email': email,
      });

  /// Sent to a medical provider after registration while awaiting approval.
  Future<void> sendProviderPendingVerification({
    required String name,
    required String email,
  }) =>
      _send(_kTplProviderPending, {
        'to_name': name,
        'to_email': email,
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
      _send(_kTplApptPatient, {
        'to_name': patientName,
        'to_email': patientEmail,
        'provider_name': 'Dr. $providerName',
        'date_time': dtStr,
        'reason': reasonStr,
      }),
      // Notification to provider
      if (providerEmail != null)
        _send(_kTplApptProvider, {
          'to_name': 'Dr. $providerName',
          'to_email': providerEmail,
          'patient_name': patientName,
          'date_time': dtStr,
          'reason': reasonStr,
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
    final patientName = data?['name'] as String? ?? 'Patient';
    if (patientEmail == null) return;

    await _send(_kTplApptConfirmed, {
      'to_name': patientName,
      'to_email': patientEmail,
      'provider_name': 'Dr. $providerName',
      'date_time': _fmt(dateTime),
    });
  }
}
