package com.stream.ledger.data.local

import androidx.room.TypeConverter
import com.stream.ledger.data.local.entity.AccountType
import com.stream.ledger.data.local.entity.TransactionSource
import com.stream.ledger.data.local.entity.TransactionType

class Converters {
    @TypeConverter
    fun fromTransactionType(type: TransactionType): String = type.name

    @TypeConverter
    fun toTransactionType(value: String): TransactionType = try {
        TransactionType.valueOf(value)
    } catch (_: Exception) {
        TransactionType.EXPENSE
    }

    @TypeConverter
    fun fromTransactionSource(source: TransactionSource): String = source.name

    @TypeConverter
    fun toTransactionSource(value: String): TransactionSource = try {
        TransactionSource.valueOf(value)
    } catch (_: Exception) {
        TransactionSource.MANUAL
    }

    @TypeConverter
    fun fromAccountType(type: AccountType): String = type.name

    @TypeConverter
    fun toAccountType(value: String): AccountType = try {
        AccountType.valueOf(value)
    } catch (_: Exception) {
        AccountType.OTHER
    }
}
