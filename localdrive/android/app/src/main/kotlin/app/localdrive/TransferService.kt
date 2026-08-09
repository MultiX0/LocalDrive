package app.localdrive

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Keeps uploads and downloads running while the app is not on screen.
 *
 * Android will kill a backgrounded process whenever it wants unless something
 * declares that work is genuinely in progress. A foreground service with a
 * visible notification is that declaration, and it is also honest: the person
 * can see at a glance that this app is still moving their files, and stop it.
 *
 * The service holds no transfer state of its own. Dart owns the queue and
 * tells this what to display, so there is exactly one source of truth about
 * what is happening and the notification can never disagree with the screen.
 */
class TransferService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE).orEmpty()
        val body = intent?.getStringExtra(EXTRA_BODY).orEmpty()
        val progress = intent?.getIntExtra(EXTRA_PROGRESS, 0) ?: 0
        val indeterminate = intent?.getBooleanExtra(EXTRA_INDETERMINATE, true) ?: true

        val notification = build(this, title, body, progress, indeterminate)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        // if Android kills the process mid transfer, do not resurrect the
        // service on its own. The queue is durable, so the app picks up from
        // the last acknowledged byte when it is next opened, and a zombie
        // notification with no app behind it would be worse than nothing
        return START_NOT_STICKY
    }

    companion object {
        private const val CHANNEL_ID = "transfers"
        private const val NOTIFICATION_ID = 1001
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_BODY = "body"
        private const val EXTRA_PROGRESS = "progress"
        private const val EXTRA_INDETERMINATE = "indeterminate"

        fun start(context: Context, title: String, body: String) {
            ensureChannel(context)
            val intent = Intent(context, TransferService::class.java)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_BODY, body)
                .putExtra(EXTRA_INDETERMINATE, true)
            context.startForegroundService(intent)
        }

        fun update(
            context: Context,
            title: String,
            body: String,
            progress: Int,
            indeterminate: Boolean,
        ) {
            ensureChannel(context)
            // the notification is updated directly rather than by restarting
            // the service, so the progress bar animates instead of blinking
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(
                NOTIFICATION_ID,
                build(context, title, body, progress, indeterminate),
            )
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, TransferService::class.java))
        }

        private fun build(
            context: Context,
            title: String,
            body: String,
            progress: Int,
            indeterminate: Boolean,
        ): Notification {
            // tapping it opens the app rather than doing nothing, which is the
            // only thing anyone ever tries with a progress notification
            val open = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pending = PendingIntent.getActivity(
                context,
                0,
                open,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )

            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(body)
                .setSmallIcon(android.R.drawable.stat_sys_upload)
                .setContentIntent(pending)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setProgress(100, progress, indeterminate)
                .setCategory(NotificationCompat.CATEGORY_PROGRESS)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .build()
        }

        private fun ensureChannel(context: Context) {
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) != null) return

            // low importance on purpose: a transfer running is information, not
            // an interruption, so it never makes a sound
            val channel = NotificationChannel(
                CHANNEL_ID,
                "File transfers",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Shows uploads and downloads that are still running."
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }
    }
}
