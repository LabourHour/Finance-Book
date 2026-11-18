package com.stream.ledger.ui.timeline

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
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
import com.stream.ledger.data.local.entity.TransactionType
import com.stream.ledger.data.repository.MonthRhythmData
import com.stream.ledger.ui.editorial.EditorialDeepCard
import com.stream.ledger.ui.editorial.EditorialHairline
import com.stream.ledger.ui.editorial.EditorialHeader
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.max

private val MONTH_NAMES_EN = arrayOf(
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TimelineScreen(
    year: Int,
    month: Int,
    selectedDay: Int?,
    rhythmData: MonthRhythmData,
    transactions: List<TransactionEntity>,
    accounts: List<AccountEntity>,
    categories: List<CategoryEntity>,
    onPrevMonth: () -> Unit,
    onNextMonth: () -> Unit,
    onSelectDay: (Int?) -> Unit,
    onEditTransaction: (TransactionEntity) -> Unit,
    onDeleteTransaction: (TransactionEntity) -> Unit,
    onOpenSettings: () -> Unit
) {
    val colors = LocalStreamColors.current

    val accountMap = remember(accounts) { accounts.associateBy { it.id } }
    val categoryMap = remember(categories) { categories.associateBy { it.id } }

    // 筛选当前月份且可按日过滤的流水
    val cal = remember { Calendar.getInstance() }
    val currentMonthTransactions = remember(transactions, year, month, selectedDay) {
        transactions.filter { t ->
            cal.timeInMillis = t.occurredAt
            val matchMonth = cal.get(Calendar.YEAR) == year && (cal.get(Calendar.MONTH) + 1) == month
            if (!matchMonth) return@filter false
            if (selectedDay != null) {
                cal.get(Calendar.DAY_OF_MONTH) == selectedDay
            } else {
                true
            }
        }
    }

    // 按日分组并一次性汇总每日收支
    val groupedList = remember(currentMonthTransactions) {
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.CHINA)
        val dayGroups = mutableMapOf<String, MutableList<TransactionEntity>>()
        for (t in currentMonthTransactions) {
            val key = dateFormat.format(Date(t.occurredAt))
            dayGroups.getOrPut(key) { mutableListOf() }.add(t)
        }

        dayGroups.entries
            .sortedByDescending { it.key }
            .map { entry ->
                var expense = 0L
                var income = 0L
                for (t in entry.value) {
                    when (t.type) {
                        TransactionType.EXPENSE -> expense += t.amount
                        TransactionType.INCOME -> income += t.amount
                        TransactionType.TRANSFER -> Unit
                    }
                }
                val dayCal = Calendar.getInstance().apply { timeInMillis = entry.value.first().occurredAt }
                EditorialDayGroup(
                    dateKey = entry.key,
                    dayOfMonth = dayCal.get(Calendar.DAY_OF_MONTH),
                    weekdayLabel = weekdayLabel(dayCal.get(Calendar.DAY_OF_WEEK)),
                    transactions = entry.value,
                    expenseCents = expense,
                    incomeCents = income
                )
            }
    }

    // 月度日均（历史月按整月天数）
    val dailyAverage = remember(year, month, rhythmData.monthTotalExpense) {
        val now = Calendar.getInstance()
        val isCurrentMonth = now.get(Calendar.YEAR) == year && (now.get(Calendar.MONTH) + 1) == month
        val days = if (isCurrentMonth) {
            max(1, now.get(Calendar.DAY_OF_MONTH))
        } else {
            Calendar.getInstance().apply {
                set(Calendar.YEAR, year)
                set(Calendar.MONTH, month - 1)
                set(Calendar.DAY_OF_MONTH, 1)
            }.getActualMaximum(Calendar.DAY_OF_MONTH).coerceAtLeast(1)
        }
        rhythmData.monthTotalExpense / days
    }

    val heroAmount = if (selectedDay != null) {
        rhythmData.selectedDayExpense ?: rhythmData.monthTotalExpense
    } else {
        rhythmData.monthTotalExpense
    }
    val heroKicker = if (selectedDay != null) "${month}月${selectedDay}日 支出" else "本月支出"

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.paperBase),
        contentPadding = PaddingValues(bottom = 24.dp)
    ) {
        item {
            EditorialHeader(
                eyebrow = "MONTHLY LEDGER",
                title = MONTH_NAMES_EN[(month - 1).coerceIn(0, 11)],
                subtitle = String.format(Locale.ROOT, "%02d / %d", month, year),
                actions = {
                    IconButton(onClick = onPrevMonth, modifier = Modifier.size(32.dp)) {
                        Icon(
                            Icons.Default.ArrowBack,
                            contentDescription = "上月",
                            modifier = Modifier.size(16.dp),
                            tint = colors.textSecondary
                        )
                    }
                    IconButton(onClick = onNextMonth, modifier = Modifier.size(32.dp)) {
                        Icon(
                            Icons.Default.ArrowForward,
                            contentDescription = "下月",
                            modifier = Modifier.size(16.dp),
                            tint = colors.textSecondary
                        )
                    }
                    IconButton(onClick = onOpenSettings, modifier = Modifier.size(32.dp)) {
                        Icon(
                            Icons.Default.Settings,
                            contentDescription = "设置",
                            modifier = Modifier.size(18.dp),
                            tint = colors.textSecondary
                        )
                    }
                }
            )
        }

        item {
            Box(modifier = Modifier.padding(horizontal = 20.dp, vertical = 14.dp)) {
                EditorialDeepCard {
                    Text(
                        text = heroKicker,
                        fontSize = 9.5.sp,
                        letterSpacing = 2.2.sp,
                        fontWeight = FontWeight.Medium,
                        color = colors.onDeepMuted
                    )
                    Spacer(modifier = Modifier.height(10.dp))
                    AmountText(
                        cents = heroAmount,
                        integerSize = 50.sp,
                        decimalSize = 22.sp,
                        integerWeight = FontWeight.Light,
                        color = colors.onDeep,
                        secondaryColor = colors.onDeepMuted,
                        showSymbol = false
                    )
                    Spacer(modifier = Modifier.height(14.dp))
                    HorizontalDivider(
                        color = colors.onDeep.copy(alpha = 0.14f),
                        thickness = 0.5.dp
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Row(modifier = Modifier.fillMaxWidth()) {
                        DeepMetric(
                            label = "收入",
                            value = "+${CurrencyFormatter.formatPlain(rhythmData.monthIncome, false)}",
                            valueColor = Color(0xFF7CBF97),
                            modifier = Modifier.weight(1f)
                        )
                        DeepMetric(
                            label = "结余",
                            value = CurrencyFormatter.formatPlain(rhythmData.monthBalance, false),
                            valueColor = colors.onDeep,
                            modifier = Modifier.weight(1f)
                        )
                        DeepMetric(
                            label = "日均",
                            value = CurrencyFormatter.formatPlain(dailyAverage, false),
                            valueColor = colors.onDeep,
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }
        }

        if (groupedList.isEmpty()) {
            item {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 48.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "本月暂无记录，轻触右下角「+」记一笔",
                        style = MaterialTheme.typography.bodyMedium,
                        color = colors.textSecondary
                    )
                }
            }
        } else {
            groupedList.forEach { group ->
                item(key = "day_${group.dateKey}") {
                    val isFiltered = selectedDay == group.dayOfMonth
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                onSelectDay(if (isFiltered) null else group.dayOfMonth)
                            }
                            .padding(start = 24.dp, end = 22.dp, top = 18.dp, bottom = 6.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = group.dayOfMonth.toString(),
                            style = StreamEditorialType.DayNumber,
                            color = if (isFiltered) colors.accentWarmYellow else colors.textPrimary
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = group.weekdayLabel,
                            style = StreamEditorialType.DayLabel,
                            color = colors.textSecondary
                        )
                        Spacer(modifier = Modifier.width(10.dp))
                        HorizontalDivider(
                            modifier = Modifier.weight(1f),
                            thickness = 0.5.dp,
                            color = colors.hairline
                        )
                        Spacer(modifier = Modifier.width(10.dp))
                        Text(
                            text = when {
                                group.expenseCents > 0 ->
                                    "-${CurrencyFormatter.formatPlain(group.expenseCents, false)}"
                                group.incomeCents > 0 ->
                                    "+${CurrencyFormatter.formatPlain(group.incomeCents, false)}"
                                else -> "0.00"
                            },
                            fontSize = 11.sp,
                            color = if (group.expenseCents > 0) colors.textSecondary else colors.incomeGreen
                        )
                    }
                }

                itemsIndexed(
                    items = group.transactions,
                    key = { _, tx -> tx.id }
                ) { index, tx ->
                    TimelineRowItem(
                        transaction = tx,
                        category = categoryMap[tx.categoryId],
                        account = accountMap[tx.accountId],
                        toAccount = tx.toAccountId?.let { accountMap[it] },
                        onClick = { onEditTransaction(tx) },
                        onDelete = { onDeleteTransaction(tx) }
                    )
                    if (index < group.transactions.size - 1) {
                        EditorialHairline()
                    }
                }
            }
        }
    }
}

