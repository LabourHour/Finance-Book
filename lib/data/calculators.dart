import 'dart:math';

import '../core/money.dart';
import 'models.dart';

/// 纯计算移植：与旧 `LedgerRepository` 的同名方法逐条对齐，不做 IO。
class LedgerCalculators {
  static BalanceSummary computeBalances(
    List<Account> accounts,
    List<LedgerTransaction> transactions,
  ) {
    final balances = <String, int>{
      for (final account in accounts) account.id: account.initialBalance,
    };

    for (final transaction in transactions) {
      switch (transaction.type) {
        case TransactionType.expense:
          final expenseBalance = balances[transaction.accountId];
          if (expenseBalance != null) {
            balances[transaction.accountId] = expenseBalance - transaction.amount;
          }
        case TransactionType.income:
          final incomeBalance = balances[transaction.accountId];
          if (incomeBalance != null) {
            balances[transaction.accountId] = incomeBalance + transaction.amount;
          }
        case TransactionType.transfer:
          final fromBalance = balances[transaction.accountId];
          if (fromBalance != null) {
            balances[transaction.accountId] = fromBalance - transaction.amount;
          }
          final toAccountId = transaction.toAccountId;
          if (toAccountId != null) {
            final toBalance = balances[toAccountId];
            if (toBalance != null) {
              balances[toAccountId] = toBalance + transaction.amount;
            }
          }
      }
    }

    var netAssets = 0;
    var totalAssets = 0;
    var totalLiabilities = 0;
    for (final balance in balances.values) {
      netAssets += balance;
      if (balance >= 0) {
        totalAssets += balance;
      } else {
        totalLiabilities += -balance;
      }
    }

    return BalanceSummary(
      accountBalances: balances,
      netAssets: netAssets,
      totalAssets: totalAssets,
      totalLiabilities: totalLiabilities,
    );
  }

