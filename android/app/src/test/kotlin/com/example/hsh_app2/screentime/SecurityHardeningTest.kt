package com.example.hsh_app2.screentime

import com.example.hsh_app2.screentime.ProtectedScreens.TamperKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SecurityHardeningTest {

    @Test
    fun `tamperScreenKind identifies device admin, usage access, overlay, and date-time across OEMs`() {
        assertEquals(
            TamperKind.DEVICE_ADMIN,
            ProtectedScreens.tamperScreenKind(
                "com.coloros.settings",
                "com.android.settings.applications.specialaccess.deviceadmin.DeviceAdminAdd",
            ),
        )
        assertEquals(
            TamperKind.USAGE_ACCESS,
            ProtectedScreens.tamperScreenKind(
                "com.android.settings",
                "com.android.settings.Settings\$UsageAccessSettingsActivity",
            ),
        )
        assertEquals(
            TamperKind.OVERLAY,
            ProtectedScreens.tamperScreenKind(
                "com.samsung.android.settings",
                "com.android.settings.Settings\$ManageOverlayActivity",
            ),
        )
        assertEquals(
            TamperKind.OVERLAY,
            ProtectedScreens.tamperScreenKind(
                "com.samsung.android.settings",
                "com.android.settings.Settings\$OverlaySettingsActivity",
            ),
        )
        assertEquals(
            TamperKind.OVERLAY,
            ProtectedScreens.tamperScreenKind(
                "com.samsung.android.settings",
                "com.samsung.android.settings.applications.AppDrawOverlaySettingsActivity",
            ),
        )
        assertEquals(
            TamperKind.OVERLAY,
            ProtectedScreens.tamperScreenKind(
                "com.samsung.android.settings",
                "com.samsung.android.settings.AppearOnTopActivity",
            ),
        )
        assertEquals(
            TamperKind.USAGE_ACCESS,
            ProtectedScreens.tamperScreenKind(
                "com.samsung.android.settings",
                "com.samsung.android.settings.UsageDataSettingsActivity",
            ),
        )
        assertEquals(
            TamperKind.DATE_TIME,
            ProtectedScreens.tamperScreenKind(
                "com.oplus.settings",
                "com.android.settings.DateTimeSettingsActivity",
            ),
        )
        assertEquals(
            TamperKind.DEVELOPER_OPTIONS,
            ProtectedScreens.tamperScreenKind(
                "com.android.settings",
                "com.android.settings.Settings\$DevelopmentSettingsDashboardActivity",
            ),
        )
        assertNull(
            ProtectedScreens.tamperScreenKind(
                "com.android.settings",
                "com.android.settings.SubSettings",
            ),
        )
    }

    @Test
    fun `browser and sideload installer sets cover common bypass packages`() {
        assertTrue("com.android.chrome" in PolicyEvaluator.BROWSER_PACKAGES)
        assertTrue("com.brave.browser" in PolicyEvaluator.BROWSER_PACKAGES)
        assertTrue("com.sec.android.app.sbrowser" in PolicyEvaluator.BROWSER_PACKAGES)
        assertTrue("com.aefyr.sai" in PolicyEvaluator.INSTALLER_PACKAGES)
        assertTrue("com.coloros.appmarket" in PolicyEvaluator.INSTALLER_PACKAGES)
    }
}
