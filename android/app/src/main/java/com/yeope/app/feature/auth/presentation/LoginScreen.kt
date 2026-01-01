package com.yeope.app.feature.auth.presentation

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.yeope.app.ui.component.NeonButton

@Composable
fun LoginScreen(
    viewModel: LoginViewModel = hiltViewModel(),
    onLoginSuccess: () -> Unit,
    onGuestLogin: () -> Unit,
    onSignUpClick: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    
    var email by remember { mutableStateOf("") }
    var nickname by remember { mutableStateOf("") }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background // Deep Black
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // Header
            Text(
                text = "YEO.PE",
                fontSize = 48.sp,
                fontWeight = FontWeight.Black,
                color = MaterialTheme.colorScheme.primary, // Neon Green
                modifier = Modifier.padding(bottom = 8.dp)
            )
            
            Text(
                text = "지금, 여기, 우리",
                fontSize = 18.sp,
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.7f),
                fontWeight = FontWeight.Medium
            )

            Spacer(modifier = Modifier.height(60.dp))

            // Inputs
            GlassTextField(
                value = email,
                onValueChange = { email = it },
                label = "이메일"
            )

            Spacer(modifier = Modifier.height(16.dp))

            GlassTextField(
                value = nickname,
                onValueChange = { nickname = it },
                label = "닉네임"
            )

            Spacer(modifier = Modifier.height(40.dp))

            // Actions
            if (uiState is LoginUiState.Loading) {
                CircularProgressIndicator(
                    color = MaterialTheme.colorScheme.primary
                )
            } else {
                NeonButton(
                    text = "시작하기",
                    onClick = { viewModel.login(email, nickname) },
                    enabled = email.isNotBlank() && nickname.isNotBlank()
                )
                
                Spacer(modifier = Modifier.height(24.dp))
                
                // OR Divider
                Text("또는", color = Color.Gray, fontSize = 14.sp)
                
                Spacer(modifier = Modifier.height(24.dp))

                // Social Login Buttons (Placeholders)
                val context = LocalContext.current
                SocialLoginButton(
                    text = "Google로 계속하기",
                    backgroundColor = com.yeope.app.ui.theme.GoogleBlue,
                    textColor = com.yeope.app.ui.theme.GoogleWhite,
                    onClick = { android.widget.Toast.makeText(context, "준비 중입니다", android.widget.Toast.LENGTH_SHORT).show() }
                )
                
                Spacer(modifier = Modifier.height(12.dp))

                SocialLoginButton(
                    text = "Kakao로 계속하기",
                    backgroundColor = com.yeope.app.ui.theme.KakaoYellow,
                    textColor = Color.Black.copy(alpha = 0.85f),
                    onClick = { android.widget.Toast.makeText(context, "준비 중입니다", android.widget.Toast.LENGTH_SHORT).show() }
                )

                Spacer(modifier = Modifier.height(32.dp))

                // Guest & SignUp
                Row(
                    horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    androidx.compose.material3.TextButton(onClick = onGuestLogin) {
                        Text("둘러보기 (비로그인)", color = Color.Gray)
                    }
                    
                    androidx.compose.material3.TextButton(onClick = onSignUpClick) {
                        Text("회원가입", color = MaterialTheme.colorScheme.primary)
                    }
                }
            }
            
            if (uiState is LoginUiState.Error) {
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = (uiState as LoginUiState.Error).message,
                    color = MaterialTheme.colorScheme.error
                )
            }
            
            if (uiState is LoginUiState.Success) {
                onLoginSuccess()
            }
        }
    }
}

@Composable
fun GlassTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label, color = Color.Gray) },
        modifier = Modifier.fillMaxWidth(),
        shape = androidx.compose.foundation.shape.RoundedCornerShape(12.dp),
        colors = androidx.compose.material3.TextFieldDefaults.colors(
            focusedContainerColor = com.yeope.app.ui.theme.GlassBlack,
            unfocusedContainerColor = com.yeope.app.ui.theme.GlassBlack,
            focusedIndicatorColor = MaterialTheme.colorScheme.primary, // Neon Green
            unfocusedIndicatorColor = Color.White.copy(alpha = 0.1f),
            focusedTextColor = Color.White,
            unfocusedTextColor = Color.White,
            cursorColor = MaterialTheme.colorScheme.primary
        )
    )
}

@Composable
fun SocialLoginButton(
    text: String,
    backgroundColor: Color,
    textColor: Color,
    onClick: () -> Unit
) {
    Button(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .height(50.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = backgroundColor,
            contentColor = textColor
        )
    ) {
        Text(text, fontSize = 16.sp, fontWeight = FontWeight.Bold)
    }
}
