package com.yeope.app.feature.home.presentation

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.yeope.app.ui.theme.NeonGreen
import kotlin.math.cos
import kotlin.math.sin

@Composable
fun RadarView(
    users: List<DiscoveredUserUiModel>,
    onUserClick: (DiscoveredUserUiModel) -> Unit
) {
    val infiniteTransition = rememberInfiniteTransition(label = "RadarPulse")
    
    // Pulse 1
    val radius1 by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 1000f,
        animationSpec = infiniteRepeatable(
            animation = tween(3000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "Radius1"
    )
    val alpha1 by infiniteTransition.animateFloat(
        initialValue = 0.5f,
        targetValue = 0f,
        animationSpec = infiniteRepeatable(
            animation = tween(3000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "Alpha1"
    )

    // Pulse 2 (Delayed visually via offset in tween logic or separate transition? 
    // Compose infiniteTransition doesn't support start delay easily. 
    // We can simulate it by wrapping ranges or using initial variants, 
    // but easiest is to just have offsets in `initialValue` logic or separate transitions.
    // Actually, simple math offset works best: (time + delay) % duration.
    // Let's keep it simple with slightly different speeds or just 3 identical waves for now
    // to match the "Ripple" effect.
    // Better yet: 3 separate animations with different initialOffsets is hard in infiniteTransition.
    // Let's use a single phase 0..1 and derive 3 circles from it.)

    val phase by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(3000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "Phase"
    )

    Box(modifier = Modifier.fillMaxSize()) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val center = center
            val maxRadius = size.minDimension * 0.8f

            // Draw 3 Pulse Waves based on Phase
            // Wave 1: phase
            // Wave 2: (phase + 0.33) % 1
            // Wave 3: (phase + 0.66) % 1
            
            drawPulseCircle(this, center, phase, maxRadius, NeonGreen)
            drawPulseCircle(this, center, (phase + 0.33f) % 1f, maxRadius, NeonGreen)
            drawPulseCircle(this, center, (phase + 0.66f) % 1f, maxRadius, NeonGreen)
        }
        
        // Center Node (Me) - Glowing Dot
        Box(
            modifier = Modifier
                .align(Alignment.Center)
                .size(24.dp)
                .shadow(10.dp, CircleShape, spotColor = NeonGreen)
                .background(NeonGreen, CircleShape)
                .border(2.dp, Color.White.copy(alpha = 0.5f), CircleShape)
        )

        // Render Users
        users.forEach { user ->
            // Deterministic position based on hash (matches iOS "Scatter" logic loosely)
            val angle = (user.address.hashCode().rem(360)).toDouble()
            val distance = 120.dp // approx distance from center
            
            // In a real app we'd map RSSI to distance.
            // For parity layout, let's use a standard offset logic.
            
            val rad = Math.toRadians(angle)
            // We need to use density to convert dp to px for offset, 
            // but `offset` modifier takes dp.
            
            // Simple circular layout
            // Note: In real Ref, iOS uses `offset` with `cos(angle) * distance`.
            
            Box(
                modifier = Modifier
                    .align(Alignment.Center)
                    // We can't easily use cos/sin with dp directly in offset lambda without density.
                    // Let's specific layout or `GraphicsLayer`. 
                    // `BiasAlignment` is easier for relative positioning.
                    .offset(
                        x = (cos(rad) * 100).dp, 
                        y = (sin(rad) * 100).dp
                    )
            ) {
               UserNode(user = user, onClick = { onUserClick(user) })
            }
        }
    }
}

private fun drawPulseCircle(scope: androidx.compose.ui.graphics.drawscope.DrawScope, center: Offset, progress: Float, maxRadius: Float, color: Color) {
    val currentRadius = progress * maxRadius
    val currentAlpha = 0.5f * (1f - progress) // Fade out
    
    scope.drawCircle(
        color = color.copy(alpha = currentAlpha),
        radius = currentRadius,
        style = Stroke(width = 2f)
    )
}

@Composable
fun UserNode(user: DiscoveredUserUiModel, onClick: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.clickable { onClick() }
    ) {
        // Avatar Bubble
        Box(
            modifier = Modifier
                .size(60.dp)
                .shadow(8.dp, CircleShape, spotColor = NeonGreen)
                .background(com.yeope.app.ui.theme.DarkSurface, CircleShape) // Deep or Surface
                .border(2.dp, NeonGreen, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            // Placeholder Icon
            Text(
                text = user.name.take(1),
                color = Color.White,
                fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
                fontSize = 20.sp
            )
        }
        
        // Name Label
        Box(
            modifier = Modifier
                .padding(top = 4.dp)
                .background(Color.Black.copy(alpha = 0.6f), androidx.compose.foundation.shape.RoundedCornerShape(4.dp))
                .padding(horizontal = 6.dp, vertical = 2.dp)
        ) {
            Text(
                text = user.name,
                color = Color.White,
                fontSize = 12.sp
            )
        }
    }
}
