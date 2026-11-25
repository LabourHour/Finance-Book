import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stream_ledger/app_state.dart';
import 'package:stream_ledger/data/ledger_database.dart';
import 'package:stream_ledger/data/ledger_repository.dart';
import 'package:stream_ledger/data/models.dart';

Future<(LedgerDatabase, LedgerRepository)> _openInMemoryRepo() async {
  sqfliteFfiInit();
  final db = LedgerDatabase.forTesting(
    path: inMemoryDatabasePath,
    databaseFactory: databaseFactoryFfi,
  );
  final repo = LedgerRepository(db);
  await repo.ensureInitialData();
  return (db, repo);
}

void main() {
  group('真实 SQLite 仓库导出与恢复', () {
    test('导出排除示例与回收站流水，保留预算、周期规则、dedupKey 与分类归档状态', () async {
      final (db, repo) = await _openInMemoryRepo();
      addTearDown(db.close);

      await repo.insertAccount(
        const Account(
          id: 'acc_bank',
          name: '储蓄卡',
          type: AccountType.bank,
          initialBalance: 500000,
          symbolText: '卡',
          colorHex: '#5B88A5',
          order: 2,
        ),
      );
      await repo.insertCategory(
        const Category(
          id: 'cat_archived',
          name: '旧分类',
          type: TransactionType.expense,
          symbolText: '旧',
          colorHex: '#8C867A',
          order: 99,
          isDefault: false,
          isArchived: true,
        ),
      );

      final now = DateTime(2026, 11, 15, 10).millisecondsSinceEpoch;
      await repo.insertTransaction(
        LedgerTransaction(
          id: 'tx_real',
          type: TransactionType.expense,
          amount: 8800,
          accountId: 'acc_bank',
          categoryId: 'cat_dining',
          occurredAt: now,
          note: '真实晚餐',
          dedupKey: 'recurring:rule_1:2026-11',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repo.insertTransaction(
        LedgerTransaction(
          id: 'tx_sample',
          type: TransactionType.expense,
          amount: 2000,
          accountId: 'acc_bank',
          categoryId: 'cat_dining',
          occurredAt: now,
          isSample: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repo.insertTransaction(
        LedgerTransaction(
          id: 'tx_trashed',
          type: TransactionType.expense,
          amount: 1500,
          accountId: 'acc_bank',
          categoryId: 'cat_dining',
          occurredAt: now,
          createdAt: now,
          updatedAt: now,
          deletedAt: now,
        ),
      );

      await repo.saveBudget(
        const Budget(month: '2026-11', totalBudget: 300000),
      );
      await repo.saveRecurringRule(
        RecurringRule(
          id: 'rule_1',
          name: '房租',
          type: TransactionType.expense,
          amount: 450000,
          accountId: 'acc_bank',
          categoryId: 'cat_rent',
          dayOfMonth: 5,
          nextDueDate: now,
        ),
      );

      final jsonString = await repo.exportBackupJson();
      final decoded = jsonDecode(jsonString) as Map<String, Object?>;

      expect(decoded['schemaVersion'], LedgerDatabase.schemaVersion);

      final txs = decoded['transactions'] as List;
      expect(txs.length, 1);
      final exportedTx = txs.single as Map<String, Object?>;
      expect(exportedTx['id'], 'tx_real');
      expect(exportedTx['dedupKey'], 'recurring:rule_1:2026-11');

      final budgets = decoded['budgets'] as List;
      expect(budgets.length, 1);
      expect((budgets.single as Map)['totalBudget'], 300000);

      final rules = decoded['recurringRules'] as List;
      expect(rules.length, 1);
      expect((rules.single as Map)['name'], '房租');

      // 恢复到全新数据库，验证全量还原
      final (db2, repo2) = await _openInMemoryRepo();
      addTearDown(db2.close);

      final result = await repo2.restoreBackupJson(jsonString);
      expect(result.ok, isTrue);
      expect(result.count, 1);

      final restoredTxs = await repo2.loadAllTransactions();
      expect(restoredTxs.length, 1);
      expect(restoredTxs.single.dedupKey, 'recurring:rule_1:2026-11');

      final restoredBudget = await repo2.loadBudget('2026-11');
      expect(restoredBudget?.totalBudget, 300000);

      final restoredRules = await repo2.loadRecurringRules();
      expect(restoredRules.length, 1);
      expect(restoredRules.single.id, 'rule_1');

      // 已归档分类保持归档，不会混入可用分类列表
      final activeCategories = await repo2.loadCategories();
      expect(activeCategories.any((c) => c.id == 'cat_archived'), isFalse);
    });

    test('恢复校验：缺失 schemaVersion 或缺少账户时拒绝恢复', () async {
      final (db, repo) = await _openInMemoryRepo();
      addTearDown(db.close);

      final missingVersion = await repo.restoreBackupJson(
        jsonEncode(<String, Object?>{'transactions': <Object>[]}),
      );
      expect(missingVersion.ok, isFalse);
      expect(missingVersion.error, '备份文件无效：缺失正确的 schemaVersion');

      final missingAccounts = await repo.restoreBackupJson(
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'transactions': <Map<String, Object?>>[
            <String, Object?>{
              'id': 't1',
              'type': 'EXPENSE',
              'amount': 100,
              'accountId': 'acc_missing',
            },
          ],
          'accounts': <Object>[],
        }),
      );
      expect(missingAccounts.ok, isFalse);
      expect(missingAccounts.error, '备份文件无效：缺少账单所属账户');
    });

    test('兼容旧版 v1 备份（不含 budgets / recurringRules / categories）', () async {
      final (db, repo) = await _openInMemoryRepo();
      addTearDown(db.close);

      final legacyJson = jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'exportedAt': 1763000000000,
        'accounts': <Map<String, Object?>>[
          <String, Object?>{
            'id': 'acc_cash',
            'name': '现金',
            'type': 'CASH',
            'initialBalance': 1000,
          },
        ],
        'transactions': <Map<String, Object?>>[
          <String, Object?>{
            'id': 'tx_legacy',
            'type': 'EXPENSE',
            'amount': 500,
            'accountId': 'acc_cash',
            'categoryId': 'cat_dining',
            'occurredAt': 1763000000000,
          },
        ],
      });

      final result = await repo.restoreBackupJson(legacyJson);
      expect(result.ok, isTrue);
      expect(result.count, 1);
      expect((await repo.loadCategories()).isNotEmpty, isTrue);
      expect((await repo.loadAllTransactions()).single.id, 'tx_legacy');
    });
  });

  group('归档与回收站冲突 & AppState 持久化', () {
    test('账户或分类在回收站中仍有账单时禁止归档；恢复账单时自动解除归档', () async {
      final (db, repo) = await _openInMemoryRepo();
      addTearDown(db.close);
      final state = AppState(repo);
      addTearDown(state.dispose);
      await state.initialize();

      await state.createAccount(
        name: '副卡',
        type: AccountType.bank,
        initialBalance: 0,
      );
      final bank = state.accounts.firstWhere((a) => a.name == '副卡');
      await state.saveCategory(
        name: '测试分类',
        type: TransactionType.expense,
        isPinned: false,
        isFixedExpense: false,
      );
      final customCat = state.categories.firstWhere((c) => c.name == '测试分类');

      final saveErr = await state.saveTransaction(
        type: TransactionType.expense,
        amountCents: 2500,
        accountId: bank.id,
        categoryId: customCat.id,
        occurredAt: DateTime.now().millisecondsSinceEpoch,
      );
      expect(saveErr, isNull);
      final tx = state.transactions.single;

      // 软删除进入回收站
      await state.deleteTransaction(tx);
      expect(state.transactions, isEmpty);

      final accErr = await state.archiveAccount(bank.id);
      expect(accErr, contains('回收站'));
      final catErr = await state.archiveCategory(customCat.id);
      expect(catErr, contains('回收站'));

      // 极端历史数据保护：即使数据库层被手动置为归档，恢复账单也会自动取消归档
      await repo.archiveAccount(bank.id);
      await repo.archiveCategory(customCat.id);
      await state.restoreTrashed(tx);
      expect(state.accounts.any((a) => a.id == bank.id), isTrue);
      expect(state.categories.any((c) => c.id == customCat.id), isTrue);
    });

    test('PIN 应用锁 v2 PBKDF2 校验、兼容旧版哈希与主题持久化', () async {
      final (db, repo) = await _openInMemoryRepo();
      addTearDown(db.close);
      final state = AppState(repo);
      addTearDown(state.dispose);
      await state.initialize();

      expect(await state.enableLock('135790'), isNull);
      expect(state.lockEnabled, isTrue);
      expect(state.verifyPin('135790'), isTrue);
      expect(state.verifyPin('000000'), isFalse);
      final storedPin = await repo.getSetting('app_lock_pin');
      expect(storedPin, startsWith('v2:'));

      // 验证旧版单轮 SHA-256 凭证仍可正常解锁
      const legacySalt = '0123456789abcdef';
      final legacyHash = sha256.convert(utf8.encode('${legacySalt}246810')).toString();
      await repo.setSetting('app_lock_pin', '$legacySalt:$legacyHash');
      await state.refreshLockState();
      expect(state.unlocked, isFalse);
      expect(state.verifyPin('246810'), isTrue);
      expect(state.verifyPin('111111'), isFalse);

      // 主题切换持久化
      await state.setThemeMode(ThemeMode.dark);
      expect(state.themeMode, ThemeMode.dark);

      final state2 = AppState(repo);
      addTearDown(state2.dispose);
      await state2.initialize();
      expect(state2.themeMode, ThemeMode.dark);
    });
  });
}
