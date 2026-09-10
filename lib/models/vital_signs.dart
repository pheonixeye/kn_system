import 'package:equatable/equatable.dart';

class VitalSigns extends Equatable {
  final String? bloodPressure; // e.g. "120/80"
  final String? heartRate; // bpm
  final String? temperature; // °C
  final String? spo2; // %
  final String? respiratoryRate; // breaths/min
  final String? weight; // kg
  final String? height; // cm
  final String? bloodSugar; // mg/dL

  const VitalSigns({
    this.bloodPressure,
    this.heartRate,
    this.temperature,
    this.spo2,
    this.respiratoryRate,
    this.weight,
    this.height,
    this.bloodSugar,
  });

  double? get bmi {
    if (weight == null || height == null) return null;
    final w = double.tryParse(weight!);
    final h = double.tryParse(height!);
    if (w != null && h != null && h > 0) {
      final hInMeters = h / 100.0;
      return w / (hInMeters * hInMeters);
    }
    return null;
  }

  factory VitalSigns.fromJson(dynamic json) {
    if (json == null) return const VitalSigns();
    if (json is! Map) return const VitalSigns();
    return VitalSigns(
      bloodPressure: json['bloodPressure']?.toString(),
      heartRate: json['heartRate']?.toString(),
      temperature: json['temperature']?.toString(),
      spo2: json['spo2']?.toString(),
      respiratoryRate: json['respiratoryRate']?.toString(),
      weight: json['weight']?.toString(),
      height: json['height']?.toString(),
      bloodSugar: json['bloodSugar']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (bloodPressure != null && bloodPressure!.isNotEmpty)
        'bloodPressure': bloodPressure,
      if (heartRate != null && heartRate!.isNotEmpty) 'heartRate': heartRate,
      if (temperature != null && temperature!.isNotEmpty)
        'temperature': temperature,
      if (spo2 != null && spo2!.isNotEmpty) 'spo2': spo2,
      if (respiratoryRate != null && respiratoryRate!.isNotEmpty)
        'respiratoryRate': respiratoryRate,
      if (weight != null && weight!.isNotEmpty) 'weight': weight,
      if (height != null && height!.isNotEmpty) 'height': height,
      if (bloodSugar != null && bloodSugar!.isNotEmpty)
        'bloodSugar': bloodSugar,
    };
  }

  bool get isEmpty =>
      (bloodPressure == null || bloodPressure!.isEmpty) &&
      (heartRate == null || heartRate!.isEmpty) &&
      (temperature == null || temperature!.isEmpty) &&
      (spo2 == null || spo2!.isEmpty) &&
      (respiratoryRate == null || respiratoryRate!.isEmpty) &&
      (weight == null || weight!.isEmpty) &&
      (height == null || height!.isEmpty) &&
      (bloodSugar == null || bloodSugar!.isEmpty);

  @override
  List<Object?> get props => [
    bloodPressure,
    heartRate,
    temperature,
    spo2,
    respiratoryRate,
    weight,
    height,
    bloodSugar,
  ];
}
