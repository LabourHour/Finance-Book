import 'dart:math';

enum TransactionType { expense, income, transfer }

enum TransactionSource { manual, notification, screenshot, import }

enum AccountType { wechat, alipay, bank, credit, cash, other }

/// 存库/备份统一使用大写枚举名，与旧 Room TypeConverters 保持一致。
String enumToDb(Object value) {
  if (value is Enum) return value.name.toUpperCase();
  throw ArgumentError.value(value, 'value', '仅支持枚举值');
}

T enumFromDb<T>(String raw, T fallback) {
  final target = raw.trim().toUpperCase();
  if (fallback is TransactionType) {
    for (final value in TransactionType.values) {
      if (value.name.toUpperCase() == target) return value as T;
    }
  } else if (fallback is TransactionSource) {
    for (final value in TransactionSource.values) {
      if (value.name.toUpperCase() == target) return value as T;
    }
  } else if (fallback is AccountType) {
    for (final value in AccountType.values) {
      if (value.name.toUpperCase() == target) return value as T;
    }
  }
  return fallback;
}

String newId() {
  final random = Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < 32; i++) {
    buffer.write(random.nextInt(16).toRadixString(16));
  }
  return buffer.toString();
}

int _intOf(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;

String _stringOf(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

String? _stringOrNullOf(Object? value) => value is String ? value : null;

bool _boolOf(Object? value) =>
    value == true || (value is num && value.toInt() == 1);

class Account {
  final String id;
  final String name;
  final AccountType type;
  final int initialBalance;
  final String symbolText;
  final String colorHex;
  final int order;
  final bool isSample;
  final bool isArchived;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    this.initialBalance = 0,
    required this.symbolText,
    required this.colorHex,
    this.order = 0,
    this.isSample = false,
    this.isArchived = false,
  });

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    int? initialBalance,
    String? symbolText,
    String? colorHex,
    int? order,
    bool? isSample,
    bool? isArchived,
  }) =>
      Account(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        initialBalance: initialBalance ?? this.initialBalance,
        symbolText: symbolText ?? this.symbolText,
        colorHex: colorHex ?? this.colorHex,
        order: order ?? this.order,
        isSample: isSample ?? this.isSample,
        isArchived: isArchived ?? this.isArchived,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'name': name,
        'type': enumToDb(type),
        'initialBalance': initialBalance,
        'symbolText': symbolText,
        'colorHex': colorHex,
        'sort_order': order,
        'isSample': isSample ? 1 : 0,
        'isArchived': isArchived ? 1 : 0,
      };

  factory Account.fromMap(Map<String, Object?> map) => Account(
        id: _stringOf(map['id']),
        name: _stringOf(map['name']),
        type: enumFromDb(_stringOf(map['type']), AccountType.other),
        initialBalance: _intOf(map['initialBalance']),
        symbolText: _stringOf(map['symbolText'], '账'),
        colorHex: _stringOf(map['colorHex'], '#1677FF'),
        order: _intOf(map['sort_order']),
        isSample: _boolOf(map['isSample']),
        isArchived: _boolOf(map['isArchived']),
      );
}

class Category {
  final String id;
  final String name;
  final TransactionType type;
  final String symbolText;
  final String colorHex;
  final bool isPinned;
  final bool isFixedExpense;
  final int order;
  final bool isDefault;
  final bool isSample;
  final bool isArchived;

  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.symbolText,
    required this.colorHex,
    this.isPinned = false,
    this.isFixedExpense = false,
    this.order = 0,
    this.isDefault = true,
    this.isSample = false,
    this.isArchived = false,
  });

  Category copyWith({
    String? id,
    String? name,
    TransactionType? type,
    String? symbolText,
    String? colorHex,
    bool? isPinned,
    bool? isFixedExpense,
    int? order,
    bool? isDefault,
    bool? isSample,
    bool? isArchived,
  }) =>
      Category(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        symbolText: symbolText ?? this.symbolText,
        colorHex: colorHex ?? this.colorHex,
        isPinned: isPinned ?? this.isPinned,
        isFixedExpense: isFixedExpense ?? this.isFixedExpense,
        order: order ?? this.order,
        isDefault: isDefault ?? this.isDefault,
        isSample: isSample ?? this.isSample,
        isArchived: isArchived ?? this.isArchived,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'name': name,
        'type': enumToDb(type),
        'symbolText': symbolText,
        'colorHex': colorHex,
        'isPinned': isPinned ? 1 : 0,
        'isFixedExpense': isFixedExpense ? 1 : 0,
        'sort_order': order,
        'isDefault': isDefault ? 1 : 0,
        'isSample': isSample ? 1 : 0,
        'isArchived': isArchived ? 1 : 0,
      };

  factory Category.fromMap(Map<String, Object?> map) => Category(
        id: _stringOf(map['id']),
        name: _stringOf(map['name']),
        type: enumFromDb(_stringOf(map['type']), TransactionType.expense),
        symbolText: _stringOf(map['symbolText'], '他'),
        colorHex: _stringOf(map['colorHex'], '#8C867A'),
        isPinned: _boolOf(map['isPinned']),
        isFixedExpense: _boolOf(map['isFixedExpense']),
        order: _intOf(map['sort_order']),
        isDefault: map.containsKey('isDefault') ? _boolOf(map['isDefault']) : true,
        isSample: _boolOf(map['isSample']),
        isArchived: _boolOf(map['isArchived']),
      );
}

