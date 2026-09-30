import '../models/queue.dart';

/// Service for Smart Triage calculations and priority assignment
class TriageService {
  /// Calculate priority based on vital signs, red flags, and patient category
  static Priority calculatePriority({
    required List<RedFlag> redFlags,
    double? temperature,
    double? systolicBP,
    double? diastolicBP,
    double? heartRate,
    double? respiratoryRate,
    double? oxygenSaturation,
    int? painScale,
    bool isSenior = false,
    bool isPregnant = false,
    bool isInfant = false,
    bool isEssentiallyNormal = false,
  }) {
    // EMERGENCY: Any critical red flag
    if (redFlags.any((flag) => _isCriticalRedFlag(flag))) {
      return Priority.emergency;
    }

    // EMERGENCY: Critical vital signs
    if (_hasCriticalVitals(
      temperature: temperature,
      systolicBP: systolicBP,
      diastolicBP: diastolicBP,
      heartRate: heartRate,
      respiratoryRate: respiratoryRate,
      oxygenSaturation: oxygenSaturation,
    )) {
      return Priority.emergency;
    }

    // HIGH: Moderate red flags
    if (redFlags.isNotEmpty) {
      return Priority.high;
    }

    // HIGH: High pain scale
    if (painScale != null && painScale >= 8) {
      return Priority.high;
    }

    // HIGH: Abnormal vitals in vulnerable patients
    if ((isSenior || isPregnant || isInfant) &&
        _hasAbnormalVitals(
          temperature: temperature,
          systolicBP: systolicBP,
          diastolicBP: diastolicBP,
          heartRate: heartRate,
          respiratoryRate: respiratoryRate,
          oxygenSaturation: oxygenSaturation,
        )) {
      return Priority.high;
    }

    // NORMAL: Essentially normal toggle
    if (isEssentiallyNormal) {
      return Priority.normal;
    }

    // LOW: No concerns
    return Priority.low;
  }

  /// Check if a red flag is critical (requires immediate attention)
  static bool _isCriticalRedFlag(RedFlag flag) {
    return [
      RedFlag.unconscious,
      RedFlag.difficultyBreathing,
      RedFlag.activeBleeding,
      RedFlag.anaphylaxis,
      RedFlag.seizure,
      RedFlag.severeChestPain,
    ].contains(flag);
  }

  /// Check for critical vital signs
  static bool _hasCriticalVitals({
    double? temperature,
    double? systolicBP,
    double? diastolicBP,
    double? heartRate,
    double? respiratoryRate,
    double? oxygenSaturation,
  }) {
    // Temperature > 40°C or < 35°C
    if (temperature != null && (temperature > 40.0 || temperature < 35.0)) {
      return true;
    }

    // Systolic BP < 90 or > 180
    if (systolicBP != null && (systolicBP < 90 || systolicBP > 180)) {
      return true;
    }

    // Diastolic BP > 120
    if (diastolicBP != null && diastolicBP > 120) {
      return true;
    }

    // Heart rate < 50 or > 120
    if (heartRate != null && (heartRate < 50 || heartRate > 120)) {
      return true;
    }

    // Respiratory rate < 12 or > 30
    if (respiratoryRate != null &&
        (respiratoryRate < 12 || respiratoryRate > 30)) {
      return true;
    }

    // Oxygen saturation < 90%
    if (oxygenSaturation != null && oxygenSaturation < 90) {
      return true;
    }

    return false;
  }

  /// Check for abnormal vitals (not critical but concerning)
  static bool _hasAbnormalVitals({
    double? temperature,
    double? systolicBP,
    double? diastolicBP,
    double? heartRate,
    double? respiratoryRate,
    double? oxygenSaturation,
  }) {
    // Temperature > 38°C or < 36°C
    if (temperature != null && (temperature > 38.0 || temperature < 36.0)) {
      return true;
    }

    // Systolic BP < 100 or > 160
    if (systolicBP != null && (systolicBP < 100 || systolicBP > 160)) {
      return true;
    }

    // Diastolic BP > 100
    if (diastolicBP != null && diastolicBP > 100) {
      return true;
    }

    // Heart rate < 60 or > 100
    if (heartRate != null && (heartRate < 60 || heartRate > 100)) {
      return true;
    }

    // Respiratory rate < 14 or > 24
    if (respiratoryRate != null &&
        (respiratoryRate < 14 || respiratoryRate > 24)) {
      return true;
    }

    // Oxygen saturation < 95%
    if (oxygenSaturation != null && oxygenSaturation < 95) {
      return true;
    }

    return false;
  }

  /// Calculate BMI from height (cm) and weight (kg)
  static double? calculateBMI(double? heightCm, double? weightKg) {
    if (heightCm == null || weightKg == null || heightCm <= 0 || weightKg <= 0) {
      return null;
    }
    // BMI = weight (kg) / (height (m))^2
    final heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }

  /// Get BMI category
  static BMICategory getBMICategory(double? bmi) {
    if (bmi == null) return BMICategory.unknown;
    if (bmi < 18.5) return BMICategory.underweight;
    if (bmi < 25) return BMICategory.normal;
    if (bmi < 30) return BMICategory.overweight;
    return BMICategory.obese;
  }

  /// Get triage recommendation text
  static String getTriageRecommendation(Priority priority) {
    switch (priority) {
      case Priority.emergency:
        return 'IMMEDIATE: Proceed to emergency bay immediately';
      case Priority.high:
        return 'URGENT: See within 15 minutes';
      case Priority.normal:
        return 'ROUTINE: See within 30-60 minutes';
      case Priority.low:
        return 'NON-URGENT: See when available';
    }
  }
}

/// BMI categories
enum BMICategory {
  unknown,
  underweight,
  normal,
  overweight,
  obese,
}

/// Extension for BMI category display
extension BMICategoryExtension on BMICategory {
  String get displayName {
    switch (this) {
      case BMICategory.unknown:
        return 'Unknown';
      case BMICategory.underweight:
        return 'Underweight';
      case BMICategory.normal:
        return 'Normal';
      case BMICategory.overweight:
        return 'Overweight';
      case BMICategory.obese:
        return 'Obese';
    }
  }
}
