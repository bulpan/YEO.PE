package com.yeope.app.core.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.os.ParcelUuid
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class BLEScanner @Inject constructor(
    private val adapter: BluetoothAdapter?
) {

    private var scanner: BluetoothLeScanner? = null
    private var scanCallback: ScanCallback? = null
    
    // We expose discovered devices as a flow of results
    private val _discoveredDevices = MutableStateFlow<List<ScanResult>>(emptyList())
    val discoveredDevices = _discoveredDevices.asStateFlow()

    private val SERVICE_UUID = UUID.fromString("00001E00-0000-1000-8000-00805F9B34FB") // Must match iOS

    @SuppressLint("MissingPermission")
    fun startScanning() {
        if (adapter == null || !adapter.isEnabled) {
            Log.e("BLEScanner", "Bluetooth is not enabled")
            return
        }

        scanner = adapter.bluetoothLeScanner

        val filters = listOf(
            ScanFilter.Builder()
                .setServiceUuid(ParcelUuid(SERVICE_UUID))
                .build()
        )

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY) // High duty cycle for foreground
            .setReportDelay(0) // Immediate reporting
            .build()

        scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                handleScanResult(result)
            }

            override fun onBatchScanResults(results: MutableList<ScanResult>) {
                results.forEach { handleScanResult(it) }
            }

            override fun onScanFailed(errorCode: Int) {
                Log.e("BLEScanner", "Scan failed with error: $errorCode")
            }
        }

        scanner?.startScan(filters, settings, scanCallback)
        Log.d("BLEScanner", "Started scanning for Service UUID: $SERVICE_UUID")
    }

    @SuppressLint("MissingPermission")
    fun stopScanning() {
        if (scanner != null && scanCallback != null && adapter?.isEnabled == true) {
            scanner?.stopScan(scanCallback)
            Log.d("BLEScanner", "Stopped scanning")
        }
        scanCallback = null
    }

    private fun handleScanResult(result: ScanResult) {
        val currentList = _discoveredDevices.value.toMutableList()
        
        // Basic deduping by address for now (improve later to update RSSI/Timestamp)
        val index = currentList.indexOfFirst { it.device.address == result.device.address }
        if (index != -1) {
            currentList[index] = result
        } else {
            currentList.add(result)
        }
        
        _discoveredDevices.value = currentList
        Log.v("BLEScanner", "Discovered: ${result.device.address} RSSI: ${result.rssi}")
    }
}
