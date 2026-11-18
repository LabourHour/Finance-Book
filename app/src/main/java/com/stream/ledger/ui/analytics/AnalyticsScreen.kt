package com.stream.ledger.ui.analytics

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.stream.ledger.core.designsystem.LocalStreamColors
import com.stream.ledger.core.designsystem.StreamEditorialType
import com.stream.ledger.core.util.AmountText
import com.stream.ledger.core.util.CurrencyFormatter
import com.stream.ledger.data.local.entity.AccountEntity
import com.stream.ledger.data.local.entity.CategoryEntity
import com.stream.ledger.data.local.entity.TransactionEntity
import com.stream.ledger.data.repository.AnalyticsData
import com.stream.ledger.data.repository.CategoryProportionItem
import com.stream.ledger.ui.editorial.EditorialHairline
import com.stream.ledger.ui.editorial.EditorialHeader
import com.stream.ledger.ui.editorial.EditorialSectionLabel
import com.stream.ledger.ui.timeline.TimelineRowItem
import java.util.Locale

@Composable
fun AnalyticsScreen(
    year: Int,
    month: Int,
    analyticsData: AnalyticsData,
    isExpense: Boolean,
    excludeFixedExpense: Boolean,
    accounts: List<AccountEntity>,
    categories: List<CategoryEntity>,
    onToggleType: (Boolean) -> Unit,
    onToggleExcludeFixed: () -> Unit,
    onEditTransaction: (TransactionEntity) -> Unit,
    onDeleteTransaction: (TransactionEntity) -> Unit
) {
    val colors = LocalStreamColors.current
    var selectedCategoryId by remember { mutableStateOf<String?>(null) }

    val accountMap = remember(accounts) { accounts.associateBy { it.id } }
    val categoryMap = remember(categories) { categories.associateBy { it.id } }

    val drillDownTransactions = remember(analyticsData.filteredTransactions, selectedCategoryId) {
        if (selectedCategoryId == null) {
            emptyList()
        } else {
            analyticsData.filteredTransactions.filter { it.categoryId == selectedCategoryId }
        }
    }

    val legendItems = remember(analyticsData.proportionItems) {
        buildLegendItems(analyticsData.proportionItems)
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.paperBase),
        contentPadding = PaddingValues(bottom = 24.dp)
    ) {
        item {
            EditorialHeader(
                eyebrow = "COMPOSITION",
                title = "Overview",
                subtitle = String.format(Locale.ROOT, "%02d / %d", month, year)
            )
        }

        // 总额与日均：先给结论，再给结构
        item {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp, vertical = 10.dp),
                verticalAlignment = Alignment.Bottom
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = if (isExpense) "总支出" else "总收入",
                        fontSize = 9.5.sp,
                        letterSpacing = 1.6.sp,
                        color = colors.textSecondary
                    )
                    Spacer(modifier = Modifier.height(3.dp))
                    AmountText(
                        cents = analyticsData.totalAmount,
                        integerSize = 30.sp,
                        integerWeight = FontWeight.Light,
                        color = if (isExpense) colors.textPrimary else colors.incomeGreen
                    )
                }
                if (isExpense) {
                    Column(horizontalAlignment = Alignment.End) {
                        Text(
                            text = "日均",
                            fontSize = 9.5.sp,
                            letterSpacing = 1.6.sp,
                            color = colors.textSecondary
                        )
                        Spacer(modifier = Modifier.height(3.dp))
                        AmountText(
                            cents = analyticsData.dailyAverage,
                            integerSize = 15.sp,
                            color = colors.textPrimary
                        )
                    }
                }
            }
        }

        // 收支切换 + 不含固定支出
        item {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp, vertical = 2.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                TypeTab(
                    text = "支出",
                    selected = isExpense,
                    onClick = {
                        onToggleType(true)
                        selectedCategoryId = null
                    }
                )
                Spacer(modifier = Modifier.width(18.dp))
                TypeTab(
                    text = "收入",
                    selected = !isExpense,
                    onClick = {
                        onToggleType(false)
                        selectedCategoryId = null
                    }
                )
                Spacer(modifier = Modifier.weight(1f))
                if (isExpense) {
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(8.dp))
                            .clickable(onClick = onToggleExcludeFixed)
                            .padding(horizontal = 6.dp, vertical = 5.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(7.dp)
                                .clip(CircleShape)
                                .background(
                                    if (excludeFixedExpense) colors.accentWarmYellow else colors.hairline
                                )
                        )
                        Spacer(modifier = Modifier.width(5.dp))
                        Text(
                            text = "不含固定支出",
                            fontSize = 10.5.sp,
                            color = if (excludeFixedExpense) colors.textPrimary else colors.textSecondary
                        )
                    }
                }
            }
        }

        // 占比条 + 图例（绝不使用饼图/环形图）
        item {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp, vertical = 8.dp)
            ) {
                if (legendItems.isNotEmpty()) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(7.dp)
                            .clip(RoundedCornerShape(4.dp)),
                        horizontalArrangement = Arrangement.spacedBy(2.dp)
                    ) {
                        legendItems.forEach { item ->
                            Box(
                                modifier = Modifier
                                    .weight(item.percentage.coerceAtLeast(0.002f))
                                    .fillMaxHeight()
                                    .clip(RoundedCornerShape(2.dp))
                                    .background(item.color)
                            )
                        }
                    }
                    Spacer(modifier = Modifier.height(10.dp))
                    if (legendItems.size <= 3) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(16.dp)
                        ) {
                            legendItems.forEach { item ->
                                LegendChip(
                                    item = item,
                                    modifier = Modifier.weight(1f)
                                )
                            }
                        }
                    } else {
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            legendItems.chunked(2).forEach { rowItems ->
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(16.dp)
                                ) {
                                    rowItems.forEach { item ->
                                        LegendChip(
                                            item = item,
                                            modifier = Modifier.weight(1f)
                                        )
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Text(
                        text = "本月暂无统计数据",
                        fontSize = 12.sp,
                        color = colors.textSecondary
                    )
                }
            }
        }

        // 两个分类进度卡（横向进度，不做环形）
        if (analyticsData.proportionItems.isNotEmpty()) {
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    analyticsData.proportionItems.take(2).forEach { item ->
                        CategoryProgressCard(
                            item = item,
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }
        }

        // 洞察句
        if (analyticsData.insightSentence.isNotBlank()) {
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp, vertical = 6.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .background(colors.accentWarmYellow.copy(alpha = 0.10f))
                        .padding(horizontal = 14.dp, vertical = 11.dp),
                    verticalAlignment = Alignment.Top
                ) {
                    Box(
                        modifier = Modifier
                            .padding(top = 4.dp)
                            .size(7.dp)
                            .clip(CircleShape)
                            .background(colors.accentWarmYellow)
                    )
                    Spacer(modifier = Modifier.width(9.dp))
                    Text(
                        text = analyticsData.insightSentence,
                        fontSize = 11.5.sp,
                        lineHeight = 18.sp,
                        color = if (colors.isDark) colors.textPrimary else Color(0xFF6E5A2E)
                    )
                }
            }
        }

        item {
            EditorialSectionLabel(
                title = "全部分类",
                trailing = "金额 / 占比"
            )
        }

        items(
            items = analyticsData.proportionItems,
            key = { it.categoryId }
        ) { item ->
            CategoryLine(
                item = item,
                isSelected = selectedCategoryId == item.categoryId,
                onClick = {
                    selectedCategoryId = if (selectedCategoryId == item.categoryId) null else item.categoryId
                }
            )
        }

        // 下钻明细
        if (selectedCategoryId != null && drillDownTransactions.isNotEmpty()) {
            item {
                EditorialSectionLabel(
                    title = "对应明细 (${drillDownTransactions.size} 笔)",
                    trailing = "收起"
                )
            }
            items(
                items = drillDownTransactions,
                key = { "drill_${it.id}" }
            ) { tx ->
                TimelineRowItem(
                    transaction = tx,
                    category = categoryMap[tx.categoryId],
                    account = accountMap[tx.accountId],
                    toAccount = tx.toAccountId?.let { accountMap[it] },
                    onClick = { onEditTransaction(tx) },
                    onDelete = { onDeleteTransaction(tx) }
                )
                EditorialHairline()
            }
        }
    }
}

