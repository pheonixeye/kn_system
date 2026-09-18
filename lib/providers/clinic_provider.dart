import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../core/constants/app_constants.dart';
import '../core/services/pocketbase_service.dart';
import '../models/notification.dart';
import '../models/operation.dart';
import '../models/patient.dart';
import '../models/visit.dart';
import '../models/vital_signs.dart';

class ClinicProvider extends ChangeNotifier {
  final PocketBaseService _pbService = PocketBaseService();
  final String? currentUserId;
  final String? currentUserType;

  List<Patient> _patients = [];
  List<Visit> _visits = [];
  List<Operation> _operations = [];
  List<AppNotification> _notifications = [];
  final Map<String, List<Visit>> _patientVisits = {};
  final Set<String> _loadingPatientVisits = {};
  final StreamController<AppNotification> _incomingNotifications =
      StreamController<AppNotification>.broadcast();

  Visit? _selectedVisit;
  Patient? _selectedPatient;
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  String _statusFilter = 'all';

  ClinicProvider({this.currentUserId, this.currentUserType}) {
    // initialize on creation
  }

  // Getters
  List<Patient> get patients => _patients;
  List<Visit> get visits => _visits;
  List<Operation> get operations => _operations;
  List<AppNotification> get notifications => _notifications;

  /// Emits only notifications that arrive live via realtime, so UI can show
  /// transient toasts without replaying the existing backlog.
  Stream<AppNotification> get incomingNotifications =>
      _incomingNotifications.stream;
  Visit? get selectedVisit => _selectedVisit;
  Patient? get selectedPatient => _selectedPatient;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get statusFilter => _statusFilter;
  bool get realtimeConnected =>
      _pbService.visitsSubscribed ||
      _pbService.patientsSubscribed ||
      _pbService.operationsSubscribed ||
      _pbService.notificationsSubscribed;

  int get unreadNotificationCount {
    if (currentUserId == null) return 0;
    return _notifications
        .where((n) => !n.isReadBy(currentUserId!))
        .length;
  }

  List<Operation> getPatientOperations(String patientId) {
    if (patientId.isEmpty) return [];
    return _operations.where((o) => o.patientId == patientId).toList();
  }

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

  List<Visit>? getPatientVisits(String patientId) => _patientVisits[patientId];
  bool isPatientVisitsLoading(String patientId) =>
      _loadingPatientVisits.contains(patientId);

  Future<void> initialize() => loadData();
  Future<void> init() => loadData();

