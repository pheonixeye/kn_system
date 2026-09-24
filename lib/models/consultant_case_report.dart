import 'operation.dart';
import 'patient.dart';
import 'visit.dart';

/// A source visit grouped with the visitor images that belong to a report.
class ReportImageGroup {
  final Visit visit;
  final List<String> images;

  const ReportImageGroup({required this.visit, required this.images});
}

/// Which category a visit's images fall under in the case report.
enum ReportImageCategory {
  initialAssessment('initial_assessment', 'Initial Assessment'),
  fuPostFue('fu_post_fue', 'FU Post FUE'),
  finalResult('final_result', 'Final Result');

  const ReportImageCategory(this.value, this.label);

  final String value;
  final String label;
}

/// Everything the consultant selected to build the case report PDF.
class ConsultantCaseReportData {
  final Patient patient;
  final Visit? sourceVisit;
  final List<ReportImageGroup> initialAssessment;
  final List<ReportImageGroup> fuPostFue;
  final List<ReportImageGroup> finalResult;
  final List<Operation> operations;

  const ConsultantCaseReportData({
    required this.patient,
    this.sourceVisit,
    this.initialAssessment = const [],
    this.fuPostFue = const [],
    this.finalResult = const [],
    this.operations = const [],
  });

  bool get hasClinicalSummary =>
      sourceVisit != null &&
      ((sourceVisit!.consultantDiagnosis?.trim().isNotEmpty == true) ||
          (sourceVisit!.consultantPlan?.trim().isNotEmpty == true) ||
          (sourceVisit!.consultantPrescription?.trim().isNotEmpty == true));

  bool get hasAnyImages =>
      initialAssessment.isNotEmpty ||
      fuPostFue.isNotEmpty ||
      finalResult.isNotEmpty;

  bool get hasOperations => operations.isNotEmpty;
}
