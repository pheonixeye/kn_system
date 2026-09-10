import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../constants/app_constants.dart';
import '../../models/visit.dart';

class PdfService {
  static Future<Uint8List> generateVisitPdf(Visit visit) async {
    final pdf = pw.Document();
    final patient = visit.patient;
    final nowStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    // Fetch images asynchronously to embed in PDF
    final List<pw.ImageProvider> embeddedImages = [];
    for (final imgName in visit.images) {
      try {
        final url = visit.getImageUrl(imgName);
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          embeddedImages.add(pw.MemoryImage(response.bodyBytes));
        }
      } catch (_) {
        // Skip inaccessible image
      }
    }

    final primaryColor = PdfColor.fromInt(0xFF0E7490);
    final slateColor = PdfColor.fromInt(0xFF334155);
    final lightBgColor = PdfColor.fromInt(0xFFF8FAFC);
    final borderColor = PdfColor.fromInt(0xFFE2E8F0);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      pw.Container(
                        width: 38,
                        height: 38,
                        decoration: pw.BoxDecoration(
                          color: primaryColor,
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            '+',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            AppConstants.appTitle,
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          pw.Text(
                            'Comprehensive Patient Consultation & Clinical Summary',
                            style: pw.TextStyle(fontSize: 9, color: slateColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFFE0F2FE),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Text(
                          'QUEUE #${visit.queueNumber ?? '-'}',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Generated: $nowStr',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(color: borderColor, thickness: 1.5),
              pw.SizedBox(height: 12),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(color: borderColor, thickness: 1),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Confidential Medical Record • ${AppConstants.appTitle}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // 1. Patient Demographics Box
            pw.Container(
              decoration: pw.BoxDecoration(
                color: lightBgColor,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: borderColor),
              ),
              padding: const pw.EdgeInsets.all(12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PATIENT DEMOGRAPHICS',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      _buildInfoCol(
                        'Patient Name',
                        patient?.name ?? 'Unknown',
                        flex: 3,
                      ),
                      _buildInfoCol('Phone', patient?.phone ?? '-', flex: 2),
                      _buildInfoCol(
                        'Age / Gender',
                        '${patient?.calculatedAge != null ? "${patient!.calculatedAge} yrs" : (patient?.dob ?? "-")} • ${patient?.gender ?? "-"}',
                        flex: 2,
                      ),
                      _buildInfoCol(
                        'National ID',
                        patient?.nationalId ?? '-',
                        flex: 2,
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      _buildInfoCol(
                        'Visit Date',
                        visit.visitDate ?? '-',
                        flex: 2,
                      ),
                      _buildInfoCol(
                        'Visit Status',
                        AppConstants.formatStatus(visit.status),
                        flex: 2,
                      ),
                      _buildInfoCol(
                        'Resident Doctor',
                        visit.residentName?.isNotEmpty == true
                            ? visit.residentName!
                            : '-',
                        flex: 2,
                      ),
                      _buildInfoCol(
                        'Consultant',
                        visit.consultantName?.isNotEmpty == true
                            ? visit.consultantName!
                            : '-',
                        flex: 2,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // 2. Chief Complaint
            if (visit.chiefComplaint != null &&
                visit.chiefComplaint!.isNotEmpty) ...[
              _buildSectionHeader('CHIEF COMPLAINT', primaryColor),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Text(
                  visit.chiefComplaint!,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 14),
            ],

            // 3. Vital Signs Grid
            if (!visit.vitalSigns.isEmpty) ...[
              _buildSectionHeader(
                'VITAL SIGNS (RESIDENT INTAKE)',
                primaryColor,
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildVitalItem(
                      'Blood Pressure',
                      visit.vitalSigns.bloodPressure ?? '-',
                      'mmHg',
                    ),
                    _buildVitalItem(
                      'Heart Rate',
                      visit.vitalSigns.heartRate ?? '-',
                      'bpm',
                    ),
                    _buildVitalItem(
                      'Temperature',
                      visit.vitalSigns.temperature ?? '-',
                      '°C',
                    ),
                    _buildVitalItem('SpO2', visit.vitalSigns.spo2 ?? '-', '%'),
                    _buildVitalItem(
                      'Weight',
                      visit.vitalSigns.weight ?? '-',
                      'kg',
                    ),
                    _buildVitalItem(
                      'Height',
                      visit.vitalSigns.height ?? '-',
                      'cm',
                    ),
                    _buildVitalItem(
                      'BMI',
                      visit.vitalSigns.bmi != null
                          ? visit.vitalSigns.bmi!.toStringAsFixed(1)
                          : '-',
                      'kg/m²',
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
            ],

            // 4. Clinical History
            _buildSectionHeader('MEDICAL & SURGICAL HISTORY', primaryColor),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: borderColor),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildSubField(
                    'History of Present Illness (HPI):',
                    visit.historyPresentIllness,
                  ),
                  pw.SizedBox(height: 6),
                  _buildSubField(
                    'Past Medical & Surgical History:',
                    visit.pastMedicalHistory,
                  ),
                  pw.SizedBox(height: 6),
                  _buildSubField(
                    'Drug History & Allergies:',
                    visit.drugHistoryAllergies,
                  ),
                  pw.SizedBox(height: 6),
                  _buildSubField(
                    'Physical Examination & Initial Assessment:',
                    visit.examinationNotes ?? visit.residentAssessment,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // 5. Consultant Assessment & Treatment Plan
            _buildSectionHeader('CONSULTANT ASSESSMENT & PLAN', primaryColor),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF0FDF4), // soft green tint
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColor.fromInt(0xFFBBF7D0)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildSubField(
                    'Final Diagnosis:',
                    visit.consultantDiagnosis?.isNotEmpty == true
                        ? visit.consultantDiagnosis
                        : 'Pending review',
                    boldValue: true,
                  ),
                  pw.SizedBox(height: 6),
                  _buildSubField(
                    'Management / Treatment Plan:',
                    visit.consultantPlan,
                  ),
                  pw.SizedBox(height: 6),
                  _buildSubField(
                    'Prescription / Medications:',
                    visit.consultantPrescription,
                  ),
                  if (visit.consultantNotes != null &&
                      visit.consultantNotes!.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    _buildSubField(
                      'Additional Clinical Notes:',
                      visit.consultantNotes,
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // 6. Embedded Clinical Images (if any)
            if (embeddedImages.isNotEmpty) ...[
              _buildSectionHeader(
                'CLINICAL IMAGES & INVESTIGATIONS (${embeddedImages.length})',
                primaryColor,
              ),
              pw.Wrap(
                spacing: 10,
                runSpacing: 10,
                children: embeddedImages.map((imgProvider) {
                  return pw.Container(
                    width: 150,
                    height: 120,
                    decoration: pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: borderColor),
                    ),
                    child: pw.ClipRRect(
                      horizontalRadius: 6,
                      verticalRadius: 6,
                      child: pw.Image(imgProvider, fit: pw.BoxFit.cover),
                    ),
                  );
                }).toList(),
              ),
              pw.SizedBox(height: 16),
            ],

            // 7. Signature Block
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Resident Doctor Signature:',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 25),
                    pw.Container(width: 140, height: 1, color: borderColor),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      visit.residentName?.isNotEmpty == true
                          ? 'Dr. ${visit.residentName}'
                          : 'Resident in Charge',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Consultant Signature & Stamp:',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 25),
                    pw.Container(width: 140, height: 1, color: borderColor),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      visit.consultantName?.isNotEmpty == true
                          ? 'Dr. ${visit.consultantName}'
                          : 'Consultant Physician',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> printVisitReport(Visit visit) async {
    final pdfBytes = await generateVisitPdf(visit);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Clinic_Report_${visit.patient?.name ?? "Patient"}_${visit.id}.pdf',
    );
  }

  static pw.Widget _buildSectionHeader(String title, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static pw.Widget _buildInfoCol(String label, String value, {int flex = 1}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildVitalItem(String label, String value, String unit) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          unit,
          style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey500),
        ),
      ],
    );
  }

  static pw.Widget _buildSubField(
    String label,
    String? value, {
    bool boldValue = false,
  }) {
    final displayVal = (value != null && value.trim().isNotEmpty)
        ? value.trim()
        : 'None recorded';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          displayVal,
          style: pw.TextStyle(
            fontSize: 9,
            color: (value != null && value.trim().isNotEmpty)
                ? PdfColors.black
                : PdfColors.grey600,
            fontWeight: boldValue ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
