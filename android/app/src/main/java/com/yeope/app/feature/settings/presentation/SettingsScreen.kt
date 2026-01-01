package com.yeope.app.feature.settings.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.yeope.app.ui.theme.DarkSurface
import com.yeope.app.ui.theme.GlassBlack
import com.yeope.app.ui.theme.NeonGreen

fun friendlyEmail(email: String): String {
    return when {
         email.startsWith("apple_") -> "Apple Account"
         email.startsWith("google_") -> "Google Account"
         email.startsWith("kakao_") -> "Kakao Account"
         else -> email
    }
}

@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel = hiltViewModel(),
    onClose: () -> Unit,
    onNavigateToProfileEdit: () -> Unit,
    onNavigateToBlockedUsers: () -> Unit,
    onNavigateToTerms: () -> Unit,
    onNavigateToPrivacy: () -> Unit,
    onNavigateToOpenSource: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    
    // Selection State
    var showLanguageMenu by remember { mutableStateOf(false) }
    var showRetentionMenu by remember { mutableStateOf(false) }
    var showExitMenu by remember { mutableStateOf(false) }

    // Main Container
    Scaffold(
        containerColor = com.yeope.app.ui.theme.DeepBlack,
        topBar = {
            SettingsHeader(onClose = onClose)
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            // 1. Profile Section
            SettingsSection(title = "Profile") {
                ProfileCard(
                    name = uiState.userName,
                    email = friendlyEmail(uiState.userEmail),
                    onClick = onNavigateToProfileEdit
                )
            }

            // 2. UI Section
            SettingsSection(title = "Screen Mode") {
                SettingsToggleRow(
                    label = if (uiState.isDarkMode) "Dark Mode" else "Light Mode",
                    isChecked = uiState.isDarkMode,
                    onCheckedChange = { viewModel.toggleDarkMode(it) }
                )
                Spacer(modifier = Modifier.height(8.dp))
                
                Box {
                    SettingsNavigationRow(
                        label = "Language",
                        value = "English", // TODO: Map real language code
                        onClick = { showLanguageMenu = true }
                    )
                    DropdownMenu(
                        expanded = showLanguageMenu,
                        onDismissRequest = { showLanguageMenu = false }
                    ) {
                        DropdownMenuItem(
                            text = { Text("English") },
                            onClick = { 
                                // viewModel.setLanguage("en") 
                                showLanguageMenu = false 
                            }
                        )
                        DropdownMenuItem(
                            text = { Text("Korean (한국어)") },
                            onClick = { 
                                // viewModel.setLanguage("ko") 
                                showLanguageMenu = false 
                            }
                        )
                    }
                }
            }

            // 3. Notifications
            SettingsSection(title = "Notifications") {
                SettingsToggleRow(
                    label = "Push Notifications",
                    isChecked = uiState.isPushEnabled,
                    onCheckedChange = { viewModel.togglePush(it) }
                )
            }

            // 4. Messages
            SettingsSection(title = "Message Settings") {
                // Retention Selection
                Box {
                    SettingsNavigationRow(
                        label = "Message Retention",
                        value = "${uiState.messageRetention} Hours",
                        onClick = { showRetentionMenu = true }
                    )
                    DropdownMenu(
                        expanded = showRetentionMenu,
                        onDismissRequest = { showRetentionMenu = false }
                    ) {
                        listOf("6", "12", "24").forEach { hours ->
                             DropdownMenuItem(
                                text = { Text("${hours} Hours") },
                                onClick = { 
                                    viewModel.setRetention(hours)
                                    showRetentionMenu = false 
                                }
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))
                
                // Room Exit Selection
                Box {
                    SettingsNavigationRow(
                        label = "Room Exit Condition",
                        value = when(uiState.roomExitCondition) {
                            "24h" -> "24 Hours"
                            "activity" -> "Activity Based"
                            else -> "Off"
                        },
                        onClick = { showExitMenu = true }
                    )
                    DropdownMenu(
                        expanded = showExitMenu,
                        onDismissRequest = { showExitMenu = false }
                    ) {
                        DropdownMenuItem(
                            text = { Text("24 Hours") },
                            onClick = { viewModel.setRoomExitCondition("24h"); showExitMenu = false }
                        )
                        DropdownMenuItem(
                            text = { Text("Activity Based") },
                            onClick = { viewModel.setRoomExitCondition("activity"); showExitMenu = false }
                        )
                        DropdownMenuItem(
                            text = { Text("Off") },
                            onClick = { viewModel.setRoomExitCondition("off"); showExitMenu = false }
                        )
                    }
                }
            }

            // 5. Privacy
            SettingsSection(title = "Privacy Settings") {
                SettingsNavigationRow(
                    label = "Blocked Users",
                    onClick = onNavigateToBlockedUsers
                )
            }
            
            // 6. Developer (Hidden usually, visible for parity)
            SettingsSection(title = "Developer Settings") {
                 SettingsNavigationRow(
                    label = "Environment",
                    value = "Production",
                    onClick = { /* TODO */ }
                )
            }

            // 7. Legal
            SettingsSection(title = "Legal") {
                SettingsNavigationRow(label = "Terms of Service", onClick = onNavigateToTerms)
                Spacer(modifier = Modifier.height(8.dp))
                SettingsNavigationRow(label = "Privacy Policy", onClick = onNavigateToPrivacy)
                Spacer(modifier = Modifier.height(8.dp))
                SettingsNavigationRow(label = "Open Source Licenses", onClick = onNavigateToOpenSource)
            }
            
            Spacer(modifier = Modifier.height(40.dp))
        }
    }
}

// --- Composable Components ---

@Composable
fun SettingsHeader(onClose: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "Settings",
            fontSize = 28.sp,
            fontWeight = FontWeight.Black,
            color = NeonGreen
        )
        Icon(
            imageVector = Icons.Default.Close,
            contentDescription = "Close",
            tint = NeonGreen,
            modifier = Modifier
                .size(32.dp)
                .clickable { onClose() }
        )
    }
}

