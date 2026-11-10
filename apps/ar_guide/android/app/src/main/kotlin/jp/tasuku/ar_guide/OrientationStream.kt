package jp.tasuku.ar_guide

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import io.flutter.plugin.common.EventChannel
import kotlin.math.asin
import kotlin.math.atan2

/**
 * Device heading (compass) and camera tilt for the compass-mode arrow, on `tasuku_ar/orientation`.
 *
 * Events: `{available: true, heading: deg (0 = north, clockwise), pitch: deg (0 = camera level,
 * 90 = camera pointing at the floor), accuracy: 0..3 or -1}`; or `{available: false}` when the device
 * has no magnetometer.
 *
 * `accuracy` is the magnetometer's SensorManager accuracy (0 unreliable, 1 low, 2 medium, 3 high).
 * Dart pauses the arrow and asks for a figure-8 calibration when it stays 0 for 1 s (requirements F3B);
 * at 1 it keeps the arrow and shows a small "low accuracy" note.
 *
 * Pass the application context (the stream outlives no activity, but must not hold one).
 *
 * Sources: TYPE_ROTATION_VECTOR (fused) when present; otherwise accelerometer + magnetometer with
 * SensorManager.getRotationMatrix. Written natively because the maintained Flutter sensor plugins do not
 * expose the magnetometer accuracy, which the calibration prompt needs.
 */
class OrientationStream(context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val rotationSensor: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
    private val magnetometer: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
    private val accelerometer: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

    private var sink: EventChannel.EventSink? = null
    private val rotation = FloatArray(9)
    private val gravity = FloatArray(3)
    private val geomagnetic = FloatArray(3)
    private var hasGravity = false
    private var hasGeomagnetic = false
    private var magAccuracy = -1
    private var lastEmitMs = 0L

    /** false between the activity's onPause and onResume: sensors are unregistered in the background. */
    private var activityResumed = true
    private var registered = false

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        if (magnetometer == null || (rotationSensor == null && accelerometer == null)) {
            events.success(mapOf("available" to false))
            return
        }
        register()
    }

    override fun onCancel(arguments: Any?) {
        unregister()
        sink = null
    }

    /** Called from MainActivity.onResume. */
    fun resume() {
        activityResumed = true
        register()
    }

    /** Called from MainActivity.onPause. */
    fun pause() {
        activityResumed = false
        unregister()
    }

    private fun register() {
        if (registered || !activityResumed || sink == null || magnetometer == null) return
        // The magnetometer is always registered: its accuracy drives the calibration prompt.
        sensorManager.registerListener(this, magnetometer, SensorManager.SENSOR_DELAY_GAME)
        if (rotationSensor != null) {
            sensorManager.registerListener(this, rotationSensor, SensorManager.SENSOR_DELAY_GAME)
        } else if (accelerometer != null) {
            sensorManager.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_GAME)
        }
        registered = true
    }

    private fun unregister() {
        if (!registered) return
        sensorManager.unregisterListener(this)
        registered = false
        hasGravity = false
        hasGeomagnetic = false
    }

    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {
        if (sensor.type == Sensor.TYPE_MAGNETIC_FIELD) magAccuracy = accuracy
    }

    override fun onSensorChanged(event: SensorEvent) {
        when (event.sensor.type) {
            Sensor.TYPE_ROTATION_VECTOR -> {
                SensorManager.getRotationMatrixFromVector(rotation, event.values)
                emit()
            }
            Sensor.TYPE_MAGNETIC_FIELD -> {
                magAccuracy = event.accuracy
                lowPass(event.values, geomagnetic, hasGeomagnetic)
                hasGeomagnetic = true
                if (rotationSensor == null) fromAccelMag()
            }
            Sensor.TYPE_ACCELEROMETER -> {
                lowPass(event.values, gravity, hasGravity)
                hasGravity = true
                fromAccelMag()
            }
        }
    }

    private fun fromAccelMag() {
        if (!hasGravity || !hasGeomagnetic) return
        if (SensorManager.getRotationMatrix(rotation, null, gravity, geomagnetic)) emit()
    }

    private fun lowPass(input: FloatArray, output: FloatArray, initialized: Boolean) {
        for (i in 0..2) output[i] = if (initialized) output[i] + 0.2f * (input[i] - output[i]) else input[i]
    }

    /**
     * rotation (row-major) maps device axes to world axes (x = east, y = north, z = up).
     * The camera looks along device -Z; the top edge of the phone is device +Y.
     */
    private fun emit() {
        val now = SystemClock.elapsedRealtime()
        if (now - lastEmitMs < EMIT_INTERVAL_MS) return
        lastEmitMs = now
        val r = rotation
        // Horizontal heading of "where the phone points": the camera axis and the phone's top edge agree
        // when the phone is held upright in portrait and tilted forward; their sum stays stable from
        // upright (camera axis level) to flat (camera at the floor, top edge level).
        val east = -r[2] + r[1]
        val north = -r[5] + r[4]
        var heading = Math.toDegrees(atan2(east.toDouble(), north.toDouble()))
        if (heading < 0) heading += 360.0
        // Camera axis world-up component is -r[8]; angle below the horizon:
        val pitch = Math.toDegrees(asin(r[8].coerceIn(-1f, 1f).toDouble()))
        sink?.success(
            mapOf(
                "available" to true,
                "heading" to heading,
                "pitch" to pitch,
                "accuracy" to magAccuracy,
            ),
        )
    }

    private companion object {
        const val EMIT_INTERVAL_MS = 33L
    }
}
