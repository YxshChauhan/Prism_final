package com.airlink.airlink_4

import android.content.Context

/**
 * Placeholder BleTransferManager extracted from AirLinkPlugin responsibilities.
 * TODO(native-refactor): Move BLE transfer logic here without changing channel API.
 */
class BleTransferManager(private val context: Context) {
    fun startTransfer(params: Map<String, Any?>): String {
        // TODO: implement using existing BleAdvertiser / GATT server
        return ""
    }

    fun stopTransfer(transferId: String) {
        // TODO: implement
    }
}


