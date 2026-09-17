import 'package:equatable/equatable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../core/constants/app_constants.dart';
import 'patient.dart';

class Operation extends Equatable {
  final String id;
  final String patientId;
  final Patient? patient;
  final DateTime? dateTime;
  final int? graftsExpected;
  final int? graftsDone;
  final double? totalPrice;
  final double? deposit;
  final double? remainingAtOperation;
  final List<String> intraOpImages;
  final DateTime? created;
  final DateTime? updated;

  const Operation({
    required this.id,
    required this.patientId,
    this.patient,
    this.dateTime,
    this.graftsExpected,
    this.graftsDone,
    this.totalPrice,
    this.deposit,
    this.remainingAtOperation,
    this.intraOpImages = const [],
    this.created,
    this.updated,
  });

  factory Operation.fromRecord(RecordModel record) {
    Patient? expPatient;
    try {
      final expanded = record.get<RecordModel?>('expand.patient');
      if (expanded != null) {
        expPatient = Patient.fromRecord(expanded);
      }
    } catch (_) {}

    DateTime? parsedDateTime;
    final dtStr = record.getStringValue('date_time');
    if (dtStr.isNotEmpty) {
      parsedDateTime = DateTime.tryParse(dtStr);
    }

    final imagesList = record.getListValue<String>('intra_op_images');

    return Operation(
      id: record.id,
      patientId: record.getStringValue('patient'),
      patient: expPatient,
      dateTime: parsedDateTime,
      graftsExpected: record.getIntValue('grafts_expected', 0),
      graftsDone: record.getIntValue('grafts_done', 0),
      totalPrice: record.getDoubleValue('total_price', 0.0),
      deposit: record.getDoubleValue('deposit', 0.0),
      remainingAtOperation: record.getDoubleValue(
        'remaining_at_operation',
        0.0,
      ),
      intraOpImages: imagesList,
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patient': patientId,
      if (dateTime != null) 'date_time': dateTime!.toIso8601String(),
      if (graftsExpected != null) 'grafts_expected': graftsExpected,
      if (graftsDone != null) 'grafts_done': graftsDone,
      if (totalPrice != null) 'total_price': totalPrice,
      if (deposit != null) 'deposit': deposit,
      if (remainingAtOperation != null)
        'remaining_at_operation': remainingAtOperation,
    };
  }

  Operation copyWith({
    String? id,
    String? patientId,
    Patient? patient,
    DateTime? dateTime,
    int? graftsExpected,
    int? graftsDone,
    double? totalPrice,
    double? deposit,
    double? remainingAtOperation,
    List<String>? intraOpImages,
    DateTime? created,
    DateTime? updated,
  }) {
    return Operation(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patient: patient ?? this.patient,
      dateTime: dateTime ?? this.dateTime,
      graftsExpected: graftsExpected ?? this.graftsExpected,
      graftsDone: graftsDone ?? this.graftsDone,
      totalPrice: totalPrice ?? this.totalPrice,
      deposit: deposit ?? this.deposit,
      remainingAtOperation: remainingAtOperation ?? this.remainingAtOperation,
      intraOpImages: intraOpImages ?? this.intraOpImages,
      created: created ?? this.created,
      updated: updated ?? this.updated,
    );
  }

  String getImageUrl(String filename) {
    return '${AppConstants.pocketBaseUrl}/api/files/${AppConstants.operationsCollection}/$id/$filename';
  }

  @override
  List<Object?> get props => [
    id,
    patientId,
    patient,
    dateTime,
    graftsExpected,
    graftsDone,
    totalPrice,
    deposit,
    remainingAtOperation,
    intraOpImages,
    created,
    updated,
  ];
}
