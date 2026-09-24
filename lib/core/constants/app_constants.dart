class AppConstants {
  static const String appTitle = 'Khaled Nabil Clinics';
  static const String appSubtitle =
      'ProKliniK Integrated Clinical Workflow & Patient Management System';
  static const String pocketBaseUrl = String.fromEnvironment('POCKETBASE_URL');
  static const String appVersion = String.fromEnvironment('APP_VERSION');

  // Collections
  static const String patientsCollection = 'patients';
  static const String visitsCollection = 'visits';
  static const String operationsCollection = 'operations';
  static const String usersCollection = 'users';
  static const String notificationsCollection = 'notifications';

  // Notification Types
  static const String notifTypePatientSentBack = 'patient_sent_back';
  static const String notifTypeReferredToManagement = 'referred_to_management';
  static const String notifTypeOperationScheduled = 'operation_scheduled';
  static const String notifTypeOperationUpdated = 'operation_updated';
  static const String notifTypeOperationImagesAdded = 'operation_images_added';
  static const String notifTypePrescriptionAdded = 'prescription_added';
  static const String notifTypeSentToResident = 'sent_to_resident';
  static const String notifTypeVisitCompleted = 'visit_completed';
  static const String notifTypeGeneral = 'general';

  // Visit Fields
  static const String visitPrescriptionImagesField = 'prescription_images';

  // User Types
  static const String userTypeReceptionist = 'receptionist';
  static const String userTypeResident = 'resident';
  static const String userTypeConsultant = 'consultant';
  static const String userTypeManager = 'manager';

  // Visit Statuses
  static const String statusWaitingResident = 'waiting_resident';
  static const String statusWithResident = 'with_resident';
  static const String statusWaitingConsultant = 'waiting_consultant';
  static const String statusWithConsultant = 'with_consultant';
  static const String statusSentToManagement = 'sent_to_management';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

  static String get todayDateString {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String formatStatus(String? status) {
    switch (status) {
      case statusWaitingResident:
        return 'Waiting for Resident';
      case statusWithResident:
        return 'With Resident Doctor';
      case statusWaitingConsultant:
        return 'Ready for Consultant';
      case statusWithConsultant:
        return 'With Consultant';
      case statusSentToManagement:
        return 'Sent to Management';
      case statusCompleted:
        return 'Visit Completed';
      case statusCancelled:
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }

  // Visit Types
  static const String notSpecified = '';
  static const String consultation = 'consultation';
  static const String consultationHasPreopImages =
      'consultation_has_preop_images';
  static const String followup = 'followup';
  static const String followupHasFuImages = 'followup_has_fu_images';
  static const String prp = 'prp';
  static const String prpHasFuImages = 'prp_has_fu_images';
  static const String finalResult = 'final_result';

  static const List<String> visitTypeValues = [
    notSpecified,
    consultation,
    consultationHasPreopImages,
    followup,
    followupHasFuImages,
    prp,
    prpHasFuImages,
    finalResult,
  ];

  static String formatVisitType(String? type) {
    switch (type) {
      case consultation:
        return 'Consultation';
      case consultationHasPreopImages:
        return 'Consultation with (PRE-OP) Images';
      case followup:
        return 'Followup';
      case followupHasFuImages:
        return 'Followup with (FU) Images';
      case prp:
        return 'PRP';
      case prpHasFuImages:
        return 'PRP with (FU) Images';
      case finalResult:
        return 'Final Result';
      default:
        return 'Not Specified';
    }
  }
}
