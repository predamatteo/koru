package com.dev.koru.channels

import com.dev.koru.channels.blocking.AppActionsCallHandler
import com.dev.koru.channels.blocking.AppInventoryCallHandler
import com.dev.koru.channels.blocking.DeviceInfoCallHandler
import com.dev.koru.channels.blocking.LimitsCallHandler
import com.dev.koru.channels.blocking.NotificationFilterCallHandler
import com.dev.koru.channels.blocking.QuickBlockCallHandler
import com.dev.koru.channels.blocking.ServiceLifecycleCallHandler
import com.dev.koru.channels.blocking.UsageStatsCallHandler
import com.dev.koru.channels.blocking.WifiCallHandler
import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * ARCH-09 — verifica che la decomposizione del god-facade
 * [BlockingMethodChannel] in handler per-concern NON abbia perso, rinominato o
 * duplicato nessun metodo del canale `com.koru/blocking`.
 *
 * [BlockingMethodChannel.routingTable] è la mappa autoritativa `method ->
 * handler` che il router consulta a runtime. Qui asseriamo:
 *  - il set ESATTO dei 29 method name pre-refactor è presente (nessuno
 *    droppato, nessuno aggiunto / rinominato per sbaglio);
 *  - ogni metodo è instradato all'handler del concern corretto (vecchio `when`
 *    case → nuovo handler);
 *  - nessuna collisione (la `check` in `routingTable` fallirebbe già a build —
 *    qui ribadiamo che ogni handler possiede esattamente i suoi metodi).
 *
 * È un test PURO: tocca solo i set `methods` degli handler (nessun Android /
 * Robolectric / Keystore), quindi gira ovunque.
 */
class BlockingMethodChannelRoutingTest {

    /// I 29 method name che il canale `com.koru/blocking` esponeva PRIMA della
    /// decomposizione (snapshot del `when` storico). È il contratto di wire:
    /// se cambia, il Dart-side / un altro runtime si rompe con
    /// MissingPluginException o notImplemented.
    private val expectedWireMethods = setOf(
        // service lifecycle
        "startBlockingService",
        "stopBlockingService",
        "isBlockingServiceRunning",
        // app inventory
        "getInstalledApps",
        "getInstalledPackageNames",
        "getLauncherPackageNames",
        // usage stats
        "getUsageStats",
        "getUsageStatsByDay",
        "getUsageTodayMs",
        // quick block / pomodoro
        "startQuickBlock",
        "stopQuickBlock",
        "startPomodoro",
        "stopPomodoro",
        // app actions
        "launchApp",
        "uninstallApp",
        "openAppInfo",
        // device info
        "getBatteryLevel",
        "isCharging",
        "getDefaultDialerPackage",
        "getDefaultCameraPackage",
        // daily limits + bypass
        "getAppDailyLimits",
        "setAppDailyLimits",
        "getBypassCountToday",
        "resetBypassCount",
        // notification filter
        "getSilencedPackages",
        "setSilencedPackages",
        "isNotificationAccessGranted",
        "openNotificationAccessSettings",
        // wifi
        "getCurrentWifiSsid",
    )

    @Test
    fun routingTable_coversExactlyTheWireMethods_noneDroppedNoneAdded() {
        assertThat(BlockingMethodChannel.routingTable.keys)
            .containsExactlyElementsIn(expectedWireMethods)
    }

    @Test
    fun routingTable_hasExactly29Methods() {
        // Sentinella sul numero: se un futuro metodo viene aggiunto senza
        // aggiornare questo test, il count diverge e il test fallisce,
        // forzando una rivisitazione consapevole del wire-contract.
        assertThat(BlockingMethodChannel.routingTable).hasSize(29)
    }

    @Test
    fun eachMethod_routesToItsConcernHandler() {
        val table = BlockingMethodChannel.routingTable

        // service lifecycle
        assertThat(table["startBlockingService"]).isEqualTo(ServiceLifecycleCallHandler)
        assertThat(table["stopBlockingService"]).isEqualTo(ServiceLifecycleCallHandler)
        assertThat(table["isBlockingServiceRunning"]).isEqualTo(ServiceLifecycleCallHandler)

        // app inventory
        assertThat(table["getInstalledApps"]).isEqualTo(AppInventoryCallHandler)
        assertThat(table["getInstalledPackageNames"]).isEqualTo(AppInventoryCallHandler)
        assertThat(table["getLauncherPackageNames"]).isEqualTo(AppInventoryCallHandler)

        // usage stats
        assertThat(table["getUsageStats"]).isEqualTo(UsageStatsCallHandler)
        assertThat(table["getUsageStatsByDay"]).isEqualTo(UsageStatsCallHandler)
        assertThat(table["getUsageTodayMs"]).isEqualTo(UsageStatsCallHandler)

        // quick block / pomodoro
        assertThat(table["startQuickBlock"]).isEqualTo(QuickBlockCallHandler)
        assertThat(table["stopQuickBlock"]).isEqualTo(QuickBlockCallHandler)
        assertThat(table["startPomodoro"]).isEqualTo(QuickBlockCallHandler)
        assertThat(table["stopPomodoro"]).isEqualTo(QuickBlockCallHandler)

        // app actions
        assertThat(table["launchApp"]).isEqualTo(AppActionsCallHandler)
        assertThat(table["uninstallApp"]).isEqualTo(AppActionsCallHandler)
        assertThat(table["openAppInfo"]).isEqualTo(AppActionsCallHandler)

        // device info
        assertThat(table["getBatteryLevel"]).isEqualTo(DeviceInfoCallHandler)
        assertThat(table["isCharging"]).isEqualTo(DeviceInfoCallHandler)
        assertThat(table["getDefaultDialerPackage"]).isEqualTo(DeviceInfoCallHandler)
        assertThat(table["getDefaultCameraPackage"]).isEqualTo(DeviceInfoCallHandler)

        // daily limits + bypass
        assertThat(table["getAppDailyLimits"]).isEqualTo(LimitsCallHandler)
        assertThat(table["setAppDailyLimits"]).isEqualTo(LimitsCallHandler)
        assertThat(table["getBypassCountToday"]).isEqualTo(LimitsCallHandler)
        assertThat(table["resetBypassCount"]).isEqualTo(LimitsCallHandler)

        // notification filter
        assertThat(table["getSilencedPackages"]).isEqualTo(NotificationFilterCallHandler)
        assertThat(table["setSilencedPackages"]).isEqualTo(NotificationFilterCallHandler)
        assertThat(table["isNotificationAccessGranted"]).isEqualTo(NotificationFilterCallHandler)
        assertThat(table["openNotificationAccessSettings"]).isEqualTo(NotificationFilterCallHandler)

        // wifi
        assertThat(table["getCurrentWifiSsid"]).isEqualTo(WifiCallHandler)
    }

    @Test
    fun unknownMethod_isNotInRoutingTable() {
        // Un metodo sconosciuto non è in tabella → il router risponde
        // notImplemented() (come il vecchio `else` del when).
        assertThat(BlockingMethodChannel.routingTable["doesNotExist"]).isNull()
    }
}
