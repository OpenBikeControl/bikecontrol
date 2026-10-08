package de.jonasbark.swiftcontrol

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle

/**
 * Health Connect's "why does BikeControl want this?" link: opens the privacy
 * policy, which explains that rides are written (never read) only after the
 * rider says yes, and finishes.
 */
class HealthPermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://bikecontrol.app/privacy-policy")))
        } catch (e: ActivityNotFoundException) {
            // No browser: nothing else to show; Health Connect stays open.
        }
        finish()
    }
}
