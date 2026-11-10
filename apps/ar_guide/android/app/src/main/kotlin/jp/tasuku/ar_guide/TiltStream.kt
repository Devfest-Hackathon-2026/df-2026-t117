package jp.tasuku.ar_guide

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.SystemClock
import io.flutter.plugin.common.EventChannel
import kotlin.math.asin
import kotlin.math.sqrt

/**
 * Camera tilt only, for "device raised -> AR" (requirements F36), on `tasuku_ar/tilt`.
 *
 * Events: `{available: true, pitch: deg (0 = camera level / phone upright, 90 = camera pointing at the
 * floor / phone flat)}`; or `{available: false}` when the device has no accelerometer.
 *
 * Separate from [OrientationStream] so it needs no magnetometer and so both can run at once: the AR
 * screen (S11) listens to `tasuku_ar/orientation` while Dart listens here to detect lowering the phone.
 * Sources: TYPE_GRAVITY when present; otherwise the accelerometer with a low-pass filter.
 * Dart listens only while S04 / S11 / S12 are shown; sensors are also off while the activity is paused.
 */
class TiltStream(context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val gravitySensor: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_GRAVITY)
    private val accelerometer: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

    private var sink: EventChannel.EventSink? = null
    private val gravity = FloatArray(3)
    private var hasGravity = false
    private var lastEmitMs = 0L
    private var activityResumed = true
    private var registered = false

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        if (gravitySensor == null && accelerometer == null) {
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
        if (registered || !activityResumed || sink == null) return
        val sensor = gravitySensor ?: accelerometer ?: return
        sensorManager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_UI)
        registered = true
    }

    private fun unregister() {
        if (!registered) return
        sensorManager.unregisterListener(this)
        registered = false
        hasGravity = false
    }

    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {}

    override fun onSensorChanged(event: SensorEvent) {
        val v = event.values
        if (event.sensor.type == Sensor.TYPE_GRAVITY || !hasGravity) {
            for (i in 0..2) gravity[i] = v[i]
        } else {
            for (i in 0..2) gravity[i] += 0.2f * (v[i] - gravity[i])
        }
        hasGravity = true
        val now = SystemClock.elapsedRealtime()
        if (now - lastEmitMs < EMIT_INTERVAL_MS) return
        lastEmitMs = now
        val g = sqrt(gravity[0] * gravity[0] + gravity[1] * gravity[1] + gravity[2] * gravity[2])
        if (g < 1e-3f) return
        // At rest the reading points away from the ground: device +Z (out of the screen) is up when the
        // phone lies flat, so the camera (device -Z) points at the floor. Same angle as OrientationStream's pitch.
        val pitch = Math.toDegrees(asin((gravity[2] / g).coerceIn(-1f, 1f).toDouble()))
        sink?.success(mapOf("available" to true, "pitch" to pitch))
    }

    private companion object {
        const val EMIT_INTERVAL_MS = 50L
    }
}
