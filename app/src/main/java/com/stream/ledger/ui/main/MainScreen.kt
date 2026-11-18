package com.stream.ledger.ui.main

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.stream.ledger.core.designsystem.LocalStreamColors
import com.stream.ledger.core.designsystem.StreamIcons
import com.stream.ledger.core.designsystem.StreamShapes
import com.stream.ledger.ui.StreamViewModel
import com.stream.ledger.ui.accounts.AccountsScreen
import com.stream.ledger.ui.analytics.AnalyticsScreen
import com.stream.ledger.ui.quickadd.QuickAddSheet
import com.stream.ledger.ui.settings.SettingsDialog
import com.stream.ledger.ui.timeline.TimelineScreen

@Composable
fun MainScreen(viewModel: StreamViewModel) {
    val colors = LocalStreamColors.current
    val uiState by viewModel.uiState.collectAsState()

    val transactions by viewModel.transactions.collectAsState()
    val accounts by viewModel.accounts.collectAsState()
    val categories by viewModel.categories.collectAsState()

    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(uiState.undoSnackbarMessage) {
        val msg = uiState.undoSnackbarMessage
        if (msg != null) {
            val result = snackbarHostState.showSnackbar(
                message = msg,
                actionLabel = "撤销",
                duration = SnackbarDuration.Short
            )
            if (result == SnackbarResult.ActionPerformed) {
                viewModel.undoDelete()
            } else {
                viewModel.dismissUndoSnackbar()
            }
        }
    }

    LaunchedEffect(uiState.userMessage) {
        val msg = uiState.userMessage
        if (msg != null) {
            snackbarHostState.showSnackbar(message = msg, duration = SnackbarDuration.Short)
            viewModel.consumeUserMessage()
        }
    }

    Scaffold(
        containerColor = colors.paperBase,
        snackbarHost = {
            SnackbarHost(
                hostState = snackbarHostState,
                modifier = Modifier.padding(bottom = 8.dp)
            ) { data ->
                Surface(
                    shape = StreamShapes.Capsule,
                    color = colors.textPrimary,
                    modifier = Modifier.padding(horizontal = 24.dp)
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = data.visuals.message,
                            style = MaterialTheme.typography.bodyMedium,
                            color = colors.cardBackground,
                            modifier = Modifier.weight(1f)
                        )
                        data.visuals.actionLabel?.let { label ->
                            Text(
                                text = label,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.Bold,
                                color = colors.accentWarmYellow,
                                modifier = Modifier
                                    .clickable { data.performAction() }
                                    .padding(start = 12.dp)
                            )
                        }
                    }
                }
            }
        },
        bottomBar = {
            // dock / FAB 由占位底栏承载，正文区域在底栏之上结束，
            // 因此任何列表内容都不会被浮层遮挡（无穿模）。
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .navigationBarsPadding()
                    .height(86.dp),
                contentAlignment = Alignment.BottomCenter
            ) {
                EditorialDock(
                    selectedTab = uiState.currentTab,
                    onSelect = { viewModel.setTab(it) },
                    modifier = Modifier.padding(bottom = 18.dp)
                )
                EditorialFab(
                    onClick = { viewModel.openQuickAdd(null) },
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(end = 18.dp, bottom = 18.dp)
                )
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            when (uiState.currentTab) {
                0 -> {
                    val rhythmData by viewModel.monthRhythm.collectAsState()
                    TimelineScreen(
                        year = uiState.selectedYear,
                        month = uiState.selectedMonth,
                        selectedDay = uiState.selectedDay,
                        rhythmData = rhythmData,
                        transactions = transactions,
                        accounts = accounts,
                        categories = categories,
                        onPrevMonth = { viewModel.prevMonth() },
                        onNextMonth = { viewModel.nextMonth() },
                        onSelectDay = { day -> viewModel.selectDay(day) },
                        onEditTransaction = { tx -> viewModel.openQuickAdd(tx) },
                        onDeleteTransaction = { tx -> viewModel.deleteTransaction(tx) },
                        onOpenSettings = { viewModel.openSettings() }
                    )
                }
                1 -> {
                    val analyticsData by viewModel.analyticsData.collectAsState()
                    AnalyticsScreen(
                        year = uiState.selectedYear,
                        month = uiState.selectedMonth,
                        analyticsData = analyticsData,
                        isExpense = uiState.analyticsIsExpense,
                        excludeFixedExpense = uiState.analyticsExcludeFixed,
                        accounts = accounts,
                        categories = categories,
                        onToggleType = { isExp -> viewModel.setAnalyticsType(isExp) },
                        onToggleExcludeFixed = { viewModel.toggleExcludeFixedExpense() },
                        onEditTransaction = { tx -> viewModel.openQuickAdd(tx) },
                        onDeleteTransaction = { tx -> viewModel.deleteTransaction(tx) }
                    )
                }
                else -> {
                    val balanceSummary by viewModel.balanceSummary.collectAsState()
                    AccountsScreen(
                        balanceSummary = balanceSummary,
                        accounts = accounts,
                        transactions = transactions,
                        onOpenTransfer = { viewModel.openQuickAdd(null) }
                    )
                }
            }


            // 记一笔 BottomSheet
            QuickAddSheet(
                isVisible = uiState.isQuickAddVisible,
                editingTransaction = uiState.editingTransaction,
                accounts = accounts,
                categories = categories,
                lastUsedAccountId = viewModel.lastUsedAccountId,
                onDismiss = { viewModel.closeQuickAdd() },
                onSave = { type, amount, accId, toAccId, catId, time, note ->
                    viewModel.saveTransaction(type, amount, accId, toAccId, catId, time, note)
                }
            )

            // 设置与数据 Dialog
            SettingsDialog(
                isVisible = uiState.isSettingsVisible,
                viewModel = viewModel,
                onDismiss = { viewModel.closeSettings() }
            )
        }
    }
}

