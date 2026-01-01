package com.yeope.app.feature.home.presentation

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChatBubble
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.yeope.app.ui.theme.NeonGreen
import com.yeope.app.ui.theme.DarkSurface
import com.yeope.app.ui.theme.GlassBlack

@Composable
fun MainScreen(
    viewModel: HomeViewModel = hiltViewModel(),
    onNavigateToSettings: () -> Unit,
    onNavigateToProfile: () -> Unit,
    onNavigateToChatList: () -> Unit
) {
    val discoveredUsers by viewModel.discoveredUsers.collectAsState()
    
    // Main Container (Full Screen, Deep Black)
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // 1. Radar Layer (Bottom)
        RadarView(
            users = discoveredUsers,
            onUserClick = { user -> viewModel.onUserClicked(user) }
        )

        // 2. Chrome Layer (Top & Bottom)
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            // --- TOP HEADER ---
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 10.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Left: Signal Active Chip
                Box(
                    modifier = Modifier
                        .background(NeonGreen.copy(alpha = 0.1f), RoundedCornerShape(4.dp))
                        .border(1.dp, NeonGreen.copy(alpha = 0.3f), RoundedCornerShape(4.dp))
                        .padding(horizontal = 12.dp, vertical = 6.dp)
                ) {
                    Text(
                        text = "SIGNAL ACTIVE",
                        color = NeonGreen,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace
                    )
                }

                // Right: Settings Button
                Icon(
                    imageVector = Icons.Default.Settings,
                    contentDescription = "Settings",
                    tint = Color.Gray,
                    modifier = Modifier
                        .size(32.dp)
                        .background(Color.White.copy(alpha = 0.05f), CircleShape)
                        .padding(4.dp)
                        .clickable { onNavigateToSettings() }
                )
            }

            // --- BOTTOM CONTROL BAR ---
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 20.dp),
                contentAlignment = Alignment.Center
            ) {
                // Floating Glass Bar
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(80.dp)
                        .background(GlassBlack, RoundedCornerShape(30.dp))
                        .border(1.dp, Color.White.copy(alpha = 0.1f), RoundedCornerShape(30.dp))
                        .padding(horizontal = 30.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Left: Chat List
                    BottomBarButton(
                        icon = Icons.Default.ChatBubble,
                        label = "Chat",
                        onClick = onNavigateToChatList
                    )

                    // Spacer for Center Button
                    Spacer(modifier = Modifier.size(60.dp))

                    // Right: Profile
                    BottomBarButton(
                        icon = Icons.Default.Person,
                        label = "Profile",
                        onClick = onNavigateToProfile
                    )
                }

                // Center: Signal Boost (Floating above)
                Box(
                    modifier = Modifier
                        .size(90.dp) // Large Touch Area
                        .offset(y = (-20).dp) // Float Up
                        .clickable { /* TODO: Signal Boost / Quick Question */ },
                    contentAlignment = Alignment.Center
                ) {
                    // Pulse Effect Container would go here if animating
                    Box(
                        modifier = Modifier
                            .size(70.dp)
                            .background(NeonGreen.copy(alpha = 0.1f), CircleShape)
                            .border(1.dp, NeonGreen, CircleShape)
                            .padding(4.dp)
                            .background(DarkSurface, CircleShape),
                        contentAlignment = Alignment.Center
                    ) {
                         Icon(
                            imageVector = Icons.Default.Bolt,
                            contentDescription = "Signal Boost",
                            tint = NeonGreen,
                            modifier = Modifier.size(32.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun BottomBarButton(
    icon: ImageVector,
    label: String,
    onClick: () -> Unit
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = Modifier.clickable { onClick() }
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            tint = Color.White,
            modifier = Modifier.size(24.dp)
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = label,
            fontSize = 10.sp,
            color = Color.Gray
        )
    }
}
