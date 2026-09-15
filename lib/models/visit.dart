import 'package:equatable/equatable.dart';
import 'package:pocketbase/pocketbase.dart';
import '../core/constants/app_constants.dart';
import 'patient.dart';
import 'vital_signs.dart';

class Visit extends Equatable {
  final String id;
  final String patientId;
  final Patient? patient;
  final String? visitDate;
  final int? queueNumber;
  final String status;
  final String? chiefComplaint;
  final String? historyPresentIllness;
  final String? pastMedicalHistory;
  final String? drugHistoryAllergies;
  final VitalSigns vitalSigns;
  final String? examinationNotes;
  final String? residentAssessment;
  final String? residentName;
  final List<String> images;
  final String? consultantDiagnosis;
  final String? consultantPlan;
  final String? consultantPrescription;
  final String? consultantNotes;
  final String? consultantName;
  final String? addedBy;
  final DateTime? created;
  final DateTime? updated;

  const Visit({
    required this.id,
    required this.patientId,
    this.patient,
    this.visitDate,
    this.queueNumber,
    this.status = AppConstants.statusWaitingResident,
    this.chiefComplaint,
    this.historyPresentIllness,
    this.pastMedicalHistory,
    this.drugHistoryAllergies,
    this.vitalSigns = const VitalSigns(),
    this.examinationNotes,
    this.residentAssessment,
    this.residentName,
    this.images = const [],
    this.consultantDiagnosis,
    this.consultantPlan,
    this.consultantPrescription,
    this.consultantNotes,
    this.consultantName,
    this.addedBy,
    this.created,
    this.updated,
  });

  String getImageUrl(String filename) {
    return '${AppConstants.pocketBaseUrl}/api/files/${AppConstants.visitsCollection}/$id/$filename';
  }

  factory Visit.fromRecord(RecordModel record) {
    Patient? expandedPatient;
    final patientRecord = record.get<RecordModel?>('expand.patient');
    if (patientRecord != null) {
      expandedPatient = Patient.fromRecord(patientRecord);
    } else {
      final list = record.get<List<RecordModel>?>('expand.patient');
      if (list != null && list.isNotEmpty) {
        expandedPatient = Patient.fromRecord(list.first);
      }
    }

    final rawImages = record.getListValue<String>('images');

    return Visit(
      id: record.id,
      patientId: record.getStringValue('patient'),
      patient: expandedPatient,
      visitDate: record.getStringValue('visit_date'),
      queueNumber: record.getIntValue('queue_number', 0) > 0
          ? record.getIntValue('queue_number')
          : null,
      status: record.getStringValue('status').isEmpty
          ? AppConstants.statusWaitingResident
          : record.getStringValue('status'),
      chiefComplaint: record.getStringValue('chief_complaint'),
      historyPresentIllness: record.getStringValue('history_present_illness'),
      pastMedicalHistory: record.getStringValue('past_medical_history'),
      drugHistoryAllergies: record.getStringValue('drug_history_allergies'),
      vitalSigns: VitalSigns.fromJson(record.data['vital_signs']),
      examinationNotes: record.getStringValue('examination_notes'),
      residentAssessment: record.getStringValue('resident_assessment'),
      residentName: record.getStringValue('resident_name'),
      images: rawImages,
      consultantDiagnosis: record.getStringValue('consultant_diagnosis'),
      consultantPlan: record.getStringValue('consultant_plan'),
      consultantPrescription: record.getStringValue('consultant_prescription'),
      consultantNotes: record.getStringValue('consultant_notes'),
      consultantName: record.getStringValue('consultant_name'),
      addedBy: record.getStringValue('added_by'),
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patient': patientId,
      if (visitDate != null) 'visit_date': visitDate,
      if (queueNumber != null) 'queue_number': queueNumber,
      'status': status,
      if (chiefComplaint != null) 'chief_complaint': chiefComplaint,
      if (historyPresentIllness != null)
        'history_present_illness': historyPresentIllness,
      if (pastMedicalHistory != null)
        'past_medical_history': pastMedicalHistory,
      if (drugHistoryAllergies != null)
        'drug_history_allergies': drugHistoryAllergies,
      'vital_signs': vitalSigns.toJson(),
      if (examinationNotes != null) 'examination_notes': examinationNotes,
      if (residentAssessment != null) 'resident_assessment': residentAssessment,
      if (residentName != null) 'resident_name': residentName,
      if (consultantDiagnosis != null)
        'consultant_diagnosis': consultantDiagnosis,
      if (consultantPlan != null) 'consultant_plan': consultantPlan,
      if (consultantPrescription != null)
        'consultant_prescription': consultantPrescription,
      if (consultantNotes != null) 'consultant_notes': consultantNotes,
      if (consultantName != null) 'consultant_name': consultantName,
      if (addedBy != null) 'added_by': addedBy,
    };
  }

  Visit copyWith({
    String? id,
    String? patientId,
    Patient? patient,
    String? visitDate,
    int? queueNumber,
    String? status,
    String? chiefComplaint,
    String? historyPresentIllness,
    String? pastMedicalHistory,
    String? drugHistoryAllergies,
    VitalSigns? vitalSigns,
    String? examinationNotes,
    String? residentAssessment,
    String? residentName,
    List<String>? images,
    String? consultantDiagnosis,
    String? consultantPlan,
    String? consultantPrescription,
    String? consultantNotes,
    String? consultantName,
    String? addedBy,
    DateTime? created,
    DateTime? updated,
  }) {
    return Visit(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patient: patient ?? this.patient,
      visitDate: visitDate ?? this.visitDate,
      queueNumber: queueNumber ?? this.queueNumber,
      status: status ?? this.status,
      chiefComplaint: chiefComplaint ?? this.chiefComplaint,
      historyPresentIllness:
          historyPresentIllness ?? this.historyPresentIllness,
      pastMedicalHistory: pastMedicalHistory ?? this.pastMedicalHistory,
      drugHistoryAllergies: drugHistoryAllergies ?? this.drugHistoryAllergies,
      vitalSigns: vitalSigns ?? this.vitalSigns,
      examinationNotes: examinationNotes ?? this.examinationNotes,
      residentAssessment: residentAssessment ?? this.residentAssessment,
      residentName: residentName ?? this.residentName,
      images: images ?? this.images,
      consultantDiagnosis: consultantDiagnosis ?? this.consultantDiagnosis,
      consultantPlan: consultantPlan ?? this.consultantPlan,
      consultantPrescription:
          consultantPrescription ?? this.consultantPrescription,
      consultantNotes: consultantNotes ?? this.consultantNotes,
      consultantName: consultantName ?? this.consultantName,
      addedBy: addedBy ?? this.addedBy,
      created: created ?? this.created,
      updated: updated ?? this.updated,
    );
  }

  @override
  List<Object?> get props => [
    id,
    patientId,
    patient,
    visitDate,
    queueNumber,
    status,
    chiefComplaint,
    historyPresentIllness,
    pastMedicalHistory,
    drugHistoryAllergies,
    vitalSigns,
    examinationNotes,
    residentAssessment,
    residentName,
    images,
    consultantDiagnosis,
    consultantPlan,
    consultantPrescription,
    consultantNotes,
    consultantName,
    addedBy,
    created,
    updated,
  ];
}
