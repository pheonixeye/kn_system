import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/patient.dart';
import '../../models/visit.dart';
import '../../providers/clinic_provider.dart';
import '../../widgets/custom_badge.dart';
import '../../widgets/stat_card.dart';

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
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
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
      );

      if (_autoCheckIn) {
        await provider.checkInPatient(
          patient: patient,
          chiefComplaint: _complaintController.text.trim().isNotEmpty
              ? _complaintController.text.trim()
              : null,
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
                  const SnackBar(
                    backgroundColor: AppTheme.success,
                    content: Text('Patient added to queue!'),
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
                                    child: const Icon(
                                      Icons.person_add,
                                      color: AppTheme.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
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
                                    const Expanded(
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
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
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
                                    'Active Queue (${visits.length})',
                                    Icons.queue_music_outlined,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildTabButton(
                                    1,
                                    'All Patients (${patients.length})',
                                    Icons.folder_shared_outlined,
                                  ),
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
                                  ? _buildQueueTable(provider, visits)
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

  Widget _buildQueueTable(ClinicProvider provider, List<Visit> visits) {
    final query = _searchController.text.toLowerCase().trim();
    final filtered = visits.where((v) {
      if (query.isEmpty) return true;
      final name = v.patient?.name.toLowerCase() ?? '';
      final phone = v.patient?.phone.toLowerCase() ?? '';
      return name.contains(query) || phone.contains(query);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 48,
              color: AppTheme.slate400,
            ),
            const SizedBox(height: 8),
            Text(
              query.isEmpty
                  ? 'No active visits in the queue.'
                  : 'No visits match your search.',
              style: const TextStyle(color: AppTheme.slate500, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final visit = filtered[index];
        final patient = visit.patient;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          leading: CircleAvatar(
            backgroundColor: AppTheme.primaryLight,
            child: Text(
              '#${visit.queueNumber ?? (index + 1)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: AppTheme.primary,
              ),
            ),
          ),
          title: Row(
            children: [
              Text(
                patient?.name ?? 'Unknown Patient',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              if (patient?.gender != null)
                Text(
                  '(${patient!.gender})',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.slate400,
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                'Phone: ${patient?.phone ?? "-"} • DOB: ${patient?.dob ?? "-"} • Date: ${visit.visitDate ?? "-"}',
                style: const TextStyle(fontSize: 12, color: AppTheme.slate500),
              ),
              if (visit.chiefComplaint != null &&
                  visit.chiefComplaint!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Complaint: ${visit.chiefComplaint}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.slate700,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          trailing: CustomBadge.fromStatus(visit.status),
        );
      },
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
      return const Center(
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
              style: const TextStyle(
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
            style: const TextStyle(fontSize: 12, color: AppTheme.slate500),
          ),
          trailing: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: AppTheme.primary,
            ),
            onPressed: () => _showQuickCheckInDialog(patient),
            icon: const Icon(Icons.add, size: 14),
            label: const Text('New Visit', style: TextStyle(fontSize: 12)),
          ),
        );
      },
    );
  }
}