  Future<void> loadData({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final results = await Future.wait([
        _pbService.getPatients(),
        _pbService.getVisits(),
        _pbService.getOperations(),
        _pbService.getNotifications(target: currentUserType ?? ''),
      ]);

      _patients = results[0] as List<Patient>;
      _visits = results[1] as List<Visit>;
      _operations = results[2] as List<Operation>;
      _notifications = results[3] as List<AppNotification>;

      // Keep selected visit updated
      if (_selectedVisit != null) {
        final updated = _visits
            .where((v) => v.id == _selectedVisit!.id)
            .firstOrNull;
        _selectedVisit = updated ?? _selectedVisit;
      }

      _errorMessage = null;
      _setupRealtime();
    } catch (e) {
      _errorMessage = 'Failed to load clinic data: $e';
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  void _setupRealtime() {
    _pbService.subscribeToVisits((event) {
      final action = event.action;
      final record = event.record;
      if (record == null) {
        loadData(showLoading: false);
        return;
      }

      if (action == 'create') {
        final newVisit = Visit.fromRecord(record);
        if (newVisit.isTodayVisit) {
          final patient = _patients
              .where((p) => p.id == newVisit.patientId)
              .firstOrNull;
          final fullVisit = newVisit.copyWith(patient: patient);
          _updateVisitInList(fullVisit);
        }

        if (_patientVisits.containsKey(newVisit.patientId)) {
          final patient = _patients
              .where((p) => p.id == newVisit.patientId)
              .firstOrNull;
          final fullVisit = newVisit.copyWith(patient: patient);
          _patientVisits[newVisit.patientId]!.insert(0, fullVisit);
        }

        notifyListeners();
      } else if (action == 'update') {
        final updatedVisit = Visit.fromRecord(record);
        final patient = _patients
            .where((p) => p.id == updatedVisit.patientId)
            .firstOrNull;
        final fullVisit = updatedVisit.copyWith(patient: patient);

        final index = _visits.indexWhere((v) => v.id == updatedVisit.id);
        if (index != -1) {
          if (updatedVisit.isTodayVisit) {
            _visits[index] = fullVisit;
          } else {
            _visits.removeAt(index);
          }
        } else if (updatedVisit.isTodayVisit) {
          _visits.insert(0, fullVisit);
        }

        if (_selectedVisit?.id == updatedVisit.id) {
          _selectedVisit = fullVisit;
        }

        if (_patientVisits.containsKey(updatedVisit.patientId)) {
          final pIndex = _patientVisits[updatedVisit.patientId]!.indexWhere(
            (v) => v.id == updatedVisit.id,
          );
          if (pIndex != -1) {
            _patientVisits[updatedVisit.patientId]![pIndex] = fullVisit;
          } else {
            _patientVisits[updatedVisit.patientId]!.insert(0, fullVisit);
          }
        }

        notifyListeners();
      } else if (action == 'delete') {
        final deletedId = record.id;
        _visits.removeWhere((v) => v.id == deletedId);
        if (_selectedVisit?.id == deletedId) {
          _selectedVisit = null;
        }

        for (final list in _patientVisits.values) {
          list.removeWhere((v) => v.id == deletedId);
        }

        notifyListeners();
      }
    });

    _pbService.subscribeToPatients((event) {
      final action = event.action;
      final record = event.record;
      if (record == null) return;

      if (action == 'create') {
        final newPatient = Patient.fromRecord(record);
        _patients.insert(0, newPatient);
        notifyListeners();
      } else if (action == 'update') {
        final updatedPatient = Patient.fromRecord(record);
        final index = _patients.indexWhere((p) => p.id == updatedPatient.id);
        if (index != -1) {
          _patients[index] = updatedPatient;
          if (_selectedPatient?.id == updatedPatient.id) {
            _selectedPatient = updatedPatient;
          }
          for (var i = 0; i < _visits.length; i++) {
            if (_visits[i].patientId == updatedPatient.id) {
              _visits[i] = _visits[i].copyWith(patient: updatedPatient);
            }
          }
          if (_selectedVisit?.patientId == updatedPatient.id) {
            _selectedVisit = _selectedVisit?.copyWith(patient: updatedPatient);
          }
        }
        notifyListeners();
      } else if (action == 'delete') {
        final deletedId = record.id;
        _patients.removeWhere((p) => p.id == deletedId);
        if (_selectedPatient?.id == deletedId) {
          _selectedPatient = null;
        }
        notifyListeners();
      }
    });

    _pbService.subscribeToOperations((event) {
      final action = event.action;
      final record = event.record;
      if (record == null) return;

      if (action == 'create') {
        final newOp = Operation.fromRecord(record);
        final patient = _patients
            .where((p) => p.id == newOp.patientId)
            .firstOrNull;
        final existingIndex = _operations.indexWhere((o) => o.id == newOp.id);
        final existing = existingIndex != -1
            ? _operations[existingIndex]
            : null;
        final fullOp = newOp.copyWith(
          patient: patient ?? existing?.patient,
          addedBy: newOp.addedBy ?? existing?.addedBy,
          addedById: newOp.addedById ?? existing?.addedById,
        );
        _operations.removeWhere((o) => o.id == fullOp.id);
        _operations.insert(0, fullOp);
        notifyListeners();
      } else if (action == 'update') {
        final updatedOp = Operation.fromRecord(record);
        final patient = _patients
            .where((p) => p.id == updatedOp.patientId)
            .firstOrNull;

        final index = _operations.indexWhere((o) => o.id == updatedOp.id);
        final existing = index != -1 ? _operations[index] : null;
        final fullOp = updatedOp.copyWith(
          patient: patient ?? existing?.patient,
          addedBy: updatedOp.addedBy ?? existing?.addedBy,
          addedById: updatedOp.addedById ?? existing?.addedById,
        );

        if (index != -1) {
          _operations[index] = fullOp;
        } else {
          _operations.insert(0, fullOp);
        }
        notifyListeners();
      } else if (action == 'delete') {
        final deletedId = record.id;
        _operations.removeWhere((o) => o.id == deletedId);
        notifyListeners();
      }
    });

    _pbService.subscribeToNotifications((event) {
      final action = event.action;
      final record = event.record;
      if (record == null) return;

      final notification = AppNotification.fromRecord(record);
      if (!_isRelevantNotification(notification)) return;

      if (action == 'create') {
        _notifications.insert(0, notification);
        if (!_incomingNotifications.isClosed) {
          _incomingNotifications.add(notification);
        }
        notifyListeners();
      } else if (action == 'update') {
        final index = _notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          _notifications[index] = notification;
        } else {
          _notifications.insert(0, notification);
        }
        notifyListeners();
      }
    });
  }

  bool _isRelevantNotification(AppNotification notification) {
    if (currentUserType == null || currentUserType!.isEmpty) return false;
    return notification.target == currentUserType;
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
    if (visit != null && visit.patientId.isNotEmpty) {
      fetchPatientVisitsHistory(visit.patientId);
    }
  }

  void selectPatient(Patient? patient) {
    _selectedPatient = patient;
    notifyListeners();
  }

  Future<List<Visit>> fetchPatientVisitsHistory(
    String patientId, {
    bool forceRefresh = false,
  }) async {
    if (patientId.isEmpty) return [];

    if (!forceRefresh && _patientVisits.containsKey(patientId)) {
      return _patientVisits[patientId]!;
    }

    _loadingPatientVisits.add(patientId);
    notifyListeners();

    try {
      final history = await _pbService.getPatientVisitsHistory(
        patientId: patientId,
      );
      _patientVisits[patientId] = history;
      return history;
    } catch (e) {
      debugPrint('Error fetching patient visits history: $e');
      return _patientVisits[patientId] ?? [];
    } finally {
      _loadingPatientVisits.remove(patientId);
      notifyListeners();
    }
  }

  // Receptionist Actions
  Future<Patient> registerPatient({
    required String name,
    required String phone,
    String? dob,
    String? gender,
    String? nationalId,
    String? address,
    String? emergencyContact,
    String? occupation,
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
        if (address != null && address.isNotEmpty) 'address': address.trim(),
        if (emergencyContact != null && emergencyContact.isNotEmpty)
          'emergency_contact': emergencyContact.trim(),
        if (occupation != null && occupation.isNotEmpty)
          'occupation': occupation.trim(),
        if (notes != null && notes.isNotEmpty) 'notes': notes.trim(),
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
    String? address,
    String? emergencyContact,
    String? occupation,
    String? notes,
    Map<String, dynamic>? data,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        if (name != null) 'name': name.trim(),
        if (phone != null) 'phone': phone.trim(),
        if (dob != null) 'dob': dob.trim(),
        if (gender != null) 'gender': gender.trim(),
        if (nationalId != null) 'national_id': nationalId.trim(),
        if (address != null) 'address': address.trim(),
        if (emergencyContact != null)
          'emergency_contact': emergencyContact.trim(),
        if (occupation != null) 'occupation': occupation.trim(),
        if (notes != null) 'notes': notes.trim(),
        if (data != null) ...data,
      };

      final updated = await _pbService.updatePatient(id, body);
      final index = _patients.indexWhere((p) => p.id == id);
      if (index != -1) {
        _patients[index] = updated;
      }
      if (_selectedPatient?.id == id) {
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
        },
      );

      final fullVisit = visit.copyWith(patient: patient);
      _updateVisitInList(fullVisit);
      _selectedVisit = fullVisit;

      if (_patientVisits.containsKey(patient.id)) {
        _patientVisits[patient.id]!.insert(0, fullVisit);
      }

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

  Future<Visit> createVisit({
    required String patientId,
    int? queueNumber,
    String? chiefComplaint,
    String? notes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final todayStr = AppConstants.todayDateString;
      final qNum = queueNumber ?? (_visits.length + 1);

      final visit = await _pbService.createVisit(
        body: {
          'patient': patientId,
          'visit_date': todayStr,
          'status': AppConstants.statusWaitingResident,
          'queue_number': qNum,
          if (chiefComplaint != null && chiefComplaint.isNotEmpty)
            'chief_complaint': chiefComplaint,
          if (notes != null && notes.isNotEmpty) 'resident_assessment': notes,
        },
      );

      final patient = _patients.where((p) => p.id == patientId).firstOrNull;
      final fullVisit = visit.copyWith(patient: patient);

      _updateVisitInList(fullVisit);
      _selectedVisit = fullVisit;

      if (_patientVisits.containsKey(patientId)) {
        _patientVisits[patientId]!.insert(0, fullVisit);
      }

      _isLoading = false;
      notifyListeners();
      return fullVisit;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to create visit: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateVisitStatus(Visit visit, String newStatus) async {
    try {
      final updated = await _pbService.updateVisitStatus(visit.id, newStatus);
      final fullVisit = updated.copyWith(patient: visit.patient);
      _updateVisitInList(fullVisit);
      if (_selectedVisit?.id == visit.id) {
        _selectedVisit = fullVisit;
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update visit status: $e';
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

      if (_patientVisits.containsKey(visit.patientId)) {
        final pIdx = _patientVisits[visit.patientId]!.indexWhere(
          (v) => v.id == visit.id,
        );
        if (pIdx != -1) {
          _patientVisits[visit.patientId]![pIdx] = fullVisit;
        }
      }

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
  Future<void> addVisitPrescriptionImages(
    Visit visit,
    List<http.MultipartFile> files, {
    String? consultantName,
  }) async {
    if (files.isEmpty) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _pbService.addVisitPrescriptionImages(
        visit.id,
        files,
      );
      final fullVisit = updated.copyWith(patient: visit.patient);
      _updateVisitInList(fullVisit);
      _selectedVisit = fullVisit;

      if (_patientVisits.containsKey(visit.patientId)) {
        final pIdx = _patientVisits[visit.patientId]!.indexWhere(
          (v) => v.id == visit.id,
        );
        if (pIdx != -1) {
          _patientVisits[visit.patientId]![pIdx] = fullVisit;
        }
      }

      _notify(
        targets: const [AppConstants.userTypeResident],
        type: AppConstants.notifTypePrescriptionAdded,
        title: 'New Prescription Available',
        body:
            '${fullVisit.patient?.name ?? "A patient"} (Queue #${fullVisit.queueNumber ?? "-"}) has a new prescription attachment from ${consultantName?.isNotEmpty == true ? consultantName : "the consultant"}.',
        visitId: fullVisit.id,
        patientId: fullVisit.patientId,
        patientName: fullVisit.patient?.name,
        senderName: consultantName,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to attach prescription image: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteVisitPrescriptionImage(
    Visit visit,
    String filename,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final remaining = List<String>.from(visit.prescriptionImages)
        ..remove(filename);
      final updated = await _pbService.removeVisitPrescriptionImage(
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
      _errorMessage = 'Failed to remove prescription image: $e';
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

      if (_patientVisits.containsKey(visit.patientId)) {
        final pIdx = _patientVisits[visit.patientId]!.indexWhere(
          (v) => v.id == visit.id,
        );
        if (pIdx != -1) {
          _patientVisits[visit.patientId]![pIdx] = fullVisit;
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to save consultant evaluation: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<Visit> sendVisitBackToResident(
    Visit visit, {
    String? notes,
    String? consultantName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'status': AppConstants.statusWaitingResident,
        if (notes != null && notes.isNotEmpty) 'consultant_notes': notes.trim(),
        if (consultantName != null && consultantName.isNotEmpty)
          'consultant_name': consultantName.trim(),
      };

      final updated = await _pbService.updateVisit(id: visit.id, body: body);
      final fullVisit = updated.copyWith(patient: visit.patient);

      _updateVisitInList(fullVisit);
      _selectedVisit = fullVisit;

      if (_patientVisits.containsKey(visit.patientId)) {
        final pIdx = _patientVisits[visit.patientId]!.indexWhere(
          (v) => v.id == visit.id,
        );
        if (pIdx != -1) {
          _patientVisits[visit.patientId]![pIdx] = fullVisit;
        }
      }

      _notify(
        targets: const [AppConstants.userTypeResident],
        type: AppConstants.notifTypePatientSentBack,
        title: 'Patient Sent Back by Consultant',
        body:
            '${fullVisit.patient?.name ?? "A patient"} (Queue #${fullVisit.queueNumber ?? "-"}) was sent back to the resident with consultant notes.'
            '${notes != null && notes.trim().isNotEmpty ? " Note: ${notes.trim()}" : ""}',
        visitId: fullVisit.id,
        patientId: fullVisit.patientId,
        patientName: fullVisit.patient?.name,
        senderName: consultantName,
      );

      _isLoading = false;
      notifyListeners();
      return fullVisit;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to send visit back to resident: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<Visit> sendVisitToManagement(
    Visit visit, {
    String? diagnosis,
    String? plan,
    String? prescription,
    String? notes,
    String? consultantName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'status': AppConstants.statusSentToManagement,
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

      if (_patientVisits.containsKey(visit.patientId)) {
        final pIdx = _patientVisits[visit.patientId]!.indexWhere(
          (v) => v.id == visit.id,
        );
        if (pIdx != -1) {
          _patientVisits[visit.patientId]![pIdx] = fullVisit;
        }
      }

      _notify(
        targets: const [AppConstants.userTypeManager],
        type: AppConstants.notifTypeReferredToManagement,
        title: 'Patient Referred for Operation',
        body:
            '${fullVisit.patient?.name ?? "A patient"} (Queue #${fullVisit.queueNumber ?? "-"}) was referred to management for operation scheduling by ${consultantName?.isNotEmpty == true ? consultantName : "the consultant"}.',
        visitId: fullVisit.id,
        patientId: fullVisit.patientId,
        patientName: fullVisit.patient?.name,
        senderName: consultantName,
      );

      _isLoading = false;
      notifyListeners();
      return fullVisit;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to send visit to management: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<Visit> reviseVisitAssessment({
    required Visit visit,
    String? diagnosis,
    String? plan,
    String? prescription,
    String? notes,
    String? consultantName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{
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

      if (_patientVisits.containsKey(visit.patientId)) {
        final pIndex = _patientVisits[visit.patientId]!.indexWhere(
          (v) => v.id == visit.id,
        );
        if (pIndex != -1) {
          _patientVisits[visit.patientId]![pIndex] = fullVisit;
        } else {
          _patientVisits[visit.patientId]!.insert(0, fullVisit);
        }
      }

      _isLoading = false;
      notifyListeners();
      return fullVisit;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to revise visit record: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _notify({
    required List<String> targets,
    required String type,
    required String title,
    required String body,
    String? visitId,
    String? operationId,
    String? patientId,
    String? patientName,
    String? senderName,
  }) async {
    for (final target in targets.toSet()) {
      try {
        await _pbService.createNotification({
          'target': target,
          'type': type,
          'title': title,
          'body': body,
          if (visitId != null && visitId.isNotEmpty) 'visit_id': visitId,
          if (operationId != null && operationId.isNotEmpty)
            'operation_id': operationId,
          if (patientId != null && patientId.isNotEmpty)
            'patient_id': patientId,
          if (patientName != null && patientName.isNotEmpty)
            'patient_name': patientName,
          if (senderName != null && senderName.isNotEmpty)
            'sender_name': senderName,
        });
      } catch (e) {
        debugPrint('Failed to create notification for $target: $e');
      }
    }
  }

  Future<void> markNotificationRead(AppNotification notification) async {
    if (currentUserId == null) return;
    if (notification.isReadBy(currentUserId!)) return;

    final readBy = [...notification.readBy, currentUserId!];
    try {
      final updated = await _pbService.markNotificationRead(notification.id, readBy);
      final idx = _notifications.indexWhere((n) => n.id == notification.id);
      if (idx != -1) {
        _notifications[idx] = updated;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to mark notification as read: $e');
    }
  }

  Future<void> markAllNotificationsRead() async {
    final unread = _notifications
        .where((n) => currentUserId != null && !n.isReadBy(currentUserId!))
        .toList();
    for (final n in unread) {
      await markNotificationRead(n);
    }
  }

  // Operations Management Actions
  Future<Operation> scheduleOperation({
    required String patientId,
    required DateTime dateTime,
    int? graftsExpected,
    int? graftsDone,
    double? totalPrice,
    double? deposit,
    double? remainingAtOperation,
    String? notifyTarget,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'patient': patientId,
        'date_time': dateTime.toUtc().toIso8601String(),
      };
      if (currentUserId != null && currentUserId!.isNotEmpty) {
        body['added_by'] = currentUserId;
      }
      if (graftsExpected != null) body['grafts_expected'] = graftsExpected;
      if (graftsDone != null) body['grafts_done'] = graftsDone;
      if (totalPrice != null) body['total_price'] = totalPrice;
      if (deposit != null) body['deposit'] = deposit;
      if (remainingAtOperation != null) {
        body['remaining_at_operation'] = remainingAtOperation;
      }

      final created = await _pbService.createOperation(body: body);
      final patient = _patients.where((p) => p.id == patientId).firstOrNull;
      final fullOp = created.copyWith(patient: patient);

      _operations.insert(0, fullOp);

      final notifyTargets = <String>[
        AppConstants.userTypeConsultant,
        AppConstants.userTypeReceptionist,
      ];
      if (notifyTarget != null) {
        notifyTargets.add(notifyTarget);
      }

      _notify(
        targets: notifyTargets,
        type: AppConstants.notifTypeOperationScheduled,
        title: 'New Operation Scheduled',
        body:
            'A new operation is booked for ${fullOp.patient?.name ?? "a patient"} on ${_formatOpDateTime(fullOp.dateTime)}.',
        operationId: fullOp.id,
        patientId: fullOp.patientId,
        patientName: fullOp.patient?.name,
      );

      _isLoading = false;
      notifyListeners();
      return fullOp;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to schedule operation: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<Operation> updateOperation(
    String id, {
    String? patientId,
    DateTime? dateTime,
    int? graftsExpected,
    int? graftsDone,
    double? totalPrice,
    double? deposit,
    double? remainingAtOperation,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{};
      if (patientId != null && patientId.isNotEmpty) {
        body['patient'] = patientId;
      }
      if (dateTime != null) {
        body['date_time'] = dateTime.toUtc().toIso8601String();
      }
      if (graftsExpected != null) body['grafts_expected'] = graftsExpected;
      if (graftsDone != null) body['grafts_done'] = graftsDone;
      if (totalPrice != null) body['total_price'] = totalPrice;
      if (deposit != null) body['deposit'] = deposit;
      if (remainingAtOperation != null) {
        body['remaining_at_operation'] = remainingAtOperation;
      }

      final updated = await _pbService.updateOperation(id: id, body: body);
      final patient = _patients
          .where((p) => p.id == (patientId ?? updated.patientId))
          .firstOrNull;
      final fullOp = updated.copyWith(patient: patient);

      final idx = _operations.indexWhere((o) => o.id == id);
      if (idx != -1) {
        _operations[idx] = fullOp;
      } else {
        _operations.insert(0, fullOp);
      }

      _notify(
        targets: const [
          AppConstants.userTypeConsultant,
          AppConstants.userTypeReceptionist,
        ],
        type: AppConstants.notifTypeOperationUpdated,
        title: 'Operation Schedule Updated',
        body:
            'The operation for ${fullOp.patient?.name ?? "a patient"} was updated (${_formatOpDateTime(fullOp.dateTime)}).',
        operationId: fullOp.id,
        patientId: fullOp.patientId,
        patientName: fullOp.patient?.name,
      );

      _isLoading = false;
      notifyListeners();
      return fullOp;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to update operation: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteOperation(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _pbService.deleteOperation(id);
      _operations.removeWhere((o) => o.id == id);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to delete operation: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<Operation> addOperationImages(
    Operation operation,
    List<http.MultipartFile> files,
  ) async {
    if (files.isEmpty) return operation;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _pbService.updateOperation(
        id: operation.id,
        body: const {},
        files: files,
      );
      final fullOp = updated.copyWith(patient: operation.patient);
      _upsertOperation(fullOp);

      _notify(
        targets: const [AppConstants.userTypeManager],
        type: AppConstants.notifTypeOperationImagesAdded,
        title: 'Intra-Operative Images Added',
        body:
            '${fullOp.patient?.name ?? "A patient"}\'s operation now has ${fullOp.intraOpImages.length} intra-operative image(s) recorded.',
        operationId: fullOp.id,
        patientId: fullOp.patientId,
        patientName: fullOp.patient?.name,
      );

      _isLoading = false;
      notifyListeners();
      return fullOp;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to add operation images: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<Operation> removeOperationImage(
    Operation operation,
    String filename,
  ) async {
    if (!operation.intraOpImages.contains(filename)) return operation;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final remaining = List<String>.from(operation.intraOpImages)
        ..remove(filename);
      final updated = await _pbService.updateOperation(
        id: operation.id,
        body: {'intra_op_images': remaining},
      );
      final fullOp = updated.copyWith(patient: operation.patient);
      _upsertOperation(fullOp);

      _isLoading = false;
      notifyListeners();
      return fullOp;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to remove operation image: $e';
      notifyListeners();
      rethrow;
    }
  }

  void _upsertOperation(Operation updatedOp) {
    final idx = _operations.indexWhere((o) => o.id == updatedOp.id);
    if (idx != -1) {
      _operations[idx] = updatedOp;
    } else {
      _operations.insert(0, updatedOp);
    }
  }

  String _formatOpDateTime(DateTime? dt) {
    if (dt == null) return 'an unset date';
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
  }

  void _updateVisitInList(Visit updatedVisit) {
    final idx = _visits.indexWhere((v) => v.id == updatedVisit.id);
    if (idx != -1) {
      _visits[idx] = updatedVisit;
    } else {
      _visits.insert(0, updatedVisit);
    }
  }

  @override
  void dispose() {
    _pbService.unsubscribeFromVisits();
    _pbService.unsubscribeFromPatients();
    _pbService.unsubscribeFromOperations();
    _pbService.unsubscribeFromNotifications();
    _incomingNotifications.close();
    super.dispose();
  }
}