@Composable
private fun LegendChip(
    item: LegendItem,
    modifier: Modifier = Modifier
) {
    val colors = LocalStreamColors.current
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(6.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(item.color)
        )
        Spacer(modifier = Modifier.width(4.dp))
        Text(
            text = "${item.name} ${formatPercent(item.percentage)}",
            fontSize = 9.5.sp,
            color = colors.textSecondary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
private fun TypeTab(
    text: String,
    selected: Boolean,
    onClick: () -> Unit
) {
    val colors = LocalStreamColors.current
    Column(
        modifier = Modifier
            .clip(RoundedCornerShape(4.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = text,
            fontSize = 11.sp,
            letterSpacing = 0.8.sp,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
            color = if (selected) colors.textPrimary else colors.textSecondary
        )
        Spacer(modifier = Modifier.height(5.dp))
        Box(
            modifier = Modifier
                .width(18.dp)
                .height(1.5.dp)
                .background(if (selected) colors.textPrimary else Color.Transparent)
        )
    }
}

@Composable
private fun CategoryProgressCard(
    item: CategoryProportionItem,
    modifier: Modifier = Modifier
) {
    val colors = LocalStreamColors.current
    val itemColor = remember(item.colorHex) { parseColor(item.colorHex) }

    Column(
        modifier = modifier
            .clip(RoundedCornerShape(20.dp))
            .background(colors.cardBackground)
            .padding(horizontal = 14.dp, vertical = 13.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Bottom
        ) {
            Text(
                text = item.name,
                fontSize = 11.sp,
                color = colors.textSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f, fill = false)
            )
            Spacer(modifier = Modifier.width(6.dp))
            Text(
                text = formatPercent(item.percentage),
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = colors.textPrimary
            )
        }
        Spacer(modifier = Modifier.height(5.dp))
        Text(
            text = CurrencyFormatter.formatPlain(item.amountCents),
            fontSize = 15.sp,
            color = colors.textPrimary,
            maxLines = 1
        )
        Spacer(modifier = Modifier.height(9.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(4.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(colors.hairline)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(item.percentage.coerceIn(0.01f, 1f))
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(2.dp))
                    .background(itemColor)
            )
        }
        Spacer(modifier = Modifier.height(7.dp))
        Text(
            text = "占本月金额",
            fontSize = 9.5.sp,
            color = colors.textSecondary
        )
    }
}

@Composable
private fun CategoryLine(
    item: CategoryProportionItem,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    val colors = LocalStreamColors.current
    val itemColor = remember(item.colorHex) { parseColor(item.colorHex) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .background(if (isSelected) colors.accentPillBackground.copy(alpha = 0.55f) else Color.Transparent)
            .padding(horizontal = 24.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(7.dp)
                .clip(CircleShape)
                .background(itemColor)
        )
        Spacer(modifier = Modifier.width(11.dp))
        Text(
            text = item.name,
            fontSize = 12.5.sp,
            color = colors.textPrimary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f)
        )
        Text(
            text = formatPercent(item.percentage),
            fontSize = 10.5.sp,
            color = colors.textSecondary,
            textAlign = TextAlign.End,
            modifier = Modifier.width(42.dp)
        )
        Text(
            text = CurrencyFormatter.formatPlain(item.amountCents, withSymbol = false),
            fontSize = 12.5.sp,
            color = colors.textPrimary,
            textAlign = TextAlign.End,
            maxLines = 1,
            modifier = Modifier.widthIn(min = 64.dp)
        )
    }
}

private data class LegendItem(
    val name: String,
    val percentage: Float,
    val color: Color
)

private fun buildLegendItems(items: List<CategoryProportionItem>): List<LegendItem> {
    if (items.isEmpty()) return emptyList()
    if (items.size <= 4) {
        return items.map { LegendItem(it.name, it.percentage, parseColor(it.colorHex)) }
    }
    val top = items.take(3).map { LegendItem(it.name, it.percentage, parseColor(it.colorHex)) }
    val restPercentage = items.drop(3).sumOf { it.percentage.toDouble() }.toFloat()
    return top + LegendItem("其他", restPercentage, Color(0xFFC9A227))
}

private fun formatPercent(percentage: Float): String =
    String.format(Locale.CHINA, "%.1f%%", percentage * 100f)

private fun parseColor(hex: String): Color = try {
    Color(android.graphics.Color.parseColor(hex))
} catch (_: Exception) {
    Color(0xFF8C867A)
}