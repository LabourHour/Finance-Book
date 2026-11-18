package com.stream.ledger.ui

import android.app.Application
import android.content.Context
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.stream.ledger.data.local.AppDatabase
import com.stream.ledger.data.local.entity.AccountEntity
import com.stream.ledger.data.local.entity.CategoryEntity
import com.stream.ledger.data.local.entity.TransactionEntity
import com.stream.ledger.data.local.entity.TransactionType
import com.stream.ledger.data.repository.AnalyticsData
import com.stream.ledger.data.repository.BalanceSummary
import com.stream.ledger.data.repository.ClearSampleResult
import com.stream.ledger.data.repository.LedgerRepository
import com.stream.ledger.data.repository.MonthRhythmData
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.Calendar

data class StreamUiState(
    val selectedYear: Int,
    val selectedMonth: Int,
    val selectedDay: Int?,
    val currentTab: Int, // 0: 账单, 1: 统计, 2: 资产
    val analyticsIsExpense: Boolean = true,
    val analyticsExcludeFixed: Boolean = false,
    val isQuickAddVisible: Boolean = false,
    val isSettingsVisible: Boolean = false,
    val editingTransaction: TransactionEntity? = null,
    val undoSnackbarMessage: String? = null,
    val userMessage: String? = null
)

private data class MonthScope(
    val year: Int,
    val month: Int,
    val day: Int?
)

private data class AnalyticsScope(
    val year: Int,
    val month: Int,
    val isExpense: Boolean,
    val excludeFixed: Boolean
)

class StreamViewModel(application: Application) : AndroidViewModel(application) {
    private val database = AppDatabase.getInstance(application)
    val repository = LedgerRepository(database, application)

    private val prefs = application.getSharedPreferences("stream_prefs", Context.MODE_PRIVATE)

    private val nowCal = Calendar.getInstance()
    private val _uiState = MutableStateFlow(
        StreamUiState(
            selectedYear = nowCal.get(Calendar.YEAR),
            selectedMonth = nowCal.get(Calendar.MONTH) + 1,
            selectedDay = null,
            currentTab = 0
        )
    )
    val uiState: StateFlow<StreamUiState> = _uiState.asStateFlow()

