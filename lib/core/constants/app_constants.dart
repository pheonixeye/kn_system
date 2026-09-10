class AppConstants {
  static const String appTitle = 'Khaled Nabil Clinics';
  static const String appSubtitle =
      'ProKliniK Integrated Clinical Workflow & Patient Management System';
  static const String pocketBaseUrl = String.fromEnvironment('POCKET_BASE_URL');

  // Collections
  static const String patientsCollection = 'patients';
  static const String visitsCollection = 'visits';

  // Visit Statuses
  static const String statusWaitingResident = 'waiting_resident';
  static const String statusWithResident = 'with_resident';
  static const String statusWaitingConsultant = 'waiting_consultant';
  static const String statusWithConsultant = 'with_consultant';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

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
      case statusCompleted:
        return 'Visit Completed';
      case statusCancelled:
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }
}
