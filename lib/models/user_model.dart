import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { patient, provider }

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? phone;
  final String? photoUrl;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.role = UserRole.patient,
    this.phone,
    this.photoUrl,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] == 'provider' ? UserRole.provider : UserRole.patient,
      phone: map['phone'],
      photoUrl: map['photoUrl'],
    );
  }

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'role': role == UserRole.provider ? 'provider' : 'patient',
        if (phone != null) 'phone': phone,
        if (photoUrl != null) 'photoUrl': photoUrl,
      };
}
