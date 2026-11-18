package com.stream.ledger.core.util

import androidx.compose.foundation.layout.Row
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import com.stream.ledger.core.designsystem.LocalStreamColors
import java.text.DecimalFormat
import kotlin.math.abs

data class FormattedAmountParts(
    val isNegative: Boolean,
    val prefix: String,
    val integerString: String,
    val decimalString: String
)

object CurrencyFormatter {
    private val decimalFormat = DecimalFormat("#,##0")

    fun formatParts(cents: Long, showSign: Boolean = false): FormattedAmountParts {
        val isNegative = cents < 0
        val absVal = abs(cents)
        val integerPart = absVal / 100
        val decimalPart = (absVal % 100).toString().padStart(2, '0')

        val sign = when {
            isNegative -> "-"
            showSign && cents > 0 -> "+"
            else -> ""
        }

        return FormattedAmountParts(
            isNegative = isNegative,
            prefix = sign,
            integerString = decimalFormat.format(integerPart),
            decimalString = ".$decimalPart"
        )
    }

    fun formatPlain(cents: Long, withSymbol: Boolean = true): String {
        val parts = formatParts(cents)
        val sym = if (withSymbol) "¥" else ""
        return "${parts.prefix}$sym${parts.integerString}${parts.decimalString}"
    }
}

/**
 * 满足设计规范的大数字金额显示组件：
 * 大数字用 Light(300)、等宽数字 (tabular-nums)，货币符号与小数部分小一号、浅色。
 */
@Composable
fun AmountText(
    cents: Long,
    modifier: Modifier = Modifier,
    integerSize: TextUnit = 28.sp,
    symbolSize: TextUnit = (integerSize.value * 0.65f).sp,
    decimalSize: TextUnit = (integerSize.value * 0.72f).sp,
    integerWeight: FontWeight = FontWeight.Light, // 300
    color: Color = LocalStreamColors.current.textPrimary,
    secondaryColor: Color = LocalStreamColors.current.textSecondary,
    showSign: Boolean = false,
    showSymbol: Boolean = true
) {
    val parts = CurrencyFormatter.formatParts(cents, showSign)

    Row(
        modifier = modifier,
        verticalAlignment = Alignment.Bottom
    ) {
        if (parts.prefix.isNotEmpty()) {
            Text(
                text = parts.prefix,
                style = TextStyle(
                    fontFamily = FontFamily.Default,
                    fontWeight = FontWeight.Medium,
                    fontSize = symbolSize,
                    color = color
                )
            )
        }

        if (showSymbol) {
            Text(
                text = "¥",
                style = TextStyle(
                    fontFamily = FontFamily.Default,
                    fontWeight = FontWeight.Normal,
                    fontSize = symbolSize,
                    color = secondaryColor
                )
            )
        }

        Text(
            text = parts.integerString,
            style = TextStyle(
                fontFamily = FontFamily.Default,
                fontWeight = integerWeight,
                fontSize = integerSize,
                color = color
            )
        )

        Text(
            text = parts.decimalString,
            style = TextStyle(
                fontFamily = FontFamily.Default,
                fontWeight = FontWeight.Normal,
                fontSize = decimalSize,
                color = secondaryColor
            )
        )
    }
}
