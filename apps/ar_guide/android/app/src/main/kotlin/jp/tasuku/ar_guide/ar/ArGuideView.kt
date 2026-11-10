package jp.tasuku.ar_guide.ar

import android.app.Activity
import android.opengl.GLSurfaceView
import android.os.Handler
import android.os.Looper
import android.view.View
import com.google.ar.core.Config
import com.google.ar.core.Session
import com.google.ar.core.exceptions.CameraNotAvailableException
import com.google.ar.core.exceptions.UnavailableDeviceNotCompatibleException
import com.google.ar.core.exceptions.UnavailableException
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

/**
 * Camera image + turn arrow on the floor (S11), as a Flutter platform view.
 *
 * Uses the ARCore SDK directly (plane finding only; no Geospatial / VPS, no cloud anchors), so it works
 * indoors and needs no network. Rendering is plain OpenGL ES 2.0 in a [GLSurfaceView] ([ArRenderer]).
 *
 * Per-view channel `tasuku_ar/arview_<id>`:
 *  - Dart -> native: `setTurn` (left / right / straight), `setYawOffset` (deg, clockwise: route bearing
 *    minus the current compass heading; applied when the arrow is (re)placed), `getStatus`
 *  - native -> Dart: `onStatus` {state, reason}; see [ArRenderer] for the states.
 */
class ArGuideView(
    private val activity: Activity,
    messenger: BinaryMessenger,
    id: Int,
    params: Map<String, Any?>?,
) : PlatformView, MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "tasuku_ar/arview_$id")
    private val mainHandler = Handler(Looper.getMainLooper())
    private val surfaceView = GLSurfaceView(activity)
    private val renderer: ArRenderer
    private var session: Session? = null
    private var resumed = false
    private var disposed = false
    private var lastStatus: Map<String, Any?> = mapOf("state" to ArRenderer.STATE_INITIALIZING)

    init {
        channel.setMethodCallHandler(this)
        renderer = ArRenderer(activity, Turn.parse(params?.get("turn") as? String)) { state, reason ->
            mainHandler.post { sendStatus(state, reason) }
        }
        session = createSession()
        renderer.session = session

        surfaceView.preserveEGLContextOnPause = true
        surfaceView.setEGLContextClientVersion(2)
        surfaceView.setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        surfaceView.setRenderer(renderer)
        surfaceView.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY

        // Screen-on is set app-wide in MainActivity (compass mode needs it too).
        current = this
        resume()
    }

    private fun createSession(): Session? = try {
        Session(activity).also { s ->
            val config = Config(s).apply {
                planeFindingMode = Config.PlaneFindingMode.HORIZONTAL
                focusMode = Config.FocusMode.AUTO
                updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                lightEstimationMode = Config.LightEstimationMode.DISABLED
                geospatialMode = Config.GeospatialMode.DISABLED
                cloudAnchorMode = Config.CloudAnchorMode.DISABLED
                depthMode = Config.DepthMode.DISABLED
            }
            s.configure(config)
        }
    } catch (e: UnavailableDeviceNotCompatibleException) {
        sendStatus(ArRenderer.STATE_UNSUPPORTED, "device")
        null
    } catch (e: UnavailableException) {
        sendStatus(ArRenderer.STATE_UNSUPPORTED, e.javaClass.simpleName)
        null
    } catch (e: Exception) {
        sendStatus(ArRenderer.STATE_ERROR, e.javaClass.simpleName)
        null
    }

    fun resume() {
        if (disposed || resumed) return
        val s = session ?: return
        try {
            s.resume()
        } catch (e: CameraNotAvailableException) {
            sendStatus(ArRenderer.STATE_ERROR, "camera")
            return
        } catch (e: Exception) {
            sendStatus(ArRenderer.STATE_ERROR, e.javaClass.simpleName)
            return
        }
        surfaceView.onResume()
        resumed = true
    }

    fun pause() {
        if (!resumed) return
        // Stop the GL thread first (blocks until it is paused), then the session, as in the ARCore samples.
        surfaceView.onPause()
        session?.pause()
        resumed = false
    }

    override fun getView(): View = surfaceView

    override fun dispose() {
        if (disposed) return
        pause()
        disposed = true
        renderer.session = null
        session?.close()
        session = null
        channel.setMethodCallHandler(null)
        if (current === this) current = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setTurn" -> {
                renderer.setTurn(Turn.parse(call.arguments as? String))
                result.success(null)
            }
            "setYawOffset" -> {
                renderer.yawOffsetDeg = (call.arguments as? Number)?.toFloat() ?: 0f
                result.success(null)
            }
            "getStatus" -> result.success(lastStatus)
            else -> result.notImplemented()
        }
    }

    private fun sendStatus(state: String, reason: String?) {
        if (disposed) return
        val status = mapOf("state" to state, "reason" to reason)
        if (status == lastStatus) return
        lastStatus = status
        channel.invokeMethod("onStatus", status)
    }

    companion object {
        const val VIEW_TYPE = "tasuku_ar/arview"

        /** The view that receives the activity's onResume / onPause (only one AR view at a time). */
        var current: ArGuideView? = null
            private set
    }
}
