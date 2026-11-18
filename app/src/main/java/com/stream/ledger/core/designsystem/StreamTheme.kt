package com.stream.ledger.core.designsystem

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

data class StreamColorPalette(
    val paperBase: Color,
    val cardBackground: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val hairline: Color,
    val inputBackground: Color,
    val accentWarmYellow: Color,
    val textOnAccent: Color,
    val accentPillBackground: Color,
    val incomeGreen: Color,
    val overBudgetRed: Color,
    val fixedExpenseBlockColor: Color,
    val deepSurface: Color,
    val onDeep: Color,
    val onDeepMuted: Color,
    val isDark: Boolean
)

val LocalStreamColors = staticCompositionLocalOf {
    StreamColorPalette(
        paperBase = StreamColors.LightPaperBase,
        cardBackground = StreamColors.LightCardBackground,
        textPrimary = StreamColors.LightTextPrimary,
        textSecondary = StreamColors.LightTextSecondary,
        hairline = StreamColors.LightHairline,
        inputBackground = StreamColors.LightInputBackground,
        accentWarmYellow = StreamColors.AccentWarmYellow,
        textOnAccent = StreamColors.TextOnAccent,
        accentPillBackground = StreamColors.AccentPillBackground,
        incomeGreen = StreamColors.IncomeGreen,
        overBudgetRed = StreamColors.OverBudgetRed,
        fixedExpenseBlockColor = StreamColors.FixedExpenseBlockColor,
        deepSurface = StreamColors.DeepSurface,
        onDeep = StreamColors.OnDeep,
        onDeepMuted = StreamColors.OnDeepMuted,
        isDark = false
    )
}

@Composable
fun StreamTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val streamColors = if (darkTheme) {
        StreamColorPalette(
            paperBase = StreamColors.DarkPaperBase,
            cardBackground = StreamColors.DarkCardBackground,
            textPrimary = StreamColors.DarkTextPrimary,
            textSecondary = StreamColors.DarkTextSecondary,
            hairline = StreamColors.DarkHairline,
            inputBackground = StreamColors.DarkInputBackground,
            accentWarmYellow = StreamColors.AccentWarmYellow,
            textOnAccent = StreamColors.TextOnAccent,
            accentPillBackground = Color(0xFF2C2415),
            incomeGreen = StreamColors.DarkIncomeGreen,
            overBudgetRed = StreamColors.OverBudgetRed,
            fixedExpenseBlockColor = StreamColors.FixedExpenseBlockColor,
            deepSurface = StreamColors.DeepSurfaceDark,
            onDeep = StreamColors.OnDeep,
            onDeepMuted = StreamColors.OnDeepMuted,
            isDark = true
        )
    } else {
        StreamColorPalette(
            paperBase = StreamColors.LightPaperBase,
            cardBackground = StreamColors.LightCardBackground,
            textPrimary = StreamColors.LightTextPrimary,
            textSecondary = StreamColors.LightTextSecondary,
            hairline = StreamColors.LightHairline,
            inputBackground = StreamColors.LightInputBackground,
            accentWarmYellow = StreamColors.AccentWarmYellow,
            textOnAccent = StreamColors.TextOnAccent,
            accentPillBackground = StreamColors.AccentPillBackground,
            incomeGreen = StreamColors.IncomeGreen,
            overBudgetRed = StreamColors.OverBudgetRed,
            fixedExpenseBlockColor = StreamColors.FixedExpenseBlockColor,
            deepSurface = StreamColors.DeepSurface,
            onDeep = StreamColors.OnDeep,
            onDeepMuted = StreamColors.OnDeepMuted,
            isDark = false
        )
    }

    val materialColors = if (darkTheme) {
        darkColorScheme(
            primary = streamColors.accentWarmYellow,
            onPrimary = streamColors.textOnAccent,
            background = streamColors.paperBase,
            surface = streamColors.cardBackground,
            onBackground = streamColors.textPrimary,
            onSurface = streamColors.textPrimary
        )
    } else {
        lightColorScheme(
            primary = streamColors.accentWarmYellow,
            onPrimary = streamColors.textOnAccent,
            background = streamColors.paperBase,
            surface = streamColors.cardBackground,
            onBackground = streamColors.textPrimary,
            onSurface = streamColors.textPrimary
        )
    }

    CompositionLocalProvider(LocalStreamColors provides streamColors) {
        MaterialTheme(
            colorScheme = materialColors,
            typography = StreamTypography,
            content = content
        )
    }
}
