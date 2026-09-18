import 'package:equatable/equatable.dart';
import 'package:pocketbase/pocketbase.dart';

class AppNotification extends Equatable {
  final String id;
  final String title;
  final String body;
  final String type;
  final String target;
  final String? visitId;
  final String? operationId;
  final String? patientId;
  final String? patientName;
  final String? senderName;
  final List<String> readBy;
  final DateTime? created;
  final DateTime? updated;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.target,
    this.visitId,
    this.operationId,
    this.patientId,
    this.patientName,
    this.senderName,
    this.readBy = const [],
    this.created,
    this.updated,
  });

  bool isReadBy(String userId) => readBy.contains(userId);

  /// `target` is a multi-value select field, so PocketBase returns it as a
  /// JSON list. Each notification is written with a single target, so collapse
  /// the list to its first non-empty value.
  static String _parseTarget(dynamic raw) {
    if (raw is List) {
      for (final value in raw) {
        final text = value?.toString() ?? '';
        if (text.isNotEmpty) return text;
      }
      return '';
    }
    return raw?.toString() ?? '';
  }

  factory AppNotification.fromRecord(RecordModel record) {
    List<String> readBy = [];
    try {
      final raw = record.data['read_by'];
      if (raw is List) {
        readBy = raw.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
      }
    } catch (_) {}

    return AppNotification(
      id: record.id,
      title: record.getStringValue('title'),
      body: record.getStringValue('body'),
      type: record.getStringValue('type'),
      target: _parseTarget(record.data['target']),
      visitId: record.getStringValue('visit_id'),
      operationId: record.getStringValue('operation_id'),
      patientId: record.getStringValue('patient_id'),
      patientName: record.getStringValue('patient_name'),
      senderName: record.getStringValue('sender_name'),
      readBy: readBy,
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'target': target,
      if (visitId != null && visitId!.isNotEmpty) 'visit_id': visitId,
      if (operationId != null && operationId!.isNotEmpty)
        'operation_id': operationId,
      if (patientId != null && patientId!.isNotEmpty) 'patient_id': patientId,
      if (patientName != null && patientName!.isNotEmpty)
        'patient_name': patientName,
      if (senderName != null && senderName!.isNotEmpty)
        'sender_name': senderName,
      if (readBy.isNotEmpty) 'read_by': readBy,
    };
  }

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    String? target,
    String? visitId,
    String? operationId,
    String? patientId,
    String? patientName,
    String? senderName,
    List<String>? readBy,
    DateTime? created,
    DateTime? updated,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      target: target ?? this.target,
      visitId: visitId ?? this.visitId,
      operationId: operationId ?? this.operationId,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      senderName: senderName ?? this.senderName,
      readBy: readBy ?? this.readBy,
      created: created ?? this.created,
      updated: updated ?? this.updated,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    body,
    type,
    target,
    visitId,
    operationId,
    patientId,
    patientName,
    senderName,
    readBy,
    created,
    updated,
  ];
}