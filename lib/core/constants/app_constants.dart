class AppConstants {
  static const String appTitle = 'Khaled Nabil Clinics';
  static const String appSubtitle =
      'ProKliniK Integrated Clinical Workflow & Patient Management System';
  static const String pocketBaseUrl = String.fromEnvironment('POCKETBASE_URL');

  // Collections
  static const String patientsCollection = 'patients';
  static const String visitsCollection = 'visits';
  static const String operationsCollection = 'operations';
  static const String usersCollection = 'users';

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
