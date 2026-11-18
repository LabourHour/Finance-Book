package com.stream.ledger.data.repository

import android.content.Context
import androidx.room.withTransaction
import com.stream.ledger.data.local.AppDatabase
import com.stream.ledger.data.local.entity.AccountEntity
import com.stream.ledger.data.local.entity.AccountType
import com.stream.ledger.data.local.entity.CategoryEntity
import com.stream.ledger.data.local.entity.TransactionEntity
import com.stream.ledger.data.local.entity.TransactionSource
import com.stream.ledger.data.local.entity.TransactionType
import com.stream.ledger.data.seed.DataSeed
import kotlinx.coroutines.flow.Flow
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale
import kotlin.math.abs
import kotlin.math.max

data class BalanceSummary(
    val accountBalances: Map<String, Long>,
    val netAssets: Long,        // 净资产 (全部代数和，信用卡欠款自然减少净资产)
    val totalAssets: Long,      // 正资产汇总
    val totalLiabilities: Long  // 负债汇总 (信用卡欠款为正数展示)
)

data class DayRhythmBar(
    val dayOfMonth: Int,
    val amountCents: Long,
    val isToday: Boolean,
    val isFuture: Boolean,
    val isCapped: Boolean,      // 是否被封顶截断展示
    val heightFraction: Float   // 0f..1f 用于柱子高度
)

data class MonthRhythmData(
    val monthTotalExpense: Long,
    val comparisonSentence: String,
    val monthIncome: Long,
    val monthBalance: Long,
    val bars: List<DayRhythmBar>,
    val selectedDayExpense: Long?
)

data class CategoryProportionItem(
    val categoryId: String,
    val name: String,
    val symbolText: String,
    val colorHex: String,
    val amountCents: Long,
    val percentage: Float
)

data class AnalyticsData(
    val totalAmount: Long,
    val dailyAverage: Long,
    val insightSentence: String,
    val proportionItems: List<CategoryProportionItem>,
    val filteredTransactions: List<TransactionEntity>
)

data class ClearSampleResult(
    val deletedTransactions: Int,
    val removedAccounts: Int,
    val keptAccounts: Int
)

