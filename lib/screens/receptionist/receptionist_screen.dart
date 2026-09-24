import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/patient.dart';
import '../../providers/clinic_provider.dart';
import '../../widgets/active_queue_view.dart';
import '../../widgets/consultant_case_report_dialog.dart';
import '../../widgets/patient_operations_dialog.dart';
import '../../widgets/patient_visits_dialog.dart';
import '../../widgets/stat_card.dart';
import 'active_queue_screen.dart';

class ReceptionistScreen extends StatefulWidget {
  const ReceptionistScreen({super.key});

  @override
  State<ReceptionistScreen> createState() => _ReceptionistScreenState();
}

class _ReceptionistScreenState extends State<ReceptionistScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _complaintController = TextEditingController();
  final _searchController = TextEditingController();

  String _gender = 'Male';
  bool _autoCheckIn = true;
  int _selectedTab = 0; // 0: Active Queue, 1: Patient Directory

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _nationalIdController.dispose();
    _complaintController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _clearForm() {
    _nameController.clear();
    _phoneController.clear();
    _dobController.clear();
    _nationalIdController.clear();
    _complaintController.clear();
    setState(() {
      _gender = 'Male';
      _autoCheckIn = true;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1995, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.primary,
              onPrimary: AppTheme.onPrimary,
              onSurface: AppTheme.secondary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submitPatient() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ClinicProvider>();
    final currentUserId = provider.currentUserId;

    try {
      final patient = await provider.registerPatient(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        dob: _dobController.text.trim().isNotEmpty
            ? _dobController.text.trim()
            : null,
        gender: _gender,
        nationalId: _nationalIdController.text.trim().isNotEmpty
            ? _nationalIdController.text.trim()
            : null,
        addedBy: currentUserId,
      );

      if (_autoCheckIn) {
        await provider.checkInPatient(
          patient: patient,
          chiefComplaint: _complaintController.text.trim().isNotEmpty
              ? _complaintController.text.trim()
              : null,
          addedBy: currentUserId,
        );
      }

      _clearForm();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Text(
              _autoCheckIn
                  ? 'Patient registered & checked into queue successfully!'
                  : 'Patient registered in directory successfully!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text('Error registering patient: $e'),
          ),
        );
      }
    }
  }

  void _showEditPatientDialog(Patient patient) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: patient.name);
    final phoneCtrl = TextEditingController(text: patient.phone);
    final dobCtrl = TextEditingController(text: patient.dob ?? '');
    final nationalIdCtrl = TextEditingController(
      text: patient.nationalId ?? '',
    );
    final notesCtrl = TextEditingController(text: patient.notes ?? '');
    String gender = patient.gender ?? 'Male';
    bool saving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          Future<void> pickDate() async {
            final now = DateTime.now();
            final initial =
                DateTime.tryParse(dobCtrl.text) ?? DateTime(1995, 1, 1);
            final picked = await showDatePicker(
              context: dialogCtx,
              initialDate: initial.month > now.month && initial.year == now.year
                  ? DateTime(now.year - 1, initial.month, initial.day)
                  : initial,
              firstDate: DateTime(1900),
              lastDate: now,
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: AppTheme.primary,
                      onPrimary: AppTheme.onPrimary,
                      onSurface: AppTheme.secondary,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setDialogState(() {
                dobCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
              });
            }
          }

          Future<void> save() async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            setDialogState(() => saving = true);
            try {
              await context.read<ClinicProvider>().updatePatient(
                patient.id,
                name: nameCtrl.text,
                phone: phoneCtrl.text,
                dob: dobCtrl.text,
                gender: gender,
                nationalId: nationalIdCtrl.text,
                notes: notesCtrl.text,
              );
              if (dialogCtx.mounted) {
                Navigator.of(dialogCtx).pop();
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppTheme.success,
                    content: const Text('Patient info updated successfully!'),
                  ),
                );
              }
            } catch (e) {
              setDialogState(() => saving = false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppTheme.danger,
                    content: Text('Error updating patient: $e'),
                  ),
                );
              }
            }
          }

          Widget label(String text) => Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          );

          return AlertDialog(
            title: Text('Edit Patient'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 540),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      label('Full Name *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Johnathan Doe',
                          isDense: true,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Patient name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      label('Mobile Phone Number *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: 'e.g. +1 555-0199',
                          isDense: true,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Mobile phone number is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                label('Date of Birth'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: dobCtrl,
                                  readOnly: true,
                                  onTap: pickDate,
                                  decoration: const InputDecoration(
                                    hintText: 'YYYY-MM-DD',
                                    isDense: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                label('Gender'),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: gender,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 12,
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Male',
                                      child: Text('Male'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Female',
                                      child: Text('Female'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDialogState(() => gender = val);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      label('National ID / Passport (Optional)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nationalIdCtrl,
                        decoration: const InputDecoration(
                          hintText: 'e.g. ID-9823472',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      label('Notes (Optional)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: notesCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Allergies, conditions, remarks...',
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: saving ? null : save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.onPrimary,
                ),
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showQuickCheckInDialog(Patient patient) {
    final complaintCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Check In: ${patient.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phone: ${patient.phone} | DOB: ${patient.dob ?? "-"}'),
            const SizedBox(height: 14),
            TextField(
              controller: complaintCtrl,
              decoration: const InputDecoration(
                labelText: 'Chief Complaint / Reason for Visit',
                hintText: 'e.g. Fever, Sore throat, Follow-up...',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<ClinicProvider>().checkInPatient(
                patient: patient,
                chiefComplaint: complaintCtrl.text.trim().isNotEmpty
                    ? complaintCtrl.text.trim()
                    : null,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppTheme.success,
                    content: const Text('Patient added to queue!'),
                  ),
                );
              }
            },
            child: const Text('Confirm Check In'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClinicProvider>();
    final patients = provider.patients;
    final visits = provider.visits;

    final waitingCount = visits
        .where((v) => v.status == AppConstants.statusWaitingResident)
        .length;
    final inProgressCount = visits
        .where(
          (v) =>
              v.status == AppConstants.statusWithResident ||
              v.status == AppConstants.statusWaitingConsultant ||
              v.status == AppConstants.statusWithConsultant,
        )
        .length;
    final completedCount = visits
        .where((v) => v.status == AppConstants.statusCompleted)
        .length;
    final todayVisitsCount = provider.todayVisits.length;

    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Top Stats Banner
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(
                    width: 220,
                    child: StatCard(
                      title: 'Total Patients',
                      value: '${patients.length}',
                      icon: Icons.people_alt_outlined,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 220,
                    child: StatCard(
                      title: 'Waiting for Doctor',
                      value: '$waitingCount',
                      icon: Icons.hourglass_top_rounded,
                      color: AppTheme.warning,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 220,
                    child: StatCard(
                      title: 'Visits in Progress',
                      value: '$inProgressCount',
                      icon: Icons.pending_actions_outlined,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 220,
                    child: StatCard(
                      title: 'Completed Today',
                      value: '$completedCount',
                      icon: Icons.check_circle_outline,
                      color: AppTheme.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Main Split Panel: Intake Form (Left) & Live Queue / Patients (Right)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Form: Patient Registration & Check-in
                  SizedBox(
                    width: 420,
                    child: Card(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.person_add,
                                      color: AppTheme.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'New Patient Registration',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.secondary,
                                          ),
                                        ),
                                        Text(
                                          'Enter personal info & check-in to queue',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.slate500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 16),

                              // Full Name
                              const Text(
                                'Full Name *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. Johnathan Doe',
                                  prefixIcon: Icon(
                                    Icons.badge_outlined,
                                    size: 18,
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Patient name is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // Phone Number
                              const Text(
                                'Mobile Phone Number *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. +1 555-0199',
                                  prefixIcon: Icon(
                                    Icons.phone_outlined,
                                    size: 18,
                                  ),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Mobile phone number is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // DOB & Gender Row
                              Row(
                                children: [
                                  // DOB
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Date of Birth',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: _dobController,
                                          readOnly: true,
                                          onTap: _selectDate,
                                          decoration: const InputDecoration(
                                            hintText: 'YYYY-MM-DD',
                                            prefixIcon: Icon(
                                              Icons.calendar_today_outlined,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Gender
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Gender',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          initialValue: _gender,
                                          decoration: const InputDecoration(
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 12,
                                                ),
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'Male',
                                              child: Text('Male'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'Female',
                                              child: Text('Female'),
                                            ),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() => _gender = val);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // National ID
                              const Text(
                                'National ID / Passport (Optional)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _nationalIdController,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. ID-9823472',
                                  prefixIcon: Icon(
                                    Icons.credit_card_outlined,
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Chief Complaint / Reason for visit
                              const Text(
                                'Chief Complaint / Reason for Visit',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _complaintController,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Brief summary of patient complaint...',
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Auto Check-in Toggle
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.slate50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.slate200),
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: _autoCheckIn,
                                      activeColor: AppTheme.primary,
                                      onChanged: (val) => setState(
                                        () => _autoCheckIn = val ?? true,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Auto Check-In into Live Queue',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            'Assigns a queue number immediately',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: AppTheme.slate500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),

                              // Submit Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _clearForm,
                                      child: const Text('Reset'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed: provider.isLoading
                                          ? null
                                          : _submitPatient,
                                      icon: provider.isLoading
                                          ? SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppTheme.onPrimary,
                                              ),
                                            )
                                          : const Icon(Icons.check, size: 18),
                                      label: const Text('Register & Save'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Right Panel: Active Queue & Patient Directory Tabs
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Tabs & Search
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildTabButton(
                                    0,
                                    'Active Queue ($todayVisitsCount)',
                                    Icons.queue_music_outlined,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildTabButton(
                                    1,
                                    'All Patients (${patients.length})',
                                    Icons.folder_shared_outlined,
                                  ),
                                  if (_selectedTab == 0) ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      tooltip:
                                          'Open Active Queue in Full Screen',
                                      icon: Icon(
                                        Icons.open_in_full_rounded,
                                        size: 18,
                                        color: AppTheme.primary,
                                      ),
                                      onPressed: () =>
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const ActiveQueueScreen(),
                                              fullscreenDialog: true,
                                            ),
                                          ),
                                    ),
                                  ],
                                  const SizedBox(width: 16),
                                  SizedBox(
                                    width: 200,
                                    height: 38,
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        hintText: 'Search patients...',
                                        prefixIcon: const Icon(
                                          Icons.search,
                                          size: 18,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                        suffixIcon:
                                            _searchController.text.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(
                                                  Icons.clear,
                                                  size: 16,
                                                ),
                                                onPressed: () {
                                                  _searchController.clear();
                                                  setState(() {});
                                                },
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),

                            // Tab Body
                            Expanded(
                              child: _selectedTab == 0
                                  ? ActiveQueueView(
                                      searchQuery: _searchController.text,
                                    )
                                  : _buildPatientsTable(provider, patients),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String title, IconData icon) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.slate200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppTheme.primary : AppTheme.slate500,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.primary : AppTheme.slate700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientsTable(ClinicProvider provider, List<Patient> patients) {
    final query = _searchController.text.toLowerCase().trim();
    final filtered = patients.where((p) {
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query) ||
          p.phone.toLowerCase().contains(query) ||
          (p.nationalId?.toLowerCase().contains(query) ?? false);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No patients found.',
          style: TextStyle(color: AppTheme.slate500),
        ),
      );
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final patient = filtered[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          leading: CircleAvatar(
            backgroundColor: AppTheme.slate100,
            child: Text(
              patient.name.isNotEmpty ? patient.name[0].toUpperCase() : 'P',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.slate700,
              ),
            ),
          ),
          title: Text(
            patient.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            'Phone: ${patient.phone} • DOB: ${patient.dob ?? "-"} • Gender: ${patient.gender ?? "-"}',
            style: TextStyle(fontSize: 12, color: AppTheme.slate500),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Previous Visits',
                icon: Icon(
                  Icons.history_rounded,
                  size: 18,
                  color: AppTheme.accent,
                ),
                onPressed: () => PatientVisitsDialog.show(
                  context,
                  patientId: patient.id,
                  patientName: patient.name,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Patient Operations',
                icon: Icon(
                  Icons.local_hospital_outlined,
                  size: 18,
                  color: AppTheme.secondary,
                ),
                onPressed: () => PatientOperationsDialog.show(
                  context,
                  patientId: patient.id,
                  patientName: patient.name,
                ),
              ),
              if (provider.currentUserType ==
                  AppConstants.userTypeConsultant) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Consultant Case Report',
                  icon: Icon(
                    Icons.description_outlined,
                    size: 18,
                    color: AppTheme.purple,
                  ),
                  onPressed: () => ConsultantCaseReportDialog.show(
                    context,
                    patientId: patient.id,
                    patientName: patient.name,
                  ),
                ),
              ],
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Edit Patient',
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppTheme.primary,
                ),
                onPressed: () => _showEditPatientDialog(patient),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  backgroundColor: AppTheme.primary,
                ),
                onPressed: () => _showQuickCheckInDialog(patient),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('New Visit', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }
}
