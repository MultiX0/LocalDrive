package app.localdrive

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager

/**
 * "This person, on this network, right now."
 *
 * Advertised over mDNS while a sharing screen is open, and never otherwise.
 * Broadcasting your presence at all times is not something an app should do
 * without asking, and it would cost battery for nothing the rest of the time.
 *
 * This changes discovery and presentation only. The share itself is still a
 * permission grant against the server, so the person on the other end gets an
 * ongoing shared item they can open next week from a different device, not a
 * one-off copy beamed between two phones.
 */
class PresenceBeacon(private val context: Context) {

    private var nsdManager: NsdManager? = null
    private var listener: NsdManager.RegistrationListener? = null
    private var multicastLock: WifiManager.MulticastLock? = null

    fun start(displayName: String, userId: String, avatarSeed: String) {
        if (listener != null) stop()

        // Android drops multicast packets by default to save power, so
        // discovering anyone else requires holding this open for the duration
        val wifi = context.applicationContext
            .getSystemService(Context.WIFI_SERVICE) as WifiManager
        multicastLock = wifi.createMulticastLock(LOCK_NAME).apply {
            setReferenceCounted(true)
            acquire()
        }

        val info = NsdServiceInfo().apply {
            // the instance name is what other devices see before they resolve
            // the record, so it carries nothing private
            serviceName = "ld-${userId.take(8)}"
            serviceType = SERVICE_TYPE
            port = PRESENCE_PORT
            setAttribute("name", displayName)
            setAttribute("uid", userId)
            setAttribute("seed", avatarSeed)
        }

        val registration = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(info: NsdServiceInfo) = Unit
            override fun onRegistrationFailed(info: NsdServiceInfo, code: Int) = Unit
            override fun onServiceUnregistered(info: NsdServiceInfo) = Unit
            override fun onUnregistrationFailed(info: NsdServiceInfo, code: Int) = Unit
        }
        listener = registration

        nsdManager = (context.getSystemService(Context.NSD_SERVICE) as NsdManager).also {
            it.registerService(info, NsdManager.PROTOCOL_DNS_SD, registration)
        }
    }

    fun stop() {
        listener?.let { current ->
            // unregistering can throw if registration never completed, which
            // is not worth crashing over when the screen is already closing
            runCatching { nsdManager?.unregisterService(current) }
        }
        listener = null
        nsdManager = null

        runCatching { multicastLock?.release() }
        multicastLock = null
    }

    companion object {
        const val SERVICE_TYPE = "_ldpeer._tcp"

        /**
         * Nothing listens on it. mDNS requires a port in the SRV record, and
         * the beacon is presence only: the actual share goes through the
         * server, so there is no socket for anyone to connect to here.
         */
        private const val PRESENCE_PORT = 7444

        private const val LOCK_NAME = "localdrive-presence"
    }
}