@Composable
fun SettingsSection(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = title,
            fontSize = 12.sp,
            color = Color.Gray,
            modifier = Modifier.padding(start = 4.dp)
        )
        content()
    }
}

@Composable
fun ProfileCard(name: String, email: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(GlassBlack, RoundedCornerShape(12.dp))
            .border(1.dp, Color.White.copy(alpha = 0.1f), RoundedCornerShape(12.dp))
            .clickable { onClick() }
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Avatar Placeholder
        Box(
            modifier = Modifier
                .size(50.dp)
                .background(NeonGreen.copy(alpha = 0.1f), CircleShape)
                .border(1.dp, NeonGreen, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.Person,
                contentDescription = null,
                tint = NeonGreen
            )
        }
        
        Spacer(modifier = Modifier.width(12.dp))
        
        Column(modifier = Modifier.weight(1f)) {
            Text(text = name, color = Color.White, fontWeight = FontWeight.Bold)
            Text(text = email, color = Color.Gray, fontSize = 12.sp)
        }
        
        Icon(
            imageVector = Icons.Default.ChevronRight,
            contentDescription = "Edit",
            tint = NeonGreen
        )
    }
}

@Composable
fun SettingsToggleRow(label: String, isChecked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(GlassBlack, RoundedCornerShape(12.dp))
            .border(1.dp, Color.White.copy(alpha = 0.1f), RoundedCornerShape(12.dp))
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text = label, color = Color.White)
        Switch(
            checked = isChecked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = NeonGreen,
                checkedTrackColor = NeonGreen.copy(alpha = 0.3f),
                uncheckedThumbColor = Color.Gray,
                uncheckedTrackColor = Color.DarkGray
            )
        )
    }
}

@Composable
fun SettingsNavigationRow(label: String, value: String? = null, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(GlassBlack, RoundedCornerShape(12.dp))
            .border(1.dp, Color.White.copy(alpha = 0.1f), RoundedCornerShape(12.dp))
            .clickable { onClick() }
            .padding(horizontal = 16.dp, vertical = 16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text = label, color = Color.White)
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (value != null) {
                Text(text = value, color = Color.Gray, fontSize = 14.sp)
                Spacer(modifier = Modifier.width(8.dp))
            }
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = null,
                tint = Color.Gray
            )
        }
    }
}
