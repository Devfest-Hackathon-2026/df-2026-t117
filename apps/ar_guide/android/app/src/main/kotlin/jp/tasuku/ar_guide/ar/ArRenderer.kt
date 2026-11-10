package jp.tasuku.ar_guide.ar

import android.app.Activity
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.os.Build
import android.os.SystemClock
import android.view.Surface
import com.google.ar.core.Anchor
import com.google.ar.core.Camera
import com.google.ar.core.Frame
import com.google.ar.core.Plane
import com.google.ar.core.Pose
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import com.google.ar.core.exceptions.CameraNotAvailableException
import java.util.concurrent.atomic.AtomicReference
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Draws the camera image and, once a floor plane is found, the turn arrow anchored on it.
 *
 * Status (reported only when it changes):
 *  - `initializing`: session not updated yet
 *  - `searching`: camera tracking, but no floor plane / anchor yet (arrow hidden)
 *  - `tracking`: camera and anchor tracking (arrow drawn)
 *  - `lost`: camera tracking paused or stopped (arrow hidden); reason = ARCore TrackingFailureReason
 *  - `error` / `unsupported`: no AR (arrow hidden)
 *
 * The arrow is drawn only in `tracking` (requirements F3B: stop the AR arrow when tracking is lost).
 */
class ArRenderer(
    private val activity: Activity,
    initialTurn: Turn,
    private val onStatus: (state: String, reason: String?) -> Unit,
) : GLSurfaceView.Renderer {

    @Volatile
    var session: Session? = null

    /**
     * Clockwise angle (deg) from the user's viewing direction to the route bearing, from the compass.
     * ARCore's world frame is not north-aligned, so the compass decides where the arrow points.
     */
    @Volatile
    var yawOffsetDeg = 0f

    private val pendingTurn = AtomicReference<Turn?>(initialTurn)
    private val background = BackgroundRenderer()
    private val arrow = ArrowRenderer()

    private var viewportWidth = 1
    private var viewportHeight = 1
    private var displayRotation = Surface.ROTATION_0
    private var geometryChanged = false
    private var textureBoundTo: Session? = null

    private var anchor: Anchor? = null
    private var lastState: String? = null
    private var lastReason: String? = null

    private val projection = FloatArray(16)
    private val view = FloatArray(16)
    private val model = FloatArray(16)
    private val startMs = SystemClock.elapsedRealtime()

    fun setTurn(turn: Turn) {
        pendingTurn.set(turn)
    }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        GLES20.glClearColor(0.1f, 0.1f, 0.1f, 1f)
        background.createOnGlThread()
        arrow.createOnGlThread()
        // New GL context: the camera texture name must be passed to the session again.
        textureBoundTo = null
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        GLES20.glViewport(0, 0, width, height)
        viewportWidth = width
        viewportHeight = height
        displayRotation = currentDisplayRotation()
        geometryChanged = true
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        val s = session ?: return

        if (textureBoundTo !== s) {
            s.setCameraTextureName(background.textureId)
            textureBoundTo = s
        }
        if (geometryChanged) {
            s.setDisplayGeometry(displayRotation, viewportWidth, viewportHeight)
            geometryChanged = false
        }
        pendingTurn.getAndSet(null)?.let { arrow.setTurn(it) }

        val frame: Frame = try {
            s.update()
        } catch (e: CameraNotAvailableException) {
            report(STATE_ERROR, "camera")
            return
        } catch (e: Exception) {
            report(STATE_ERROR, e.javaClass.simpleName)
            return
        }

        background.draw(frame)
        if (frame.timestamp == 0L) {
            report(STATE_INITIALIZING, null)
            return
        }

        val camera = frame.camera
        if (camera.trackingState != TrackingState.TRACKING) {
            report(STATE_LOST, camera.trackingFailureReason.name)
            return
        }

        val placed = updateAnchor(frame, camera)
        if (placed == null || placed.trackingState != TrackingState.TRACKING) {
            report(STATE_SEARCHING, null)
            return
        }

        camera.getProjectionMatrix(projection, 0, 0.05f, 50f)
        camera.getViewMatrix(view, 0)
        placed.pose.toMatrix(model, 0)
        val seconds = (SystemClock.elapsedRealtime() - startMs) / 1000f
        arrow.draw(model, view, projection, seconds)
        report(STATE_TRACKING, null)
    }

    /** Keeps one anchor on the floor in front of the user; re-places it when lost or left behind. */
    private fun updateAnchor(frame: Frame, camera: Camera): Anchor? {
        anchor?.let { a ->
            val stopped = a.trackingState == TrackingState.STOPPED
            val tooFar = horizontalDistance(camera.pose, a.pose) > REPLACE_DISTANCE_M
            if (stopped || tooFar) {
                a.detach()
                anchor = null
            }
        }
        if (anchor == null) anchor = tryPlace(frame, camera)
        return anchor
    }

    /**
     * Hit-tests a point in the lower middle of the screen against horizontal, upward-facing planes
     * (the floor) and anchors the arrow there, facing the direction the user is looking.
     */
    private fun tryPlace(frame: Frame, camera: Camera): Anchor? {
        val hits = frame.hitTest(viewportWidth * 0.5f, viewportHeight * 0.68f)
        for (hit in hits) {
            val plane = hit.trackable as? Plane ?: continue
            if (plane.type != Plane.Type.HORIZONTAL_UPWARD_FACING) continue
            if (plane.subsumedBy != null) continue
            if (!plane.isPoseInPolygon(hit.hitPose)) continue
            if (hit.distance < MIN_PLACE_DISTANCE_M || hit.distance > MAX_PLACE_DISTANCE_M) continue

            // Positive yaw around +Y turns counter-clockwise seen from above: subtract the clockwise offset.
            val yaw = forwardYaw(camera.displayOrientedPose) - Math.toRadians(yawOffsetDeg.toDouble()).toFloat()
            val rotation = floatArrayOf(0f, sin(yaw / 2f), 0f, cos(yaw / 2f))
            val pose = Pose(hit.hitPose.translation, rotation)
            return plane.createAnchor(pose)
        }
        return null
    }

    /**
     * Yaw (around world +Y) that turns the arrow's local forward (-Z) to the user's horizontal
     * viewing direction. When the phone points almost straight down, the top edge of the screen
     * (+Y of the display-oriented pose) is used instead.
     */
    private fun forwardYaw(displayPose: Pose): Float {
        val z = displayPose.zAxis
        var fx = -z[0]
        var fz = -z[2]
        if (sqrt(fx * fx + fz * fz) < 0.3f) {
            val y = displayPose.yAxis
            fx = y[0]
            fz = y[2]
        }
        // Rotating (0, 0, -1) by yaw θ around +Y gives (-sin θ, 0, -cos θ).
        return atan2(-fx, -fz)
    }

    private fun horizontalDistance(a: Pose, b: Pose): Float {
        val dx = a.tx() - b.tx()
        val dz = a.tz() - b.tz()
        return sqrt(dx * dx + dz * dz)
    }

    private fun report(state: String, reason: String?) {
        if (state == lastState && reason == lastReason) return
        lastState = state
        lastReason = reason
        onStatus(state, reason)
    }

    @Suppress("DEPRECATION")
    private fun currentDisplayRotation(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.display?.rotation ?: Surface.ROTATION_0
        } else {
            activity.windowManager.defaultDisplay.rotation
        }

    companion object {
        const val STATE_INITIALIZING = "initializing"
        const val STATE_SEARCHING = "searching"
        const val STATE_TRACKING = "tracking"
        const val STATE_LOST = "lost"
        const val STATE_ERROR = "error"
        const val STATE_UNSUPPORTED = "unsupported"

        private const val MIN_PLACE_DISTANCE_M = 0.4f
        private const val MAX_PLACE_DISTANCE_M = 4.0f
        private const val REPLACE_DISTANCE_M = 5.0f
    }
}
