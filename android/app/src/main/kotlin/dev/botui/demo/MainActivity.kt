package dev.botui.demo

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.imageResource
import androidx.compose.ui.unit.dp
import dev.botui.BotView
import dev.botui.BotEyes
import dev.botui.BotFace
import dev.botui.BotFaceSpec
import dev.botui.BotMouth
import dev.botui.BotShape
import dev.botui.BotState
import dev.botui.BotStyle

private val SWATCHES = listOf(
    "Sky" to Color(0xFF8FD0FA),
    "Nojoto" to Color(0xFFF5292A),
    "Mint" to Color(0xFF1ED3C6),
    "Sun" to Color(0xFFFFC53D),
    "Plum" to Color(0xFF8E5BD9),
    "Rose" to Color(0xFFFF7AA8),
)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val start = intent.getStringExtra("state")?.let { n -> BotState.entries.firstOrNull { it.name == n } }
        setContent { MaterialTheme { Demo(start ?: BotState.Neutral) } }
    }
}

private val HEART_SVG = "M50 95C10 65 0 40 15 20C28 5 45 12 50 28C55 12 72 5 85 20C100 40 90 65 50 95Z"

private val PADDING = 20.dp

private val BEAN_SVG = "M20 40C20 10 80 10 80 40C95 55 85 95 50 95C15 95 5 55 20 40Z"

internal val SHAPES = linkedMapOf(
    "Teardrop" to BotShape.Teardrop,
    "Round" to BotShape.Round,
    "Egg" to BotShape.Egg,
    "Blob" to BotShape.Blob,
    "Blossom" to BotShape.Blossom,
    "Squircle" to BotShape.Squircle,
    "Bean" to BotShape.svg(BEAN_SVG),
    "Heart" to BotShape.svg(HEART_SVG),
)

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Demo(initial: BotState) {
    var state by remember { mutableStateOf(initial) }
    var color by remember { mutableStateOf(SWATCHES[1].second) }
    var brightness by remember { mutableFloatStateOf(1.1f) }
    var furLength by remember { mutableFloatStateOf(2.6f) }
    var mouth by remember { mutableStateOf(true) }
    var custom by remember { mutableStateOf(false) }
    var eyes by remember { mutableStateOf(BotEyes.Oval) }
    var mouthShape by remember { mutableStateOf(BotMouth.Smile) }
    var eyeScale by remember { mutableFloatStateOf(1f) }
    var eyeTilt by remember { mutableFloatStateOf(0f) }

    Column(
        Modifier.fillMaxSize().background(Color.White).verticalScroll(rememberScrollState()).padding(PADDING),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        ShapeStrip(
            state = state,
            style = BotStyle(
                color = color,
                brightness = brightness,
                furLength = furLength,
                face = if (mouth) BotFace.EyesAndMouth else BotFace.Eyes,
                customFace = if (custom) {
                    BotFaceSpec(eyes, mouthShape, eyeScale = eyeScale, eyeTilt = eyeTilt)
                } else null,
            ),
            containerPadding = PADDING,
            modifier = Modifier.padding(top = 24.dp),
        )
        Text("Mood")
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            BotState.entries.forEach { s ->
                FilterChip(selected = s == state, onClick = { state = s }, label = { Text(s.name) })
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Switch(custom, { custom = it }); Text("Custom face")
        }
        if (custom) {
            Text("Eyes")
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                BotEyes.entries.forEach { e ->
                    FilterChip(selected = e == eyes, onClick = { eyes = e }, label = { Text(e.name) })
                }
            }
            Text("Mouth")
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                BotMouth.entries.forEach { m ->
                    FilterChip(selected = m == mouthShape, onClick = { mouthShape = m }, label = { Text(m.name) })
                }
            }
            Text("Eye size %.2f".format(eyeScale))
            Slider(eyeScale, { eyeScale = it }, valueRange = 0.5f..1.6f)
            Text("Eye tilt %.2f (angry to sad)".format(eyeTilt))
            Slider(eyeTilt, { eyeTilt = it }, valueRange = -1f..1f)
        }
        Text("Tap BotUI to giggle, hold for love", color = Color.Gray)
        Text("Colour")
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            SWATCHES.forEach { (_, c) ->
                Box(
                    Modifier.size(38.dp).clip(CircleShape).background(c)
                        .border(if (c == color) 3.dp else 0.dp, Color.Black, CircleShape)
                        .clickable { color = c },
                )
            }
        }
        Text("Brightness %.2f".format(brightness))
        Slider(brightness, { brightness = it }, valueRange = 0.6f..1.6f)
        Text("Fur length %.1f".format(furLength))
        Slider(furLength, { furLength = it }, valueRange = 0f..7f)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Switch(mouth, { mouth = it }); Text("Mouth")
        }
    }
}