    val transactions: StateFlow<List<TransactionEntity>> = repository.allTransactionsFlow
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val accounts: StateFlow<List<AccountEntity>> = repository.allAccountsFlow
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val categories: StateFlow<List<CategoryEntity>> = repository.allCategoriesFlow
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    // 动态余额与净资产计算（CPU 计算下沉到 Default，避免主线程卡顿）
    val balanceSummary: StateFlow<BalanceSummary> = combine(accounts, transactions) { accs, txs ->
        repository.computeBalances(accs, txs)
    }.flowOn(Dispatchers.Default)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), BalanceSummary(emptyMap(), 0L, 0L, 0L))

    private val monthScopeFlow = uiState
        .map { MonthScope(it.selectedYear, it.selectedMonth, it.selectedDay) }
        .distinctUntilChanged()

    // 账单页「本月节奏」计算（仅月份/选中日变化时重算）
    val monthRhythm: StateFlow<MonthRhythmData> = combine(transactions, monthScopeFlow) { txs, scope ->
        repository.computeMonthRhythm(txs, scope.year, scope.month, scope.day)
    }.flowOn(Dispatchers.Default)
        .stateIn(
            viewModelScope,
            SharingStarted.WhileSubscribed(5000),
            MonthRhythmData(0L, "开始记录清晰流水", 0L, 0L, emptyList(), null)
        )

    private val analyticsScopeFlow = uiState
        .map { AnalyticsScope(it.selectedYear, it.selectedMonth, it.analyticsIsExpense, it.analyticsExcludeFixed) }
        .distinctUntilChanged()

    // 统计分析计算（仅统计相关状态变化时重算）
    val analyticsData: StateFlow<AnalyticsData> = combine(transactions, categories, analyticsScopeFlow) { txs, cats, scope ->
        repository.computeAnalytics(
            transactions = txs,
            categories = cats,
            targetYear = scope.year,
            targetMonth = scope.month,
            isExpense = scope.isExpense,
            excludeFixedExpense = scope.excludeFixed
        )
    }.flowOn(Dispatchers.Default)
        .stateIn(
            viewModelScope,
            SharingStarted.WhileSubscribed(5000),
            AnalyticsData(0L, 0L, "暂无数据", emptyList(), emptyList())
        )

    // 上次使用的扣费账户（智能记忆默认值）
    var lastUsedAccountId: String
        get() = prefs.getString("last_used_account_id", null) ?: "acc_wechat"
        set(value) = prefs.edit().putString("last_used_account_id", value).apply()

    private var deletedTransactionForUndo: TransactionEntity? = null

    init {
        viewModelScope.launch {
            try {
                repository.ensureInitialData()
            } catch (e: Exception) {
                showUserMessage("初始化数据失败：${e.message}")
            }
        }
    }

    fun showUserMessage(message: String) {
        _uiState.value = _uiState.value.copy(userMessage = message)
    }

    fun consumeUserMessage() {
        _uiState.value = _uiState.value.copy(userMessage = null)
    }

    fun setTab(index: Int) {
        _uiState.value = _uiState.value.copy(currentTab = index)
    }

    fun selectMonth(year: Int, month: Int) {
        _uiState.value = _uiState.value.copy(selectedYear = year, selectedMonth = month, selectedDay = null)
    }

    fun selectDay(day: Int?) {
        _uiState.value = _uiState.value.copy(selectedDay = if (_uiState.value.selectedDay == day) null else day)
    }

    fun prevMonth() {
        var y = _uiState.value.selectedYear
        var m = _uiState.value.selectedMonth - 1
        if (m < 1) {
            m = 12
            y -= 1
        }
        selectMonth(y, m)
    }

    fun nextMonth() {
        var y = _uiState.value.selectedYear
        var m = _uiState.value.selectedMonth + 1
        if (m > 12) {
            m = 1
            y += 1
        }
        selectMonth(y, m)
    }

    fun setAnalyticsType(isExpense: Boolean) {
        _uiState.value = _uiState.value.copy(analyticsIsExpense = isExpense)
    }

    fun toggleExcludeFixedExpense() {
        _uiState.value = _uiState.value.copy(analyticsExcludeFixed = !_uiState.value.analyticsExcludeFixed)
    }

    fun openQuickAdd(editing: TransactionEntity? = null) {
        _uiState.value = _uiState.value.copy(isQuickAddVisible = true, editingTransaction = editing)
    }

    fun closeQuickAdd() {
        _uiState.value = _uiState.value.copy(isQuickAddVisible = false, editingTransaction = null)
    }

    fun openSettings() {
        _uiState.value = _uiState.value.copy(isSettingsVisible = true)
    }

    fun closeSettings() {
        _uiState.value = _uiState.value.copy(isSettingsVisible = false)
    }

    fun saveTransaction(
        type: TransactionType,
        amountCents: Long,
        accountId: String,
        toAccountId: String?,
        categoryId: String?,
        occurredAt: Long,
        note: String?
    ) {
        viewModelScope.launch {
            val editing = _uiState.value.editingTransaction
            val availableAccounts = accounts.value

            if (amountCents <= 0L) {
                showUserMessage("金额需大于 0")
                return@launch
            }
            if (accountId.isBlank()) {
                showUserMessage("请先选择账户")
                return@launch
            }
            if (availableAccounts.isEmpty()) {
                showUserMessage("账户数据加载中，请稍后重试")
                return@launch
            }

            val accountKnown = availableAccounts.any { it.id == accountId } || editing?.accountId == accountId
            if (!accountKnown) {
                showUserMessage("所选账户不可用，请重新选择")
                return@launch
            }

            if (type == TransactionType.TRANSFER) {
                val targetKnown = toAccountId != null &&
                    toAccountId != accountId &&
                    (availableAccounts.any { it.id == toAccountId } || editing?.toAccountId == toAccountId)
                if (!targetKnown) {
                    showUserMessage("请选择不同的转入账户")
                    return@launch
                }
            }

            try {
                if (editing != null) {
                    repository.updateTransaction(
                        editing.copy(
                            type = type,
                            amount = amountCents,
                            accountId = accountId,
                            toAccountId = toAccountId,
                            categoryId = categoryId,
                            occurredAt = occurredAt,
                            note = note,
                            updatedAt = System.currentTimeMillis()
                        )
                    )
                } else {
                    repository.insertTransaction(
                        TransactionEntity(
                            type = type,
                            amount = amountCents,
                            accountId = accountId,
                            toAccountId = toAccountId,
                            categoryId = categoryId,
                            occurredAt = occurredAt,
                            note = note,
                            isSample = false
                        )
                    )
                    lastUsedAccountId = accountId
                }
                closeQuickAdd()
            } catch (e: Exception) {
                showUserMessage("保存失败：${e.message ?: "未知错误"}")
            }
        }
    }

    fun deleteTransaction(transaction: TransactionEntity) {
        deletedTransactionForUndo = transaction
        viewModelScope.launch {
            try {
                repository.deleteTransaction(transaction)
                _uiState.value = _uiState.value.copy(undoSnackbarMessage = "已删除账单")
            } catch (e: Exception) {
                showUserMessage("删除失败：${e.message ?: "未知错误"}")
            }
        }
    }

    fun undoDelete() {
        val tx = deletedTransactionForUndo ?: return
        viewModelScope.launch {
            try {
                repository.insertTransaction(tx)
                deletedTransactionForUndo = null
                _uiState.value = _uiState.value.copy(undoSnackbarMessage = null)
            } catch (e: Exception) {
                showUserMessage("撤销失败：${e.message ?: "未知错误"}")
            }
        }
    }

    fun dismissUndoSnackbar() {
        deletedTransactionForUndo = null
        _uiState.value = _uiState.value.copy(undoSnackbarMessage = null)
    }

    suspend fun clearSampleData(): ClearSampleResult = repository.clearSampleData()
}
