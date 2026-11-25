import 'package:flutter_test/flutter_test.dart';
import 'package:stream_ledger/data/calculators.dart';
import 'package:stream_ledger/data/models.dart';

Account _account({
  required String id,
  required String name,
  AccountType type = AccountType.bank,
  int initialBalance = 0,
}) {
  return Account(
    id: id,
    name: name,
    type: type,
    initialBalance: initialBalance,
    symbolText: '测',
    colorHex: '#1677FF',
  );
}

Category _category({
  required String id,
  required String name,
  TransactionType type = TransactionType.expense,
  String symbolText = '餐',
  String colorHex = '#D97757',
  bool isFixedExpense = false,
}) {
  return Category(
    id: id,
    name: name,
    type: type,
    symbolText: symbolText,
    colorHex: colorHex,
    isFixedExpense: isFixedExpense,
  );
}

LedgerTransaction _tx({
  required String id,
  required TransactionType type,
  required int amount,
  required String accountId,
  required DateTime at,
  String? toAccountId,
  String? categoryId,
}) {
  return LedgerTransaction(
    id: id,
    type: type,
    amount: amount,
    accountId: accountId,
    toAccountId: toAccountId,
    categoryId: categoryId,
    occurredAt: at.millisecondsSinceEpoch,
    createdAt: at.millisecondsSinceEpoch,
    updatedAt: at.millisecondsSinceEpoch,
  );
}

DateTime _at(int year, int month, int day) => DateTime(year, month, day, 12);

