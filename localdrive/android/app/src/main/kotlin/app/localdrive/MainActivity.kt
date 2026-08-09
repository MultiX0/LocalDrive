package app.localdrive

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The single Android activity.
 *
 * It owns one method channel, which is the only way Dart reaches native code
 * on this platform. Everything behind it is about keeping transfers alive
 * while the app is not on screen, which is the one thing Flutter cannot do on
 * its own.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private val beacon by lazy { PresenceBeacon(applicationContext) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger
        channel = MethodChannel(messenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    // a transfer started, so the process has to survive the app
                    // leaving the screen. Android kills a backgrounded process
                    // freely unless a foreground service says otherwise
                    "startTransferService" -> {
                        val title = call.argument<String>("title") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        TransferService.start(this@MainActivity, title, body)
                        result.success(true)
                    }

                    "updateTransferProgress" -> {
                        val title = call.argument<String>("title") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        val progress = call.argument<Int>("progress") ?: 0
                        val indeterminate =
                            call.argument<Boolean>("indeterminate") ?: false
                        TransferService.update(
                            this@MainActivity,
                            title,
                            body,
                            progress,
                            indeterminate,
                        )
                        result.success(true)
                    }

                    // the queue drained, so the notification and the service go
                    "stopTransferService" -> {
                        TransferService.stop(this@MainActivity)
                        result.success(true)
                    }

                    // presence, advertised only while a sharing screen is open
                    "startPresence" -> {
                        beacon.start(
                            call.argument<String>("name") ?: "",
                            call.argument<String>("userId") ?: "",
                            call.argument<String>("avatarSeed") ?: "",
                        )
                        result.success(true)
                    }

                    "stopPresence" -> {
                        beacon.stop()
                        result.success(true)
                    }

                    "scheduleRetry" -> {
                        TransferRetryWorker.schedule(this@MainActivity)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    /**
     * A deep link that arrived while the app was already running. Flutter's own
     * plugin handles the cold start case; this covers the warm one, which it
     * does not see because the activity is `singleTop` and is reused rather
     * than recreated.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.dataString?.let { channel?.invokeMethod("deepLink", it) }
    }

    /**
     * The beacon never outlives a visible screen, both for battery and because
     * advertising presence in the background is not something this should do
     * without asking.
     */
    override fun onStop() {
        beacon.stop()
        super.onStop()
    }

    override fun onDestroy() {
        beacon.stop()
        channel?.setMethodCallHandler(null)
        channel = null
        super.onDestroy()
    }

    companion object {
        const val CHANNEL = "app.localdrive/platform"
    }
}
