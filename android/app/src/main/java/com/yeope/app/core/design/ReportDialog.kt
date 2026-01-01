package com.yeope.app.core.design

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.yeope.app.ui.theme.GlassBlack
import com.yeope.app.ui.theme.NeonGreen

@Composable
fun ReportDialog(
    onDismiss: () -> Unit,
    onReport: (String, String) -> Unit // reason, details
) {
    var selectedReason by remember { mutableStateOf<String?>(null) }
    var details by remember { mutableStateOf("") }
    
    val reasons = listOf("Spam", "Inappropriate Content", "Abusive Behavior", "Other")

    Dialog(onDismissRequest = onDismiss) {
        GlassBox(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier.padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Text(
                    text = "Report User",
                    style = MaterialTheme.typography.titleLarge,
                    color = NeonGreen,
                    fontWeight = FontWeight.Bold
                )

                Text(
                    text = "Why are you reporting this user?",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.White
                )

                // Reason Selection
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    reasons.forEach { reason ->
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { selectedReason = reason }
                                .padding(vertical = 4.dp)
                        ) {
                            RadioButton(
                                selected = (selectedReason == reason),
                                onClick = { selectedReason = reason },
                                colors = RadioButtonDefaults.colors(
                                    selectedColor = NeonGreen,
                                    unselectedColor = Color.Gray
                                )
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(text = reason, color = Color.White)
                        }
                    }
                }

                // Details Input
                OutlinedTextField(
                    value = details,
                    onValueChange = { details = it },
                    label = { Text("Details (Optional)") },
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = NeonGreen,
                        unfocusedBorderColor = Color.Gray,
                        focusedLabelColor = NeonGreen,
                        unfocusedLabelColor = Color.Gray,
                        cursorColor = NeonGreen,
                        focusedTextColor = Color.White,
                        unfocusedTextColor = Color.White
                    ),
                    modifier = Modifier.fillMaxWidth()
                )

                // Actions
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    TextButton(onClick = onDismiss) {
                        Text("Cancel", color = Color.Gray)
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Button(
                        onClick = { 
                            if (selectedReason != null) {
                                onReport(selectedReason!!, details)
                            }
                        },
                        enabled = selectedReason != null,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = NeonGreen,
                            contentColor = Color.Black,
                            disabledContainerColor = Color.DarkGray,
                            disabledContentColor = Color.Gray
                        )
                    ) {
                        Text("Report")
                    }
                }
            }
        }
    }
}
