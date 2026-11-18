package com.stream.ledger.ui.editorial

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.stream.ledger.core.designsystem.LocalStreamColors
import com.stream.ledger.core.designsystem.StreamEditorialType

/**
 * C 编辑风通用页头：衬线斜体大标题 + 宽字距眉题 + 右侧操作区。
 */
@Composable
fun EditorialHeader(
    eyebrow: String,
    title: String,
    subtitle: String,
    modifier: Modifier = Modifier,
    actions: @Composable RowScope.() -> Unit = {}
) {
    val colors = LocalStreamColors.current
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(start = 24.dp, end = 14.dp, top = 16.dp, bottom = 2.dp),
        verticalAlignment = Alignment.Top
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = eyebrow,
                style = StreamEditorialType.Eyebrow,
                color = colors.textSecondary
            )
            Text(
                text = title,
                style = StreamEditorialType.Title,
                color = colors.textPrimary,
                maxLines = 1
            )
            Text(
                text = subtitle,
                style = StreamEditorialType.Subtitle,
                color = colors.textSecondary,
                modifier = Modifier.padding(top = 2.dp)
            )
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.End,
            content = actions
        )
    }
}

@Composable
fun EditorialSectionLabel(
    title: String,
    modifier: Modifier = Modifier,
    trailing: String? = null
) {
    val colors = LocalStreamColors.current
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(start = 24.dp, end = 22.dp, top = 18.dp, bottom = 5.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title,
            style = StreamEditorialType.SectionLabel,
            color = colors.textSecondary
        )
        if (trailing != null) {
            Text(
                text = trailing,
                style = StreamEditorialType.SectionLabel,
                color = colors.textSecondary
            )
        }
    }
}

@Composable
fun EditorialHairline(
    modifier: Modifier = Modifier,
    startPadding: Dp = 72.dp
) {
    HorizontalDivider(
        modifier = modifier.padding(start = startPadding),
        thickness = 0.5.dp,
        color = LocalStreamColors.current.hairline
    )
}

/** 深色主卡（hero / 账户主卡），统一圆角与内边距 */
@Composable
fun EditorialDeepCard(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    val colors = LocalStreamColors.current
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(26.dp))
            .background(colors.deepSurface)
            .padding(20.dp),
        content = content
    )
}