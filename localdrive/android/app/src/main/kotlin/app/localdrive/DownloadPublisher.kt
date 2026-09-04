package app.localdrive

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import java.io.File

/**
 * Moves a finished download out of the app's own storage and into the phone's
 * Downloads folder.
 *
 * The bytes have to land in app storage first: that is the only place a
 * partial `.part` file can be appended to across restarts, which is what makes
 * a download resumable. But app storage is private, so a file that stays there
 * cannot be opened, shared or found by anything else on the device, which
 * makes "downloaded" mean nothing to the person who asked for it. This is the
 * second half of that trip.
 *
 * From Android 10 the file goes in through MediaStore, which needs no
 * permission and puts it where every file manager already looks. Below that
 * there is no MediaStore collection for downloads, so it is a plain write to
 * the public folder and the caller is expected to have the storage permission
 * by then.
 */
object DownloadPublisher {

    /** The folder inside Downloads, so this app's files stay together. */
    private const val FOLDER = "Local Drive"

    /**
     * True when publishing needs a runtime permission first, which is only the
     * case on the versions that predate MediaStore's downloads collection.
     */
    val needsStoragePermission: Boolean
        get() = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q

    /**
     * Returns where the file ended up, written the way someone would say it
     * out loud, or null if it could not be published at all. Null is not a
     * failure worth surfacing on its own: the bytes are still in app storage
     * and the caller falls back to reporting that path.
     */
    fun publish(context: Context, sourcePath: String, mimeType: String?): String? {
        val source = File(sourcePath)
        if (!source.exists()) return null

        val name = source.name
        val saved = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            publishToMediaStore(context, source, name, mimeType)
        } else {
            publishLegacy(context, source, name)
        } ?: return null

        // the copy in app storage has served its purpose. Leaving it behind
        // would quietly hold on to a second copy of every download
        source.delete()
        return "${Environment.DIRECTORY_DOWNLOADS}/$FOLDER/$saved"
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun publishToMediaStore(
        context: Context,
        source: File,
        name: String,
        mimeType: String?,
    ): String? {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            if (!mimeType.isNullOrEmpty()) {
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            }
            put(
                MediaStore.MediaColumns.RELATIVE_PATH,
                "${Environment.DIRECTORY_DOWNLOADS}/$FOLDER",
            )
            // nothing else gets to see a half written file
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val target = resolver.insert(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            values,
        ) ?: return null

        try {
            resolver.openOutputStream(target).use { out ->
                if (out == null) throw java.io.IOException("no stream for $target")
                source.inputStream().use { it.copyTo(out) }
            }
        } catch (error: Exception) {
            resolver.delete(target, null, null)
            return null
        }

        resolver.update(
            target,
            ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) },
            null,
            null,
        )

        // a name already taken gets a suffix from MediaStore rather than an
        // error, so the name it actually used is the one worth reporting
        return displayName(context, target) ?: name
    }

    private fun displayName(context: Context, uri: Uri): String? {
        val columns = arrayOf(MediaStore.MediaColumns.DISPLAY_NAME)
        context.contentResolver.query(uri, columns, null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) return cursor.getString(0)
            }
        return null
    }

    private fun publishLegacy(context: Context, source: File, name: String): String? {
        val directory = File(
            Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS,
            ),
            FOLDER,
        )
        if (!directory.exists() && !directory.mkdirs()) return null

        val target = availableName(directory, name)
        try {
            source.inputStream().use { input ->
                target.outputStream().use { input.copyTo(it) }
            }
        } catch (error: Exception) {
            target.delete()
            return null
        }

        // without this the file is on disk but absent from every file manager
        // until the next boot
        MediaScannerConnection.scanFile(
            context,
            arrayOf(target.absolutePath),
            null,
            null,
        )
        return target.name
    }

    /**
     * The same rule the rest of the app follows: never overwrite, add a number
     * beside it the way a browser would.
     */
    private fun availableName(directory: File, name: String): File {
        var candidate = File(directory, name)
        if (!candidate.exists()) return candidate

        val dot = name.lastIndexOf('.')
        val stem = if (dot > 0) name.substring(0, dot) else name
        val extension = if (dot > 0) name.substring(dot) else ""
        var counter = 1
        while (candidate.exists()) {
            candidate = File(directory, "$stem ($counter)$extension")
            counter++
        }
        return candidate
    }
}
