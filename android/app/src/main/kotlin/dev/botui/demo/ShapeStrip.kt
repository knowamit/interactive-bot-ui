package dev.botui.demo

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.botui.BotState
import dev.botui.BotStyle
import dev.botui.BotView

private const val VISIBLE_AT_ONCE = 4

/** Room above each bot for the hop and the badges. */
private val HEADROOM = 24.dp
private val BOT_INSET = 6.dp

/**
 * Every body shape in one horizontal row, exactly [VISIBLE_AT_ONCE] visible at a time.
 * Each bot uses [style] with its own shape, so every control in the demo applies to all of them.
 * [containerPadding] is the horizontal padding already around the row.
 */
@Composable
internal fun ShapeStrip(state: BotState, style: BotStyle, containerPadding: Dp, modifier: Modifier = Modifier) {
    val cell = (LocalConfiguration.current.screenWidthDp.dp - containerPadding * 2) / VISIBLE_AT_ONCE
    Row(modifier.fillMaxWidth().horizontalScroll(rememberScrollState())) {
        SHAPES.entries.forEachIndexed { index, (name, shape) ->
            Column(Modifier.width(cell), horizontalAlignment = Alignment.CenterHorizontally) {
                Box(Modifier.padding(top = HEADROOM, start = BOT_INSET, end = BOT_INSET), contentAlignment = Alignment.Center) {
                    BotView(
                        state = state,
                        modifier = Modifier.size(cell - BOT_INSET * 2),
                        style = style.copy(shape = shape),
                        seed = 0.11f + index * 0.13f,
                    )
                }
                Text(name, fontSize = 12.sp, color = Color.Gray)
            }
        }
    }
}
