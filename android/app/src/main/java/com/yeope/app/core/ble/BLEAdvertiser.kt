package com.yeope.app.core.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.os.ParcelUuid
import android.util.Log
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class BLEAdvertiser @Inject constructor(
    private val adapter: BluetoothAdapter?
) {

    private var advertiser: BluetoothLeAdvertiser? = null
    private var advertiseCallback: AdvertiseCallback? = null
    
    private val SERVICE_UUID = UUID.fromString("00001E00-0000-1000-8000-00805F9B34FB")

    @SuppressLint("MissingPermission")
    fun startAdvertising(uid: String) {
        if (adapter == null || !adapter.isEnabled) {
            Log.e("BLEAdvertiser", "Bluetooth is not enabled")
            return
        }

        advertiser = adapter.bluetoothLeAdvertiser
        if (advertiser == null) {
            Log.e("BLEAdvertiser", "Device does not support broadcasting")
            return
        }

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(true)
            .build()
            
        // Protocol: Advertise Service UUID and put UID in LocalName 
        // Note: Android LocalName is limited in length (approx 8 bytes in legacy adv).
        // Since YEO.PE UIDs might be longer or random, we might need a different strategy.
        // For compatibility with iOS "Overflow Area" scanning, we just need the Service UUID.
        // The actual identity exchange might happen via Characteristic Read (GATT Server).
        // For now, let's stick to the basic Service UUID advertisement.
        
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false) // Save space
            .addServiceUuid(ParcelUuid(SERVICE_UUID))
            // .addServiceData(...) // Could add truncated UID here if needed
            .build()

        advertiseCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                Log.d("BLEAdvertiser", "Advertising started successfully")
            }

            override fun onStartFailure(errorCode: Int) {
                Log.e("BLEAdvertiser", "Advertising failed: $errorCode")
            }
        }

        advertiser?.startAdvertising(settings, data, advertiseCallback)
    }

    @SuppressLint("MissingPermission")
    fun stopAdvertising() {
        if (advertiser != null && advertiseCallback != null && adapter?.isEnabled == true) {
            advertiser?.stopAdvertising(advertiseCallback)
            Log.d("BLEAdvertiser", "Stopped advertising")
        }
        advertiseCallback = null
    }
}
