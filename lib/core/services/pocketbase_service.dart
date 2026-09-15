import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import '../constants/app_constants.dart';
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
    String? search,
    String? filter,
  }) async {
    try {
      final filters = <String>[];
      if (status != null && status.isNotEmpty && status != 'all') {
        filters.add('status = "$status"');
      }
      if (date != null && date.isNotEmpty) {
        filters.add('visit_date ~ "$date"');
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
            sort: 'status,queue_number,-created',
            filter: filterString,
          );

      return records.map((r) => Visit.fromRecord(r)).toList();
    } catch (e) {
      rethrow;
    }
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

  Future<Visit> removeVisitImage(
    String visitId,
    String filename,
    List<String> remainingImages,
  ) async {
    try {
      // In PocketBase, updating with the array of remaining filenames or passing empty removes deleted ones
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

  // Real-time Subscriptions
  bool _visitsSubscribed = false;
  bool _patientsSubscribed = false;

  bool get visitsSubscribed => _visitsSubscribed;
  bool get patientsSubscribed => _patientsSubscribed;

  Future<void> subscribeToVisits(
    void Function(RecordSubscriptionEvent) onEvent,
  ) async {
    if (_visitsSubscribed) return;
    _visitsSubscribed = true;
    try {
      // The future completes when the connection drops or the
      // subscription is unsubscribed, so the flag is cleared here to let
      // callers detect a disconnect and re-subscribe.
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
}
