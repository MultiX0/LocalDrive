package app.localdrive

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.WorkManager

/**
 * Wakes the app once the network comes back, so a transfer that failed while
 * the device was offline resumes without anyone having to reopen the app.
 *
 * It does no transferring itself. WorkManager cannot run Dart code, and
 * duplicating the queue in Kotlin would mean two implementations of resumable
 * uploads that have to agree forever. Instead this exists purely to be
 * scheduled with a connectivity constraint: Android runs it when there is a
 * network, it starts the app's transfer service, and the real queue in Dart
 * picks up from its last acknowledged byte.
 */
class TransferRetryWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {

    override fun doWork(): Result {
        TransferService.start(
            applicationContext,
            "Local Drive",
            "Resuming transfers",
        )
        return Result.success()
    }

    companion object {
        private const val WORK_NAME = "transfer-retry"

        fun schedule(context: Context) {
            val request = OneTimeWorkRequestBuilder<TransferRetryWorker>()
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build(),
                )
                .build()

            // REPLACE, not APPEND: several failures while offline should mean
            // one wake up when the network returns, not one per failed item
            WorkManager.getInstance(context).enqueueUniqueWork(
                WORK_NAME,
                ExistingWorkPolicy.REPLACE,
                request,
            )
        }
    }
}
