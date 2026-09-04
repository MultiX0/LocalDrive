package app.localdrive

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
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

    /** downloads waiting on the storage permission, oldest first */
    private val pendingPublishes =
        mutableListOf<Triple<String, String?, MethodChannel.Result>>()

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

                    // a finished download, still sitting in app storage where
                    // nothing else on the device can reach it
                    "publishDownload" -> {
                        val path = call.argument<String>("path") ?: ""
                        val mimeType = call.argument<String>("mimeType")
                        publishDownload(path, mimeType, result)
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
     * Hands a download to the phone's Downloads folder, asking for the storage
     * permission first on the versions that still need one.
     *
     * A refusal is answered with null rather than an error. The file is not
     * lost, it is simply still in app storage, and the queue reports that path
     * instead of nagging about a permission nobody has to grant.
     */
    private fun publishDownload(
        path: String,
        mimeType: String?,
        result: MethodChannel.Result,
    ) {
        if (path.isEmpty()) {
            result.success(null)
            return
        }

        if (!DownloadPublisher.needsStoragePermission || hasStoragePermission()) {
            result.success(DownloadPublisher.publish(this, path, mimeType))
            return
        }

        // one request at a time. A second download finishing while the sheet
        // is up waits for the answer the first one asked for
        pendingPublishes += Triple(path, mimeType, result)
        if (pendingPublishes.size == 1) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                STORAGE_REQUEST,
            )
        }
    }

    private fun hasStoragePermission(): Boolean =
        ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.WRITE_EXTERNAL_STORAGE,
        ) == PackageManager.PERMISSION_GRANTED

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != STORAGE_REQUEST) return

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        val waiting = pendingPublishes.toList()
        pendingPublishes.clear()
        for ((path, mimeType, result) in waiting) {
            result.success(
                if (granted) DownloadPublisher.publish(this, path, mimeType) else null,
            )
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
        private const val STORAGE_REQUEST = 4711
    }
}
