package com.yeope.app.feature.chat.presentation

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.material3.TopAppBarDefaults
import androidx.hilt.navigation.compose.hiltViewModel
import com.yeope.app.core.token.TokenManager
import com.yeope.app.feature.chat.data.ChatMessage
import coil.compose.AsyncImage
import androidx.compose.ui.layout.ContentScale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(
    roomId: String,
    roomName: String,
    onBackClick: () -> Unit,
    viewModel: ChatViewModel = hiltViewModel(),
    tokenManager: TokenManager
) {
    val messages by viewModel.messages.collectAsState()
    val typingUserIds by viewModel.typingUserIds.collectAsState()
    var inputText by remember { mutableStateOf("") }
    val myId = remember { tokenManager.getUserId() ?: "" }

    DisposableEffect(roomId) {
        viewModel.connect()
        viewModel.joinRoom(roomId)
        onDispose {
            viewModel.disconnect()
        }
    }

    Scaffold(
        topBar = {
            Column(modifier = Modifier.background(MaterialTheme.colorScheme.background)) {
                TopAppBar(
                    title = { 
                        Column {
                            Text(roomName)
                            if (typingUserIds.isNotEmpty()) {
                                Text(
                                    text = "${typingUserIds.size} typing...",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.primary
                                )
                            }
                        }
                    },
                    navigationIcon = {
                        IconButton(onClick = onBackClick) {
                            Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                        }
                    },
                     colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = MaterialTheme.colorScheme.background,
                        titleContentColor = MaterialTheme.colorScheme.onBackground
                    )
                )
            }
        },
        containerColor = com.yeope.app.ui.theme.DeepBlack
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            LazyColumn(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                reverseLayout = false
            ) {
                items(messages) { message ->
                    if (message.type == "system") {
                        SystemMessage(content = message.content)
                    } else {
                        MessageBubble(
                            message = message,
                            isMe = (message.userId == myId)
                        )
                    }
                }
            }

            // Input Area
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                TextField(
                    value = inputText,
                    onValueChange = { 
                        inputText = it 
                        viewModel.onTextInput(roomId, it)
                    },
                    modifier = Modifier
                        .weight(1f)
                        .background(Color.Transparent),
                    placeholder = { Text("Type a message...") },
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = Color.White.copy(alpha = 0.1f),
                        unfocusedContainerColor = Color.White.copy(alpha = 0.1f),
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent,
                        focusedTextColor = Color.White,
                        unfocusedTextColor = Color.White
                    ),
                    shape = RoundedCornerShape(20.dp)
                )
                IconButton(
                    onClick = {
                        if (inputText.isNotBlank()) {
                            viewModel.sendMessage(roomId, inputText)
                            inputText = ""
                        }
                    }
                ) {
                    Icon(
                        Icons.Default.Send, 
                        contentDescription = "Send", 
                        tint = com.yeope.app.ui.theme.NeonGreen
                    )
                }
            }
        }
    }
}

@Composable
fun SystemMessage(content: String) {
    Box(
        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = content,
            style = MaterialTheme.typography.bodySmall,
            color = Color.Gray
        )
    }
}



@Composable
fun MessageBubble(
    message: ChatMessage,
    isMe: Boolean
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        horizontalAlignment = if (isMe) Alignment.End else Alignment.Start
    ) {
        if (!isMe) {
            // Display Name (prefer mask)
            val displayName = message.nicknameMask ?: message.nickname ?: "Unknown"
            Text(
                text = displayName,
                style = MaterialTheme.typography.labelSmall,
                color = Color.Gray,
                modifier = Modifier.padding(start = 12.dp, bottom = 2.dp)
            )
        }
        
        Box(
            modifier = Modifier
                .background(
                    color = if (isMe) com.yeope.app.ui.theme.NeonGreen else Color.White.copy(alpha = 0.1f),
                    shape = RoundedCornerShape(16.dp)
                )
                .padding(if (message.imageUrl != null) 0.dp else 12.dp) // No padding for images
        ) {
            if (message.imageUrl != null) {
                AsyncImage(
                    model = message.imageUrl,
                    contentDescription = "Image",
                    modifier = Modifier
                        .heightIn(max = 200.dp)
                        .fillMaxWidth(0.7f),
                    contentScale = ContentScale.Crop
                )
            } else {
                Text(
                    text = message.content,
                    color = if (isMe) Color.Black else Color.White,
                    modifier = Modifier.padding(12.dp)
                )
            }
        }
        
        if (isMe && message.localStatus == com.yeope.app.feature.chat.data.LocalStatus.SENDING) {
             Text(
                text = "Sending...",
                style = MaterialTheme.typography.labelSmall,
                color = Color.Gray,
                modifier = Modifier.padding(end = 4.dp, top = 2.dp)
            )
        }
    }
}
