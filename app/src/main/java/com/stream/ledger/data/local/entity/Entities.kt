package com.stream.ledger.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import java.util.UUID

enum class TransactionType {
    EXPENSE, // 支出
    INCOME,  // 收入
    TRANSFER // 转账
}

enum class TransactionSource {
    MANUAL,       // 手动记账
    NOTIFICATION, // 通知监听 (Lab)
    SCREENSHOT,   // 屏幕识别 (Lab)
    IMPORT        // 备份导入
}

enum class AccountType {
    WECHAT, ALIPAY, BANK, CREDIT, CASH, OTHER
}

@Entity(
    tableName = "accounts",
    indices = [Index("order"), Index("isSample")]
)
data class AccountEntity(
    @PrimaryKey
    val id: String,
    val name: String,
    val type: AccountType,
    val initialBalance: Long = 0L,         // 初始金额（分），信用卡欠款存为负数
    val symbolText: String,                 // 中性单字符号（如"微","支","招","卡","现"）
    val colorHex: String,                  // 标识微色
    val order: Int = 0,
    val isSample: Boolean = false,
    val isArchived: Boolean = false
)

@Entity(
    tableName = "categories",
    indices = [Index("type"), Index("order"), Index("isPinned"), Index("isArchived")]
)
data class CategoryEntity(
    @PrimaryKey
    val id: String,
    val name: String,
    val type: TransactionType,             // EXPENSE 或 INCOME
    val symbolText: String,                 // 简易符号单字或图标名
    val colorHex: String,                  // 基于 OKLCH 生成的 8 组柔和色彩
    val isPinned: Boolean = false,         // 置顶常用
    val isFixedExpense: Boolean = false,   // 是否为固定支出（房租等，用于统计过滤）
    val order: Int = 0,
    val isDefault: Boolean = true,         // 是否为默认分类
    val isSample: Boolean = false,         // 是否为示例（一键清除不删默认分类）
    val isArchived: Boolean = false        // 归档状态（删除改为归档）
)

@Entity(
    tableName = "transactions",
    foreignKeys = [
        ForeignKey(
            entity = AccountEntity::class,
            parentColumns = ["id"],
            childColumns = ["accountId"],
            onDelete = ForeignKey.RESTRICT
        )
    ],
    indices = [
        Index("occurredAt"),
        Index("accountId"),
        Index("toAccountId"),
        Index("categoryId"),
        Index("isSample"),
        Index("dedupKey")
    ]
)
data class TransactionEntity(
    @PrimaryKey
    val id: String = UUID.randomUUID().toString(),
    val type: TransactionType,
    val amount: Long,                      // 金额（单位：分，整数）
    val accountId: String,                 // 支出账户 / 转出账户 / 收入存入账户
    val toAccountId: String? = null,       // 转入账户（转账专用）
    val categoryId: String? = null,        // 分类 ID（转账时为 null）
    val occurredAt: Long,                  // 发生时间（epoch 毫秒，合并原 date/time）
    val note: String? = null,              // 备注信息
    val source: TransactionSource = TransactionSource.MANUAL,
    val isSample: Boolean = false,         // 是否为演示样本数据
    val dedupKey: String? = null,          // Lab 阶段防重识别 Key 预留
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "budgets")
data class BudgetEntity(
    @PrimaryKey
    val month: String,                     // 格式: YYYY-MM
    val totalBudget: Long,                 // 月度总预算（分）
    val categoryBudgetsJson: String? = null
)

@Entity(tableName = "recurring_rules")
data class RecurringRuleEntity(
    @PrimaryKey
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val type: TransactionType,
    val amount: Long,                      // 分
    val accountId: String,
    val toAccountId: String? = null,
    val categoryId: String? = null,
    val frequency: String = "MONTHLY",
    val dayOfMonth: Int,                   // 每月几号（29-31需特殊封顶处理）
    val nextDueDate: Long,
    val isActive: Boolean = true,
    val isSample: Boolean = false
)
