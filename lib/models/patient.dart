import 'package:equatable/equatable.dart';
import 'package:pocketbase/pocketbase.dart';

class Patient extends Equatable {
  final String id;
  final String name;
  final String? dob;
  final String phone;
  final String? gender;
  final String? nationalId;
  final String? notes;
  final DateTime? created;
  final DateTime? updated;

  const Patient({
    required this.id,
    required this.name,
    this.dob,
    required this.phone,
    this.gender,
    this.nationalId,
    this.notes,
    this.created,
    this.updated,
  });

  int? get calculatedAge {
    if (dob == null || dob!.isEmpty) return null;
    try {
      final birthDate = DateTime.parse(dob!);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  factory Patient.fromRecord(RecordModel record) {
    return Patient(
      id: record.id,
      name: record.getStringValue('name'),
      dob: record.getStringValue('dob'),
      phone: record.getStringValue('phone'),
      gender: record.getStringValue('gender'),
      nationalId: record.getStringValue('national_id'),
      notes: record.getStringValue('notes'),
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (dob != null) 'dob': dob,
      'phone': phone,
      if (gender != null) 'gender': gender,
      if (nationalId != null) 'national_id': nationalId,
      if (notes != null) 'notes': notes,
    };
  }

  Patient copyWith({
    String? id,
    String? name,
    String? dob,
    String? phone,
    String? gender,
    String? nationalId,
    String? notes,
    DateTime? created,
    DateTime? updated,
  }) {
    return Patient(
      id: id ?? this.id,
      name: name ?? this.name,
      dob: dob ?? this.dob,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      nationalId: nationalId ?? this.nationalId,
      notes: notes ?? this.notes,
      created: created ?? this.created,
      updated: updated ?? this.updated,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    dob,
    phone,
    gender,
    nationalId,
    notes,
    created,
    updated,
  ];
}