@Composable
private fun DeepMetric(
    label: String,
    value: String,
    valueColor: Color,
    modifier: Modifier = Modifier
) {
    val colors = LocalStreamColors.current
    Column(modifier = modifier) {
        Text(
            text = label,
            fontSize = 9.sp,
            letterSpacing = 1.sp,
            color = colors.onDeepMuted
        )
        Spacer(modifier = Modifier.height(3.dp))
        Text(
            text = value,
            fontSize = 12.5.sp,
            fontWeight = FontWeight.Medium,
            color = valueColor,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
fun TimelineRowItem(
    transaction: TransactionEntity,
    category: CategoryEntity?,
    account: AccountEntity?,
    toAccount: AccountEntity?,
    onClick: () -> Unit,
    onDelete: () -> Unit
) {
    val colors = LocalStreamColors.current
    val catColor = remember(category) {
        try {
            Color(android.graphics.Color.parseColor(category?.colorHex ?: "#8C867A"))
        } catch (_: Exception) {
            Color(0xFF8C867A)
        }
    }
    val timeStr = remember(transaction.occurredAt) {
        SimpleDateFormat("HH:mm", Locale.CHINA).format(Date(transaction.occurredAt))
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 24.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // C 编辑风：白色圆形底 + 彩色单字
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(colors.cardBackground),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = if (transaction.type == TransactionType.TRANSFER) "转" else (category?.symbolText ?: "他"),
                fontWeight = FontWeight.SemiBold,
                fontSize = 14.sp,
                color = if (transaction.type == TransactionType.TRANSFER) Color(0xFF5E72E4) else catColor
            )
        }

        Spacer(modifier = Modifier.width(12.dp))

        Column(modifier = Modifier.weight(1f)) {
            val mainTitle = when {
                !transaction.note.isNullOrBlank() -> transaction.note
                transaction.type == TransactionType.TRANSFER -> "转账到 ${toAccount?.name ?: "账户"}"
                else -> category?.name ?: "未分类"
            }
            Text(
                text = mainTitle,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
                color = colors.textPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )

            val subDetail = buildString {
                if (transaction.type == TransactionType.TRANSFER) {
                    append(account?.name ?: "账户")
                    append(" ➔ ")
                    append(toAccount?.name ?: "账户")
                } else {
                    category?.name?.let { append(it).append(" · ") }
                    account?.name?.let { append(it).append(" · ") }
                    append(timeStr)
                }
            }
            Text(
                text = subDetail,
                fontSize = 10.5.sp,
                color = colors.textSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }

        Spacer(modifier = Modifier.width(10.dp))

        val amountPrefix = when (transaction.type) {
            TransactionType.EXPENSE -> "-"
            TransactionType.INCOME -> "+"
            TransactionType.TRANSFER -> ""
        }
        val amountColor = when (transaction.type) {
            TransactionType.EXPENSE -> colors.textPrimary
            TransactionType.INCOME -> colors.incomeGreen
            TransactionType.TRANSFER -> Color(0xFF5E72E4)
        }
        Text(
            text = "$amountPrefix${CurrencyFormatter.formatPlain(transaction.amount, false)}",
            fontSize = 14.sp,
            fontWeight = FontWeight.Normal,
            color = amountColor,
            maxLines = 1
        )
    }
}

private data class EditorialDayGroup(
    val dateKey: String,
    val dayOfMonth: Int,
    val weekdayLabel: String,
    val transactions: List<TransactionEntity>,
    val expenseCents: Long,
    val incomeCents: Long
)

private fun weekdayLabel(dayOfWeek: Int): String = when (dayOfWeek) {
    Calendar.MONDAY -> "周一"
    Calendar.TUESDAY -> "周二"
    Calendar.WEDNESDAY -> "周三"
    Calendar.THURSDAY -> "周四"
    Calendar.FRIDAY -> "周五"
    Calendar.SATURDAY -> "周六"
    else -> "周日"
}