class LedgerTransaction {
  final String id;
  final TransactionType type;
  final int amount;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final int occurredAt;
  final String? note;
  final TransactionSource source;
  final bool isSample;
  final String? dedupKey;
  final int createdAt;
  final int updatedAt;

  /// 软删除标记：0 表示有效，其余值为删除时刻的毫秒时间戳。
  final int deletedAt;

  const LedgerTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    required this.occurredAt,
    this.note,
    this.source = TransactionSource.manual,
    this.isSample = false,
    this.dedupKey,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt = 0,
  });

  static const Object _unset = Object();

  LedgerTransaction copyWith({
    String? id,
    TransactionType? type,
    int? amount,
    String? accountId,
    Object? toAccountId = _unset,
    Object? categoryId = _unset,
    int? occurredAt,
    Object? note = _unset,
    TransactionSource? source,
    bool? isSample,
    Object? dedupKey = _unset,
    int? createdAt,
    int? updatedAt,
    int? deletedAt,
  }) =>
      LedgerTransaction(
        id: id ?? this.id,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        accountId: accountId ?? this.accountId,
        toAccountId:
            identical(toAccountId, _unset) ? this.toAccountId : toAccountId as String?,
        categoryId:
            identical(categoryId, _unset) ? this.categoryId : categoryId as String?,
        occurredAt: occurredAt ?? this.occurredAt,
        note: identical(note, _unset) ? this.note : note as String?,
        source: source ?? this.source,
        isSample: isSample ?? this.isSample,
        dedupKey: identical(dedupKey, _unset) ? this.dedupKey : dedupKey as String?,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'type': enumToDb(type),
        'amount': amount,
        'accountId': accountId,
        'toAccountId': toAccountId,
        'categoryId': categoryId,
        'occurredAt': occurredAt,
        'note': note,
        'source': enumToDb(source),
        'isSample': isSample ? 1 : 0,
        'dedupKey': dedupKey,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deletedAt': deletedAt,
      };

  factory LedgerTransaction.fromMap(Map<String, Object?> map) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return LedgerTransaction(
      id: _stringOf(map['id']),
      type: enumFromDb(_stringOf(map['type']), TransactionType.expense),
      amount: _intOf(map['amount']),
      accountId: _stringOf(map['accountId']),
      toAccountId: _stringOrNullOf(map['toAccountId']),
      categoryId: _stringOrNullOf(map['categoryId']),
      occurredAt: _intOf(map['occurredAt'], now),
      note: _stringOrNullOf(map['note']),
      source: enumFromDb(_stringOf(map['source'], 'MANUAL'), TransactionSource.manual),
      isSample: _boolOf(map['isSample']),
      dedupKey: _stringOrNullOf(map['dedupKey']),
      createdAt: _intOf(map['createdAt'], now),
      updatedAt: _intOf(map['updatedAt'], now),
      deletedAt: _intOf(map['deletedAt'], 0),
    );
  }
}

class Budget {
  final String month;
  final int totalBudget;
  final String? categoryBudgetsJson;

  const Budget({
    required this.month,
    required this.totalBudget,
    this.categoryBudgetsJson,
  });

  Budget copyWith({
    String? month,
    int? totalBudget,
    String? categoryBudgetsJson,
  }) =>
      Budget(
        month: month ?? this.month,
        totalBudget: totalBudget ?? this.totalBudget,
        categoryBudgetsJson: categoryBudgetsJson ?? this.categoryBudgetsJson,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'month': month,
        'totalBudget': totalBudget,
        'categoryBudgetsJson': categoryBudgetsJson,
      };

  factory Budget.fromMap(Map<String, Object?> map) => Budget(
        month: _stringOf(map['month']),
        totalBudget: _intOf(map['totalBudget']),
        categoryBudgetsJson: _stringOrNullOf(map['categoryBudgetsJson']),
      );
}

class RecurringRule {
  final String id;
  final String name;
  final TransactionType type;
  final int amount;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final String frequency;
  final int dayOfMonth;
  final int nextDueDate;
  final bool isActive;
  final bool isSample;