void main() {
  group('LedgerCalculators.computeBalances', () {
    test('支出扣减、信用卡还款转账与净资产汇总', () {
      final accounts = [
        _account(id: 'acc_bank', name: '储蓄卡', initialBalance: 100000),
        _account(
          id: 'acc_credit',
          name: '信用卡',
          type: AccountType.credit,
          initialBalance: -20000,
        ),
      ];
      final transactions = [
        _tx(
          id: '1',
          type: TransactionType.expense,
          amount: 10000,
          accountId: 'acc_bank',
          at: _at(2020, 1, 3),
        ),
        _tx(
          id: '2',
          type: TransactionType.expense,
          amount: 5000,
          accountId: 'acc_credit',
          at: _at(2020, 1, 4),
        ),
        _tx(
          id: '3',
          type: TransactionType.transfer,
          amount: 15000,
          accountId: 'acc_bank',
          toAccountId: 'acc_credit',
          at: _at(2020, 1, 5),
        ),
      ];

      final summary = LedgerCalculators.computeBalances(accounts, transactions);

      expect(summary.accountBalances['acc_bank'], 75000);
      expect(summary.accountBalances['acc_credit'], -10000);
      expect(summary.netAssets, 65000);
      expect(summary.totalAssets, 75000);
      expect(summary.totalLiabilities, 10000);
    });

    test('未命中账户的流水被忽略', () {
      final accounts = [_account(id: 'acc_bank', name: '储蓄卡', initialBalance: 100000)];
      final transactions = [
        _tx(
          id: '1',
          type: TransactionType.expense,
          amount: 10000,
          accountId: 'acc_missing',
          at: _at(2020, 1, 3),
        ),
        _tx(
          id: '2',
          type: TransactionType.transfer,
          amount: 20000,
          accountId: 'acc_bank',
          toAccountId: 'acc_missing_to',
          at: _at(2020, 1, 4),
        ),
      ];

      final summary = LedgerCalculators.computeBalances(accounts, transactions);

      expect(summary.accountBalances['acc_bank'], 80000);
      expect(summary.accountBalances.containsKey('acc_missing'), isFalse);
      expect(summary.netAssets, 80000);
    });

    test('空输入返回零值且不抛异常', () {
      final summary = LedgerCalculators.computeBalances(const [], const []);
      expect(summary.accountBalances, isEmpty);
      expect(summary.netAssets, 0);
      expect(summary.totalAssets, 0);
      expect(summary.totalLiabilities, 0);
    });
  });

  group('LedgerCalculators.computeMonthRhythm', () {
    test('当月收支汇总与按日柱高', () {
      final transactions = [
        _tx(
          id: '1',
          type: TransactionType.expense,
          amount: 10000,
          accountId: 'acc_bank',
          at: _at(2020, 1, 1),
        ),
        _tx(
          id: '2',
          type: TransactionType.expense,
          amount: 20000,
          accountId: 'acc_bank',
          at: _at(2020, 1, 2),
        ),
        _tx(
          id: '3',
          type: TransactionType.income,
          amount: 50000,
          accountId: 'acc_bank',
          at: _at(2020, 1, 2),
        ),
        // 相邻月份的数据不参与本月节奏
        _tx(
          id: '4',
          type: TransactionType.expense,
          amount: 99900,
          accountId: 'acc_bank',
          at: _at(2019, 12, 20),
        ),
      ];

      final rhythm = LedgerCalculators.computeMonthRhythm(
        transactions,
        year: 2020,
        month: 1,
      );

      expect(rhythm.monthTotalExpense, 30000);
      expect(rhythm.monthIncome, 50000);
      expect(rhythm.monthBalance, 20000);
      expect(rhythm.bars.length, 31);
      expect(rhythm.selectedDayExpense, isNull);

      // 支出日不足 3 天：封顶基准取 max(最大值 20000, 5000) = 20000
      final day1 = rhythm.bars[0];
      expect(day1.amountCents, 10000);
      expect(day1.heightFraction, closeTo(0.5, 1e-9));
      expect(day1.isCapped, isFalse);

      final day2 = rhythm.bars[1];
      expect(day2.amountCents, 20000);
      expect(day2.heightFraction, closeTo(1.0, 1e-9));

      final day3 = rhythm.bars[2];
      expect(day3.amountCents, 0);
      expect(day3.heightFraction, closeTo(0.08, 1e-9));
    });

    test('支出日不足 3 天时用 5000 分最小刻度兜底', () {
      final transactions = [
        _tx(
          id: '1',
          type: TransactionType.expense,
          amount: 3000,
          accountId: 'acc_bank',
          at: _at(2020, 1, 5),
        ),
      ];

      final rhythm = LedgerCalculators.computeMonthRhythm(
        transactions,
        year: 2020,
        month: 1,
      );

      expect(rhythm.bars[4].heightFraction, closeTo(0.6, 1e-9));
      expect(rhythm.bars[4].isCapped, isFalse);
    });

    test('支出日达到 3 天时按 85 分位 ×2 封顶并标记 isCapped', () {
      final transactions = [
        _tx(
          id: '1',
          type: TransactionType.expense,
          amount: 10000,
          accountId: 'acc_bank',
          at: _at(2020, 1, 1),
        ),
        _tx(
          id: '2',
          type: TransactionType.expense,
          amount: 20000,
          accountId: 'acc_bank',
          at: _at(2020, 1, 2),
        ),
        _tx(
          id: '3',
          type: TransactionType.expense,
          amount: 60000,
          accountId: 'acc_bank',
          at: _at(2020, 1, 3),
        ),
      ];

      // 升序 [10000, 20000, 60000]，85 分位索引 1 -> 20000 ×2 = 40000
      final rhythm = LedgerCalculators.computeMonthRhythm(
        transactions,
        year: 2020,
        month: 1,
      );

      expect(rhythm.bars[0].heightFraction, closeTo(0.25, 1e-9));
      expect(rhythm.bars[1].heightFraction, closeTo(0.5, 1e-9));
      expect(rhythm.bars[2].heightFraction, closeTo(1.0, 1e-9));
      expect(rhythm.bars[2].isCapped, isTrue);
    });

    test('历史月不标记今天与未来', () {
      final rhythm = LedgerCalculators.computeMonthRhythm(
        [
          _tx(
            id: '1',
            type: TransactionType.expense,
            amount: 10000,
            accountId: 'acc_bank',
            at: _at(2020, 1, 1),
          ),
        ],
        year: 2020,
        month: 1,
      );

      expect(rhythm.bars.every((bar) => !bar.isToday), isTrue);
      expect(rhythm.bars.every((bar) => !bar.isFuture), isTrue);
    });

    test('selectedDayExpense 返回选中日支出，无支出为 0', () {
      final transactions = [
        _tx(
          id: '1',
          type: TransactionType.expense,
          amount: 20000,
          accountId: 'acc_bank',
          at: _at(2020, 1, 2),
        ),
      ];

      final selected = LedgerCalculators.computeMonthRhythm(
        transactions,
        year: 2020,
        month: 1,
        selectedDay: 2,
      );
      expect(selected.selectedDayExpense, 20000);

      final emptyDay = LedgerCalculators.computeMonthRhythm(
        transactions,
        year: 2020,
        month: 1,
        selectedDay: 10,
      );
      expect(emptyDay.selectedDayExpense, 0);
    });

    test('对比句四种分支', () {
      final currentExpense = [
        _tx(
          id: 'cur',
          type: TransactionType.expense,
          amount: 20000,
          accountId: 'acc_bank',
          at: _at(2020, 1, 4),
        ),
      ];

      final noPrevious = LedgerCalculators.computeMonthRhythm(
        currentExpense,
        year: 2020,
        month: 1,
      );
      expect(noPrevious.comparisonSentence, '开始记录你的清晰流水');

      final lessThanPrevious = LedgerCalculators.computeMonthRhythm(
        [
          ...currentExpense,
          _tx(
            id: 'prev',
            type: TransactionType.expense,
            amount: 30000,
            accountId: 'acc_bank',
            at: _at(2019, 12, 18),
          ),
        ],
        year: 2020,
        month: 1,
      );
      expect(lessThanPrevious.comparisonSentence, '较上月同期少支出 ¥100.00');

      final moreThanPrevious = LedgerCalculators.computeMonthRhythm(
        [
          ...currentExpense,
          _tx(
            id: 'cur2',
            type: TransactionType.expense,
            amount: 10000,
            accountId: 'acc_bank',
            at: _at(2020, 1, 6),
          ),
          _tx(
            id: 'prev',
            type: TransactionType.expense,
            amount: 20000,
            accountId: 'acc_bank',
            at: _at(2019, 12, 18),
          ),
        ],
        year: 2020,
        month: 1,
      );
      expect(moreThanPrevious.comparisonSentence, '较上月同期多支出 ¥100.00');

      final even = LedgerCalculators.computeMonthRhythm(
        [
          ...currentExpense,
          _tx(
            id: 'prev',
            type: TransactionType.expense,
            amount: 20000,
            accountId: 'acc_bank',
            at: _at(2019, 12, 18),
          ),
        ],
        year: 2020,
        month: 1,
      );
      expect(even.comparisonSentence, '与上月同期支出持平');
    });
  });

  group('LedgerCalculators.computeAnalytics', () {
    final dining = _category(id: 'cat_dining', name: '餐饮美食');
    final rent = _category(
      id: 'cat_rent',
      name: '房租',
      symbolText: '租',
      colorHex: '#8C867A',
      isFixedExpense: true,
    );
    final salary = _category(
      id: 'cat_salary',
      name: '工资',
      type: TransactionType.income,
      symbolText: '薪',
      colorHex: '#3F7D5B',
    );

    test('排除转账与非目标月份，按分类金额降序汇总', () {
      final transactions = [
        _tx(
          id: '1',
          type: TransactionType.expense,
          amount: 60000,
          accountId: 'acc_bank',
          categoryId: 'cat_dining',
          at: _at(2020, 1, 4),
        ),
        _tx(
          id: '2',
          type: TransactionType.expense,
          amount: 40000,
          accountId: 'acc_bank',
          categoryId: 'cat_rent',
          at: _at(2020, 1, 5),
        ),
        _tx(
          id: '3',
          type: TransactionType.transfer,
          amount: 50000,
          accountId: 'acc_bank',
          toAccountId: 'acc_wallet',
          at: _at(2020, 1, 6),
        ),
        _tx(
          id: '4',
          type: TransactionType.expense,
          amount: 10000,
          accountId: 'acc_bank',
          categoryId: 'cat_dining',
          at: _at(2020, 2, 1),
        ),
      ];

      final analytics = LedgerCalculators.computeAnalytics(
        transactions,
        [dining, rent, salary],
        year: 2020,
        month: 1,
        isExpense: true,
        excludeFixedExpense: false,
      );

      expect(analytics.totalAmount, 100000);
      expect(analytics.filteredTransactions.length, 2);
      // 历史月按当月天数取日均：100000 / 31
      expect(analytics.dailyAverage, 3225);
      expect(analytics.proportionItems.length, 2);
      expect(analytics.proportionItems[0].categoryId, 'cat_dining');
      expect(analytics.proportionItems[0].amountCents, 60000);
      expect(analytics.proportionItems[0].percentage, closeTo(0.6, 1e-6));
      expect(analytics.proportionItems[1].categoryId, 'cat_rent');
      expect(analytics.insightSentence, '本月「餐饮美食」支出最多，占总支出 60%');
    });

    test('占比小于 3% 的分类合并为「其他」', () {
      final transactions = [
        _tx(
          id: '1',
          type: TransactionType.expense,
          amount: 97000,
          accountId: 'acc_bank',
          categoryId: 'cat_dining',
          at: _at(2020, 1, 4),
        ),
        _tx(
          id: '2',
          type: TransactionType.expense,
          amount: 2000,
          accountId: 'acc_bank',
          categoryId: 'cat_minor_a',
          at: _at(2020, 1, 5),
        ),
        _tx(
          id: '3',
          type: TransactionType.expense,
          amount: 1000,
          accountId: 'acc_bank',
          categoryId: 'cat_minor_b',
          at: _at(2020, 1, 6),
        ),
      ];

      final analytics = LedgerCalculators.computeAnalytics(
        transactions,
        [dining, rent, salary],
        year: 2020,
        month: 1,
        isExpense: true,
        excludeFixedExpense: false,
      );

      expect(analytics.proportionItems.length, 2);
      final merged = analytics.proportionItems.last;
      expect(merged.categoryId, 'cat_merged_other');
      expect(merged.name, '其他');
      expect(merged.symbolText, '他');
      expect(merged.colorHex, '#8C867A');
      expect(merged.amountCents, 3000);
      expect(merged.percentage, closeTo(0.03, 1e-6));
    });

    test('不含固定支出时排除固定支出分类', () {
      final transactions = [
        _tx(
          id: '1',
          type: TransactionType.expense,
          amount: 60000,
          accountId: 'acc_bank',
          categoryId: 'cat_dining',
          at: _at(2020, 1, 4),
        ),
        _tx(
          id: '2',
          type: TransactionType.expense,
          amount: 40000,
          accountId: 'acc_bank',
          categoryId: 'cat_rent',
          at: _at(2020, 1, 5),
        ),
      ];

      final analytics = LedgerCalculators.computeAnalytics(
        transactions,
        [dining, rent, salary],
        year: 2020,
        month: 1,
        isExpense: true,
        excludeFixedExpense: true,
      );

      expect(analytics.totalAmount, 60000);
      expect(analytics.filteredTransactions.length, 1);
      expect(analytics.proportionItems.length, 1);
      expect(analytics.proportionItems.single.categoryId, 'cat_dining');
    });

    test('切换为收入视角时只统计收入流水', () {
      final transactions = [
        _tx(
          id: '1',
          type: TransactionType.income,
          amount: 62000,
          accountId: 'acc_bank',
          categoryId: 'cat_salary',
          at: _at(2020, 1, 10),
        ),
        _tx(
          id: '2',
          type: TransactionType.expense,
          amount: 60000,
          accountId: 'acc_bank',
          categoryId: 'cat_dining',
          at: _at(2020, 1, 4),
        ),
      ];

      final analytics = LedgerCalculators.computeAnalytics(
        transactions,
        [dining, rent, salary],
        year: 2020,
        month: 1,
        isExpense: false,
        excludeFixedExpense: false,
      );

      expect(analytics.totalAmount, 62000);
      expect(analytics.dailyAverage, 2000);
      expect(analytics.proportionItems.length, 1);
      expect(analytics.proportionItems.single.categoryId, 'cat_salary');
      expect(analytics.insightSentence, '消费结构平稳有序');
    });

    test('空数据返回提示句与空列表', () {
      final expense = LedgerCalculators.computeAnalytics(
        const [],
        [dining],
        year: 2020,
        month: 1,
        isExpense: true,
        excludeFixedExpense: false,
      );
      expect(expense.totalAmount, 0);
      expect(expense.dailyAverage, 0);
      expect(expense.insightSentence, '本月暂无支出记录');
      expect(expense.proportionItems, isEmpty);
      expect(expense.filteredTransactions, isEmpty);

      final income = LedgerCalculators.computeAnalytics(
        const [],
        [dining],
        year: 2020,
        month: 1,
        isExpense: false,
        excludeFixedExpense: false,
      );
      expect(income.insightSentence, '本月暂无收入记录');
    });
  });
}