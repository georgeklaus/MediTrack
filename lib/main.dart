import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/auth_service.dart';
import 'services/medication_service.dart';
import 'services/appointment_service.dart';
import 'services/record_service.dart';
import 'services/provider_service.dart';
import 'services/notification_service.dart';
import 'services/document_service.dart';
import 'theme/app_theme.dart';
import 'screens/role_selection_screen.dart';
import 'widgets/app_shell.dart';
import 'screens/provider/provider_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService().init();
  runApp(const MediTrackApp());
}

class MediTrackApp extends StatelessWidget {
  const MediTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<MedicationService>(create: (_) => MedicationService()),
        Provider<AppointmentService>(create: (_) => AppointmentService()),
        Provider<RecordService>(create: (_) => RecordService()),
        Provider<ProviderService>(create: (_) => ProviderService()),
        Provider<DocumentService>(create: (_) => DocumentService()),
      ],
      child: MaterialApp(
        title: 'MediTrack',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _AuthGate(),
      ),
    );
  }
}

/// Listens to FirebaseAuth state and routes based on role or shows role selection.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          // Start listening for in-app notifications for this user
          NotificationService().startListening(snapshot.data!.uid);

          // User is logged in — determine role and route accordingly
          return FutureBuilder<String>(
            future: authService.getUserRole(),
            builder: (context, roleSnap) {
              if (roleSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final role = roleSnap.data ?? 'patient';
              if (role == 'provider') {
                return const ProviderShell();
              }
              return const AppShell();
            },
          );
        }
        // Not logged in — stop listening and show role selection
        NotificationService().stopListening();
        return const RoleSelectionScreen();
      },
    );
  }
}
