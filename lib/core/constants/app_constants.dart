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
}
