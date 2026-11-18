package com.stream.ledger.ui.quickadd

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowForward
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.stream.ledger.core.designsystem.LocalStreamColors
import com.stream.ledger.core.designsystem.StreamIcons
import com.stream.ledger.core.designsystem.StreamShapes
import com.stream.ledger.core.util.AmountText
import com.stream.ledger.core.util.ArithmeticParser
import com.stream.ledger.core.util.CurrencyFormatter
import com.stream.ledger.data.local.entity.AccountEntity
import com.stream.ledger.data.local.entity.CategoryEntity
import com.stream.ledger.data.local.entity.TransactionEntity
import com.stream.ledger.data.local.entity.TransactionType
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuickAddSheet(
    isVisible: Boolean,
    editingTransaction: TransactionEntity?,
    accounts: List<AccountEntity>,
    categories: List<CategoryEntity>,
    lastUsedAccountId: String,
    onDismiss: () -> Unit,
    onSave: (
        type: TransactionType,
        amountCents: Long,
        accountId: String,
        toAccountId: String?,
        categoryId: String?,
        occurredAt: Long,
        note: String?
    ) -> Unit
) {
    if (!isVisible) return

    val colors = LocalStreamColors.current
    val haptic = LocalHapticFeedback.current

    var type by remember { mutableStateOf(TransactionType.EXPENSE) }
    var expression by remember { mutableStateOf("") }
    var selectedCategoryId by remember { mutableStateOf<String?>("") }
    var selectedAccountId by remember { mutableStateOf("") }
    var selectedToAccountId by remember { mutableStateOf("") }
    var occurredAt by remember { mutableStateOf(System.currentTimeMillis()) }
    var note by remember { mutableStateOf("") }
    var isEditingNote by remember { mutableStateOf(false) }

    // 初始化或回填编辑
    LaunchedEffect(isVisible, editingTransaction) {
        if (editingTransaction != null) {
            type = editingTransaction.type
            expression = ArithmeticParser.centsToDisplayInput(editingTransaction.amount)
            selectedCategoryId = editingTransaction.categoryId
            selectedAccountId = editingTransaction.accountId
            selectedToAccountId = editingTransaction.toAccountId ?: ""
            occurredAt = editingTransaction.occurredAt
            note = editingTransaction.note ?: ""
        } else {
            type = TransactionType.EXPENSE
            expression = ""
            occurredAt = System.currentTimeMillis()
            note = ""
            isEditingNote = false

            // 智能记忆默认账户
            selectedAccountId = if (accounts.any { it.id == lastUsedAccountId }) {
                lastUsedAccountId
            } else {
                accounts.firstOrNull()?.id ?: ""
            }

            // 默认分类
            val firstPinnedCat = categories.find { it.type == TransactionType.EXPENSE && it.isPinned }
            selectedCategoryId = firstPinnedCat?.id ?: categories.firstOrNull { it.type == TransactionType.EXPENSE }?.id
        }
    }

    // 切换到转账时，确保两个账户不同
    LaunchedEffect(type, accounts) {
        if (type == TransactionType.TRANSFER && accounts.size >= 2) {
            if (selectedToAccountId.isEmpty() || selectedToAccountId == selectedAccountId) {
                val other = accounts.firstOrNull { it.id != selectedAccountId }
                if (other != null) selectedToAccountId = other.id
            }
        }
    }

    // 账户/分类为异步加载，数据到达后补齐默认选择，避免打开时数据未就绪导致无法保存
    LaunchedEffect(accounts, categories, type, isVisible) {
        if (selectedAccountId.isBlank() && accounts.isNotEmpty()) {
            selectedAccountId = if (accounts.any { it.id == lastUsedAccountId }) {
                lastUsedAccountId
            } else {
                accounts.first().id
            }
        }
        if (type != TransactionType.TRANSFER && selectedCategoryId.isNullOrBlank()) {
            categories.firstOrNull { it.type == type }?.let { selectedCategoryId = it.id }
        }
    }

    // 实时计算输入结果
    val evaluatedCents = remember(expression) {
        ArithmeticParser.evaluate(expression)
    }

    val filteredCategories = remember(categories, type) {
        categories.filter { it.type == (if (type == TransactionType.TRANSFER) TransactionType.EXPENSE else type) }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = colors.paperBase,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        dragHandle = {
            Box(
                modifier = Modifier
                    .padding(vertical = 10.dp)
                    .size(width = 36.dp, height = 4.dp)
                    .clip(CircleShape)
                    .background(colors.hairline)
            )
        }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 24.dp)
        ) {
            // 顶部栏：关闭按钮 + 类型分段控制器
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onDismiss, modifier = Modifier.size(32.dp)) {
                    Icon(Icons.Default.Close, contentDescription = "取消", tint = colors.textSecondary)
                }

                // 支出 / 收入 / 转账 分段切换
                Surface(
                    shape = StreamShapes.Capsule,
                    color = colors.cardBackground,
                    modifier = Modifier.height(34.dp)
                ) {
                    Row(modifier = Modifier.padding(2.dp)) {
                        listOf(
                            TransactionType.EXPENSE to "支出",
                            TransactionType.INCOME to "收入",
                            TransactionType.TRANSFER to "转账"
                        ).forEach { (t, label) ->
                            val isSelected = type == t
                            Box(
                                modifier = Modifier
                                    .clip(StreamShapes.Capsule)
                                    .background(if (isSelected) colors.accentPillBackground else Color.Transparent)
                                    .clickable {
                                        if (t == TransactionType.TRANSFER && accounts.size < 2) return@clickable
                                        type = t
                                        if (t != TransactionType.TRANSFER) {
                                            selectedCategoryId = categories.firstOrNull { it.type == t }?.id
                                        }
                                    }
                                    .padding(horizontal = 14.dp, vertical = 6.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = label,
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                                    color = if (isSelected) colors.textPrimary else colors.textSecondary
                                )
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.size(32.dp))
            }

            // 金额居中显示 + 计算器即时回显
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 12.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                val hasOperator = expression.contains("+") || expression.contains("-")
                Text(
                    text = if (hasOperator) "= ${CurrencyFormatter.formatPlain(evaluatedCents)}" else "输入金额",
                    style = MaterialTheme.typography.labelSmall,
                    color = colors.textSecondary
                )
                Spacer(modifier = Modifier.height(2.dp))
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(
                        text = "¥",
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Normal,
                        color = colors.textSecondary,
                        modifier = Modifier.padding(bottom = 4.dp, end = 2.dp)
                    )
                    Text(
                        text = if (expression.isEmpty()) "0.00" else expression,
                        style = MaterialTheme.typography.headlineLarge,
                        fontSize = 42.sp,
                        fontWeight = FontWeight.Light,
                        color = colors.textPrimary
                    )
                }
            }

            // 属性胶囊行：账户、日期、备注
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (type == TransactionType.TRANSFER) {
                    // 转账从 A -> B
                    Surface(
                        shape = StreamShapes.Capsule,
                        color = colors.cardBackground,
                        border = androidx.compose.foundation.BorderStroke(0.5.dp, colors.hairline),
                        modifier = Modifier.padding(vertical = 2.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = accounts.find { it.id == selectedAccountId }?.name ?: "转出账户",
                                style = MaterialTheme.typography.labelSmall,
                                color = colors.textPrimary
                            )
                            Icon(
                                Icons.Default.ArrowForward,
                                contentDescription = null,
                                modifier = Modifier.size(12.dp).padding(horizontal = 2.dp),
                                tint = colors.textSecondary
                            )
                            Text(
                                text = accounts.find { it.id == selectedToAccountId }?.name ?: "转入账户",
                                style = MaterialTheme.typography.labelSmall,
                                color = colors.textPrimary
                            )
                        }
                    }
                } else {
                    // 扣费/收款账户胶囊
                    Surface(
                        shape = StreamShapes.Capsule,
                        color = colors.cardBackground,
                        border = androidx.compose.foundation.BorderStroke(0.5.dp, colors.hairline)
                    ) {
                        Row(
                            modifier = Modifier
                                .clickable(enabled = accounts.isNotEmpty()) {
                                    val currentIndex = accounts.indexOfFirst { it.id == selectedAccountId }
                                    selectedAccountId = if (currentIndex >= 0) {
                                        accounts[(currentIndex + 1) % accounts.size].id
                                    } else {
                                        accounts.first().id
                                    }
                                }
                                .padding(horizontal = 10.dp, vertical = 6.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            val curAcc = accounts.find { it.id == selectedAccountId }
                            Text(
                                text = curAcc?.symbolText ?: "账",
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = colors.accentWarmYellow
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = when {
                                    accounts.isEmpty() -> "暂无可用账户"
                                    curAcc != null -> curAcc.name
                                    else -> "选择账户"
                                },
                                style = MaterialTheme.typography.labelSmall,
                                color = if (accounts.isEmpty()) colors.overBudgetRed else colors.textPrimary
                            )
                        }
                    }
                }

                // 日期胶囊 (今天)
                Surface(
                    shape = StreamShapes.Capsule,
                    color = colors.cardBackground,
                    border = androidx.compose.foundation.BorderStroke(0.5.dp, colors.hairline)
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(StreamIcons.Calendar, contentDescription = null, modifier = Modifier.size(12.dp), tint = colors.textSecondary)
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = "今天",
                            style = MaterialTheme.typography.labelSmall,
                            color = colors.textPrimary
                        )
                    }
                }

                // 备注输入胶囊
                Surface(
                    shape = StreamShapes.Capsule,
                    color = colors.cardBackground,
                    border = androidx.compose.foundation.BorderStroke(0.5.dp, colors.hairline),
                    modifier = Modifier.clickable { isEditingNote = !isEditingNote }
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.Edit, contentDescription = null, modifier = Modifier.size(12.dp), tint = colors.textSecondary)
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = if (note.isBlank()) "添加备注" else note,
                            style = MaterialTheme.typography.labelSmall,
                            color = if (note.isBlank()) colors.textSecondary else colors.textPrimary
                        )
                    }
                }
            }

            if (isEditingNote) {
                OutlinedTextField(
                    value = note,
                    onValueChange = { note = it },
                    placeholder = { Text("写点备注...", fontSize = 13.sp) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp, vertical = 6.dp),
                    shape = StreamShapes.SmallCard,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = colors.accentWarmYellow,
                        unfocusedBorderColor = colors.hairline
                    ),
                    singleLine = true
                )
            }

            // 分类网格 (转账时不展示分类)
            if (type != TransactionType.TRANSFER) {
                LazyVerticalGrid(
                    columns = GridCells.Fixed(4),
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = 164.dp)
                        .padding(horizontal = 12.dp, vertical = 4.dp)
                ) {
                    items(filteredCategories) { cat ->
                        val isSelected = cat.id == selectedCategoryId
                        val catColor = try {
                            Color(android.graphics.Color.parseColor(cat.colorHex))
                        } catch (_: Exception) {
                            Color(0xFF8C867A)
                        }

                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier
                                .clip(StreamShapes.SmallCard)
                                .clickable { selectedCategoryId = cat.id }
                                .padding(vertical = 6.dp)
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(38.dp)
                                    .clip(CircleShape)
                                    .background(if (isSelected) colors.accentWarmYellow else catColor.copy(alpha = 0.12f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = cat.symbolText,
                                    fontSize = 15.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = if (isSelected) colors.textOnAccent else catColor
                                )
                            }
                            Spacer(modifier = Modifier.height(2.dp))
                            Text(
                                text = cat.name,
                                style = MaterialTheme.typography.labelSmall,
                                color = if (isSelected) colors.textPrimary else colors.textSecondary
                            )
                        }
                    }
                }
            }

            // 自定义轻量数字键盘 (附带微触觉反馈)
            Surface(
                color = colors.cardBackground,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp)
            ) {
                Column(modifier = Modifier.padding(12.dp)) {
                    val keyRows = listOf(
                        listOf("7", "8", "9", "+"),
                        listOf("4", "5", "6", "-"),
                        listOf("1", "2", "3", "C"),
                        listOf(".", "0", "DEL", "OK")
                    )

                    keyRows.forEach { row ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            row.forEach { key ->
                                val isOk = key == "OK"
                                val isOp = key == "+" || key == "-" || key == "C"

                                Box(
                                    modifier = Modifier
                                        .weight(1f)
                                        .height(48.dp)
                                        .clip(StreamShapes.SmallCard)
                                        .background(
                                            when {
                                                isOk -> colors.accentWarmYellow
                                                isOp -> colors.paperBase
                                                else -> colors.paperBase.copy(alpha = 0.6f)
                                            }
                                        )
                                        .clickable {
                                            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                            when (key) {
                                                "DEL" -> if (expression.isNotEmpty()) expression = expression.dropLast(1)
                                                "C" -> expression = ""
                                                "OK" -> {
                                                    val cents = ArithmeticParser.evaluate(expression)
                                                    val hasValidAccount = selectedAccountId.isNotBlank() &&
                                                        accounts.any { it.id == selectedAccountId }
                                                    val hasValidTransferTarget =
                                                        type != TransactionType.TRANSFER || (
                                                            selectedToAccountId.isNotBlank() &&
                                                                selectedToAccountId != selectedAccountId &&
                                                                accounts.any { it.id == selectedToAccountId }
                                                            )
                                                    if (cents > 0 && hasValidAccount && hasValidTransferTarget) {
                                                        onSave(
                                                            type,
                                                            cents,
                                                            selectedAccountId,
                                                            if (type == TransactionType.TRANSFER) selectedToAccountId else null,
                                                            if (type != TransactionType.TRANSFER) selectedCategoryId else null,
                                                            occurredAt,
                                                            note.ifBlank { null }
                                                        )
                                                    }
                                                }
                                                "+" -> if (expression.isNotEmpty() && !expression.endsWith("+") && !expression.endsWith("-")) expression += "+"
                                                "-" -> if (!expression.endsWith("-") && !expression.endsWith("+")) expression += "-"
                                                "." -> {
                                                    val lastSegment = expression.split("+", "-").lastOrNull() ?: ""
                                                    if (!lastSegment.contains(".")) expression += "."
                                                }
                                                else -> expression += key
                                            }
                                        },
                                    contentAlignment = Alignment.Center
                                ) {
                                    if (key == "DEL") {
                                        Icon(StreamIcons.Backspace, contentDescription = "删除", tint = colors.textPrimary, modifier = Modifier.size(18.dp))
                                    } else if (key == "OK") {
                                        Icon(Icons.Default.Check, contentDescription = "完成", tint = colors.textOnAccent, modifier = Modifier.size(24.dp))
                                    } else {
                                        Text(
                                            text = key,
                                            fontSize = 20.sp,
                                            fontWeight = if (isOp) FontWeight.SemiBold else FontWeight.Normal,
                                            color = colors.textPrimary
                                        )
                                    }
                                }
                            }
                        }
                        Spacer(modifier = Modifier.height(8.dp))
                    }
                }
            }
        }
    }
}
