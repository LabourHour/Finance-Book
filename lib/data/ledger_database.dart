import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// 对应旧 Room `AppDatabase`：单例、手写 DDL、外键开启。
class LedgerDatabase {
  LedgerDatabase._([this._customPath, this._databaseFactory]);

  static final LedgerDatabase instance = LedgerDatabase._();

  /// 仅供测试注入内存数据库或 FFI 工厂。
  factory LedgerDatabase.forTesting({
    String path = inMemoryDatabasePath,
    DatabaseFactory? databaseFactory,
  }) =>
      LedgerDatabase._(path, databaseFactory);

  static const int schemaVersion = 2;
  static const String dbFileName = 'stream_ledger.db';

  final String? _customPath;
  final DatabaseFactory? _databaseFactory;
  Future<Database>? _database;

  Future<Database> get database {
    final existing = _database;
    if (existing != null) return existing;
    final opening = _open();
    _database = opening;
    return opening;
  }

  Future<void> close() async {
    final existing = _database;
    _database = null;
    if (existing != null) {
      final db = await existing;
      await db.close();
    }
  }

  Future<Database> _open() async {
    final customFactory = _databaseFactory;
    final dbPath = _customPath ?? join(await getDatabasesPath(), dbFileName);
    if (customFactory != null) {
      return customFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: schemaVersion,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: _createSchema,
          onUpgrade: _upgradeSchema,
        ),
      );
    }
    return openDatabase(
      dbPath,
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute(
      'CREATE TABLE accounts ('
      'id TEXT PRIMARY KEY, '
      'name TEXT NOT NULL, '
      'type TEXT NOT NULL, '
      'initialBalance INTEGER NOT NULL DEFAULT 0, '
      'symbolText TEXT NOT NULL, '
      'colorHex TEXT NOT NULL, '
      'sort_order INTEGER NOT NULL DEFAULT 0, '
      'isSample INTEGER NOT NULL DEFAULT 0, '
      'isArchived INTEGER NOT NULL DEFAULT 0)',
    );
    await db.execute(
      'CREATE INDEX index_accounts_sort_order ON accounts (sort_order)',
    );
    await db.execute(
      'CREATE INDEX index_accounts_isSample ON accounts (isSample)',
    );

    await db.execute(
      'CREATE TABLE categories ('
      'id TEXT PRIMARY KEY, '
      'name TEXT NOT NULL, '
      'type TEXT NOT NULL, '
      'symbolText TEXT NOT NULL, '
      'colorHex TEXT NOT NULL, '
      'isPinned INTEGER NOT NULL DEFAULT 0, '
      'isFixedExpense INTEGER NOT NULL DEFAULT 0, '
      'sort_order INTEGER NOT NULL DEFAULT 0, '
      'isDefault INTEGER NOT NULL DEFAULT 1, '
      'isSample INTEGER NOT NULL DEFAULT 0, '
      'isArchived INTEGER NOT NULL DEFAULT 0)',
    );
    await db.execute('CREATE INDEX index_categories_type ON categories (type)');
    await db.execute(
      'CREATE INDEX index_categories_sort_order ON categories (sort_order)',
    );

    await db.execute(
      'CREATE TABLE transactions ('
      'id TEXT PRIMARY KEY, '
      'type TEXT NOT NULL, '
      'amount INTEGER NOT NULL, '
      'accountId TEXT NOT NULL, '
      'toAccountId TEXT, '
      'categoryId TEXT, '
      'occurredAt INTEGER NOT NULL, '
      'note TEXT, '
      'source TEXT NOT NULL, '
      'isSample INTEGER NOT NULL DEFAULT 0, '
      'dedupKey TEXT, '
      'createdAt INTEGER NOT NULL, '
      'updatedAt INTEGER NOT NULL, '
      'deletedAt INTEGER NOT NULL DEFAULT 0, '
      'FOREIGN KEY(accountId) REFERENCES accounts(id) ON DELETE RESTRICT)',
    );
    await db.execute(
      'CREATE INDEX index_transactions_occurredAt ON transactions (occurredAt)',
    );
    await db.execute(
      'CREATE INDEX index_transactions_accountId ON transactions (accountId)',
    );
    await db.execute(
      'CREATE INDEX index_transactions_isSample ON transactions (isSample)',
    );
    await db.execute(
      'CREATE INDEX index_transactions_dedupKey ON transactions (dedupKey)',
    );

    await db.execute(
      'CREATE TABLE budgets ('
      'month TEXT PRIMARY KEY, '
      'totalBudget INTEGER NOT NULL, '
      'categoryBudgetsJson TEXT)',
    );

    await db.execute(
      'CREATE TABLE recurring_rules ('
      'id TEXT PRIMARY KEY, '
      'name TEXT NOT NULL, '
      'type TEXT NOT NULL, '
      'amount INTEGER NOT NULL, '
      'accountId TEXT NOT NULL, '
      'toAccountId TEXT, '
      'categoryId TEXT, '
      'frequency TEXT NOT NULL DEFAULT \'MONTHLY\', '
      'dayOfMonth INTEGER NOT NULL, '
      'nextDueDate INTEGER NOT NULL, '
      'isActive INTEGER NOT NULL DEFAULT 1, '
      'isSample INTEGER NOT NULL DEFAULT 0)',
    );

    await db.execute(
      'CREATE TABLE settings ("key" TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
  }

  Future<void> _upgradeSchema(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE transactions '
        'ADD COLUMN deletedAt INTEGER NOT NULL DEFAULT 0',
      );
    }
  }
}