package com.stream.ledger.ui.accounts

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
import com.stream.ledger.data.local.entity.AccountType
import com.stream.ledger.data.local.entity.TransactionEntity
import com.stream.ledger.data.local.entity.TransactionType
import com.stream.ledger.data.repository.BalanceSummary
import com.stream.ledger.ui.editorial.EditorialDeepCard
import com.stream.ledger.ui.editorial.EditorialHeader
import com.stream.ledger.ui.editorial.EditorialSectionLabel
import java.util.Calendar
import java.util.Locale

@Composable
fun AccountsScreen(
    balanceSummary: BalanceSummary,
    accounts: List<AccountEntity>,
    transactions: List<TransactionEntity>,
    onOpenTransfer: () -> Unit
) {
    val colors = LocalStreamColors.current

    // 一次性汇总「各账户本月支出」与「本月净收支」
    val monthStats = remember(transactions) {
        val cal = Calendar.getInstance()
        val curYear = cal.get(Calendar.YEAR)
        val curMonth = cal.get(Calendar.MONTH) + 1

        val expenses = mutableMapOf<String, Long>()
        var income = 0L
        var expenseTotal = 0L
        for (t in transactions) {
            cal.timeInMillis = t.occurredAt
            if (cal.get(Calendar.YEAR) != curYear || (cal.get(Calendar.MONTH) + 1) != curMonth) {
                continue
            }
            when (t.type) {
                TransactionType.EXPENSE -> {
                    expenses[t.accountId] = (expenses[t.accountId] ?: 0L) + t.amount
                    expenseTotal += t.amount
                }
                TransactionType.INCOME -> income += t.amount
                TransactionType.TRANSFER -> Unit
            }
        }
        AccountMonthStats(expenses, income - expenseTotal)
    }

    val assetAccounts = accounts.filter { it.type != AccountType.CREDIT }
    val creditAccounts = accounts.filter { it.type == AccountType.CREDIT }
    val heroAccount = assetAccounts.firstOrNull() ?: accounts.firstOrNull()

    val now = remember { Calendar.getInstance() }
    val subtitle = String.format(
        Locale.ROOT,
        "%02d / %d",
        now.get(Calendar.MONTH) + 1,
        now.get(Calendar.YEAR)
    )

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.paperBase),
        contentPadding = PaddingValues(bottom = 24.dp)
    ) {
        item {
            EditorialHeader(
                eyebrow = "PORTFOLIO",
                title = "Accounts",
                subtitle = subtitle,
                actions = {
                    Text(
                        text = "快速转账",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        color = colors.accentWarmYellow,
                        modifier = Modifier
                            .clip(RoundedCornerShape(8.dp))
                            .clickable(onClick = onOpenTransfer)
                            .padding(horizontal = 8.dp, vertical = 6.dp)
                    )
                }
            )
        }

        // 账户主卡（单张完整卡片，不做横滑露边）
        if (heroAccount != null) {
            item {
                Box(modifier = Modifier.padding(horizontal = 20.dp, vertical = 14.dp)) {
                    AccountHeroCard(
                        account = heroAccount,
                        balance = balanceSummary.accountBalances[heroAccount.id]
                            ?: heroAccount.initialBalance,
                        monthExpense = monthStats.expenses[heroAccount.id] ?: 0L
                    )
                }
            }
        }

        // 净资产卡 + 资产/负债分割条
        item {
            Box(modifier = Modifier.padding(horizontal = 20.dp, vertical = 2.dp)) {
                NetWorthCard(balanceSummary = balanceSummary)
            }
        }

        // 流动资产
        if (assetAccounts.isNotEmpty()) {
            item {
                EditorialSectionLabel(
                    title = "流动资产",
                    trailing = "${assetAccounts.size} 个"
                )
            }
            items(items = assetAccounts, key = { it.id }) { account ->
                AccountLine(
                    account = account,
                    balance = balanceSummary.accountBalances[account.id] ?: account.initialBalance,
                    monthExpense = monthStats.expenses[account.id] ?: 0L
                )
            }
        }

        // 信用负债
        if (creditAccounts.isNotEmpty()) {
            item {
                EditorialSectionLabel(
                    title = "信用负债",
                    trailing = "${creditAccounts.size} 个"
                )
            }
            items(items = creditAccounts, key = { it.id }) { account ->
                AccountLine(
                    account = account,
                    balance = balanceSummary.accountBalances[account.id] ?: account.initialBalance,
                    monthExpense = monthStats.expenses[account.id] ?: 0L
                )
            }
        }

        if (accounts.isEmpty()) {
            item {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp, vertical = 32.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "暂无账户，先在记账面板记一笔即可开始",
                        fontSize = 12.sp,
                        color = colors.textSecondary
                    )
                }
            }
        }
    }
}

