package com.example.rooted

import android.annotation.TargetApi
import android.os.Build
import android.os.Bundle
import android.view.View
import android.window.SplashScreenView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.time.Duration
import java.time.Instant

/**
 * Hands the launch splash over to the Flutter opening without a jump.
 *
 * On Android 12+ the splash plays the animated sleeping kuwago
 * (res/drawable/splash_lockup_anim.xml). Normally Android removes it the
 * moment Flutter draws its first frame — possibly mid-animation. Instead we
 * keep it on screen, tell Flutter exactly where the owl is, and only
 * remove it once its animation has finished AND Flutter asks (by then
 * Flutter is showing the identical picture underneath).
 *
 * Channel "kuwago/splash" (see lib/services/splash_bridge.dart):
 *   iconCenter → {x, y} in Flutter logical pixels, or null if
 *                there's no splash (older Android, hot restart)
 *   remove     → removes the splash once its animation has finished
 */
class MainActivity : FlutterActivity() {
    private var splash: View? = null // a SplashScreenView (Android 12+)
    private var splashGone = false
    private var pendingCenter: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) listenForSplash()
    }

    @TargetApi(Build.VERSION_CODES.S)
    private fun listenForSplash() {
        splashScreen.setOnExitAnimationListener { view ->
            splash = view
            pendingCenter?.let { answerCenter(it) }
            pendingCenter = null
            // Safety net: never leave the splash up if Flutter doesn't ask.
            view.postDelayed({ removeNow() }, 4000)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kuwago/splash")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "iconCenter" -> when {
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.S || splashGone -> result.success(null)
                        splash != null -> answerCenter(result)
                        else -> pendingCenter = result // splash not handed over yet
                    }
                    "remove" -> removeAfterAnimation(result)
                    else -> result.notImplemented()
                }
            }
    }

    /** Where the owl (centre of the splash icon) is, in Flutter's coordinates. */
    @TargetApi(Build.VERSION_CODES.S)
    private fun answerCenter(result: MethodChannel.Result) {
        val icon = (splash as? SplashScreenView)?.iconView
        val content = findViewById<View>(android.R.id.content)
        if (icon == null || content == null) {
            result.success(null)
            return
        }
        val iconAt = IntArray(2).also { icon.getLocationOnScreen(it) }
        val contentAt = IntArray(2).also { content.getLocationOnScreen(it) }
        val density = resources.displayMetrics.density
        result.success(
            mapOf(
                "x" to ((iconAt[0] - contentAt[0] + icon.width / 2f) / density).toDouble(),
                "y" to ((iconAt[1] - contentAt[1] + icon.height / 2f) / density).toDouble(),
            )
        )
    }

    private fun removeAfterAnimation(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            result.success(null)
            return
        }
        val view = splash as? SplashScreenView
        if (view == null) {
            result.success(null)
            return
        }
        view.postDelayed({
            removeNow()
            result.success(null)
        }, millisUntilAnimationEnds(view))
    }

    @TargetApi(Build.VERSION_CODES.S)
    private fun millisUntilAnimationEnds(view: SplashScreenView): Long {
        val start = view.iconAnimationStart ?: return 0
        val length = view.iconAnimationDuration ?: return 0
        return Duration.between(Instant.now(), start.plus(length)).toMillis().coerceAtLeast(0)
    }

    @TargetApi(Build.VERSION_CODES.S)
    private fun removeNow() {
        val view = splash as? SplashScreenView ?: return
        splash = null
        splashGone = true
        view.remove()
    }
}
