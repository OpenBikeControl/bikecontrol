import 'package:bike_control/utils/core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum TrainerFeedbackRating {
  works('works'),
  needsAdjustment('needs adjustment'),
  doesNotWork('does not work at all');

  final String apiValue;
  const TrainerFeedbackRating(this.apiValue);
}

class TrainerFeedbackPayload {
  final String userFeedback;
  final TrainerFeedbackRating? userRating;
  final String? bluetoothName;
  final String? hardwareManufacturer;
  final String? firmwareVersion;
  final bool? trainerSupportsVirtualShifting;
  final String? trainerControlMode;
  final String? virtualShiftingMode;
  final bool? gradeSmoothing;
  final List<double>? gearRatios;
  final String? appVersion;
  final String? appPlatform;
  final String? trainerApp;

  const TrainerFeedbackPayload({
    required this.userFeedback,
    this.userRating,
    this.bluetoothName,
    this.hardwareManufacturer,
    this.firmwareVersion,
    this.trainerSupportsVirtualShifting,
    this.trainerControlMode,
    this.virtualShiftingMode,
    this.gradeSmoothing,
    this.gearRatios,
    this.appVersion,
    this.appPlatform,
    this.trainerApp,
  });

  static const int _trainerAppMaxLength = 100;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'user_feedback': userFeedback.trim(),
    };
    if (userRating != null) json['user_rating'] = userRating!.apiValue;
    if (bluetoothName != null) json['bluetooth_name'] = bluetoothName;
    if (hardwareManufacturer != null) json['hardware_manufacturer'] = hardwareManufacturer;
    if (firmwareVersion != null) json['firmware_version'] = firmwareVersion;
    if (trainerSupportsVirtualShifting != null) {
      json['trainer_supports_virtual_shifting'] = trainerSupportsVirtualShifting;
    }
    if (trainerControlMode != null) json['trainer_control_mode'] = trainerControlMode;
    if (virtualShiftingMode != null) json['virtual_shifting_mode'] = virtualShiftingMode;
    if (gradeSmoothing != null) json['grade_smoothing'] = gradeSmoothing;
    if (gearRatios != null && gearRatios!.isNotEmpty) json['gear_ratios'] = gearRatios;
    if (appVersion != null) json['app_version'] = appVersion;
    if (appPlatform != null) json['app_platform'] = appPlatform;
    if (trainerApp != null) {
      json['trainer_app'] = trainerApp!.length > _trainerAppMaxLength
          ? trainerApp!.substring(0, _trainerAppMaxLength)
          : trainerApp;
    }
    return json;
  }
}

class TrainerFeedbackException implements Exception {
  final String message;
  const TrainerFeedbackException(this.message);

  @override
  String toString() => 'TrainerFeedbackException: $message';
}

class TrainerFeedbackService {
  static const _functionName = 'submit-trainer-feedback';

  final SupabaseClient _supabase;

  TrainerFeedbackService({SupabaseClient? supabase}) : _supabase = supabase ?? core.supabase;

  Future<void> submit(TrainerFeedbackPayload payload) async {
    try {
      await _supabase.functions.invoke(
        _functionName,
        body: payload.toJson(),
      );
    } on FunctionException catch (e) {
      throw TrainerFeedbackException(_extractError(e.details) ?? 'Failed to submit feedback');
    } catch (_) {
      throw const TrainerFeedbackException('Failed to submit feedback');
    }
  }

  String? _extractError(dynamic details) {
    if (details is Map && details['error'] is String) return details['error'] as String;
    return null;
  }
}
