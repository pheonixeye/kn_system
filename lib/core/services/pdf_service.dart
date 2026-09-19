import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../constants/app_constants.dart';
import '../utils/text_utils.dart';
import '../../models/operation.dart';
import '../../models/visit.dart';

class PdfService {
  // ========================= Branded Header / Footer =========================
  static pw.MemoryImage? _cachedHeader;
  static pw.MemoryImage? _cachedFooter;

  static Future<pw.MemoryImage> _loadHeader() async {
    if (_cachedHeader == null) {
      final data = await rootBundle.load('assets/images/header.png');
      _cachedHeader = pw.MemoryImage(data.buffer.asUint8List());
    }
    return _cachedHeader!;
  }

  static Future<pw.MemoryImage> _loadFooter() async {
    if (_cachedFooter == null) {
      final data = await rootBundle.load('assets/images/footer.png');
      _cachedFooter = pw.MemoryImage(data.buffer.asUint8List());
    }
    return _cachedFooter!;
  }

  static const double _pageMarginPt = 32;
  static const double _headerAspectRatio = 4.17;
  static const double _footerAspectRatio = 6.1;

  static pw.Widget _brandHeader(pw.MemoryImage image, pw.Context context) {
    final width = context.page.pageFormat.width - (_pageMarginPt * 2);
    return pw.SizedBox(
      height: width / _headerAspectRatio,
      child: pw.Image(image, fit: pw.BoxFit.contain, width: width),
    );
  }

  static pw.Widget _brandFooter(pw.MemoryImage image, pw.Context context) {
    final width = context.page.pageFormat.width - (_pageMarginPt * 2);
    return pw.SizedBox(
      height: width / _footerAspectRatio,
      child: pw.Stack(
        children: [
          pw.Image(image, fit: pw.BoxFit.contain, width: width),
          pw.Align(
            alignment: pw.Alignment.bottomRight,
            child: pw.Text('Powered by ProKliniK-One'),
          ),
        ],
      ),
    );
  }

  // ========================= Cairo Fonts (Google Fonts) =========================
  static Future<pw.Font>? _cairoRegularFuture;
  static Future<pw.Font>? _cairoBoldFuture;
  static Future<pw.ThemeData>? _cairoThemeFuture;

