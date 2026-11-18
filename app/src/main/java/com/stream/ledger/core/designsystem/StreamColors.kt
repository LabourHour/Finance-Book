package com.stream.ledger.core.designsystem

import androidx.compose.ui.graphics.Color

/**
 * Apple 备忘录质感色彩设计系统
 * 满足 WCAG AA 4.5:1 对比度标准
 */
object StreamColors {
    // 浅色模式 - 温暖纸张调色板（C 编辑风）
    val LightPaperBase = Color(0xFFF3EFE6)          // 温暖米纸底色
    val LightCardBackground = Color(0xFFFFFFFF)     // 纯白圆角卡片
    val LightTextPrimary = Color(0xFF221F1A)        // 深墨黑
    val LightTextSecondary = Color(0xFF7C7264)      // 暖棕灰副文本
    val LightHairline = Color(0xFFE5DED1)           // 极细发丝线
    val LightInputBackground = Color(0xFFEDE7DA)    // 输入框底色

    // 深色主卡（编辑风 hero / 账户主卡）
    val DeepSurface = Color(0xFF231F1A)
    val DeepSurfaceDark = Color(0xFF2A2620)
    val OnDeep = Color(0xFFF2EBDD)
    val OnDeepMuted = Color(0x80F2EBDD)

    // 深色模式 - 纸张碳素深灰调色板
    val DarkPaperBase = Color(0xFF181715)           // 深碳墨纸底
    val DarkCardBackground = Color(0xFF24221F)      // 深暖灰卡片
    val DarkTextPrimary = Color(0xFFEDEAE3)         // 柔和白墨主文字
    val DarkTextSecondary = Color(0xFFA69E92)       // 暖灰次要文字
    val DarkHairline = Color(0xFF33302B)            // 深色发丝线
    val DarkInputBackground = Color(0xFF2C2A26)     // 深色输入底

    // 核心品牌主色
    val AccentWarmYellow = Color(0xFFE5A93C)        // 备忘录暖黄 (仅作填充底色)
    val TextOnAccent = Color(0xFF1C1B18)            // 黄色底上的文字 (强制深色，严禁白色)
    val AccentPillBackground = Color(0xFFFBF1DE)    // 浅黄胶囊选中底色

    // 语义色彩
    val IncomeGreen = Color(0xFF2F7D52)             // 柔和森林绿 (浅色)
    val DarkIncomeGreen = Color(0xFF3D9A66)         // 柔和森林绿 (深色)
    val OverBudgetRed = Color(0xFFC0463F)           // 超预算警戒柔红 (日常支出不用红色)
    val FixedExpenseGray = Color(0xFF9E9B93)        // 房租等固定支出专用灰 (仅用于色块)

    // 8 组基于 OKLCH 均匀明度/彩度生成的分类色彩
    val CategoryColors = listOf(
        Color(0xFFD97757), // 陶土暖橙 (餐饮美食)
        Color(0xFF5B88A5), // 雾霾蓝 (交通出行)
        Color(0xFF5B9B88), // 鼠尾青 (日常购物)
        Color(0xFF7E72A6), // 浅紫灰 (休闲娱乐)
        Color(0xFFC98B3E), // 暖琥珀 (生活日用)
        Color(0xFFBF6B7B), // 枯玫瑰红 (医疗健康)
        Color(0xFF6A9A7B), // 橄榄绿 (教育成长)
        Color(0xFF8C867A), // 亚麻灰 (其他杂项)
    )

    // 固定支出专用块色
    val FixedExpenseBlockColor = Color(0xFF9E9B93)
}