@Composable
private fun AccountHeroCard(
    account: AccountEntity,
    balance: Long,
    monthExpense: Long
) {
    val colors = LocalStreamColors.current
    val accent = remember(account.colorHex) { parseColor(account.colorHex) }

    EditorialDeepCard(modifier = Modifier.padding(0.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.weight(1f)
            ) {
                Box(
                    modifier = Modifier
                        .size(28.dp)
                        .clip(CircleShape)
                        .background(colors.onDeep.copy(alpha = 0.12f)),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = account.symbolText,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = if (account.type == AccountType.CREDIT) Color(0xFFC0605A) else accent
                    )
                }
                Spacer(modifier = Modifier.width(9.dp))
                Text(
                    text = account.name,
                    fontSize = 12.5.sp,
                    fontWeight = FontWeight.Medium,
                    color = colors.onDeep,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            Text(
                text = accountTypeLabel(account.type),
                fontSize = 9.sp,
                letterSpacing = 1.4.sp,
                color = colors.onDeepMuted
            )
        }

        Spacer(modifier = Modifier.height(15.dp))
        AmountText(
            cents = balance,
            integerSize = 28.sp,
            decimalSize = 13.sp,
            integerWeight = FontWeight.Light,
            color = colors.onDeep,
            secondaryColor = colors.onDeepMuted,
            showSymbol = false
        )
        Spacer(modifier = Modifier.height(9.dp))
        HorizontalDivider(
            color = colors.onDeep.copy(alpha = 0.12f),
            thickness = 0.5.dp
        )
        Spacer(modifier = Modifier.height(8.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = "本月支出",
                fontSize = 9.5.sp,
                color = colors.onDeepMuted
            )
            Text(
                text = "-${CurrencyFormatter.formatPlain(monthExpense, false)}",
                fontSize = 9.5.sp,
                color = colors.onDeep
            )
        }

    }
}

@Composable
private fun NetWorthCard(balanceSummary: BalanceSummary) {
    val colors = LocalStreamColors.current
    val assets = balanceSummary.totalAssets
    val liabilities = balanceSummary.totalLiabilities
    val total = (assets + liabilities).coerceAtLeast(1L)
    val assetRatio = (assets.toFloat() / total).coerceIn(0.02f, 1f)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(colors.cardBackground)
            .padding(horizontal = 16.dp, vertical = 15.dp)
    ) {
        Text(
            text = "净资产",
            style = StreamEditorialType.SectionLabel,
            color = colors.textSecondary
        )
        Spacer(modifier = Modifier.height(3.dp))
        AmountText(
            cents = balanceSummary.netAssets,
            integerSize = 27.sp,
            integerWeight = FontWeight.Light,
            color = colors.textPrimary
        )
        Spacer(modifier = Modifier.height(12.dp))
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(4.dp)
                .clip(RoundedCornerShape(2.dp)),
            horizontalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Box(
                modifier = Modifier
                    .weight(assetRatio)
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(2.dp))
                    .background(Color(0xFF3F8A62))
            )
            if (liabilities > 0L) {
                Box(
                    modifier = Modifier
                        .weight((1f - assetRatio).coerceAtLeast(0.02f))
                        .fillMaxHeight()
                        .clip(RoundedCornerShape(2.dp))
                        .background(Color(0xFFC0605A))
                )
            }
        }
        Spacer(modifier = Modifier.height(9.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = "正资产 ${CurrencyFormatter.formatPlain(assets)}",
                fontSize = 9.5.sp,
                color = colors.textSecondary
            )
            Text(
                text = "负债 ${CurrencyFormatter.formatPlain(liabilities)}",
                fontSize = 9.5.sp,
                color = colors.textSecondary
            )
        }
    }
}

@Composable
private fun AccountLine(
    account: AccountEntity,
    balance: Long,
    monthExpense: Long
) {
    val colors = LocalStreamColors.current
    val accent = remember(account.colorHex) { parseColor(account.colorHex) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(7.dp)
                .clip(CircleShape)
                .background(accent)
        )
        Spacer(modifier = Modifier.width(11.dp))
        Text(
            text = account.name,
            fontSize = 12.5.sp,
            color = colors.textPrimary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f)
        )
        Text(
            text = if (monthExpense > 0L) {
                "本月 -${CurrencyFormatter.formatPlain(monthExpense, false)}"
            } else {
                "本月无支出"
            },
            fontSize = 10.5.sp,
            color = colors.textSecondary,
            textAlign = TextAlign.End,
            maxLines = 1,
            modifier = Modifier.widthIn(min = 72.dp)
        )
        Text(
            text = CurrencyFormatter.formatPlain(balance, withSymbol = false),
            fontSize = 12.5.sp,
            color = if (balance < 0) colors.overBudgetRed else colors.textPrimary,
            textAlign = TextAlign.End,
            maxLines = 1,
            modifier = Modifier.widthIn(min = 64.dp)
        )
    }
}

private data class AccountMonthStats(
    val expenses: Map<String, Long>,
    val netChange: Long
)

private fun accountTypeLabel(type: AccountType): String = when (type) {
    AccountType.WECHAT -> "WECHAT"
    AccountType.ALIPAY -> "ALIPAY"
    AccountType.BANK -> "BANK"
    AccountType.CREDIT -> "CREDIT"
    AccountType.CASH -> "CASH"
    else -> "OTHER"
}

private fun parseColor(hex: String): Color = try {
    Color(android.graphics.Color.parseColor(hex))
} catch (_: Exception) {
    Color(0xFF1677FF)
}