  const RecurringRule({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    this.frequency = 'MONTHLY',
    required this.dayOfMonth,
    required this.nextDueDate,
    this.isActive = true,
    this.isSample = false,
  });

  static const Object _unset = Object();

  RecurringRule copyWith({
    String? id,
    String? name,
    TransactionType? type,
    int? amount,
    String? accountId,
    Object? toAccountId = _unset,
    Object? categoryId = _unset,
    String? frequency,
    int? dayOfMonth,
    int? nextDueDate,
    bool? isActive,
    bool? isSample,
  }) =>
      RecurringRule(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        accountId: accountId ?? this.accountId,
        toAccountId:
            identical(toAccountId, _unset) ? this.toAccountId : toAccountId as String?,
        categoryId:
            identical(categoryId, _unset) ? this.categoryId : categoryId as String?,
        frequency: frequency ?? this.frequency,
        dayOfMonth: dayOfMonth ?? this.dayOfMonth,
        nextDueDate: nextDueDate ?? this.nextDueDate,
        isActive: isActive ?? this.isActive,
        isSample: isSample ?? this.isSample,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'name': name,
        'type': enumToDb(type),
        'amount': amount,
        'accountId': accountId,
        'toAccountId': toAccountId,
        'categoryId': categoryId,
        'frequency': frequency,
        'dayOfMonth': dayOfMonth,
        'nextDueDate': nextDueDate,
        'isActive': isActive ? 1 : 0,
        'isSample': isSample ? 1 : 0,
      };

  factory RecurringRule.fromMap(Map<String, Object?> map) => RecurringRule(
        id: _stringOf(map['id']),
        name: _stringOf(map['name']),
        type: enumFromDb(_stringOf(map['type']), TransactionType.expense),
        amount: _intOf(map['amount']),
        accountId: _stringOf(map['accountId']),
        toAccountId: _stringOrNullOf(map['toAccountId']),
        categoryId: _stringOrNullOf(map['categoryId']),
        frequency: _stringOf(map['frequency'], 'MONTHLY'),
        dayOfMonth: _intOf(map['dayOfMonth']),
        nextDueDate: _intOf(map['nextDueDate']),
        isActive: map.containsKey('isActive') ? _boolOf(map['isActive']) : true,
        isSample: _boolOf(map['isSample']),
      );
}

class BalanceSummary {
  final Map<String, int> accountBalances;
  final int netAssets;
  final int totalAssets;
  final int totalLiabilities;

  const BalanceSummary({
    required this.accountBalances,
    required this.netAssets,
    required this.totalAssets,
    required this.totalLiabilities,
  });
}

class DayRhythmBar {
  final int dayOfMonth;
  final int amountCents;
  final bool isToday;
  final bool isFuture;
  final bool isCapped;
  final double heightFraction;

  const DayRhythmBar({
    required this.dayOfMonth,
    required this.amountCents,
    required this.isToday,
    required this.isFuture,
    required this.isCapped,
    required this.heightFraction,
  });
}

class MonthRhythmData {
  final int monthTotalExpense;
  final String comparisonSentence;
  final int monthIncome;
  final int monthBalance;
  final List<DayRhythmBar> bars;
  final int? selectedDayExpense;

  const MonthRhythmData({
    required this.monthTotalExpense,
    required this.comparisonSentence,
    required this.monthIncome,
    required this.monthBalance,
    required this.bars,
    required this.selectedDayExpense,
  });
}

class CategoryProportionItem {
  final String categoryId;
  final String name;
  final String symbolText;
  final String colorHex;
  final int amountCents;
  final double percentage;

  const CategoryProportionItem({
    required this.categoryId,
    required this.name,
    required this.symbolText,
    required this.colorHex,
    required this.amountCents,
    required this.percentage,
  });
}

class AnalyticsData {
  final int totalAmount;
  final int dailyAverage;
  final String insightSentence;
  final List<CategoryProportionItem> proportionItems;
  final List<LedgerTransaction> filteredTransactions;

  const AnalyticsData({
    required this.totalAmount,
    required this.dailyAverage,
    required this.insightSentence,
    required this.proportionItems,
    required this.filteredTransactions,
  });
}

class ClearSampleResult {
  final int deletedTransactions;
  final int removedAccounts;
  final int keptAccounts;

  const ClearSampleResult({
    required this.deletedTransactions,
    required this.removedAccounts,
    required this.keptAccounts,
  });
}

class RestoreResult {
  final bool ok;
  final int count;
  final String? error;

  const RestoreResult.success(this.count)
      : ok = true,
        error = null;

  const RestoreResult.failure(this.error)
      : ok = false,
        count = 0;
}