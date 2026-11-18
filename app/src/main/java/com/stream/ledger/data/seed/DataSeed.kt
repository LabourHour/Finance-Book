package com.stream.ledger.data.seed

import com.stream.ledger.data.local.entity.AccountEntity
import com.stream.ledger.data.local.entity.AccountType
import com.stream.ledger.data.local.entity.CategoryEntity
import com.stream.ledger.data.local.entity.TransactionEntity
import com.stream.ledger.data.local.entity.TransactionSource
import com.stream.ledger.data.local.entity.TransactionType
import java.util.Calendar
import java.util.UUID

object DataSeed {

    // 默认系统分类（isDefault = true, isSample = false：一键清除不会误删）
    val defaultCategories = listOf(
        // 支出分类
        CategoryEntity(
            id = "cat_dining",
            name = "餐饮美食",
            type = TransactionType.EXPENSE,
            symbolText = "餐",
            colorHex = "#D97757",
            isPinned = true,
            isFixedExpense = false,
            order = 1,
            isDefault = true,
            isSample = false
        ),
        CategoryEntity(
            id = "cat_transport",
            name = "交通出行",
            type = TransactionType.EXPENSE,
            symbolText = "行",
            colorHex = "#5B88A5",
            isPinned = true,
            isFixedExpense = false,
            order = 2,
            isDefault = true,
            isSample = false
        ),
        CategoryEntity(
            id = "cat_shopping",
            name = "日常购物",
            type = TransactionType.EXPENSE,
            symbolText = "购",
            colorHex = "#5B9B88",
            isPinned = true,
            isFixedExpense = false,
            order = 3,
            isDefault = true,
            isSample = false
        ),
        CategoryEntity(
            id = "cat_entertainment",
            name = "休闲娱乐",
            type = TransactionType.EXPENSE,
            symbolText = "乐",
            colorHex = "#7E72A6",
            isPinned = false,
            isFixedExpense = false,
            order = 4,
            isDefault = true,
            isSample = false
        ),
        CategoryEntity(
            id = "cat_rent",
            name = "房租租金",
            type = TransactionType.EXPENSE,
            symbolText = "房",
            colorHex = "#9E9B93",
            isPinned = false,
            isFixedExpense = true, // 固定大额支出
            order = 5,
            isDefault = true,
            isSample = false
        ),
        CategoryEntity(
            id = "cat_daily",
            name = "生活日用",
            type = TransactionType.EXPENSE,
            symbolText = "用",
            colorHex = "#C98B3E",
            isPinned = true,
            isFixedExpense = false,
            order = 6,
            isDefault = true,
            isSample = false
        ),
        CategoryEntity(
            id = "cat_medical",
            name = "医疗健康",
            type = TransactionType.EXPENSE,
            symbolText = "医",
            colorHex = "#BF6B7B",
            isPinned = false,
            isFixedExpense = false,
            order = 7,
            isDefault = true,
            isSample = false
        ),
        CategoryEntity(
            id = "cat_other",
            name = "其他杂项",
            type = TransactionType.EXPENSE,
            symbolText = "他",
            colorHex = "#8C867A",
            isPinned = false,
            isFixedExpense = false,
            order = 8,
            isDefault = true,
            isSample = false
        ),

        // 收入分类
        CategoryEntity(
            id = "cat_salary",
            name = "薪资酬劳",
            type = TransactionType.INCOME,
            symbolText = "薪",
            colorHex = "#2F7D52",
            isPinned = true,
            isFixedExpense = false,
            order = 9,
            isDefault = true,
            isSample = false
        ),
        CategoryEntity(
            id = "cat_invest",
            name = "理财收益",
            type = TransactionType.INCOME,
            symbolText = "理",
            colorHex = "#5B88A5",
            isPinned = true,
            isFixedExpense = false,
            order = 10,
            isDefault = true,
            isSample = false
        ),
        CategoryEntity(
            id = "cat_sideline",
            name = "外包兼职",
            type = TransactionType.INCOME,
            symbolText = "职",
            colorHex = "#C98B3E",
            isPinned = false,
            isFixedExpense = false,
            order = 11,
            isDefault = true,
            isSample = false
        )
    )

