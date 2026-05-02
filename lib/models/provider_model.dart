import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? specialization;
  final String? facility;

  ProviderModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.specialization,
    this.facility,
  });

  factory ProviderModel.fromMap(Map<String, dynamic> map, String id) {
    return ProviderModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      specialization: map['specialization'],
      facility: map['facility'],
    );
  }

  factory ProviderModel.fromDoc(DocumentSnapshot doc) {
    return ProviderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'role': 'provider',
        if (phone != null) 'phone': phone,
        if (specialization != null) 'specialization': specialization,
        if (facility != null) 'facility': facility,
      };
}
