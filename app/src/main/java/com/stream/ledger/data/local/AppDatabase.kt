package com.stream.ledger.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import com.stream.ledger.data.local.dao.AccountDao
import com.stream.ledger.data.local.dao.BudgetDao
import com.stream.ledger.data.local.dao.CategoryDao
import com.stream.ledger.data.local.dao.RecurringRuleDao
import com.stream.ledger.data.local.dao.TransactionDao
import com.stream.ledger.data.local.entity.AccountEntity
import com.stream.ledger.data.local.entity.BudgetEntity
import com.stream.ledger.data.local.entity.CategoryEntity
import com.stream.ledger.data.local.entity.RecurringRuleEntity
import com.stream.ledger.data.local.entity.TransactionEntity

@Database(
    entities = [
        TransactionEntity::class,
        AccountEntity::class,
        CategoryEntity::class,
        BudgetEntity::class,
        RecurringRuleEntity::class
    ],
    version = 1,
    exportSchema = false
)
@androidx.room.TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun transactionDao(): TransactionDao
    abstract fun accountDao(): AccountDao
    abstract fun categoryDao(): CategoryDao
    abstract fun budgetDao(): BudgetDao
    abstract fun recurringRuleDao(): RecurringRuleDao

    companion object {
        const val SCHEMA_VERSION = 1

        @Volatile
        private var INSTANCE: AppDatabase? = null

        fun getInstance(context: Context): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "stream_ledger.db"
                ).build()
                INSTANCE = instance
                instance
            }
        }
    }
}