    // 示例账户（isSample = true）
    val sampleAccounts = listOf(
        AccountEntity(
            id = "acc_wechat",
            name = "微信零钱",
            type = AccountType.WECHAT,
            initialBalance = 158050L, // ¥1,580.50
            symbolText = "微",
            colorHex = "#07C160",
            order = 1,
            isSample = true
        ),
        AccountEntity(
            id = "acc_alipay",
            name = "支付宝",
            type = AccountType.ALIPAY,
            initialBalance = 684000L, // ¥6,840.00
            symbolText = "支",
            colorHex = "#1677FF",
            order = 2,
            isSample = true
        ),
        AccountEntity(
            id = "acc_bank",
            name = "招商储蓄卡",
            type = AccountType.BANK,
            initialBalance = 3850000L, // ¥38,500.00
            symbolText = "招",
            colorHex = "#D97757",
            order = 3,
            isSample = true
        ),
        AccountEntity(
            id = "acc_credit",
            name = "招行信用卡",
            type = AccountType.CREDIT,
            initialBalance = -245000L, // -¥2,450.00 (欠款)
            symbolText = "卡",
            colorHex = "#C0463F",
            order = 4,
            isSample = true
        ),
        AccountEntity(
            id = "acc_cash",
            name = "随身现金",
            type = AccountType.CASH,
            initialBalance = 40000L, // ¥400.00
            symbolText = "现",
            colorHex = "#8C867A",
            order = 5,
            isSample = true
        )
    )

