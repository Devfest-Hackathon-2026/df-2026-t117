package jp.tasuku.ar_guide

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.view.WindowManager
import com.google.ar.core.ArCoreApk
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import jp.tasuku.ar_guide.ar.ArGuideView
import jp.tasuku.ar_guide.ar.ArGuideViewFactory

/**
 * Hosts the Flutter UI.
 *
 * Channels:
 *  - `tasuku_ar/link`: deep links (`tasuku-ar://guide?...`). Dart asks for the initial link; later links
 *    (the activity is singleTop) are pushed with `onLink`.
 *  - `tasuku_ar/ar`: `prepare` (camera permission + ARCore availability) and `openAppSettings`.
 *  - `tasuku_ar/orientation`: compass heading + camera tilt ([OrientationStream]).
 *  - `tasuku_ar/tilt`: camera tilt only, for "device raised -> AR" (F36, [TiltStream]).
 *  - `tasuku_ar/vibrate`: `vibrate` with a pattern of [on, off, on, ...] ms, as the web's navigator.vibrate.
 *  - platform view `tasuku_ar/arview`: ARCore camera image with the floor arrow ([ArGuideView]), used only
 *    on ARCore-supported devices. Elsewhere (e.g. AQUOS wish4) Dart uses the `camera` plugin + compass.
 */
class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var linkChannel: MethodChannel? = null
    private var pendingPermission: MethodChannel.Result? = null
    private var initialLink: String? = null
    private var orientation: OrientationStream? = null
    private var tilt: TiltStream? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        initialLink = intent?.data?.toString()
        super.onCreate(savedInstanceState)
        // The whole app is the guidance screen: keep the display on in both compass and ARCore modes.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        flutterEngine.platformViewsController.registry
            .registerViewFactory(ArGuideView.VIEW_TYPE, ArGuideViewFactory(this, messenger))

        linkChannel = MethodChannel(messenger, "tasuku_ar/link").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialLink" -> result.success(initialLink)
                    else -> result.notImplemented()
                }
            }
        }

        MethodChannel(messenger, "tasuku_ar/vibrate").setMethodCallHandler { call, result ->
            when (call.method) {
                "vibrate" -> {
                    vibrate(call.argument<List<Number>>("pattern").orEmpty().map { it.toLong() })
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        orientation = OrientationStream(applicationContext).also {
            EventChannel(messenger, "tasuku_ar/orientation").setStreamHandler(it)
        }
        tilt = TiltStream(applicationContext).also {
            EventChannel(messenger, "tasuku_ar/tilt").setStreamHandler(it)
        }

        MethodChannel(messenger, "tasuku_ar/ar").setMethodCallHandler { call, result ->
            when (call.method) {
                "prepare" -> prepare(call.argument<Boolean>("requestPermission") ?: true, result)
                "openAppSettings" -> {
                    val intent = Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.fromParts("package", packageName, null),
                    )
                    startActivity(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val link = intent.data?.toString() ?: return
        linkChannel?.invokeMethod("onLink", link)
    }

    override fun onResume() {
        super.onResume()
        orientation?.resume()
        tilt?.resume()
        ArGuideView.current?.resume()
    }

    override fun onPause() {
        ArGuideView.current?.pause()
        // Sensors off while in the background (battery); re-registered in onResume.
        orientation?.pause()
        tilt?.pause()
        super.onPause()
    }

    // ---------------------------------------------------------------------------------------------
    // Camera permission + ARCore availability

    /**
     * Result: `{camera: "granted" | "denied" | "blocked", arcore: Boolean}`.
     * `blocked` = denied with "don't ask again" (only Settings can fix it).
     * `arcore` is true only when ARCore is supported AND already installed: ARCore is an optional
     * upgrade (plane finding), so the app never prompts to install it and uses the compass mode instead.
     */
    private fun prepare(requestPermission: Boolean, result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            if (!requestPermission) {
                result.success(mapOf("camera" to "denied", "arcore" to false))
                return
            }
            if (pendingPermission != null) {
                result.error("busy", "A permission request is already showing", null)
                return
            }
            pendingPermission = result
            requestPermissions(arrayOf(Manifest.permission.CAMERA), REQUEST_CAMERA)
            return
        }
        checkArCore(result, 0)
    }

    @Deprecated("Deprecated in Android framework; still the callback used by Activity.requestPermissions")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_CAMERA) return
        val result = pendingPermission ?: return
        pendingPermission = null
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        when {
            granted -> checkArCore(result, 0)
            // false right after a denial = "don't ask again" (or blocked by policy).
            !shouldShowRequestPermissionRationale(Manifest.permission.CAMERA) ->
                result.success(mapOf("camera" to "blocked", "arcore" to false))
            else -> result.success(mapOf("camera" to "denied", "arcore" to false))
        }
    }

    @Suppress("DEPRECATION")
    private fun checkArCore(result: MethodChannel.Result, attempt: Int) {
        val availability = try {
            ArCoreApk.getInstance().checkAvailability(this)
        } catch (e: Exception) {
            ArCoreApk.Availability.UNKNOWN_ERROR
        }
        if (availability.isTransient && attempt < 10) {
            mainHandler.postDelayed({ checkArCore(result, attempt + 1) }, 200)
            return
        }
        val arcore = availability == ArCoreApk.Availability.SUPPORTED_INSTALLED
        result.success(mapOf("camera" to "granted", "arcore" to arcore))
    }

    private companion object {
        const val REQUEST_CAMERA = 0xA7
    }

    @Suppress("DEPRECATION")
    private fun vibrate(pattern: List<Long>) {
        if (pattern.isEmpty()) return
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            getSystemService(VIBRATOR_SERVICE) as Vibrator
        }
        // Android's waveform starts with a wait.
        val timings = (listOf(0L) + pattern).toLongArray()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createWaveform(timings, -1))
        } else {
            vibrator.vibrate(timings, -1)
        }
    }
}