class LedgerRepository(
    private val database: AppDatabase,
    private val context: Context
) {
    private val transactionDao = database.transactionDao()
    private val accountDao = database.accountDao()
    private val categoryDao = database.categoryDao()

    val allTransactionsFlow: Flow<List<TransactionEntity>> = transactionDao.getAllFlow()
    val allAccountsFlow: Flow<List<AccountEntity>> = accountDao.getAllFlow()
    val allCategoriesFlow: Flow<List<CategoryEntity>> = categoryDao.getActiveFlow()

    /**
     * 首次启动自动检查并注入默认分类和生动示例数据
     */
    suspend fun ensureInitialData() {
        val existingCats = categoryDao.getAllList()
        if (existingCats.isEmpty()) {
            categoryDao.insertAll(DataSeed.defaultCategories)
        }
        val existingAccs = accountDao.getAllList()
        if (existingAccs.isEmpty()) {
            accountDao.insertAll(DataSeed.sampleAccounts)
            transactionDao.insertAll(DataSeed.createSampleTransactions())
        }
    }

    private fun formatYuan(cents: Long): String =
        String.format(Locale.CHINA, "%,.2f", cents / 100.0)

    /**
     * 实时计算账户动态余额与净资产
     * 规则：余额 = 初始余额 + 收入/转入 - 支出/转出
     */
    fun computeBalances(
        accounts: List<AccountEntity>,
        transactions: List<TransactionEntity>
    ): BalanceSummary {
        val balances = mutableMapOf<String, Long>()
        for (acc in accounts) {
            balances[acc.id] = acc.initialBalance
        }

        for (t in transactions) {
            when (t.type) {
                TransactionType.EXPENSE -> {
                    balances[t.accountId]?.let { balances[t.accountId] = it - t.amount }
                }
                TransactionType.INCOME -> {
                    balances[t.accountId]?.let { balances[t.accountId] = it + t.amount }
                }
                TransactionType.TRANSFER -> {
                    // 转出账户扣减
                    balances[t.accountId]?.let { balances[t.accountId] = it - t.amount }
                    // 转入账户增加 (信用卡欠款负余额趋近于0)
                    t.toAccountId?.let { toId ->
                        balances[toId]?.let { balances[toId] = it + t.amount }
                    }
                }
            }
        }

        var netAssets = 0L
        var totalAssets = 0L
        var totalLiabilities = 0L

        for ((_, b) in balances) {
            netAssets += b
            if (b >= 0L) {
                totalAssets += b
            } else {
                totalLiabilities += abs(b)
            }
        }

        return BalanceSummary(balances, netAssets, totalAssets, totalLiabilities)
    }

    /**
     * 计算「本月节奏」：顶部大数字 + 较上月同期对比 + 每日柱状条（含封顶与最小刻度兜底）
     */
    fun computeMonthRhythm(
        transactions: List<TransactionEntity>,
        targetYear: Int,
        targetMonth: Int, // 1-based (1..12)
        selectedDay: Int? = null
    ): MonthRhythmData {
        val cal = Calendar.getInstance()
        val currentYear = cal.get(Calendar.YEAR)
        val currentMonth = cal.get(Calendar.MONTH) + 1
        val currentDay = cal.get(Calendar.DAY_OF_MONTH)
        val isCurrentMonth = (targetYear == currentYear && targetMonth == currentMonth)

        // 目标月份总天数
        cal.set(Calendar.YEAR, targetYear)
        cal.set(Calendar.MONTH, targetMonth - 1)
        val daysInMonth = cal.getActualMaximum(Calendar.DAY_OF_MONTH)

        // 筛选本月所有交易
        val monthTxs = transactions.filter { t ->
            cal.timeInMillis = t.occurredAt
            cal.get(Calendar.YEAR) == targetYear && (cal.get(Calendar.MONTH) + 1) == targetMonth
        }

        var monthTotalExpense = 0L
        var monthIncome = 0L
        val dailyExpenseMap = mutableMapOf<Int, Long>()

        for (t in monthTxs) {
            cal.timeInMillis = t.occurredAt
            val day = cal.get(Calendar.DAY_OF_MONTH)
            if (t.type == TransactionType.EXPENSE) {
                monthTotalExpense += t.amount
                dailyExpenseMap[day] = (dailyExpenseMap[day] ?: 0L) + t.amount
            } else if (t.type == TransactionType.INCOME) {
                monthIncome += t.amount
            }
        }

        // 计算上月同期支出用于对比
        val prevCal = Calendar.getInstance().apply {
            set(Calendar.YEAR, targetYear)
            set(Calendar.MONTH, targetMonth - 2) // 上个月
        }
        val prevYear = prevCal.get(Calendar.YEAR)
        val prevMonth = prevCal.get(Calendar.MONTH) + 1
        val samePeriodDay = if (isCurrentMonth) currentDay else daysInMonth

        val prevSamePeriodExpense = transactions.filter { t ->
            cal.timeInMillis = t.occurredAt
            val y = cal.get(Calendar.YEAR)
            val m = cal.get(Calendar.MONTH) + 1
            val d = cal.get(Calendar.DAY_OF_MONTH)
            y == prevYear && m == prevMonth && d <= samePeriodDay && t.type == TransactionType.EXPENSE
        }.sumOf { it.amount }

        val comparisonSentence = when {
            prevSamePeriodExpense == 0L -> "开始记录你的清晰流水"
            monthTotalExpense < prevSamePeriodExpense -> {
                val diffCents = prevSamePeriodExpense - monthTotalExpense
                "较上月同期少支出 ¥${formatYuan(diffCents)}"
            }
            monthTotalExpense > prevSamePeriodExpense -> {
                val diffCents = monthTotalExpense - prevSamePeriodExpense
                "较上月同期多支出 ¥${formatYuan(diffCents)}"
            }
            else -> "与上月同期支出持平"
        }

        // 封顶基准高度计算：天数不足时用固定最小刻度兜底（5000分 = ¥50.00）
        val positiveDays = dailyExpenseMap.values.filter { it > 0 }.sorted()
        val capBaseline: Long = if (positiveDays.size < 3) {
            max(positiveDays.maxOrNull() ?: 5000L, 5000L) // 最小刻度兜底
        } else {
            // 排除最大的固定房租极端值，取 85 分位数
            val p85Index = ((positiveDays.size - 1) * 0.85).toInt()
            max(positiveDays[p85Index] * 2L, 5000L)
        }

        val bars = (1..daysInMonth).map { d ->
            val isToday = isCurrentMonth && (d == currentDay)
            val isFuture = isCurrentMonth && (d > currentDay)
            val amount = dailyExpenseMap[d] ?: 0L

            val isCapped = amount > capBaseline
            val fraction = if (isFuture || amount == 0L) {
                0.08f // 浅灰占位底线高度
            } else {
                (amount.toFloat() / capBaseline.toFloat()).coerceIn(0.12f, 1.0f)
            }

            DayRhythmBar(
                dayOfMonth = d,
                amountCents = amount,
                isToday = isToday,
                isFuture = isFuture,
                isCapped = isCapped,
                heightFraction = fraction
            )
        }

        val selectedDayExpense = selectedDay?.let { dailyExpenseMap[it] ?: 0L }

        return MonthRhythmData(
            monthTotalExpense = monthTotalExpense,
            comparisonSentence = comparisonSentence,
            monthIncome = monthIncome,
            monthBalance = monthIncome - monthTotalExpense,
            bars = bars,
            selectedDayExpense = selectedDayExpense
        )
    }

    /**
     * 计算统计分析数据：排除 TRANSFER，支持「不含固定支出」开关，小于 3% 合并为其他
     */
    fun computeAnalytics(
        transactions: List<TransactionEntity>,
        categories: List<CategoryEntity>,
        targetYear: Int,
        targetMonth: Int,
        isExpense: Boolean,
        excludeFixedExpense: Boolean
    ): AnalyticsData {
        val cal = Calendar.getInstance()
        val targetType = if (isExpense) TransactionType.EXPENSE else TransactionType.INCOME
        val catMap = categories.associateBy { it.id }

        // 排除 TRANSFER (转账不计入收支统计)
        val filtered = transactions.filter { t ->
            if (t.type != targetType) return@filter false
            cal.timeInMillis = t.occurredAt
            val matchMonth = cal.get(Calendar.YEAR) == targetYear && (cal.get(Calendar.MONTH) + 1) == targetMonth
            if (!matchMonth) return@filter false

            // 不含固定支出开关
            if (excludeFixedExpense && isExpense) {
                val cat = t.categoryId?.let { catMap[it] }
                if (cat?.isFixedExpense == true) return@filter false
            }

            true
        }

        val totalAmount = filtered.sumOf { it.amount }

        // 日均消费：仅当查看的是「当前年 + 当前月」时才按已过天数计算，历史月按当月实际天数
        val now = Calendar.getInstance()
        val isCurrentMonth = now.get(Calendar.YEAR) == targetYear &&
            (now.get(Calendar.MONTH) + 1) == targetMonth
        val daysPassed = if (isCurrentMonth) {
            max(1, now.get(Calendar.DAY_OF_MONTH))
        } else {
            Calendar.getInstance().apply {
                set(Calendar.YEAR, targetYear)
                set(Calendar.MONTH, targetMonth - 1)
                set(Calendar.DAY_OF_MONTH, 1)
            }.getActualMaximum(Calendar.DAY_OF_MONTH).coerceAtLeast(1)
        }
        val dailyAverage = if (daysPassed > 0) totalAmount / daysPassed else 0L

        if (totalAmount == 0L) {
            return AnalyticsData(
                totalAmount = 0L,
                dailyAverage = 0L,
                insightSentence = "本月暂无${if (isExpense) "支出" else "收入"}记录",
                proportionItems = emptyList(),
                filteredTransactions = emptyList()
            )
        }

        // 按分类汇总
        val catSums = mutableMapOf<String, Long>()
        for (t in filtered) {
            val cid = t.categoryId ?: "unknown"
            catSums[cid] = (catSums[cid] ?: 0L) + t.amount
        }

        val sortedList = catSums.entries
            .map { (cid, amt) ->
                val cat = catMap[cid]
                val pct = amt.toFloat() / totalAmount.toFloat()
                CategoryProportionItem(
                    categoryId = cid,
                    name = cat?.name ?: "其他",
                    symbolText = cat?.symbolText ?: "他",
                    colorHex = cat?.colorHex ?: "#8C867A",
                    amountCents = amt,
                    percentage = pct
                )
            }
            .sortedByDescending { it.amountCents }

        // 小于 3% 合并为「其他」
        val majorItems = mutableListOf<CategoryProportionItem>()
        var otherAmount = 0L
        var otherPct = 0f

        for (item in sortedList) {
            if (item.percentage >= 0.03f) {
                majorItems.add(item)
            } else {
                otherAmount += item.amountCents
                otherPct += item.percentage
            }
        }

        if (otherAmount > 0L) {
            majorItems.add(
                CategoryProportionItem(
                    categoryId = "cat_merged_other",
                    name = "其他",
                    symbolText = "他",
                    colorHex = "#8C867A",
                    amountCents = otherAmount,
                    percentage = otherPct
                )
            )
        }

        val topCategory = majorItems.firstOrNull()
        val insight = if (topCategory != null && isExpense) {
            "本月「${topCategory.name}」支出最多，占总支出 ${(topCategory.percentage * 100).toInt()}%"
        } else {
            "消费结构平稳有序"
        }

        return AnalyticsData(
            totalAmount = totalAmount,
            dailyAverage = dailyAverage,
            insightSentence = insight,
            proportionItems = majorItems,
            filteredTransactions = filtered
        )
    }

    /**
     * 一键清除演示数据（仅删 isSample 流水与账户，绝对不误删系统默认分类）
     * 注意：示例账户可能仍被用户新记的真实流水引用，直接删除会触发外键约束异常；
     * 因此被引用的示例账户转为正式账户保留，未被引用的才真正删除。
     */
    suspend fun clearSampleData(): ClearSampleResult {
        return database.withTransaction {
            val referencedAccountIds = transactionDao.getAllList()
                .asSequence()
                .filter { !it.isSample }
                .flatMap { tx -> listOfNotNull(tx.accountId, tx.toAccountId).asSequence() }
                .toSet()

            val deletedTxs = transactionDao.deleteSamples()

            var removedAccounts = 0
            var keptAccounts = 0
            for (account in accountDao.getAllList()) {
                if (!account.isSample) continue
                if (account.id in referencedAccountIds) {
                    accountDao.update(account.copy(isSample = false))
                    keptAccounts++
                } else {
                    accountDao.delete(account)
                    removedAccounts++
                }
            }

            categoryDao.deleteSamples()
            ClearSampleResult(
                deletedTransactions = deletedTxs,
                removedAccounts = removedAccounts,
                keptAccounts = keptAccounts
            )
        }
    }

    /**
     * 导出 JSON 备份：交易排除 isSample，但账户需全量导出。
     * 原因：真实流水可能引用示例账户，若账户被过滤掉，恢复时会触发外键约束失败。
     * 包含 schemaVersion
     */
    suspend fun exportBackupJson(): String {
        val allTxs = transactionDao.getAllList().filter { !it.isSample }
        val allAccs = accountDao.getAllList()
        val allCats = categoryDao.getAllList()

        val root = JSONObject().apply {
            put("schemaVersion", AppDatabase.SCHEMA_VERSION)
            put("exportedAt", System.currentTimeMillis())

            val txArray = JSONArray()
            for (t in allTxs) {
                txArray.put(JSONObject().apply {
                    put("id", t.id)
                    put("type", t.type.name)
                    put("amount", t.amount)
                    put("accountId", t.accountId)
                    put("toAccountId", t.toAccountId ?: JSONObject.NULL)
                    put("categoryId", t.categoryId ?: JSONObject.NULL)
                    put("occurredAt", t.occurredAt)
                    put("note", t.note ?: "")
                    put("source", t.source.name)
                    put("createdAt", t.createdAt)
                })
            }
            put("transactions", txArray)

            val accArray = JSONArray()
            for (a in allAccs) {
                accArray.put(JSONObject().apply {
                    put("id", a.id)
                    put("name", a.name)
                    put("type", a.type.name)
                    put("initialBalance", a.initialBalance)
                    put("symbolText", a.symbolText)
                    put("colorHex", a.colorHex)
                    put("order", a.order)
                    put("isSample", a.isSample)
                    put("isArchived", a.isArchived)
                })
            }
            put("accounts", accArray)

            val catArray = JSONArray()
            for (c in allCats) {
                catArray.put(JSONObject().apply {
                    put("id", c.id)
                    put("name", c.name)
                    put("type", c.type.name)
                    put("symbolText", c.symbolText)
                    put("colorHex", c.colorHex)
                    put("isPinned", c.isPinned)
                    put("isFixedExpense", c.isFixedExpense)
                    put("isDefault", c.isDefault)
                })
            }
            put("categories", catArray)
        }

        return root.toString(2)
    }

    /**
     * 导入恢复 JSON 备份：事务处理并强校验 schemaVersion
     */
    suspend fun restoreBackupJson(jsonString: String): Result<Int> {
        return try {
            val root = JSONObject(jsonString)
            val version = root.optInt("schemaVersion", -1)
            if (version < 1) {
                return Result.failure(IllegalArgumentException("备份文件无效：缺失正确的 schemaVersion"))
            }

            val txArray = root.getJSONArray("transactions")
            val accArray = root.getJSONArray("accounts")
            if (txArray.length() > 0 && accArray.length() == 0) {
                return Result.failure(IllegalArgumentException("备份文件无效：缺少账单所属账户"))
            }

            database.withTransaction {
                // 清空并导入
                transactionDao.clearAll()
                accountDao.clearAll()

                val accList = mutableListOf<AccountEntity>()
                for (i in 0 until accArray.length()) {
                    val obj = accArray.getJSONObject(i)
                    accList.add(
                        AccountEntity(
                            id = obj.getString("id"),
                            name = obj.getString("name"),
                            type = AccountType.valueOf(obj.getString("type")),
                            initialBalance = obj.getLong("initialBalance"),
                            symbolText = obj.optString("symbolText", "账"),
                            colorHex = obj.optString("colorHex", "#1677FF"),
                            order = obj.optInt("order", i),
                            isSample = obj.optBoolean("isSample", false),
                            isArchived = obj.optBoolean("isArchived", false)
                        )
                    )
                }
                accountDao.insertAll(accList)

                // 恢复分类（旧备份可能缺失该字段，此时保留现有分类）
                root.optJSONArray("categories")?.let { catArray ->
                    if (catArray.length() > 0) {
                        val catList = mutableListOf<CategoryEntity>()
                        for (i in 0 until catArray.length()) {
                            val obj = catArray.getJSONObject(i)
                            catList.add(
                                CategoryEntity(
                                    id = obj.getString("id"),
                                    name = obj.getString("name"),
                                    type = TransactionType.valueOf(obj.getString("type")),
                                    symbolText = obj.optString("symbolText", "他"),
                                    colorHex = obj.optString("colorHex", "#8C867A"),
                                    isPinned = obj.optBoolean("isPinned", false),
                                    isFixedExpense = obj.optBoolean("isFixedExpense", false),
                                    order = obj.optInt("order", i),
                                    isDefault = obj.optBoolean("isDefault", true),
                                    isArchived = false
                                )
                            )
                        }
                        categoryDao.clearAll()
                        categoryDao.insertAll(catList)
                    }
                }

                val txList = mutableListOf<TransactionEntity>()
                for (i in 0 until txArray.length()) {
                    val obj = txArray.getJSONObject(i)
                    val source = runCatching {
                        TransactionSource.valueOf(obj.optString("source", "MANUAL"))
                    }.getOrDefault(TransactionSource.MANUAL)
                    txList.add(
                        TransactionEntity(
                            id = obj.getString("id"),
                            type = TransactionType.valueOf(obj.getString("type")),
                            amount = obj.getLong("amount"),
                            accountId = obj.getString("accountId"),
                            toAccountId = if (obj.isNull("toAccountId")) null else obj.getString("toAccountId"),
                            categoryId = if (obj.isNull("categoryId")) null else obj.getString("categoryId"),
                            occurredAt = obj.getLong("occurredAt"),
                            note = if (obj.isNull("note")) null else obj.getString("note"),
                            source = source,
                            isSample = false
                        )
                    )
                }
                transactionDao.insertAll(txList)
            }

            Result.success(txArray.length())
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun insertTransaction(transaction: TransactionEntity) = transactionDao.insert(transaction)
    suspend fun deleteTransaction(transaction: TransactionEntity) = transactionDao.delete(transaction)
    suspend fun updateTransaction(transaction: TransactionEntity) = transactionDao.update(transaction)
}
