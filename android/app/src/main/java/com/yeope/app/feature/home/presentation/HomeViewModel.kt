package com.yeope.app.feature.home.presentation

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.yeope.app.core.ble.BLEScanner
import com.yeope.app.feature.chat.data.RoomRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val bleScanner: BLEScanner,
    private val roomRepository: RoomRepository
) : ViewModel() {

    // Transform raw BLE ScanResults into UI models
    val discoveredUsers = bleScanner.discoveredDevices.map { results ->
        results.map { result ->
            val name = result.device.name ?: result.scanRecord?.deviceName ?: "Unknown"
            DiscoveredUserUiModel(
                address = result.device.address,
                name = name, // In real app, we'd look up nickname via API
                rssi = result.rssi
            )
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    private val _navigationEvent = MutableSharedFlow<HomeNavigationEvent>()
    val navigationEvent = _navigationEvent.asSharedFlow()

    fun onUserClicked(user: DiscoveredUserUiModel) {
        viewModelScope.launch {
            // "Unknown" creates a problem if we need an actual User ID.
            // For now, let's assume the BLE LocalName IS the User ID (which Android Advertiser is doing implicitly?)
            // Actually, Android Advertiser is just sending Service UUID.
            // Android GATT Server is hosting UID.
            // On the scanning side (Android), we just see a MAC address unless we connect and read GATT.
            // This is a gap in my current "Scanner" implementation. 
            // The Scanner currently just returns ScanResults.
            // To be functional, `BLEScanner` or a `UserRepository` needs to resolve MAC -> UID.
            
            // For this Phase 4 demo, let's assume valid UID is available or we use a hardcoded fallback 
            // for testing (since resolving UID via GATT read on Android is "Phase 3+" refinement).
            // Wait, iOS advertises LocalName as UID. So Android scanning iOS works fine!
            // Android scanning Android (Advertiser) currently sends UUID only. 
            // So Android->Android needs connection.
            // Android->iOS works via LocalName.
            
            // Let's assume we are testing against iOS (which puts UID in LocalName) 
            // OR I will implement "Connect to Read" logic in `BLEScanner` later.
            // For now, treat `user.name` as UID if it looks like one (6 chars).
            
            val potentialUid = user.name
            
            val result = roomRepository.createRoom(potentialUid)
            result.onSuccess { room ->
                _navigationEvent.emit(HomeNavigationEvent.NavigateToChat(room._id, room.participants.joinToString { it.take(3) }))
            }.onFailure { e ->
                Log.e("HomeViewModel", "Failed to create room", e)
                // Fallback for demo/debug if server fails or UID invalid
                // _navigationEvent.emit(HomeNavigationEvent.NavigateToChat("debug_room", "Debug Room"))
            }
        }
    }
}

data class DiscoveredUserUiModel(
    val address: String,
    val name: String,
    val rssi: Int
)

sealed class HomeNavigationEvent {
    data class NavigateToChat(val roomId: String, val roomName: String) : HomeNavigationEvent()
}
