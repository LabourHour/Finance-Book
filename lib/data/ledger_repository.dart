import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'ledger_database.dart';
import 'models.dart';
import 'seed.dart';

class LedgerRepository {
  LedgerRepository([LedgerDatabase? database])
      : _database = database ?? LedgerDatabase.instance;

  final LedgerDatabase _database;

  Future<Database> get _db => _database.database;

  Future<void> ensureInitialData() async {
    final db = await _db;
    await db.transaction((txn) async {
      final categoryCount =
          Sqflite.firstIntValue(await txn.rawQuery('SELECT COUNT(*) FROM categories')) ?? 0;
      if (categoryCount == 0) {
        for (final category in DataSeed.defaultCategories) {
          await txn.insert(
            'categories',
            category.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      final accountCount =
          Sqflite.firstIntValue(await txn.rawQuery('SELECT COUNT(*) FROM accounts')) ?? 0;
      if (accountCount == 0) {
        await txn.insert(
          'accounts',
          DataSeed.defaultAccount.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<LedgerTransaction>> loadAllTransactions() async {
    final db = await _db;
    final rows = await db.query(
      'transactions',
      where: 'deletedAt = 0',
      orderBy: 'occurredAt DESC',
    );
    return rows.map(LedgerTransaction.fromMap).toList();
  }

  Future<List<Account>> loadAccounts() async {
    final db = await _db;
    final rows = await db.query(
      'accounts',
      where: 'isArchived = 0',
      orderBy: 'sort_order',
    );
    return rows.map(Account.fromMap).toList();
  }

  Future<List<Category>> loadCategories() async {
    final db = await _db;
    final rows = await db.query(
      'categories',
      where: 'isArchived = 0',
      orderBy: 'sort_order',
    );
    return rows.map(Category.fromMap).toList();
  }

  Future<void> insertAccount(Account account) async {
    final db = await _db;
    await db.insert(
      'accounts',
      account.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateAccount(Account account) async {
    final db = await _db;
    await db.update(
      'accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[account.id],
    );
  }

  Future<int> countTransactionsOfAccount(String accountId) async {
    final db = await _db;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM transactions '
      'WHERE (accountId = ? OR toAccountId = ?) AND deletedAt = 0',
      <Object?>[accountId, accountId],
    ));
    return count ?? 0;
  }

  Future<int> countTrashedTransactionsOfAccount(String accountId) async {
    final db = await _db;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM transactions '
      'WHERE (accountId = ? OR toAccountId = ?) AND deletedAt > 0',
      <Object?>[accountId, accountId],
    ));
    return count ?? 0;
  }

  Future<void> archiveAccount(String accountId) async {
    final db = await _db;
    await db.update(
      'accounts',
      <String, Object?>{'isArchived': 1},
      where: 'id = ?',
      whereArgs: <Object?>[accountId],
    );
  }

  Future<int> countTransactionsOfCategory(String categoryId) async {
    final db = await _db;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM transactions WHERE categoryId = ? AND deletedAt = 0',
      <Object?>[categoryId],
    ));
    return count ?? 0;
  }

  Future<int> countTrashedTransactionsOfCategory(String categoryId) async {
    final db = await _db;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM transactions WHERE categoryId = ? AND deletedAt > 0',
      <Object?>[categoryId],
    ));
    return count ?? 0;
  }

  Future<void> insertCategory(Category category) async {
    final db = await _db;
    await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateCategory(Category category) async {
    final db = await _db;
    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[category.id],
    );
  }

  Future<void> archiveCategory(String categoryId) async {
    final db = await _db;
    await db.update(
      'categories',
      <String, Object?>{'isArchived': 1},
      where: 'id = ?',
      whereArgs: <Object?>[categoryId],
    );
  }

  Future<void> insertTransaction(LedgerTransaction tx) async {
    final db = await _db;
    await db.insert(
      'transactions',
      tx.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTransaction(LedgerTransaction tx) async {
    final db = await _db;
    await db.update(
      'transactions',
      tx.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[tx.id],
    );
  }

  Future<void> deleteTransaction(LedgerTransaction tx) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'transactions',
      <String, Object?>{'deletedAt': now == 0 ? 1 : now, 'updatedAt': now},
      where: 'id = ?',
      whereArgs: <Object?>[tx.id],
    );
  }

  Future<void> restoreDeletedTransaction(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        'transactions',
        <String, Object?>{'deletedAt': 0},
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      final rows = await txn.query(
        'transactions',
        columns: <String>['accountId', 'toAccountId', 'categoryId'],
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final row = rows.first;
      for (final key in const <String>['accountId', 'toAccountId']) {
        final accountId = row[key];
        if (accountId is String && accountId.isNotEmpty) {
          await txn.update(
            'accounts',
            <String, Object?>{'isArchived': 0},
            where: 'id = ?',
            whereArgs: <Object?>[accountId],
          );
        }
      }
      final categoryId = row['categoryId'];
      if (categoryId is String && categoryId.isNotEmpty) {
        await txn.update(
          'categories',
          <String, Object?>{'isArchived': 0},
          where: 'id = ?',
          whereArgs: <Object?>[categoryId],
        );
      }
    });
  }

  Future<List<LedgerTransaction>> loadDeletedTransactions() async {
    final db = await _db;
    final rows = await db.query(
      'transactions',
      where: 'deletedAt > 0',
      orderBy: 'deletedAt DESC',
    );
    return rows.map(LedgerTransaction.fromMap).toList();
  }

  Future<void> purgeTransaction(String id) async {
    final db = await _db;
    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<Budget?> loadBudget(String month) async {
    final db = await _db;
    final rows = await db.query(
      'budgets',
      where: 'month = ?',
      whereArgs: <Object?>[month],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Budget.fromMap(rows.first);
  }

  Future<void> saveBudget(Budget budget) async {
    final db = await _db;
    await db.insert(
      'budgets',
      budget.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<RecurringRule>> loadRecurringRules() async {
    final db = await _db;
    final rows = await db.query(
      'recurring_rules',
      where: 'isActive = 1',
      orderBy: 'name',
    );
    return rows.map(RecurringRule.fromMap).toList();
  }

  Future<void> saveRecurringRule(RecurringRule rule) async {
    final db = await _db;
    await db.insert(
      'recurring_rules',
      rule.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteRecurringRule(String id) async {
    final db = await _db;
    await db.delete(
      'recurring_rules',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// 已删除的账单同样占用 dedupKey，避免「生成 → 删除 → 再次生成」反复复活。
  Future<bool> hasTransactionWithDedupKey(String dedupKey) async {
    final db = await _db;
    final rows = await db.query(
      'transactions',
      columns: <String>['id'],
      where: 'dedupKey = ?',
      whereArgs: <Object?>[dedupKey],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> updateRecurringRuleNextDueDate(String id, int nextDueDate) async {
    final db = await _db;
    await db.update(
      'recurring_rules',
      <String, Object?>{'nextDueDate': nextDueDate},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await _db;
    final rows = await db.query(
      'settings',
      columns: <String>['value'],
      where: '"key" = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = rows.first['value'];
    return value is String ? value : null;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await _db;
    await db.insert(
      'settings',
      <String, Object?>{'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSetting(String key) async {
    final db = await _db;
    await db.delete(
      'settings',
      where: '"key" = ?',
      whereArgs: <Object?>[key],
    );
  }

  Future<ClearSampleResult> clearSampleData() async {
    final db = await _db;
    return db.transaction((txn) async {
      final deletedTransactions = await txn.delete(
        'transactions',
        where: 'isSample = 1',
      );

      // 清掉示例流水后，剩余流水即为用户真实数据，其引用的账户必须保留。
      final referencedAccountIds = <String>{};
      final rows = await txn.query(
        'transactions',
        columns: <String>['accountId', 'toAccountId'],
      );
      for (final row in rows) {
        final accountId = row['accountId'];
        if (accountId is String) referencedAccountIds.add(accountId);
        final toAccountId = row['toAccountId'];
        if (toAccountId is String) referencedAccountIds.add(toAccountId);
      }

      var removedAccounts = 0;
      var keptAccounts = 0;
      final sampleAccounts = await txn.query('accounts', where: 'isSample = 1');
      for (final row in sampleAccounts) {
        final account = Account.fromMap(row);
        if (referencedAccountIds.contains(account.id)) {
          await txn.update(
            'accounts',
            <String, Object?>{'isSample': 0},
            where: 'id = ?',
            whereArgs: <Object?>[account.id],
          );
          keptAccounts++;
        } else {
          await txn.delete(
            'accounts',
            where: 'id = ?',
            whereArgs: <Object?>[account.id],
          );
          removedAccounts++;
        }
      }

      await txn.delete(
        'categories',
        where: 'isSample = 1 AND isDefault = 0',
      );

      return ClearSampleResult(
        deletedTransactions: deletedTransactions,
        removedAccounts: removedAccounts,
        keptAccounts: keptAccounts,
      );
    });
  }

  Future<String> exportBackupJson() async {
    final db = await _db;
    final transactionRows = await db.query(
      'transactions',
      where: 'isSample = 0 AND deletedAt = 0',
      orderBy: 'occurredAt DESC',
    );
    final accountRows = await db.query('accounts', orderBy: 'sort_order');
    final categoryRows = await db.query('categories', orderBy: 'sort_order');
    final budgetRows = await db.query('budgets', orderBy: 'month');
    final recurringRows = await db.query(
      'recurring_rules',
      where: 'isSample = 0',
      orderBy: 'name',
    );

    final transactions = transactionRows.map(LedgerTransaction.fromMap).toList();
    final accounts = accountRows.map(Account.fromMap).toList();
    final categories = categoryRows.map(Category.fromMap).toList();
    final budgets = budgetRows.map(Budget.fromMap).toList();
    final recurringRules = recurringRows.map(RecurringRule.fromMap).toList();

    final root = <String, Object?>{
      'schemaVersion': LedgerDatabase.schemaVersion,
      'exportedAt': DateTime.now().millisecondsSinceEpoch,
      'transactions': <Map<String, Object?>>[
        for (final transaction in transactions)
          <String, Object?>{
            'id': transaction.id,
            'type': enumToDb(transaction.type),
            'amount': transaction.amount,
            'accountId': transaction.accountId,
            'toAccountId': transaction.toAccountId,
            'categoryId': transaction.categoryId,
            'occurredAt': transaction.occurredAt,
            'note': transaction.note ?? '',
            'source': enumToDb(transaction.source),
            if (transaction.dedupKey != null) 'dedupKey': transaction.dedupKey,
            'createdAt': transaction.createdAt,
          },
      ],
      'accounts': <Map<String, Object?>>[
        for (final account in accounts)
          <String, Object?>{
            'id': account.id,
            'name': account.name,
            'type': enumToDb(account.type),
            'initialBalance': account.initialBalance,
            'symbolText': account.symbolText,
            'colorHex': account.colorHex,
            'order': account.order,
            'isSample': account.isSample,
            'isArchived': account.isArchived,
          },
      ],
      'categories': <Map<String, Object?>>[
        for (final category in categories)
          <String, Object?>{
            'id': category.id,
            'name': category.name,
            'type': enumToDb(category.type),
            'symbolText': category.symbolText,
            'colorHex': category.colorHex,
            'isPinned': category.isPinned,
            'isFixedExpense': category.isFixedExpense,
            'order': category.order,
            'isDefault': category.isDefault,
            'isArchived': category.isArchived,
          },
      ],
      'budgets': <Map<String, Object?>>[
        for (final budget in budgets)
          <String, Object?>{
            'month': budget.month,
            'totalBudget': budget.totalBudget,
            'categoryBudgetsJson': budget.categoryBudgetsJson,
          },
      ],
      'recurringRules': <Map<String, Object?>>[
        for (final rule in recurringRules)
          <String, Object?>{
            'id': rule.id,
            'name': rule.name,
            'type': enumToDb(rule.type),
            'amount': rule.amount,
            'accountId': rule.accountId,
            'toAccountId': rule.toAccountId,
            'categoryId': rule.categoryId,
            'frequency': rule.frequency,
            'dayOfMonth': rule.dayOfMonth,
            'nextDueDate': rule.nextDueDate,
            'isActive': rule.isActive,
          },
      ],
    };

    return const JsonEncoder.withIndent('  ').convert(root);
  }

  Future<RestoreResult> restoreBackupJson(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map) {
        return const RestoreResult.failure('备份文件无效：缺失正确的 schemaVersion');
      }
      final version = _intOf(decoded['schemaVersion'], -1);
      if (version < 1) {
        return const RestoreResult.failure('备份文件无效：缺失正确的 schemaVersion');
      }

      final transactionList = _asMapList(decoded['transactions']);
      final accountList = _asMapList(decoded['accounts']);
      if (transactionList.isNotEmpty && accountList.isEmpty) {
        return const RestoreResult.failure('备份文件无效：缺少账单所属账户');
      }

      final hasBudgets = decoded['budgets'] is List;
      final budgetList = _asMapList(decoded['budgets']);
      final hasRecurringRules = decoded['recurringRules'] is List;
      final recurringRuleList = _asMapList(decoded['recurringRules']);

      final db = await _db;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.transaction((txn) async {
        await txn.delete('transactions');
        await txn.delete('accounts');

        for (var index = 0; index < accountList.length; index++) {
          final raw = accountList[index];
          final account = Account(
            id: _stringOf(raw['id']),
            name: _stringOf(raw['name'], '账户'),
            type: enumFromDb(_stringOf(raw['type']), AccountType.other),
            initialBalance: _intOf(raw['initialBalance'], 0),
            symbolText: _stringOf(raw['symbolText'], '账'),
            colorHex: _stringOf(raw['colorHex'], '#1677FF'),
            order: _intOf(raw['order'], index),
            isSample: _boolOf(raw['isSample']),
            isArchived: _boolOf(raw['isArchived']),
          );
          await txn.insert(
            'accounts',
            account.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // 旧备份可能没有 categories 字段，此时保留现有分类。
        final categoryList = _asMapList(decoded['categories']);
        if (categoryList.isNotEmpty) {
          await txn.delete('categories');
          for (var index = 0; index < categoryList.length; index++) {
            final raw = categoryList[index];
            final category = Category(
              id: _stringOf(raw['id']),
              name: _stringOf(raw['name']),
              type: enumFromDb(_stringOf(raw['type']), TransactionType.expense),
              symbolText: _stringOf(raw['symbolText'], '他'),
              colorHex: _stringOf(raw['colorHex'], '#8C867A'),
              isPinned: _boolOf(raw['isPinned']),
              isFixedExpense: _boolOf(raw['isFixedExpense']),
              order: _intOf(raw['order'], index),
              isDefault: _boolOf(raw['isDefault']),
              isArchived: _boolOf(raw['isArchived']),
            );
            await txn.insert(
              'categories',
              category.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        for (final raw in transactionList) {
          final transaction = LedgerTransaction(
            id: _stringOf(raw['id'], newId()),
            type: enumFromDb(_stringOf(raw['type']), TransactionType.expense),
            amount: _intOf(raw['amount'], 0),
            accountId: _stringOf(raw['accountId']),
            toAccountId: _stringOrNullOf(raw['toAccountId']),
            categoryId: _stringOrNullOf(raw['categoryId']),
            occurredAt: _intOf(raw['occurredAt'], now),
            note: _stringOrNullOf(raw['note']),
            source: enumFromDb(
              _stringOf(raw['source'], 'MANUAL'),
              TransactionSource.manual,
            ),
            isSample: false,
            dedupKey: _stringOrNullOf(raw['dedupKey']),
            createdAt: _intOf(raw['createdAt'], now),
            updatedAt: now,
            deletedAt: 0,
          );
          await txn.insert(
            'transactions',
            transaction.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        if (hasBudgets) {
          await txn.delete('budgets');
          for (final raw in budgetList) {
            final month = _stringOf(raw['month']);
            if (month.isEmpty) continue;
            final budget = Budget(
              month: month,
              totalBudget: _intOf(raw['totalBudget'], 0),
              categoryBudgetsJson: _stringOrNullOf(raw['categoryBudgetsJson']),
            );
            await txn.insert(
              'budgets',
              budget.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        if (hasRecurringRules) {
          await txn.delete('recurring_rules');
          for (final raw in recurringRuleList) {
            final id = _stringOf(raw['id'], newId());
            final accountId = _stringOf(raw['accountId']);
            if (accountId.isEmpty) continue;
            final rule = RecurringRule(
              id: id,
              name: _stringOf(raw['name'], '周期账单'),
              type: enumFromDb(_stringOf(raw['type']), TransactionType.expense),
              amount: _intOf(raw['amount'], 0),
              accountId: accountId,
              toAccountId: _stringOrNullOf(raw['toAccountId']),
              categoryId: _stringOrNullOf(raw['categoryId']),
              frequency: _stringOf(raw['frequency'], 'MONTHLY'),
              dayOfMonth: _intOf(raw['dayOfMonth'], 1).clamp(1, 28),
              nextDueDate: _intOf(raw['nextDueDate'], now),
              isActive: raw.containsKey('isActive') ? _boolOf(raw['isActive']) : true,
              isSample: false,
            );
            await txn.insert(
              'recurring_rules',
              rule.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      });

      return RestoreResult.success(transactionList.length);
    } on FormatException {
      return const RestoreResult.failure('备份文件无效：无法解析备份内容');
    } catch (error) {
      return RestoreResult.failure('恢复失败：$error');
    }
  }
}

int _intOf(Object? value, int fallback) => value is num ? value.toInt() : fallback;

String _stringOf(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

String? _stringOrNullOf(Object? value) => value is String ? value : null;

bool _boolOf(Object? value) =>
    value == true || (value is num && value.toInt() == 1);

List<Map<String, Object?>> _asMapList(Object? value) {
  if (value is! List) return const <Map<String, Object?>>[];
  return <Map<String, Object?>>[
    for (final item in value)
      if (item is Map)
        <String, Object?>{
          for (final entry in item.entries) entry.key.toString(): entry.value,
        },
  ];
}