  /// Loads the Cairo font family from Google Fonts (via the printing package's
  /// [PdfGoogleFonts]) and applies it to the whole PDF document.
  static Future<pw.ThemeData> _cairoTheme() {
    return _cairoThemeFuture ??= () async {
      final regular = await (_cairoRegularFuture ??=
          PdfGoogleFonts.cairoRegular());
      final bold = await (_cairoBoldFuture ??= PdfGoogleFonts.cairoBold());
      return pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        italic: regular,
        boldItalic: bold,
      );
    }();
  }

  // ========================= Operation Financial PDF =========================
  /// Printed from the Management tab. Contains only the financial summary -
  /// no graft counts and no intra-operative images.
  static Future<Uint8List> generateOperationFinancialPdf(Operation op) async {
    final pdf = pw.Document(theme: await _cairoTheme());
    final headerImg = await _loadHeader();
    final footerImg = await _loadFooter();

    final primaryColor = PdfColor.fromInt(0xFF0E7490);
    final greenTint = PdfColor.fromInt(0xFFF0FDF4);
    final greenBorder = PdfColor.fromInt(0xFFBBF7D0);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return _brandHeader(headerImg, context);
        },
        footer: (pw.Context context) {
          return _brandFooter(footerImg, context);
        },
        build: (pw.Context context) {
          return [
            // 1. Patient Demographics
            _operationDemographics(op),
            pw.SizedBox(height: 14),

            // 2. Financial Summary
            _buildSectionHeader('FINANCIAL SUMMARY (EGP)', primaryColor),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: greenTint,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: greenBorder),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildFinanceItem(
                    'Total Operation Price',
                    op.totalPrice != null ? _money(op.totalPrice!) : '--',
                    PdfColor.fromInt(0xFF334155),
                  ),
                  _buildFinanceItem(
                    'Deposit Paid',
                    op.deposit != null ? _money(op.deposit!) : '--',
                    PdfColor.fromInt(0xFF15803D),
                  ),
                  _buildFinanceItem(
                    'Remaining at Operation',
                    op.remainingAtOperation != null
                        ? _money(op.remainingAtOperation!)
                        : '--',
                    PdfColor.fromInt(0xFFB45309),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // 3. Notes
            _buildSectionHeader('NOTES', primaryColor),
            _operationNotes(),
            pw.SizedBox(height: 20),

            // 4. Signatures
            _operationSignatureRow(op.patient?.name),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ========================= Operation Clinical PDF =========================
  /// Printed from the Operation Details dialog. Contains graft counts and the
  /// intra-operative images - no financial information.
  static Future<Uint8List> generateOperationClinicalPdf(Operation op) async {
    final pdf = pw.Document(theme: await _cairoTheme());
    final headerImg = await _loadHeader();
    final footerImg = await _loadFooter();

    final List<pw.ImageProvider> embeddedImages = [];
    for (final imgName in op.intraOpImages) {
      try {
        final url = op.getImageUrl(imgName);
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
    final borderColor = PdfColor.fromInt(0xFFE2E8F0);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return _brandHeader(headerImg, context);
        },
        footer: (pw.Context context) {
          return _brandFooter(footerImg, context);
        },
        build: (pw.Context context) {
          return [
            // 1. Patient Demographics (with graft counts)
            _operationDemographics(op, includeGrafts: true),
            pw.SizedBox(height: 14),

            // 2. Operation Highlights
            pw.Row(
              children: [
                _buildHighlightCard(
                  'EXPECTED GRAFTS',
                  '${op.graftsExpected ?? 0}',
                  PdfColor.fromInt(0xFF0369A1),
                  PdfColor.fromInt(0xFFE0F2FE),
                ),
                pw.SizedBox(width: 12),
                _buildHighlightCard(
                  'GRAFTS DONE',
                  '${op.graftsDone ?? 0}',
                  PdfColor.fromInt(0xFF15803D),
                  PdfColor.fromInt(0xFFDCFCE7),
                ),
                pw.SizedBox(width: 12),
                _buildHighlightCard(
                  'IMAGES ON RECORD',
                  '${op.intraOpImages.length}',
                  PdfColor.fromInt(0xFF6D28D9),
                  PdfColor.fromInt(0xFFEDE9FE),
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // 3. Operative Notes
            if (op.operativeNotes != null &&
                op.operativeNotes!.trim().isNotEmpty) ...[
              _buildSectionHeader('OPERATIVE NOTES', primaryColor),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Text(
                  op.operativeNotes!.trim(),
                  textDirection: containsArabic(op.operativeNotes!.trim())
                      ? pw.TextDirection.rtl
                      : pw.TextDirection.ltr,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 14),
            ],

            // 4. Intra-op Images
            if (embeddedImages.isNotEmpty) ...[
              _buildSectionHeader(
                'INTRA-OPERATIVE IMAGES (${embeddedImages.length})',
                primaryColor,
              ),
              pw.Wrap(
                spacing: 10,
                runSpacing: 10,
                children: embeddedImages.map((imgProvider) {
                  return pw.Container(
                    width: 160,
                    height: 130,
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

            // 5. Notes
            _buildSectionHeader('NOTES', primaryColor),
            _operationNotes(),
            pw.SizedBox(height: 20),

            // 6. Signatures
            _operationSignatureRow(op.patient?.name),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _operationDemographics(
    Operation op, {
    bool includeGrafts = false,
  }) {
    final patient = op.patient;
    final primaryColor = PdfColor.fromInt(0xFF0E7490);
    final lightBgColor = PdfColor.fromInt(0xFFF8FAFC);
    final borderColor = PdfColor.fromInt(0xFFE2E8F0);

    return pw.Container(
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
                rightToLeft: containsArabic(patient?.name ?? ''),
              ),
              _buildInfoCol('Phone', patient?.phone ?? '-', flex: 2),
              _buildInfoCol(
                'Age / Gender',
                '${patient?.calculatedAge != null ? "${patient!.calculatedAge} yrs" : (patient?.dob ?? "-")} • ${patient?.gender ?? "-"}',
                flex: 2,
              ),
              _buildInfoCol('National ID', patient?.nationalId ?? '-', flex: 2),
            ],
          ),
          pw.SizedBox(height: 6),
          if (includeGrafts)
            pw.Row(
              children: [
                _buildInfoCol(
                  'Operation Date & Time',
                  op.dateTime != null
                      ? DateFormat(
                          'EEEE, dd MMMM yyyy • hh:mm a',
                        ).format(op.dateTime!)
                      : '-',
                  flex: 4,
                ),
                _buildInfoCol(
                  'Grafts Expected',
                  op.graftsExpected != null
                      ? op.graftsExpected.toString()
                      : '0',
                  flex: 2,
                ),
                _buildInfoCol(
                  'Grafts Done',
                  op.graftsDone != null ? op.graftsDone.toString() : '0',
                  flex: 2,
                ),
              ],
            )
          else
            pw.Row(
              children: [
                _buildInfoCol(
                  'Operation Date & Time',
                  op.dateTime != null
                      ? DateFormat(
                          'EEEE, dd MMMM yyyy • hh:mm a',
                        ).format(op.dateTime!)
                      : '-',
                  flex: 3,
                ),
              ],
            ),
        ],
      ),
    );
  }

  static pw.Widget _operationNotes() {
    final borderColor = PdfColor.fromInt(0xFFE2E8F0);
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: borderColor),
      ),
      child: pw.Text(
        'Please bring this document on the day of the operation. '
        'Confirm the scheduled time with the clinic 48 hours beforehand.',
        style: const pw.TextStyle(fontSize: 10),
      ),
    );
  }

  static pw.Widget _operationSignatureRow(String? patientName) {
    final borderColor = PdfColor.fromInt(0xFFE2E8F0);
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Patient / Guardian Signature:',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 25),
            pw.Container(width: 150, height: 1, color: borderColor),
            pw.SizedBox(height: 4),
            pw.Text(
              patientName ?? 'Patient',
              textDirection: containsArabic(patientName ?? '')
                  ? pw.TextDirection.rtl
                  : pw.TextDirection.ltr,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Clinic Management / Doctor Stamp:',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 25),
            pw.Container(width: 150, height: 1, color: borderColor),
            pw.SizedBox(height: 4),
            pw.Text(
              AppConstants.appTitle,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  static String _money(double value) {
    return '${NumberFormat.currency(symbol: '', decimalDigits: 0).format(value)} EGP';
  }

  static pw.Widget _buildHighlightCard(
    String label,
    String value,
    PdfColor textColor,
    PdfColor bgColor,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: textColor,
                letterSpacing: 0.4,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildFinanceItem(
    String label,
    String value,
    PdfColor color,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  static Future<void> printOperationFinancialReport(Operation op) async {
    final pdfBytes = await generateOperationFinancialPdf(op);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Operation_Financial_${op.patient?.name ?? "Patient"}_${op.id}.pdf',
    );
  }

  static Future<void> printOperationClinicalReport(Operation op) async {
    final pdfBytes = await generateOperationClinicalPdf(op);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Operation_Clinical_${op.patient?.name ?? "Patient"}_${op.id}.pdf',
    );
  }

  // ========================= Visit PDF =========================
  static Future<Uint8List> generateVisitPdf(Visit visit) async {
    final pdf = pw.Document(theme: await _cairoTheme());
    final patient = visit.patient;
    final headerImg = await _loadHeader();
    final footerImg = await _loadFooter();

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
    final lightBgColor = PdfColor.fromInt(0xFFF8FAFC);
    final borderColor = PdfColor.fromInt(0xFFE2E8F0);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return _brandHeader(headerImg, context);
        },
        footer: (pw.Context context) {
          return _brandFooter(footerImg, context);
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
                        rightToLeft: containsArabic(patient?.name ?? ''),
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

  // ========================= Prescription PDF =========================
  static Future<Uint8List> generatePrescriptionPdf(Visit visit) async {
    final pdf = pw.Document(theme: await _cairoTheme());
    final patient = visit.patient;
    final nowStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    final headerImg = await _loadHeader();
    final footerImg = await _loadFooter();

    // Fetch the attached prescription images to embed in the PDF.
    final List<pw.ImageProvider> embeddedImages = [];
    for (final imgName in visit.prescriptionImages) {
      try {
        final url = visit.getImageUrl(imgName);
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          embeddedImages.add(pw.MemoryImage(response.bodyBytes));
        }
      } catch (_) {
        // Skip inaccessible image
      }
    }

    final primaryColor = PdfColor.fromInt(0xFF0B6E4F);
    final borderColor = PdfColor.fromInt(0xFFE2E8F0);
    final lightBgColor = PdfColor.fromInt(0xFFF8FAFC);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return _brandHeader(headerImg, context);
        },
        footer: (pw.Context context) {
          return _brandFooter(footerImg, context);
        },
        build: (pw.Context context) {
          return [
            // Rx header strip
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: lightBgColor,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: borderColor),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'MEDICAL PRESCRIPTION',
                    style: pw.TextStyle(
                      fontSize: 13,
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
                        rightToLeft: containsArabic(patient?.name ?? ''),
                      ),
                      _buildInfoCol('Phone', patient?.phone ?? '-', flex: 2),
                      _buildInfoCol(
                        'Age / Gender',
                        '${patient?.calculatedAge != null ? "${patient!.calculatedAge} yrs" : (patient?.dob ?? "-")} • ${patient?.gender ?? "-"}',
                        flex: 2,
                      ),
                      _buildInfoCol(
                        'Visit Date',
                        visit.visitDate ?? '-',
                        flex: 2,
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      _buildInfoCol(
                        'Queue Number',
                        visit.queueNumber != null
                            ? '#${visit.queueNumber}'
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
                      _buildInfoCol('Issued', nowStr, flex: 2),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Diagnosis
            _buildSectionHeader('DIAGNOSIS', primaryColor),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: borderColor),
              ),
              child: pw.Text(
                (visit.consultantDiagnosis?.isNotEmpty == true)
                    ? visit.consultantDiagnosis!
                    : 'None recorded',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 14),

            // Treatment plan
            // _buildSectionHeader('MANAGEMENT / TREATMENT PLAN', primaryColor),
            // pw.Container(
            //   width: double.infinity,
            //   padding: const pw.EdgeInsets.all(10),
            //   decoration: pw.BoxDecoration(
            //     color: PdfColors.white,
            //     borderRadius: pw.BorderRadius.circular(6),
            //     border: pw.Border.all(color: borderColor),
            //   ),
            //   child: pw.Text(
            //     (visit.consultantPlan != null &&
            //             visit.consultantPlan!.trim().isNotEmpty)
            //         ? visit.consultantPlan!
            //         : 'None recorded',
            //     style: const pw.TextStyle(fontSize: 10),
            //   ),
            // ),
            // pw.SizedBox(height: 14),

            // Prescription / Medications
            _buildSectionHeader('PRESCRIPTION / MEDICATIONS', primaryColor),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF0FDF4),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColor.fromInt(0xFFBBF7D0)),
              ),
              child: pw.Text(
                (visit.consultantPrescription != null &&
                        visit.consultantPrescription!.trim().isNotEmpty)
                    ? visit.consultantPrescription!
                    : 'See attached prescription image',
                style: pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 14),

            // Attached prescription images note (printed full-size on next pages)
            if (embeddedImages.isNotEmpty) ...[
              _buildSectionHeader(
                'ATTACHED PRESCRIPTION IMAGE(S) (${embeddedImages.length})',
                primaryColor,
              ),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: lightBgColor,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Text(
                  embeddedImages.length == 1
                      ? 'The attached prescription image is printed full-size on the following page.'
                      : 'The ${embeddedImages.length} attached prescription images are printed full-size on the following pages.',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 14),
            ],

            // Clinical notes
            if (visit.consultantNotes != null &&
                visit.consultantNotes!.trim().isNotEmpty) ...[
              _buildSectionHeader('CLINICAL NOTES', primaryColor),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderColor),
                ),
                child: pw.Text(
                  visit.consultantNotes!,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 14),
            ],

            // Signature block
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Patient / Guardian Signature:',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 25),
                    pw.Container(width: 150, height: 1, color: borderColor),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      patient?.name ?? 'Patient',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textDirection: containsArabic(patient?.name ?? '')
                          ? pw.TextDirection.rtl
                          : pw.TextDirection.ltr,
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Prescribing Consultant:',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 25),
                    pw.Container(width: 150, height: 1, color: borderColor),
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

    // Full-size attached prescription images: one per page, no header/footer.
    for (final imgProvider in embeddedImages) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(imgProvider, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  static Future<void> printPrescriptionPdf(Visit visit) async {
    final pdfBytes = await generatePrescriptionPdf(visit);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Prescription_${visit.patient?.name ?? "Patient"}_${visit.id}.pdf',
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

  static pw.Widget _buildInfoCol(
    String label,
    String value, {
    int flex = 1,
    bool rightToLeft = false,
  }) {
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
          pw.Directionality(
            child: pw.Text(
              value,
              textDirection: rightToLeft
                  ? pw.TextDirection.rtl
                  : pw.TextDirection.ltr,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            textDirection: rightToLeft
                ? pw.TextDirection.rtl
                : pw.TextDirection.ltr,
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
