import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../core/constants/app_constants.dart';
import '../core/services/pocketbase_service.dart';
import '../models/patient.dart';
import '../models/visit.dart';
import '../models/vital_signs.dart';

class ClinicProvider extends ChangeNotifier {
  final PocketBaseService _pbService = PocketBaseService();
  final String? _currentUserId;

  List<Patient> _patients = [];
  List<Visit> _visits = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _statusFilter = 'all';

  Visit? _selectedVisit;
  Patient? _selectedPatient;

  bool _initialized = false;
  bool _disposed = false;
  Timer? _reconnectTimer;
  static const int _maxStartupRetries = 5;

  ClinicProvider({String? currentUserId}) : _currentUserId = currentUserId {
    _setupRealtime();
    _startReconnectWatchdog();
  }

  /// Starts the app-off bootstrap load: fetches all patients plus the
  /// visits of today (and any still-active visits) from PocketBase, then
  /// retries with backoff until it succeeds. Independent of the live
  /// subscription, which only serves as a refresh trigger afterwards.
  Future<bool> initialize() async {
    if (_initialized || _disposed) return _initialized;
    _initialized = true;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    for (var attempt = 0; attempt < _maxStartupRetries; attempt++) {
      if (_disposed) return false;
      final ok = await loadData(showLoading: false);
      if (ok || _disposed) {
        _isLoading = false;
        notifyListeners();
        return ok;
      }
      await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Getters
  List<Patient> get patients => _patients;
  List<Visit> get visits => _visits;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get statusFilter => _statusFilter;
  Visit? get selectedVisit => _selectedVisit;
  Patient? get selectedPatient => _selectedPatient;

  List<Visit> get waitingResidentVisits => _visits
      .where(
        (v) =>
            v.status == AppConstants.statusWaitingResident ||
            v.status == AppConstants.statusWithResident,
      )
      .toList();

  List<Visit> get waitingConsultantVisits => _visits
      .where(
        (v) =>
            v.status == AppConstants.statusWaitingConsultant ||
            v.status == AppConstants.statusWithConsultant,
      )
      .toList();

  List<Visit> get completedVisits =>
      _visits.where((v) => v.status == AppConstants.statusCompleted).toList();

  List<Visit> get todayVisits {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _visits.where((v) => v.visitDate == today).toList();
  }

  void _setupRealtime() {
    _pbService.subscribeToVisits((e) {
      loadData(showLoading: false);
    });
    _pbService.subscribeToPatients((e) {
      loadData(showLoading: false);
    });
  }

  void _startReconnectWatchdog() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (_disposed) return;
      if (!_pbService.visitsSubscribed || !_pbService.patientsSubscribed) {
        _setupRealtime();
      }
    });
  }

  bool get realtimeConnected =>
      _pbService.visitsSubscribed && _pbService.patientsSubscribed;

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _pbService.unsubscribeFromVisits();
    _pbService.unsubscribeFromPatients();
    super.dispose();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setStatusFilter(String status) {
    _statusFilter = status;
    notifyListeners();
  }

  void selectVisit(Visit? visit) {
    _selectedVisit = visit;
    notifyListeners();
  }

  void selectPatient(Patient? patient) {
    _selectedPatient = patient;
    notifyListeners();
  }

  Future<bool> loadData({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final activeStatuses = [
        AppConstants.statusWaitingResident,
        AppConstants.statusWithResident,
        AppConstants.statusWaitingConsultant,
        AppConstants.statusWithConsultant,
      ];
      final activeFilter = activeStatuses
          .map((s) => 'status = "$s"')
          .join(' || ');

      final results = await Future.wait([
        _pbService.getPatients(),
        _pbService.getVisits(filter: activeFilter),
        _pbService.getVisits(date: today),
      ]);

      _patients = results[0] as List<Patient>;
      final activeVisits = results[1] as List<Visit>;
      final todayVisits = results[2] as List<Visit>;
      _visits = _mergeVisits(activeVisits, todayVisits);

      // Keep selection updated with the latest data
      if (_selectedVisit != null) {
        final updated = _visits
            .where((v) => v.id == _selectedVisit!.id)
            .firstOrNull;
        _selectedVisit = updated ?? _selectedVisit;
      }
      if (_selectedPatient != null) {
        final updated = _patients
            .where((p) => p.id == _selectedPatient!.id)
            .firstOrNull;
        _selectedPatient = updated ?? _selectedPatient;
      }

      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Failed to load clinic data: $e';
      return false;
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  List<Visit> _mergeVisits(List<Visit> activeVisits, List<Visit> todayVisits) {
    final byId = <String, Visit>{
      for (final v in [...activeVisits, ...todayVisits]) v.id: v,
    };
    final merged = byId.values.toList()..sort((a, b) {
        final aq = a.queueNumber ?? (1 << 30);
        final bq = b.queueNumber ?? (1 << 30);
        if (aq != bq) return aq.compareTo(bq);
        final ac = a.created ?? DateTime(0);
        final bc = b.created ?? DateTime(0);
        return bc.compareTo(ac);
      });
    return merged;
  }

  // Receptionist Actions
  Future<Patient> registerPatient({
    required String name,
    required String phone,
    String? dob,
    String? gender,
    String? nationalId,
    String? notes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final patient = await _pbService.createPatient({
        'name': name.trim(),
        'phone': phone.trim(),
        if (dob != null && dob.isNotEmpty) 'dob': dob.trim(),
        if (gender != null && gender.isNotEmpty) 'gender': gender.trim(),
        if (nationalId != null && nationalId.isNotEmpty)
          'national_id': nationalId.trim(),
        if (notes != null && notes.isNotEmpty) 'notes': notes.trim(),
        if (_currentUserId != null) 'added_by': _currentUserId,
      });

      _patients.insert(0, patient);
      _selectedPatient = patient;
      _isLoading = false;
      notifyListeners();
      return patient;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to register patient: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<Patient> updatePatient(
    String id, {
    String? name,
    String? phone,
    String? dob,
    String? gender,
    String? nationalId,
    String? notes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _pbService.updatePatient(id, {
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (dob != null && dob.isNotEmpty) 'dob': dob.trim(),
        if (gender != null && gender.isNotEmpty) 'gender': gender.trim(),
        if (nationalId != null && nationalId.isNotEmpty)
          'national_id': nationalId.trim(),
        if (notes != null && notes.isNotEmpty) 'notes': notes.trim(),
      });

      final idx = _patients.indexWhere((p) => p.id == updated.id);
      if (idx != -1) {
        _patients[idx] = updated;
      } else {
        _patients.insert(0, updated);
      }
      if (_selectedPatient?.id == updated.id) {
        _selectedPatient = updated;
      }

      _isLoading = false;
      notifyListeners();
      return updated;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to update patient: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<Visit> checkInPatient({
    required Patient patient,
    String? chiefComplaint,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      // Calculate next queue number for today
      final todayVisitsCount = _visits
          .where((v) => v.visitDate == todayStr)
          .length;
      final nextQueueNumber = todayVisitsCount + 1;

      final visit = await _pbService.createVisit(
        body: {
          'patient': patient.id,
          'visit_date': todayStr,
          'queue_number': nextQueueNumber,
          'status': AppConstants.statusWaitingResident,
          if (chiefComplaint != null && chiefComplaint.trim().isNotEmpty)
            'chief_complaint': chiefComplaint.trim(),
          if (_currentUserId != null) 'added_by': _currentUserId,
        },
      );

      // Link patient data into visit
      final fullVisit = visit.copyWith(patient: patient);
      _visits.insert(0, fullVisit);
      _selectedVisit = fullVisit;
      _isLoading = false;
      notifyListeners();
      return fullVisit;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to check-in patient: $e';
      notifyListeners();
      rethrow;
    }
  }

  // Resident Doctor Actions
  Future<void> acceptPatientByResident(
    Visit visit, {
    String residentName = 'Resident Doctor',
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final updated = await _pbService.updateVisit(
        id: visit.id,
        body: {
          'status': AppConstants.statusWithResident,
          'resident_name': residentName,
        },
      );

      final fullVisit = updated.copyWith(patient: visit.patient);
      _updateVisitInList(fullVisit);
      _selectedVisit = fullVisit;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to accept patient: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> saveResidentIntake({
    required Visit visit,
    String? chiefComplaint,
    String? historyPresentIllness,
    String? pastMedicalHistory,
    String? drugHistoryAllergies,
    VitalSigns? vitalSigns,
    String? examinationNotes,
    String? residentAssessment,
    String? residentName,
    List<http.MultipartFile>? newImages,
    bool sendToConsultant = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final nextStatus = sendToConsultant
          ? AppConstants.statusWaitingConsultant
          : AppConstants.statusWithResident;

      final body = <String, dynamic>{
        'status': nextStatus,
        if (chiefComplaint != null) 'chief_complaint': chiefComplaint.trim(),
        if (historyPresentIllness != null)
          'history_present_illness': historyPresentIllness.trim(),
        if (pastMedicalHistory != null)
          'past_medical_history': pastMedicalHistory.trim(),
        if (drugHistoryAllergies != null)
          'drug_history_allergies': drugHistoryAllergies.trim(),
        if (vitalSigns != null) 'vital_signs': vitalSigns.toJson(),
        if (examinationNotes != null)
          'examination_notes': examinationNotes.trim(),
        if (residentAssessment != null)
          'resident_assessment': residentAssessment.trim(),
        if (residentName != null && residentName.isNotEmpty)
          'resident_name': residentName.trim(),
      };

      final updated = await _pbService.updateVisit(
        id: visit.id,
        body: body,
        files: newImages,
      );

      final fullVisit = updated.copyWith(patient: visit.patient);
      _updateVisitInList(fullVisit);
      _selectedVisit = fullVisit;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to save resident intake: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteVisitImage(Visit visit, String filename) async {
    _isLoading = true;
    notifyListeners();

    try {
      final remaining = List<String>.from(visit.images)..remove(filename);
      final updated = await _pbService.removeVisitImage(
        visit.id,
        filename,
        remaining,
      );
      final fullVisit = updated.copyWith(patient: visit.patient);
      _updateVisitInList(fullVisit);
      _selectedVisit = fullVisit;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to remove image: $e';
      notifyListeners();
      rethrow;
    }
  }

  // Consultant Actions
  Future<void> acceptPatientByConsultant(
    Visit visit, {
    String consultantName = 'Consultant',
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final updated = await _pbService.updateVisit(
        id: visit.id,
        body: {
          'status': AppConstants.statusWithConsultant,
          'consultant_name': consultantName,
        },
      );

      final fullVisit = updated.copyWith(patient: visit.patient);
      _updateVisitInList(fullVisit);
      _selectedVisit = fullVisit;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to accept patient: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> saveConsultantAssessment({
    required Visit visit,
    String? diagnosis,
    String? plan,
    String? prescription,
    String? notes,
    String? consultantName,
    bool markCompleted = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final nextStatus = markCompleted
          ? AppConstants.statusCompleted
          : AppConstants.statusWithConsultant;

      final body = <String, dynamic>{
        'status': nextStatus,
        if (diagnosis != null) 'consultant_diagnosis': diagnosis.trim(),
        if (plan != null) 'consultant_plan': plan.trim(),
        if (prescription != null)
          'consultant_prescription': prescription.trim(),
        if (notes != null) 'consultant_notes': notes.trim(),
        if (consultantName != null && consultantName.isNotEmpty)
          'consultant_name': consultantName.trim(),
      };

      final updated = await _pbService.updateVisit(id: visit.id, body: body);

      final fullVisit = updated.copyWith(patient: visit.patient);
      _updateVisitInList(fullVisit);
      _selectedVisit = fullVisit;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to save consultant evaluation: $e';
      notifyListeners();
      rethrow;
    }
  }

  void _updateVisitInList(Visit updatedVisit) {
    final idx = _visits.indexWhere((v) => v.id == updatedVisit.id);
    if (idx != -1) {
      _visits[idx] = updatedVisit;
    } else {
      _visits.insert(0, updatedVisit);
    }
  }
}
