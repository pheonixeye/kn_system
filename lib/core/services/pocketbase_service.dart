import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import '../constants/app_constants.dart';
import '../../models/notification.dart';
import '../../models/operation.dart';
import '../../models/patient.dart';
import '../../models/user.dart';
import '../../models/visit.dart';

class PocketBaseService {
  static final PocketBaseService _instance = PocketBaseService._internal();
  factory PocketBaseService() => _instance;

  late final PocketBase pb;

  PocketBaseService._internal() {
    pb = PocketBase(AppConstants.pocketBaseUrl);
  }

  // Auth API
  Future<User> login({required String email, required String password}) async {
    try {
      final record = await pb
          .collection(AppConstants.usersCollection)
          .authWithPassword(email.trim(), password);
      return User.fromRecord(record.record);
    } catch (e) {
      rethrow;
    }
  }

  void logout() {
    pb.authStore.clear();
  }

  Future<void> requestPasswordReset(String email) async {
    // PocketBase returns 204 even when the account does not exist, so this
    // never leaks whether an email is registered.
    await pb
        .collection(AppConstants.usersCollection)
        .requestPasswordReset(email.trim());
  }

  void restoreAuth(String token, Map<String, dynamic> recordJson) {
    try {
      pb.authStore.save(token, RecordModel.fromJson(recordJson));
    } catch (_) {
      pb.authStore.save(token, null);
    }
  }

  String? get authToken {
    final token = pb.authStore.token;
    return token.isEmpty ? null : token;
  }