  static MonthRhythmData computeMonthRhythm(
    List<LedgerTransaction> transactions, {
    required int year,
    required int month,
    int? selectedDay,
  }) {
    final now = DateTime.now();
    final isCurrentMonth = year == now.year && month == now.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;

    var monthTotalExpense = 0;
    var monthIncome = 0;
    final dailyExpense = <int, int>{};

    for (final transaction in transactions) {
      final occurredAt = DateTime.fromMillisecondsSinceEpoch(transaction.occurredAt);
      if (occurredAt.year != year || occurredAt.month != month) continue;
      if (transaction.type == TransactionType.expense) {
        monthTotalExpense += transaction.amount;
        dailyExpense.update(
          occurredAt.day,
          (value) => value + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
      } else if (transaction.type == TransactionType.income) {
        monthIncome += transaction.amount;
      }
    }

    final previousMonth = DateTime(year, month - 1);
    final samePeriodDay = isCurrentMonth ? now.day : daysInMonth;
    var previousSamePeriodExpense = 0;
    for (final transaction in transactions) {
      if (transaction.type != TransactionType.expense) continue;
      final occurredAt = DateTime.fromMillisecondsSinceEpoch(transaction.occurredAt);
      if (occurredAt.year == previousMonth.year &&
          occurredAt.month == previousMonth.month &&
          occurredAt.day <= samePeriodDay) {
        previousSamePeriodExpense += transaction.amount;
      }
    }

    final String comparisonSentence;
    if (previousSamePeriodExpense == 0) {
      comparisonSentence = '开始记录你的清晰流水';
    } else if (monthTotalExpense < previousSamePeriodExpense) {
      final difference = previousSamePeriodExpense - monthTotalExpense;
      comparisonSentence =
          '较上月同期少支出 ¥${MoneyFormat.formatYuanPlain(difference)}';
    } else if (monthTotalExpense > previousSamePeriodExpense) {
      final difference = monthTotalExpense - previousSamePeriodExpense;
      comparisonSentence =
          '较上月同期多支出 ¥${MoneyFormat.formatYuanPlain(difference)}';
    } else {
      comparisonSentence = '与上月同期支出持平';
    }

    final positiveDays = dailyExpense.values.where((amount) => amount > 0).toList()
      ..sort();
    final int capBaseline;
    if (positiveDays.length < 3) {
      capBaseline = max(positiveDays.isEmpty ? 5000 : positiveDays.last, 5000);
    } else {
      final p85Index = ((positiveDays.length - 1) * 0.85).toInt();
      capBaseline = max(positiveDays[p85Index] * 2, 5000);
    }

    final bars = <DayRhythmBar>[];
    for (var day = 1; day <= daysInMonth; day++) {
      final amount = dailyExpense[day] ?? 0;
      final isToday = isCurrentMonth && day == now.day;
      final isFuture = isCurrentMonth && day > now.day;
      final heightFraction = (isFuture || amount == 0)
          ? 0.08
          : (amount / capBaseline).clamp(0.12, 1.0).toDouble();
      bars.add(
        DayRhythmBar(
          dayOfMonth: day,
          amountCents: amount,
          isToday: isToday,
          isFuture: isFuture,
          isCapped: amount > capBaseline,
          heightFraction: heightFraction,
        ),
      );
    }

    return MonthRhythmData(
      monthTotalExpense: monthTotalExpense,
      comparisonSentence: comparisonSentence,
      monthIncome: monthIncome,
      monthBalance: monthIncome - monthTotalExpense,
      bars: bars,
      selectedDayExpense:
          selectedDay == null ? null : (dailyExpense[selectedDay] ?? 0),
    );
  }

  static AnalyticsData computeAnalytics(
    List<LedgerTransaction> transactions,
    List<Category> categories, {
    required int year,
    required int month,
    required bool isExpense,
    required bool excludeFixedExpense,
  }) {
    final now = DateTime.now();
    final targetType = isExpense ? TransactionType.expense : TransactionType.income;
    final categoryMap = <String, Category>{
      for (final category in categories) category.id: category,
    };

    final filtered = <LedgerTransaction>[];
    for (final transaction in transactions) {
      if (transaction.type != targetType) continue;
      final occurredAt = DateTime.fromMillisecondsSinceEpoch(transaction.occurredAt);
      if (occurredAt.year != year || occurredAt.month != month) continue;
      if (excludeFixedExpense && isExpense) {
        final categoryId = transaction.categoryId;
        final category = categoryId == null ? null : categoryMap[categoryId];
        if (category?.isFixedExpense ?? false) continue;
      }
      filtered.add(transaction);
    }

    final totalAmount =
        filtered.fold<int>(0, (sum, transaction) => sum + transaction.amount);

    final isCurrentMonth = now.year == year && now.month == month;
    final daysPassed = isCurrentMonth
        ? max(1, now.day)
        : max(1, DateTime(year, month + 1, 0).day);
    final dailyAverage = daysPassed > 0 ? totalAmount ~/ daysPassed : 0;

    if (totalAmount == 0) {
      return AnalyticsData(
        totalAmount: 0,
        dailyAverage: 0,
        insightSentence: '本月暂无${isExpense ? '支出' : '收入'}记录',
        proportionItems: const <CategoryProportionItem>[],
        filteredTransactions: const <LedgerTransaction>[],
      );
    }

    final categorySums = <String, int>{};
    for (final transaction in filtered) {
      final categoryId = transaction.categoryId ?? 'unknown';
      categorySums.update(
        categoryId,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }

    final sortedItems = categorySums.entries.map((entry) {
      final category = categoryMap[entry.key];
      return CategoryProportionItem(
        categoryId: entry.key,
        name: category?.name ?? '其他',
        symbolText: category?.symbolText ?? '他',
        colorHex: category?.colorHex ?? '#8C867A',
        amountCents: entry.value,
        percentage: entry.value / totalAmount,
      );
    }).toList()
      ..sort((a, b) => b.amountCents.compareTo(a.amountCents));

    // 小于 3% 的分类合并为「其他」，追加在末尾。
    final proportionItems = <CategoryProportionItem>[];
    var otherAmount = 0;
    var otherPercentage = 0.0;
    for (final item in sortedItems) {
      if (item.percentage >= 0.03) {
        proportionItems.add(item);
      } else {
        otherAmount += item.amountCents;
        otherPercentage += item.percentage;
      }
    }
    if (otherAmount > 0) {
      proportionItems.add(
        CategoryProportionItem(
          categoryId: 'cat_merged_other',
          name: '其他',
          symbolText: '他',
          colorHex: '#8C867A',
          amountCents: otherAmount,
          percentage: otherPercentage,
        ),
      );
    }

    final topCategory = proportionItems.isEmpty ? null : proportionItems.first;
    final insightSentence = (topCategory != null && isExpense)
        ? '本月「${topCategory.name}」支出最多，占总支出 '
            '${(topCategory.percentage * 100).toInt()}%'
        : '消费结构平稳有序';

    return AnalyticsData(
      totalAmount: totalAmount,
      dailyAverage: dailyAverage,
      insightSentence: insightSentence,
      proportionItems: proportionItems,
      filteredTransactions: filtered,
    );
  }
}