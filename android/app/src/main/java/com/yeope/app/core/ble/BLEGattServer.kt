package com.yeope.app.core.ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.content.Context
import android.util.Log
import dagger.hilt.android.qualifiers.ApplicationContext
import java.nio.charset.Charset
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class BLEGattServer @Inject constructor(
    @ApplicationContext private val context: Context,
    private val bluetoothManager: BluetoothManager
) {

    private var gattServer: BluetoothGattServer? = null
    private var currentUID: String? = null

    private val SERVICE_UUID = UUID.fromString("00001E00-0000-1000-8000-00805F9B34FB")
    private val CHARACTERISTIC_UUID = UUID.fromString("00001E01-0000-1000-8000-00805F9B34FB")

    @SuppressLint("MissingPermission")
    fun startServer(uid: String) {
        currentUID = uid
        
        if (gattServer != null) {
            // Already running, just update UID
            return
        }

        gattServer = bluetoothManager.openGattServer(context, gattServerCallback)
        if (gattServer == null) {
            Log.e("BLEGattServer", "Unable to open GATT Server")
            return
        }

        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        
        // Read-only characteristic
        val characteristic = BluetoothGattCharacteristic(
            CHARACTERISTIC_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        )

        service.addCharacteristic(characteristic)
        gattServer?.addService(service)
        Log.d("BLEGattServer", "GATT Server started. Hosting UID: $uid")
    }

    @SuppressLint("MissingPermission")
    fun stopServer() {
        gattServer?.clearServices()
        gattServer?.close()
        gattServer = null
        Log.d("BLEGattServer", "GATT Server stopped")
    }

    private val gattServerCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice?, status: Int, newState: Int) {
            Log.v("BLEGattServer", "Connection State Changed: $newState for ${device?.address}")
            super.onConnectionStateChange(device, status, newState)
        }

        @SuppressLint("MissingPermission")
        override fun onCharacteristicReadRequest(
            device: BluetoothDevice?,
            requestId: Int,
            offset: Int,
            characteristic: BluetoothGattCharacteristic?
        ) {
            super.onCharacteristicReadRequest(device, requestId, offset, characteristic)

            if (characteristic?.uuid == CHARACTERISTIC_UUID) {
                Log.d("BLEGattServer", "Read Request from ${device?.address}")
                
                val value = currentUID?.toByteArray(Charset.forName("UTF-8")) ?: ByteArray(0)
                
                // Handle offset if needed (UID is short so typically fine)
                if (offset >= value.size) {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, ByteArray(0))
                    return
                }

                val slicedValue = value.copyOfRange(offset, value.size)
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, slicedValue)
            } else {
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, offset, null)
            }
        }
    }
}