  // Patients API
  Future<List<Patient>> getPatients({String? search}) async {
    try {
      String? filter;
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().replaceAll("'", "\\'");
        filter = 'name ~ "$q" || phone ~ "$q" || national_id ~ "$q"';
      }

      final records = await pb
          .collection(AppConstants.patientsCollection)
          .getFullList(sort: '-created', filter: filter);

      return records.map((r) => Patient.fromRecord(r)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Patient> createPatient(Map<String, dynamic> data) async {
    try {
      final record = await pb
          .collection(AppConstants.patientsCollection)
          .create(body: data);
      return Patient.fromRecord(record);
    } catch (e) {
      rethrow;
    }
  }

  Future<Patient> updatePatient(String id, Map<String, dynamic> data) async {
    try {
      final record = await pb
          .collection(AppConstants.patientsCollection)
          .update(id, body: data);
      return Patient.fromRecord(record);
    } catch (e) {
      rethrow;
    }
  }

  // Visits API
  Future<List<Visit>> getVisits({
    String? status,
    String? date,
    String? patientId,
    String? search,
    String? filter,
    String? sort,
  }) async {
    try {
      final filters = <String>[];
      if (status != null && status.isNotEmpty && status != 'all') {
        filters.add('status = "$status"');
      }

      // Default to today's date if no date, filter, or patientId is explicitly passed
      final effectiveDate =
          (date == null && filter == null && patientId == null)
          ? AppConstants.todayDateString
          : date;

      if (effectiveDate != null && effectiveDate.isNotEmpty) {
        filters.add('visit_date ~ "$effectiveDate"');
      }
      if (patientId != null && patientId.isNotEmpty) {
        filters.add('patient = "$patientId"');
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().replaceAll("'", "\\'");
        filters.add(
          '(patient.name ~ "$q" || patient.phone ~ "$q" || chief_complaint ~ "$q")',
        );
      }
      if (filter != null && filter.trim().isNotEmpty) {
        filters.add(filter);
      }

      final filterString = filters.isNotEmpty ? filters.join(' && ') : null;

      final records = await pb
          .collection(AppConstants.visitsCollection)
          .getFullList(
            expand: 'patient',
            sort: sort ?? 'status,queue_number,-created',
            filter: filterString,
          );

      return records.map((r) => Visit.fromRecord(r)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Visit>> getPatientVisits(String patientId) async {
    return getVisits(
      patientId: patientId,
      date: '',
      sort: '-visit_date,-created',
    );
  }

  Future<List<Visit>> getPatientVisitsHistory({
    required String patientId,
  }) async {
    return getVisits(
      patientId: patientId,
      date: '',
      sort: '-visit_date,-created',
    );
  }

  Future<Visit> createVisit({
    required Map<String, dynamic> body,
    List<http.MultipartFile>? files,
  }) async {
    try {
      final record = await pb
          .collection(AppConstants.visitsCollection)
          .create(body: body, files: files ?? [], expand: 'patient');
      return Visit.fromRecord(record);
    } catch (e) {
      rethrow;
    }
  }

  Future<Visit> updateVisit({
    required String id,
    required Map<String, dynamic> body,
    List<http.MultipartFile>? files,
  }) async {
    try {
      final record = await pb
          .collection(AppConstants.visitsCollection)
          .update(id, body: body, files: files ?? [], expand: 'patient');
      return Visit.fromRecord(record);
    } catch (e) {
      rethrow;
    }
  }

  Future<Visit> updateVisitStatus(String id, String status) async {
    return updateVisit(id: id, body: {'status': status});
  }

  Future<Visit> removeVisitImage(
    String visitId,
    String filename,
    List<String> remainingImages,
  ) async {
    try {
      final record = await pb
          .collection(AppConstants.visitsCollection)
          .update(
            visitId,
            body: {'images': remainingImages},
            expand: 'patient',
          );
      return Visit.fromRecord(record);
    } catch (e) {
      rethrow;
    }
  }

  Future<Visit> addVisitPrescriptionImages(
    String visitId,
    List<http.MultipartFile> files,
  ) async {
    try {
      final record = await pb
          .collection(AppConstants.visitsCollection)
          .update(visitId, body: const {}, files: files, expand: 'patient');
      return Visit.fromRecord(record);
    } catch (e) {
      rethrow;
    }
  }

  Future<Visit> removeVisitPrescriptionImage(
    String visitId,
    String filename,
    List<String> remainingPrescriptionImages,
  ) async {
    try {
      final record = await pb
          .collection(AppConstants.visitsCollection)
          .update(
            visitId,
            body: {
              AppConstants.visitPrescriptionImagesField:
                  remainingPrescriptionImages,
            },
            expand: 'patient',
          );
      return Visit.fromRecord(record);
    } catch (e) {
      rethrow;
    }
  }

  // Operations API
  Future<List<Operation>> getOperations({
    String? patientId,
    String? search,
    String? filter,
    String? sort,
  }) async {
    try {
      final filters = <String>[];
      if (patientId != null && patientId.isNotEmpty) {
        filters.add('patient = "$patientId"');
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().replaceAll("'", "\\'");
        filters.add('(patient.name ~ "$q" || patient.phone ~ "$q")');
      }
      if (filter != null && filter.trim().isNotEmpty) {
        filters.add(filter);
      }

      final filterString = filters.isNotEmpty ? filters.join(' && ') : null;

      final records = await pb
          .collection(AppConstants.operationsCollection)
          .getFullList(
            expand: 'patient,added_by',
            sort: sort ?? '-date_time,-created',
            filter: filterString,
          );

      return records.map((r) => Operation.fromRecord(r)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Operation> createOperation({
    required Map<String, dynamic> body,
    List<http.MultipartFile>? files,
  }) async {
    try {
      final record = await pb
          .collection(AppConstants.operationsCollection)
          .create(body: body, files: files ?? [], expand: 'patient,added_by');
      return Operation.fromRecord(record);
    } catch (e) {
      rethrow;
    }
  }

  Future<Operation> updateOperation({
    required String id,
    required Map<String, dynamic> body,
    List<http.MultipartFile>? files,
  }) async {
    try {
      final record = await pb
          .collection(AppConstants.operationsCollection)
          .update(
            id,
            body: body,
            files: files ?? [],
            expand: 'patient,added_by',
          );
      return Operation.fromRecord(record);
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteOperation(String id) async {
    try {
      await pb.collection(AppConstants.operationsCollection).delete(id);
      return true;
    } catch (e) {
      rethrow;
    }
  }

  // Notifications API
  Future<List<AppNotification>> getNotifications({
    String? target,
    String? filter,
    int perPage = 100,
  }) async {
    try {
      final filters = <String>[];
      if (target != null && target.isNotEmpty) {
        filters.add('target = "$target"');
      }
      if (filter != null && filter.trim().isNotEmpty) {
        filters.add(filter);
      }
      final filterString = filters.isNotEmpty ? filters.join(' && ') : null;

      final records = await pb
          .collection(AppConstants.notificationsCollection)
          .getFullList(sort: '-created', filter: filterString);

      // Best-effort pagination for larger histories.
      final all = records.map((r) => AppNotification.fromRecord(r)).toList();
      return all.take(perPage).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<AppNotification> createNotification(Map<String, dynamic> data) async {
    try {
      final record = await pb
          .collection(AppConstants.notificationsCollection)
          .create(body: data);
      return AppNotification.fromRecord(record);
    } catch (e) {
      rethrow;
    }
  }

  Future<AppNotification> markNotificationRead(
    String id,
    List<String> readBy,
  ) async {
    try {
      final record = await pb
          .collection(AppConstants.notificationsCollection)
          .update(id, body: {'read_by': readBy});
      return AppNotification.fromRecord(record);
    } catch (e) {
      rethrow;
    }
  }

  // Real-time Subscriptions
  bool _visitsSubscribed = false;
  bool _patientsSubscribed = false;
  bool _operationsSubscribed = false;
  bool _notificationsSubscribed = false;

  bool get visitsSubscribed => _visitsSubscribed;
  bool get patientsSubscribed => _patientsSubscribed;
  bool get operationsSubscribed => _operationsSubscribed;
  bool get notificationsSubscribed => _notificationsSubscribed;

  Future<void> subscribeToVisits(
    void Function(RecordSubscriptionEvent) onEvent,
  ) async {
    if (_visitsSubscribed) return;
    _visitsSubscribed = true;
    try {
      await pb
          .collection(AppConstants.visitsCollection)
          .subscribe('*', onEvent);
    } catch (_) {
    } finally {
      _visitsSubscribed = false;
    }
  }

  Future<void> unsubscribeFromVisits() async {
    _visitsSubscribed = false;
    try {
      await pb.collection(AppConstants.visitsCollection).unsubscribe('*');
    } catch (_) {}
  }

  Future<void> subscribeToPatients(
    void Function(RecordSubscriptionEvent) onEvent,
  ) async {
    if (_patientsSubscribed) return;
    _patientsSubscribed = true;
    try {
      await pb
          .collection(AppConstants.patientsCollection)
          .subscribe('*', onEvent);
    } catch (_) {
    } finally {
      _patientsSubscribed = false;
    }
  }

  Future<void> unsubscribeFromPatients() async {
    _patientsSubscribed = false;
    try {
      await pb.collection(AppConstants.patientsCollection).unsubscribe('*');
    } catch (_) {}
  }

  Future<void> subscribeToOperations(
    void Function(RecordSubscriptionEvent) onEvent,
  ) async {
    if (_operationsSubscribed) return;
    _operationsSubscribed = true;
    try {
      await pb
          .collection(AppConstants.operationsCollection)
          .subscribe('*', onEvent);
    } catch (_) {
    } finally {
      _operationsSubscribed = false;
    }
  }

  Future<void> unsubscribeFromOperations() async {
    _operationsSubscribed = false;
    try {
      await pb.collection(AppConstants.operationsCollection).unsubscribe('*');
    } catch (_) {}
  }

  Future<void> subscribeToNotifications(
    void Function(RecordSubscriptionEvent) onEvent,
  ) async {
    if (_notificationsSubscribed) return;
    _notificationsSubscribed = true;
    try {
      await pb
          .collection(AppConstants.notificationsCollection)
          .subscribe('*', onEvent);
    } catch (_) {
    } finally {
      _notificationsSubscribed = false;
    }
  }

  Future<void> unsubscribeFromNotifications() async {
    _notificationsSubscribed = false;
    try {
      await pb
          .collection(AppConstants.notificationsCollection)
          .unsubscribe('*');
    } catch (_) {}
  }
}