@Composable
private fun EditorialDock(
    selectedTab: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = LocalStreamColors.current
    val items = listOf(
        StreamNavItem(0, "账单", StreamIcons.Timeline),
        StreamNavItem(1, "统计", StreamIcons.Analytics),
        StreamNavItem(2, "资产", StreamIcons.Assets)
    )

    Surface(
        shape = RoundedCornerShape(26.dp),
        color = colors.deepSurface.copy(alpha = 0.96f),
        shadowElevation = 14.dp,
        modifier = modifier
            .width(196.dp)
            .height(52.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 8.dp),
            horizontalArrangement = Arrangement.SpaceAround,
            verticalAlignment = Alignment.CenterVertically
        ) {
            items.forEach { item ->
                val selected = selectedTab == item.id
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                        .clickable { onSelect(item.id) },
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        Icon(
                            imageVector = item.icon,
                            contentDescription = item.label,
                            modifier = Modifier.size(18.dp),
                            tint = if (selected) colors.accentWarmYellow else colors.onDeep.copy(alpha = 0.45f)
                        )
                        if (selected) {
                            Spacer(modifier = Modifier.height(3.dp))
                            Box(
                                modifier = Modifier
                                    .size(4.dp)
                                    .clip(CircleShape)
                                    .background(colors.accentWarmYellow)
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun EditorialFab(
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colors = LocalStreamColors.current
    Surface(
        shape = CircleShape,
        color = colors.accentWarmYellow,
        shadowElevation = 10.dp,
        modifier = modifier
            .size(52.dp)
            .clickable(onClick = onClick)
    ) {
        Box(contentAlignment = Alignment.Center) {
            Icon(
                imageVector = Icons.Default.Add,
                contentDescription = "记一笔",
                modifier = Modifier.size(24.dp),
                tint = colors.textOnAccent
            )
        }
    }
}

private data class StreamNavItem(
    val id: Int,
    val label: String,
    val icon: ImageVector
)