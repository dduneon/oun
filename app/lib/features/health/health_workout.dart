import 'dart:io';
import 'package:flutter/services.dart';
import 'package:health/health.dart';

/// Only the selected record is passed to the editor and uploaded on save.
class HealthWorkout {
  const HealthWorkout({
    required this.id,
    required this.source,
    required this.sport,
    required this.start,
    required this.durationSec,
    this.distanceM,
    this.calories,
  });
  final String id, source, sport;
  final DateTime start;
  final int durationSec;
  final int? distanceM, calories;

  static String sportFor(String activity) => switch (activity) {
    'RUNNING' || 'RUNNING_TREADMILL' => 'running',
    'WALKING' || 'WALKING_TREADMILL' || 'HIKING' => 'walking',
    'BIKING' || 'BIKING_STATIONARY' => 'cycling',
    'TRADITIONAL_STRENGTH_TRAINING' ||
    'FUNCTIONAL_STRENGTH_TRAINING' ||
    'STRENGTH_TRAINING' ||
    'WEIGHTLIFTING' => 'weight',
    'YOGA' || 'PILATES' => 'yoga',
    _ => 'etc',
  };

  static HealthWorkout? fromPoint(HealthDataPoint point) {
    final value = point.value;
    if (value is! WorkoutHealthValue || point.uuid.isEmpty) return null;
    final duration = point.dateTo.difference(point.dateFrom).inSeconds;
    if (duration <= 0 ||
        duration > 21600 ||
        point.dateTo.isAfter(DateTime.now())) {
      return null;
    }
    return HealthWorkout(
      id: point.uuid,
      source: 'healthkit',
      sport: sportFor(value.workoutActivityType.name),
      start: point.dateFrom.toLocal(),
      durationSec: duration,
      distanceM: value.totalDistanceUnit == HealthDataUnit.METER
          ? value.totalDistance
          : null,
      calories: value.totalEnergyBurnedUnit == HealthDataUnit.KILOCALORIE
          ? value.totalEnergyBurned
          : null,
    );
  }
}

class HealthWorkouts {
  final Health _health = Health();
  static const _channel = MethodChannel('oun/health_workouts');
  static bool get supported => Platform.isIOS || Platform.isAndroid;
  static String get name => Platform.isIOS ? '애플 건강' : 'Health Connect';
  List<HealthDataType> get _types => [
    HealthDataType.WORKOUT,
    if (Platform.isAndroid) ...[
      HealthDataType.DISTANCE_DELTA,
      HealthDataType.TOTAL_CALORIES_BURNED,
    ],
  ];

  Future<bool> available() async {
    if (!supported) return false;
    await _health.configure();
    if (Platform.isIOS) {
      return await _channel.invokeMethod<bool>('available') ?? false;
    }
    return _health.isHealthConnectAvailable();
  }

  /// iOS reports whether a request is needed, never whether reading is allowed.
  Future<bool> needsAuthorization() async {
    if (Platform.isIOS) {
      return await _channel.invokeMethod<bool>('authorizationNeeded') ?? false;
    }
    return await _health.hasPermissions(
          [HealthDataType.WORKOUT],
          permissions: [HealthDataAccess.READ],
        ) !=
        true;
  }

  Future<void> install() => _health.installHealthConnect();

  Future<bool> authorize() async {
    await _health.configure();
    // iOS cannot disclose whether read permission was granted. Never label
    // authorization completion as a successful connection or permission grant.
    return _health.requestAuthorization(
      _types,
      permissions: _types.map((_) => HealthDataAccess.READ).toList(),
    );
  }

  Future<List<HealthWorkout>> readRecent() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    if (Platform.isAndroid) {
      final rows = await _channel.invokeListMethod<dynamic>('read', {
        'start': start.millisecondsSinceEpoch,
        'end': now.millisecondsSinceEpoch,
      });
      return (rows ?? [])
          .map((raw) {
            final row = Map<String, dynamic>.from(raw as Map);
            return HealthWorkout(
              id: row['id'] as String,
              source: 'health_connect',
              sport: row['sport'] as String,
              start: DateTime.fromMillisecondsSinceEpoch(row['start'] as int),
              durationSec: row['duration'] as int,
              distanceM: row['distance'] as int?,
              calories: row['calories'] as int?,
            );
          })
          .where((w) => w.durationSec > 0 && w.durationSec <= 21600)
          .toList();
    }
    final rows = await _health.getHealthDataFromTypes(
      types: [HealthDataType.WORKOUT],
      startTime: start,
      endTime: now,
    );
    return rows.map(HealthWorkout.fromPoint).whereType<HealthWorkout>().toList()
      ..sort((a, b) => b.start.compareTo(a.start));
  }
}
