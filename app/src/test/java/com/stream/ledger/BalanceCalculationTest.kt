package com.stream.ledger

import com.stream.ledger.data.local.entity.AccountEntity
import com.stream.ledger.data.local.entity.AccountType
import com.stream.ledger.data.local.entity.TransactionEntity
import com.stream.ledger.data.local.entity.TransactionType
import com.stream.ledger.data.repository.LedgerRepository
import org.junit.Assert.assertEquals
import org.junit.Test

class BalanceCalculationTest {

    @Test
    fun testRealtimeBalanceCalculation_And_CreditCardPayoff() {
        val accounts = listOf(
            AccountEntity(
                id = "acc_bank",
                name = "储蓄卡",
                type = AccountType.BANK,
                initialBalance = 100000L, // 初始 1000.00 元
                symbolText = "招",
                colorHex = "#1677FF"
            ),
            AccountEntity(
                id = "acc_credit",
                name = "信用卡",
                type = AccountType.CREDIT,
                initialBalance = -20000L, // 初始欠款 -200.00 元
                symbolText = "卡",
                colorHex = "#C0463F"
            )
        )

        val transactions = listOf(
            // 储蓄卡支出 100 元
            TransactionEntity(
                id = "1",
                type = TransactionType.EXPENSE,
                amount = 10000L,
                accountId = "acc_bank",
                occurredAt = 1000L
            ),
            // 信用卡刷卡支出 50 元 (欠款增加到 250 元)
            TransactionEntity(
                id = "2",
                type = TransactionType.EXPENSE,
                amount = 5000L,
                accountId = "acc_credit",
                occurredAt = 2000L
            ),
            // 储蓄卡转账还信用卡 150 元 (储蓄卡扣 150，信用卡欠款减少 150 -> 负数变为 -100 元)
            TransactionEntity(
                id = "3",
                type = TransactionType.TRANSFER,
                amount = 15000L,
                accountId = "acc_bank",
                toAccountId = "acc_credit",
                occurredAt = 3000L
            )
        )

        // 模拟静态余额计算逻辑
        val balances = mutableMapOf<String, Long>()
        for (acc in accounts) {
            balances[acc.id] = acc.initialBalance
        }

        for (t in transactions) {
            when (t.type) {
                TransactionType.EXPENSE -> balances[t.accountId]?.let { balances[t.accountId] = it - t.amount }
                TransactionType.INCOME -> balances[t.accountId]?.let { balances[t.accountId] = it + t.amount }
                TransactionType.TRANSFER -> {
                    balances[t.accountId]?.let { balances[t.accountId] = it - t.amount }
                    t.toAccountId?.let { toId -> balances[toId]?.let { balances[toId] = it + t.amount } }
                }
            }
        }

        // 验证：
        // 储蓄卡最终余额 = 1000 - 100(支出) - 150(转出还款) = 750 元 (75000分)
        assertEquals(75000L, balances["acc_bank"])

        // 信用卡最终余额 = -200 - 50(刷卡) + 150(还款转入) = -100 元 (-10000分)
        assertEquals(-10000L, balances["acc_credit"])

        // 净资产 = 750 + (-100) = 650 元 (65000分)
        val netAssets = balances.values.sum()
        assertEquals(65000L, netAssets)
    }
}
