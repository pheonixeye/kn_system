import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kn_system/core/theme/app_theme.dart';
import 'package:kn_system/models/patient.dart';
import 'package:kn_system/models/visit.dart';
import 'package:kn_system/models/vital_signs.dart';
import 'package:kn_system/widgets/custom_badge.dart';
import 'package:kn_system/widgets/stat_card.dart';

void main() {
  group('Aegis Clinic System Model & Widget Tests', () {
    test('Patient model age calculation test', () {
      final patient = Patient(
        id: 'pat_1',
        name: 'John Doe',
        phone: '+1234567890',
        dob: '1990-05-15',
        gender: 'Male',
      );

      expect(patient.calculatedAge, isNotNull);
      expect(patient.calculatedAge! >= 30, isTrue);
    });

    test('Vital signs BMI calculation test', () {
      const vitals = VitalSigns(
        weight: '70',
        height: '175',
        bloodPressure: '120/80',
        heartRate: '72',
      );

      expect(vitals.bmi, isNotNull);
      expect(vitals.bmi! > 22.8 && vitals.bmi! < 23.0, isTrue);
    });

    test('Visit model image URL formatting test', () {
      const visit = Visit(
        id: 'vis_123',
        patientId: 'pat_1',
        images: ['xray.png'],
      );

      final url = visit.getImageUrl('xray.png');
      expect(url, contains('/api/files/visits/vis_123/xray.png'));
    });

    testWidgets('StatCard and CustomBadge render test', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Column(
              children: [
                StatCard(
                  title: 'Waiting for Doctor',
                  value: '5',
                  icon: Icons.hourglass_top,
                  color: AppTheme.warning,
                ),
                CustomBadge(
                  label: 'Waiting for Resident',
                  textColor: AppTheme.warning,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Waiting for Doctor'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Waiting for Resident'), findsOneWidget);
    });
  });
}
