import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

const _cloudName    = 'drhvwmzrg';
const _uploadPreset = 'Meditrack-proj';

class ProfileService {
  final FirebaseFirestore _db  = FirebaseFirestore.instance;
  final FirebaseAuth      _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ---------------------------------------------------------------------------
  // Photo pick helpers
  // ---------------------------------------------------------------------------

  Future<File?> pickFromCamera()  => _pick(ImageSource.camera);
  Future<File?> pickFromGallery() => _pick(ImageSource.gallery);

  Future<File?> _pick(ImageSource source) async {
    final picker = ImagePicker();
    final xfile  = await picker.pickImage(
      source: source,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 85,
    );
    return xfile == null ? null : File(xfile.path);
  }

  // ---------------------------------------------------------------------------
  // Upload photo to Cloudinary → return secure URL
  // ---------------------------------------------------------------------------

  Future<String> uploadPhoto(File file) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder']        = 'meditrack/avatars/$uid'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final body     = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      throw Exception('Photo upload failed: $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['secure_url'] as String;
  }

  // ---------------------------------------------------------------------------
  // Update user / provider profile fields in Firestore
  // ---------------------------------------------------------------------------

  Future<void> updatePatientProfile({
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final data = <String, dynamic>{};
    if (name     != null) data['name']     = name;
    if (phone    != null) data['phone']    = phone;
    if (photoUrl != null) data['photoUrl'] = photoUrl;
    if (data.isEmpty) return;
    await _db.collection('users').doc(uid).update(data);
    // Keep Firebase Auth displayName and photoURL in sync
    if (name     != null) await _auth.currentUser?.updateDisplayName(name);
    if (photoUrl != null) await _auth.currentUser?.updatePhotoURL(photoUrl);
  }

  Future<void> updateProviderProfile({
    String? name,
    String? phone,
    String? specialization,
    String? facility,
    String? photoUrl,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final data = <String, dynamic>{};
    if (name           != null) data['name']           = name;
    if (phone          != null) data['phone']          = phone;
    if (specialization != null) data['specialization'] = specialization;
    if (facility       != null) data['facility']       = facility;
    if (photoUrl       != null) data['photoUrl']       = photoUrl;
    if (data.isEmpty) return;
    await _db.collection('users').doc(uid).update(data);
    if (name     != null) await _auth.currentUser?.updateDisplayName(name);
    if (photoUrl != null) await _auth.currentUser?.updatePhotoURL(photoUrl);
  }

  // ---------------------------------------------------------------------------
  // Fetch current user doc from Firestore
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getUserData() async {
    final uid = _uid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data();
  }
}
