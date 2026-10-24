package com.dduneon.oun

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import androidx.health.connect.client.records.metadata.DataOrigin
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.Duration

/** Read metrics from the session's own origin, avoiding double-counting apps. */
class HealthWorkoutsChannel(private val activity: FlutterFragmentActivity) {
    fun handle(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        if (call.method != "read") { result.notImplemented(); return }
        activity.lifecycleScope.launch {
            try {
                val start = Instant.ofEpochMilli(call.argument<Number>("start")!!.toLong())
                val end = Instant.ofEpochMilli(call.argument<Number>("end")!!.toLong())
                val client = HealthConnectClient.getOrCreate(activity)
                val permissions = client.permissionController.getGrantedPermissions()
                if (HealthPermission.getReadPermission(ExerciseSessionRecord::class) !in permissions) {
                    result.error("permission", "운동 읽기 권한이 필요해요", null)
                    return@launch
                }
                val rows = mutableListOf<Map<String, Any?>>()
                var page: String? = null
                do {
                    val response = client.readRecords(ReadRecordsRequest(
                        recordType = ExerciseSessionRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(start, end), pageToken = page))
                    for (record in response.records) {
                        if (record.endTime > end) continue
                        val duration = Duration.between(record.startTime, record.endTime).seconds
                        if (duration !in 1..21600) continue
                        val filter = TimeRangeFilter.between(record.startTime, record.endTime)
                        val origins = setOf(DataOrigin(record.metadata.dataOrigin.packageName))
                        val distance = if (HealthPermission.getReadPermission(DistanceRecord::class) in permissions) {
                            client.aggregate(AggregateRequest(setOf(DistanceRecord.DISTANCE_TOTAL), filter, origins))
                                .get(DistanceRecord.DISTANCE_TOTAL)?.inMeters?.toInt()
                        } else null
                        val calories = if (HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class) in permissions) {
                            client.aggregate(AggregateRequest(setOf(TotalCaloriesBurnedRecord.ENERGY_TOTAL), filter, origins))
                                .get(TotalCaloriesBurnedRecord.ENERGY_TOTAL)?.inKilocalories?.toInt()
                        } else null
                        val sport = when (record.exerciseType) {
                            ExerciseSessionRecord.EXERCISE_TYPE_RUNNING, ExerciseSessionRecord.EXERCISE_TYPE_RUNNING_TREADMILL -> "running"
                            ExerciseSessionRecord.EXERCISE_TYPE_WALKING, ExerciseSessionRecord.EXERCISE_TYPE_HIKING -> "walking"
                            ExerciseSessionRecord.EXERCISE_TYPE_BIKING, ExerciseSessionRecord.EXERCISE_TYPE_BIKING_STATIONARY -> "cycling"
                            ExerciseSessionRecord.EXERCISE_TYPE_STRENGTH_TRAINING, ExerciseSessionRecord.EXERCISE_TYPE_WEIGHTLIFTING -> "weight"
                            ExerciseSessionRecord.EXERCISE_TYPE_YOGA, ExerciseSessionRecord.EXERCISE_TYPE_PILATES -> "yoga"
                            else -> "etc"
                        }
                        rows.add(mapOf("id" to record.metadata.id, "sport" to sport,
                            "start" to record.startTime.toEpochMilli(), "duration" to duration,
                            "distance" to distance, "calories" to calories))
                    }
                    page = response.pageToken
                } while (page != null)
                result.success(rows.sortedByDescending { it["start"] as Long })
            } catch (_: Exception) {
                result.error("health_read", "건강 앱의 권한과 동기화를 확인해 주세요", null)
            }
        }
    }
}
