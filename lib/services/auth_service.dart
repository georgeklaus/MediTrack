import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
    String role = 'patient',
    String? phone,
    String? specialization,
    String? facility,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Set display name on the Firebase user
    await cred.user!.updateDisplayName(name.trim());
    // Save profile to Firestore
    final data = <String, dynamic>{
      'name': name.trim(),
      'email': email.trim(),
      'role': role,
    };
    if (role == 'provider') data['status'] = 'pending';
    if (phone != null && phone.isNotEmpty) data['phone'] = phone.trim();
    if (specialization != null && specialization.isNotEmpty) data['specialization'] = specialization.trim();
    if (facility != null && facility.isNotEmpty) data['facility'] = facility.trim();
    await _db.collection('users').doc(cred.user!.uid).set(data);
    return cred;
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<UserModel?> getUserProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromDoc(doc);
  }

  Future<String> getUserRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'patient';
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return 'patient';
    final data = doc.data() as Map<String, dynamic>;
    return data['role'] as String? ?? 'patient';
  }

  Future<void> updateName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(name.trim());
    await _db.collection('users').doc(user.uid).update({'name': name.trim()});
  }

  Future<void> sendPasswordResetEmail() async {
    final email = _auth.currentUser?.email;
    if (email == null) return;
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
    await _db.collection('users').doc(user.uid).delete();
    await user.delete();
  }

  /// Returns the provider account status: 'pending' | 'active'.
  /// Defaults to 'active' for patients (no status field) or unknown users.
  Future<String> getProviderStatus() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'active';
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return 'active';
    final data = doc.data() as Map<String, dynamic>;
    return data['status'] as String? ?? 'active';
  }
}
