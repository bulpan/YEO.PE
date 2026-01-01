package com.yeope.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Scaffold
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavType
import androidx.navigation.navArgument
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.platform.LocalContext
import androidx.compose.foundation.layout.Column
import com.yeope.app.core.service.BLEService
import com.yeope.app.feature.auth.presentation.LoginScreen
import com.yeope.app.feature.chat.presentation.ChatScreen
import com.yeope.app.feature.home.presentation.HomeNavigationEvent
import com.yeope.app.feature.home.presentation.HomeViewModel
import com.yeope.app.feature.home.presentation.MainScreen
import com.yeope.app.feature.home.presentation.RadarView
import com.yeope.app.feature.permission.presentation.PermissionScreen
import com.yeope.app.feature.permission.presentation.PermissionViewModel
import com.yeope.app.ui.theme.YeopeTheme
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import javax.inject.Inject
import com.yeope.app.core.token.TokenManager

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    
    @Inject lateinit var tokenManager: TokenManager
    @Inject lateinit var userPreferencesRepository: com.yeope.app.core.data.UserPreferencesRepository

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            // Collect Dark Mode State
            val isDarkMode by userPreferencesRepository.isDarkMode.collectAsState(initial = true)
            
            YeopeTheme(darkTheme = isDarkMode) {
                // Main Navigation Host
                val navController = rememberNavController()
                val permissionViewModel: PermissionViewModel = hiltViewModel()
                val hasPermissions by permissionViewModel.hasPermissions.collectAsState()
                
                // Simple Bootstrap Logic
                // If we don't have permissions, forcing start destination to 'permission' would be one way,
                // but dynamic start destination is tricky.
                // Instead, we can use a LaunchedEffect to navigate if needed.
                
                // Start Destination Calculation
                val startDest = if (hasPermissions) "login" else "permission"

                NavHost(navController = navController, startDestination = startDest) {
                    composable("permission") {
                        PermissionScreen(
                            onPermissionGranted = {
                                navController.navigate("login") {
                                    popUpTo("permission") { inclusive = true }
                                }
                            }
                        )
                    }

                    composable("login") {
                        val context = LocalContext.current
                        LoginScreen(
                            onLoginSuccess = {
                                navController.navigate("home") {
                                    popUpTo("login") { inclusive = true }
                                }
                            },
                            onGuestLogin = {
                                navController.navigate("home") {
                                    popUpTo("login") { inclusive = true }
                                }
                            },
                            onSignUpClick = {
                                android.widget.Toast.makeText(context, "회원가입 기능 준비 중입니다", android.widget.Toast.LENGTH_SHORT).show()
                            }
                        )
                    }
                    
                    composable("home") {
                        val homeViewModel: HomeViewModel = hiltViewModel()
                        val discoveredUsers by homeViewModel.discoveredUsers.collectAsState()
                        val context = LocalContext.current
                        
                        LaunchedEffect(Unit) {
                            // Service Start
                            val serviceIntent = Intent(context, BLEService::class.java).apply {
                                action = BLEService.ACTION_START_SCAN
                            }
                             if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                                context.startForegroundService(serviceIntent)
                            } else {
                                context.startService(serviceIntent)
                            }
                            
                            // Deep Link Handling from Notification
                            val target = intent?.getStringExtra("navigation_target")
                            if (target == "chat") {
                                val roomId = intent?.getStringExtra("roomId")
                                val roomName = intent?.getStringExtra("roomName") ?: "Chat"
                                if (roomId != null) {
                                    navController.navigate("chat/$roomId/$roomName")
                                }
                            }
                            
                            homeViewModel.navigationEvent.collectLatest { event ->
                                when (event) {
                                    is HomeNavigationEvent.NavigateToChat -> {
                                        navController.navigate("chat/${event.roomId}/${event.roomName}")
                                    }
                                }
                            }
                        }

                        MainScreen(
                            onNavigateToChatList = {
                                android.widget.Toast.makeText(context, "Chat List Coming Soon", android.widget.Toast.LENGTH_SHORT).show()
                            },
                            onNavigateToProfile = {
                                android.widget.Toast.makeText(context, "Profile Coming Soon", android.widget.Toast.LENGTH_SHORT).show()
                            },
                            onNavigateToSettings = {
                                navController.navigate("settings")
                            }
                        )
                    }
                    
                    composable("settings") {
                         com.yeope.app.feature.settings.presentation.SettingsScreen(
                            onClose = { navController.popBackStack() },
                            onNavigateToProfileEdit = { navController.navigate("profile_edit") },
                            onNavigateToBlockedUsers = { navController.navigate("blocked_users") },
                            onNavigateToTerms = { 
                                val url = java.net.URLEncoder.encode("https://yeo.pe/terms", "UTF-8")
                                navController.navigate("webview/$url/Terms of Service") 
                            },
                            onNavigateToPrivacy = { 
                                val url = java.net.URLEncoder.encode("https://yeo.pe/privacy", "UTF-8")
                                navController.navigate("webview/$url/Privacy Policy") 
                            },
                            onNavigateToOpenSource = { 
                                val url = java.net.URLEncoder.encode("https://yeo.pe/licenses", "UTF-8") // Placeholder
                                navController.navigate("webview/$url/Open Source Licenses") 
                            }
                        )
                    }
                    
                    composable(
                        "webview/{url}/{title}",
                        arguments = listOf(
                            navArgument("url") { type = NavType.StringType },
                            navArgument("title") { type = NavType.StringType }
                        )
                    ) { backStackEntry ->
                        val url = backStackEntry.arguments?.getString("url") ?: "https://yeo.pe"
                        val title = backStackEntry.arguments?.getString("title") ?: "Web"
                        
                        com.yeope.app.core.design.WebViewScreen(
                            url = url,
                            title = title,
                            onBack = { navController.popBackStack() }
                        )
                    }

                    composable("profile_edit") {
                        com.yeope.app.feature.settings.presentation.ProfileEditScreen(
                            onBack = { navController.popBackStack() }
                        )
                    }
                    
                    composable("blocked_users") {
                        com.yeope.app.feature.settings.presentation.BlockedUsersScreen(
                            navController = navController
                        )
                    }
                    
                    composable(
                        "chat/{roomId}/{roomName}",
                        arguments = listOf(
                            navArgument("roomId") { type = NavType.StringType },
                            navArgument("roomName") { type = NavType.StringType }
                        )
                    ) { backStackEntry ->
                        val roomId = backStackEntry.arguments?.getString("roomId") ?: return@composable
                        val roomName = backStackEntry.arguments?.getString("roomName") ?: "Chat"
                        
                        ChatScreen(
                            roomId = roomId,
                            roomName = roomName,
                            onBackClick = { navController.popBackStack() },
                            tokenManager = this@MainActivity.tokenManager 
                        )
                    }
                }
            }
        }
    }
}
