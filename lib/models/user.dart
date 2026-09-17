import 'package:equatable/equatable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../core/constants/app_constants.dart';

enum UserType {
  receptionist(AppConstants.userTypeReceptionist, 'Receptionist'),
  resident(AppConstants.userTypeResident, 'Resident Doctor'),
  manager(AppConstants.userTypeManager, 'Manager'),
  consultant(AppConstants.userTypeConsultant, 'Consultant');

  const UserType(this.value, this.label);

  final String value;
  final String label;

  static UserType fromString(String? value) {
    final v = value?.trim().toLowerCase() ?? '';
    return UserType.values.firstWhere(
      (t) => t.value == v,
      orElse: () => UserType.receptionist,
    );
  }

  bool get canAccessReceptionistScreen => true;

  bool get canAccessResidentScreen =>
      this == UserType.resident || this == UserType.consultant;

  bool get canAccessConsultantScreen => this == UserType.consultant;

  bool get canAccessManagerScreen =>
      this == UserType.manager || this == UserType.consultant;

  bool get canAccessManagementScreen =>
      this == UserType.manager ||
      this == UserType.consultant ||
      this == UserType.receptionist;
}

class User extends Equatable {
  final String id;
  final String email;
  final String? name;
  final UserType type;
  final DateTime? created;
  final DateTime? updated;

  const User({
    required this.id,
    required this.email,
    this.name,
    this.type = UserType.receptionist,
    this.created,
    this.updated,
  });

  factory User.fromRecord(RecordModel record) {
    return User(
      id: record.id,
      email: record.getStringValue('email'),
      name: record.getStringValue('name'),
      type: UserType.fromString(record.getStringValue('type')),
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      type: UserType.fromString(json['type'] as String?),
      created: json['created'] != null
          ? DateTime.tryParse(json['created'].toString())
          : null,
      updated: json['updated'] != null
          ? DateTime.tryParse(json['updated'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'type': type.value,
      if (created != null) 'created': created!.toIso8601String(),
      if (updated != null) 'updated': updated!.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, email, name, type, created, updated];
}