    /**
     * 生成与当前日期自然对齐的 20+ 笔生动流水
     */
    fun createSampleTransactions(): List<TransactionEntity> {
        val now = System.currentTimeMillis()
        val cal = Calendar.getInstance()

        fun getTimeAgo(daysAgo: Int, hour: Int, minute: Int): Long {
            cal.timeInMillis = now
            cal.add(Calendar.DAY_OF_YEAR, -daysAgo)
            cal.set(Calendar.HOUR_OF_DAY, hour)
            cal.set(Calendar.MINUTE, minute)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            return cal.timeInMillis
        }

        return listOf(
            // 今天
            TransactionEntity(
                id = UUID.randomUUID().toString(),
                type = TransactionType.EXPENSE,
                amount = 3600L,
                accountId = "acc_wechat",
                categoryId = "cat_dining",
                occurredAt = getTimeAgo(0, 12, 30),
                note = "日式烧肉饭午餐",
                source = TransactionSource.MANUAL,
                isSample = true
            ),
            TransactionEntity(
                id = UUID.randomUUID().toString(),
                type = TransactionType.EXPENSE,
                amount = 1800L,
                accountId = "acc_wechat",
                categoryId = "cat_dining",
                occurredAt = getTimeAgo(0, 9, 15),
                note = "燕麦拿铁",
                source = TransactionSource.MANUAL,
                isSample = true
            ),
            TransactionEntity(
                id = UUID.randomUUID().toString(),
                type = TransactionType.EXPENSE,
                amount = 700L,
                accountId = "acc_wechat",
                categoryId = "cat_transport",
                occurredAt = getTimeAgo(0, 8, 40),
                note = "地铁通勤",
                source = TransactionSource.MANUAL,
                isSample = true
            ),

            // 昨天
            TransactionEntity(
                id = UUID.randomUUID().toString(),
                type = TransactionType.EXPENSE,
                amount = 12850L,
                accountId = "acc_alipay",
                categoryId = "cat_shopping",
                occurredAt = getTimeAgo(1, 19, 45),
                note = "超市日用品与鲜奶",
                source = TransactionSource.MANUAL,
                isSample = true
            ),
            TransactionEntity(
                id = UUID.randomUUID().toString(),
                type = TransactionType.EXPENSE,
                amount = 4500L,
                accountId = "acc_alipay",
                categoryId = "cat_dining",
                occurredAt = getTimeAgo(1, 18, 30),
                note = "牛肉煲仔饭",
                source = TransactionSource.MANUAL,
                isSample = true
            ),

            // 2 天前 (转账: 还信用卡)
            TransactionEntity(
                id = UUID.randomUUID().toString(),
                type = TransactionType.TRANSFER,
                amount = 150000L,
                accountId = "acc_bank",
                toAccountId = "acc_credit",
                categoryId = null,
                occurredAt = getTimeAgo(2, 10, 0),
                note = "储蓄卡自动还信用卡",
                source = TransactionSource.MANUAL,
                isSample = true
            ),
            TransactionEntity(
                id = UUID.randomUUID().toString(),
                type = TransactionType.EXPENSE,
                amount = 8600L,
                accountId = "acc_credit",
                categoryId = "cat_entertainment",
                occurredAt = getTimeAgo(2, 15, 20),
                note = "周末电影票 2 张",
                source = TransactionSource.MANUAL,
                isSample = true
            ),

            // 3 天前
            TransactionEntity(
                id = UUID.randomUUID().toString(),
                type = TransactionType.EXPENSE,
                amount = 3200L,
                accountId = "acc_wechat",
                categoryId = "cat_dining",
                occurredAt = getTimeAgo(3, 12, 10),
                note = "公司园区食堂",
                source = TransactionSource.MANUAL,
                isSample = true
            ),

            // 5 天前 (固定大额房租支出)
            TransactionEntity(
                id = UUID.randomUUID().toString(),
                type = TransactionType.EXPENSE,
                amount = 450000L, // 4500.00 元
                accountId = "acc_bank",
                categoryId = "cat_rent",
                occurredAt = getTimeAgo(5, 14, 0),
                note = "11月整租房租 (固定支出)",
                source = TransactionSource.MANUAL,
                isSample = true
            ),
            TransactionEntity(
                id = UUID.randomUUID().toString(),
                type = TransactionType.INCOME,
                amount = 1880000L, // 18800.00 元
                accountId = "acc_bank",
                categoryId = "cat_salary",
                occurredAt = getTimeAgo(5, 10, 0),
                note = "税后薪资到账",
                source = TransactionSource.MANUAL,
                isSample = true
            ),

            // 7 天前
            TransactionEntity(
                id = UUID.randomUUID().toString(),
                type = TransactionType.EXPENSE,
                amount = 9900L,
                accountId = "acc_alipay",
                categoryId = "cat_daily",
                occurredAt = getTimeAgo(7, 11, 20),
                note = "手机话费充值",
                source = TransactionSource.MANUAL,
                isSample = true
            ),
            TransactionEntity(
                id = UUID.randomUUID().toString(),
                type = TransactionType.INCOME,
                amount = 120000L,
                accountId = "acc_alipay",
                categoryId = "cat_sideline",
                occurredAt = getTimeAgo(7, 16, 50),
                note = "设计外包尾款",
                source = TransactionSource.MANUAL,
                isSample = true
            ),

            // 10 天前
            TransactionEntity(
                id = UUID.randomUUID().toString(),
                type = TransactionType.EXPENSE,
                amount = 26000L,
                accountId = "acc_credit",
                categoryId = "cat_dining",
                occurredAt = getTimeAgo(10, 19, 30),
                note = "朋友聚餐 A 账",
                source = TransactionSource.MANUAL,
                isSample = true
            ),
            TransactionEntity(
                id = UUID.randomUUID().toString(),
                type = TransactionType.EXPENSE,
                amount = 3500L,
                accountId = "acc_wechat",
                categoryId = "cat_medical",
                occurredAt = getTimeAgo(10, 16, 0),
                note = "药店常备感冒药",
                source = TransactionSource.MANUAL,
                isSample = true
            )
        )
    }
}
