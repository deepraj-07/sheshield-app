package com.sheshield.app.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BootReceiver — listens for BOOT_COMPLETED broadcast.
 * Re-initializes any background services that need to restart after device reboot.
 * Currently a stub — extend when background services are implemented.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d(TAG, "Device booted — SheShield BootReceiver triggered")
            // TODO: Restart background services here when implemented
            // e.g., restart journey mode monitoring, re-arm SOS listeners
        }
    }

    companion object {
        private const val TAG = "SheShield:BootReceiver"
    }
}
