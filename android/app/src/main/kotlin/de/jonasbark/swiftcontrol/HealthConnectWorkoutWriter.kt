package de.jonasbark.swiftcontrol

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.activity.result.ActivityResultLauncher
import androidx.fragment.app.FragmentActivity
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.CyclingPedalingCadenceRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSegment
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.PowerRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Length
import androidx.health.connect.client.units.Power
import androidx.health.connect.client.units.Velocity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset

/**
 * Writes a finished ride to Health Connect: an indoor-cycling exercise
 * session (pauses as pause segments) plus power, cadence, speed and heart
 * rate series and distance / active energy per minute.
 *
 * The Dart side is `MethodChannelHealthWorkout.healthConnect()`; the payload
 * is the same map Apple Health gets (`HealthWorkoutPayload.toMap`). Every
 * record carries a client record id derived from the ride's sync id, so a
 * retried write replaces instead of duplicating.
 *
 * Health Connect needs API 26+; below that `availability` reports
 * `unsupported` and nothing here touches the client.
 */
class HealthConnectWorkoutWriter private constructor(private val activity: FragmentActivity) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "bike_control/health_connect/workouts"
        private const val PROVIDER = "com.google.android.apps.healthdata"

        /** TUNABLE. Samples per series record; Health Connect caps a record's size. */
        private const val SERIES_CHUNK = 600

        val PERMISSIONS: Set<String> by lazy {
            setOf(
                HealthPermission.getWritePermission(ExerciseSessionRecord::class),
                HealthPermission.getWritePermission(PowerRecord::class),
                HealthPermission.getWritePermission(CyclingPedalingCadenceRecord::class),
                HealthPermission.getWritePermission(SpeedRecord::class),
                HealthPermission.getWritePermission(HeartRateRecord::class),
                HealthPermission.getWritePermission(DistanceRecord::class),
                HealthPermission.getWritePermission(ActiveCaloriesBurnedRecord::class),
            )
        }

        /** Call from `configureFlutterEngine` (during onCreate, before STARTED). */
        fun register(messenger: BinaryMessenger, activity: FragmentActivity) {
            val writer = HealthConnectWorkoutWriter(activity)
            writer.launcher = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                activity.registerForActivityResult(
                    PermissionController.createRequestPermissionResultContract(PROVIDER),
                ) { granted -> writer.onPermissionResult(granted) }
            } else {
                null
            }
            MethodChannel(messenger, CHANNEL).setMethodCallHandler(writer)
        }
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var launcher: ActivityResultLauncher<Set<String>>? = null
    private var pendingAuthorize: MethodChannel.Result? = null

    private fun status(context: Context): Int =
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            HealthConnectClient.SDK_UNAVAILABLE
        } else {
            HealthConnectClient.getSdkStatus(context, PROVIDER)
        }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "availability" -> result.success(
                when (status(activity)) {
                    HealthConnectClient.SDK_AVAILABLE -> "available"
                    HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "notInstalled"
                    else -> "unsupported"
                },
            )
            "authorize" -> authorize(result)
            "saveWorkout" -> save(call, result)
            "openHealthSettings" -> {
                openSettings()
                result.success(null)
            }
            "openInstall" -> {
                openInstall()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun authorize(result: MethodChannel.Result) {
        if (status(activity) != HealthConnectClient.SDK_AVAILABLE) {
            result.success("denied")
            return
        }
        scope.launch {
            try {
                val granted = HealthConnectClient.getOrCreate(activity).permissionController.getGrantedPermissions()
                if (granted.containsAll(PERMISSIONS)) {
                    result.success("granted")
                    return@launch
                }
                val l = launcher
                if (l == null || pendingAuthorize != null) {
                    result.success("unknown")
                    return@launch
                }
                pendingAuthorize = result
                l.launch(PERMISSIONS)
            } catch (e: Exception) {
                result.error("authorize", e.message, null)
            }
        }
    }

    private fun onPermissionResult(granted: Set<String>) {
        val result = pendingAuthorize ?: return
        pendingAuthorize = null
        // The session itself is the one thing a ride cannot be saved without;
        // a series the rider left off is simply not written.
        val session = HealthPermission.getWritePermission(ExerciseSessionRecord::class)
        result.success(if (granted.contains(session)) "granted" else "denied")
    }

    private fun save(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        if (args == null) {
            result.error("args", "missing payload", null)
            return
        }
        scope.launch {
            try {
                val client = HealthConnectClient.getOrCreate(activity)
                val granted = client.permissionController.getGrantedPermissions()
                val records = buildRecords(args).filter {
                    granted.contains(HealthPermission.getWritePermission(it::class))
                }
                if (records.none { it is ExerciseSessionRecord }) {
                    result.error("denied", "Health Connect write access is off", null)
                    return@launch
                }
                val response = client.insertRecords(records)
                result.success(response.recordIdsList.firstOrNull())
            } catch (e: SecurityException) {
                result.error("denied", e.message, null)
            } catch (e: Exception) {
                result.error("save", e.message, null)
            }
        }
    }

    private fun buildRecords(args: Map<*, *>): List<Record> {
        val syncId = args["syncId"] as String
        val version = (args["syncVersion"] as Number).toLong()
        val start = Instant.ofEpochMilli((args["start"] as Number).toLong())
        val end = Instant.ofEpochMilli((args["end"] as Number).toLong())
        val zone = ZoneId.systemDefault().rules
        fun offset(i: Instant): ZoneOffset = zone.getOffset(i)
        fun meta(kind: String, index: Int = 0) =
            Metadata.activelyRecorded(
                device = Device(type = Device.TYPE_PHONE),
                clientRecordId = "$syncId-$kind-$index",
                clientRecordVersion = version,
            )

        val records = mutableListOf<Record>()

        val pauses = (args["pauses"] as? List<*>).orEmpty().mapNotNull { p ->
            val pair = p as? List<*> ?: return@mapNotNull null
            Instant.ofEpochMilli((pair[0] as Number).toLong()) to Instant.ofEpochMilli((pair[1] as Number).toLong())
        }.filter { it.first < it.second }.sortedBy { it.first }
        val segments = mutableListOf<ExerciseSegment>()
        var cursor = start
        for ((pStart, pEnd) in pauses) {
            if (pStart > cursor) {
                segments += ExerciseSegment(cursor, pStart, ExerciseSegment.EXERCISE_SEGMENT_TYPE_BIKING_STATIONARY)
            }
            segments += ExerciseSegment(pStart, pEnd, ExerciseSegment.EXERCISE_SEGMENT_TYPE_PAUSE)
            cursor = pEnd
        }
        if (pauses.isNotEmpty() && end > cursor) {
            segments += ExerciseSegment(cursor, end, ExerciseSegment.EXERCISE_SEGMENT_TYPE_BIKING_STATIONARY)
        }
        records += ExerciseSessionRecord(
            startTime = start,
            startZoneOffset = offset(start),
            endTime = end,
            endZoneOffset = offset(end),
            metadata = meta("session"),
            exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_BIKING_STATIONARY,
            title = "BikeControl",
            segments = segments,
        )

        fun series(key: String): List<Pair<Instant, Double>> {
            val m = args[key] as? Map<*, *> ?: return emptyList()
            val t = (m["t"] as? List<*>).orEmpty()
            val v = (m["v"] as? List<*>).orEmpty()
            return t.indices.mapNotNull { i ->
                val at = Instant.ofEpochMilli((t[i] as Number).toLong())
                if (at < start || at >= end) null else at to (v[i] as Number).toDouble()
            }
        }

        fun <S> chunks(
            key: String,
            sample: (Instant, Double) -> S,
            record: (Instant, Instant, List<S>, Metadata) -> Record,
        ) {
            series(key).chunked(SERIES_CHUNK).forEachIndexed { i, chunk ->
                val first = chunk.first().first
                // A series record must end after its last sample.
                val last = minOf(chunk.last().first.plusSeconds(1), end)
                records += record(first, last, chunk.map { (at, v) -> sample(at, v) }, meta(key, i))
            }
        }

        chunks("power", { at, v -> PowerRecord.Sample(at, Power.watts(v)) }) { s, e, samples, md ->
            PowerRecord(s, offset(s), e, offset(e), samples, md)
        }
        chunks("cadence", { at, v -> CyclingPedalingCadenceRecord.Sample(at, v) }) { s, e, samples, md ->
            CyclingPedalingCadenceRecord(s, offset(s), e, offset(e), samples, md)
        }
        chunks("speed", { at, v -> SpeedRecord.Sample(at, Velocity.metersPerSecond(v)) }) { s, e, samples, md ->
            SpeedRecord(s, offset(s), e, offset(e), samples, md)
        }
        chunks("heartRate", { at, v -> HeartRateRecord.Sample(at, v.toLong()) }) { s, e, samples, md ->
            HeartRateRecord(s, offset(s), e, offset(e), samples, md)
        }

        fun intervals(key: String, record: (Instant, Instant, Double, Metadata) -> Record) {
            val m = args[key] as? Map<*, *> ?: return
            val s = (m["s"] as? List<*>).orEmpty()
            val e = (m["e"] as? List<*>).orEmpty()
            val v = (m["v"] as? List<*>).orEmpty()
            for (i in s.indices) {
                val a = Instant.ofEpochMilli((s[i] as Number).toLong())
                val b = Instant.ofEpochMilli((e[i] as Number).toLong())
                val value = (v[i] as Number).toDouble()
                if (b > a && value > 0) records += record(a, b, value, meta(key, i))
            }
        }
        intervals("distance") { a, b, meters, md ->
            DistanceRecord(a, offset(a), b, offset(b), Length.meters(meters), md)
        }
        intervals("energy") { a, b, kcal, md ->
            ActiveCaloriesBurnedRecord(a, offset(a), b, offset(b), Energy.kilocalories(kcal), md)
        }
        return records
    }

    private fun openSettings() {
        val intent = Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS)
        try {
            activity.startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            openInstall()
        }
    }

    private fun openInstall() {
        val market = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("market://details?id=$PROVIDER&url=healthconnect%3A%2F%2Fonboarding"),
        ).setPackage("com.android.vending")
        try {
            activity.startActivity(market)
        } catch (e: ActivityNotFoundException) {
            activity.startActivity(
                Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$PROVIDER")),
            )
        }
    }
}
