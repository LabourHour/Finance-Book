
import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import 'core/pbkdf2.dart';
import 'data/calculators.dart';
import 'data/export_service.dart';
import 'data/ledger_repository.dart';
import 'data/models.dart';

/// 应用级状态：承担旧 `StreamViewModel` 的界面状态与派生数据计算，
/// 屏幕通过 [AppScope.of] 读取数据并调用这里的方法。
class AppState extends ChangeNotifier {
  AppState([LedgerRepository? repository])
      : repository = repository ?? LedgerRepository() {
    final now = DateTime.now();
    selectedYear = now.year;
    selectedMonth = now.month;
    _recalculateAll();
  }

  final LedgerRepository repository;

  List<Account> accounts = const <Account>[];
  List<Category> categories = const <Category>[];
  List<LedgerTransaction> transactions = const <LedgerTransaction>[];

  late BalanceSummary balance;
  late MonthRhythmData rhythm;
  late AnalyticsData analytics;

  late int selectedYear;
  late int selectedMonth;
  int? selectedDay;
  int currentTab = 0;

  bool analyticsIsExpense = true;
  bool analyticsExcludeFixed = false;

  /// 账单页搜索展开时禁用横滑切页，避免输入与页面滑动互相打断。
  bool timelineSearchActive = false;

  bool quickAddVisible = false;
  bool settingsVisible = false;
  LedgerTransaction? editingTransaction;

  Account? editingAccount;
  bool accountEditorVisible = false;

  bool categoryManagerVisible = false;

  String? undoMessage;
  String? message;
  String lastUsedAccountId = 'acc_wechat';

  bool _initialized = false;

  /// 已删除待撤销的账单，[undoDelete] 会把同一条记录从软删除状态恢复。
  LedgerTransaction? _pendingUndo;

  bool trashVisible = false;
  List<LedgerTransaction> deletedTransactions = const <LedgerTransaction>[];

  Budget? budget;
  bool budgetVisible = false;

  List<RecurringRule> recurringRules = const <RecurringRule>[];
  bool recurringVisible = false;

  bool lockEnabled = false;
  bool unlocked = true;
  ThemeMode themeMode = ThemeMode.system;

  /// settings 中 `app_lock_pin` 的缓存值，[verifyPin] 需要同步判定。
  String? _lockCredential;
  int _autoLockSuppressDepth = 0;

  bool get initialized => _initialized;
  bool get autoLockSuppressed => _autoLockSuppressDepth > 0;

  /// 预算按「年-月」定位，与 [selectedYear]/[selectedMonth] 保持一致。
  String get currentMonthKey =>
      '$selectedYear-${selectedMonth.toString().padLeft(2, '0')}';

  int get monthExpenseCents => rhythm.monthTotalExpense;

  Future<void> initialize() async {
    if (_initialized) {
      await reload();
      await refreshLockState();
      await applyDueRecurringRules();
      return;
    }
    try {
      await repository.ensureInitialData();
      await _purgeLegacySampleData();
      final stored = await repository.getSetting('last_used_account_id');
      if (stored != null && stored.isNotEmpty) {
        lastUsedAccountId = stored;
      }
      final storedTheme = await repository.getSetting(_themeModeKey);
      themeMode = _themeModeFromSetting(storedTheme);
      _initialized = true;
      await reload();
      await refreshLockState();
      await applyDueRecurringRules();
    } catch (error) {
      showMessage('初始化数据失败：$error');
    }
  }

  Future<void> reload() async {
    final loadedAccounts = await repository.loadAccounts();
    final loadedCategories = await repository.loadCategories();
    final loadedTransactions = await repository.loadAllTransactions();

    accounts = loadedAccounts;
    categories = loadedCategories;
    transactions = loadedTransactions;
    budget = await _loadBudgetSafely();
    recurringRules = await _loadRecurringRulesSafely();
    _recalculateAll();
    notifyListeners();
  }

  void setTab(int index) {
    currentTab = index;
    notifyListeners();
  }

  void setTimelineSearchActive(bool active) {
    if (timelineSearchActive == active) return;
    timelineSearchActive = active;
    notifyListeners();
  }

  void prevMonth() {
    var year = selectedYear;
    var month = selectedMonth - 1;
    if (month < 1) {
      month = 12;
      year -= 1;
    }
    _selectMonth(year, month);
  }

  void nextMonth() {
    var year = selectedYear;
    var month = selectedMonth + 1;
    if (month > 12) {
      month = 1;
      year += 1;
    }
    _selectMonth(year, month);
  }

  void selectDay(int? day) {
    selectedDay = selectedDay == day ? null : day;
    _recalculateRhythm();
    notifyListeners();
  }

  void setAnalyticsType(bool isExpense) {
    analyticsIsExpense = isExpense;
    _recalculateAnalytics();
    notifyListeners();
  }

  void toggleExcludeFixedExpense() {
    analyticsExcludeFixed = !analyticsExcludeFixed;
    _recalculateAnalytics();
    notifyListeners();
  }

  void openQuickAdd([LedgerTransaction? editing]) {
    quickAddVisible = true;
    editingTransaction = editing;
    notifyListeners();
  }

  void closeQuickAdd() {
    quickAddVisible = false;
    editingTransaction = null;
    notifyListeners();
  }

  void openSettings() {
    settingsVisible = true;
    notifyListeners();
  }

  void closeSettings() {
    settingsVisible = false;
    notifyListeners();
  }

  void openAccountEditor([Account? editing]) {
    editingAccount = editing;
    accountEditorVisible = true;
    notifyListeners();
  }

  void closeAccountEditor() {
    accountEditorVisible = false;
    editingAccount = null;
    notifyListeners();
  }

  void openCategoryManager() {
    categoryManagerVisible = true;
    notifyListeners();
  }

  void closeCategoryManager() {
    categoryManagerVisible = false;
    notifyListeners();
  }

  Future<String?> createAccount({
    required String name,
    required AccountType type,
    required int initialBalance,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return '请输入账户名称';
    }
    if (accounts.any((account) => account.name == trimmedName)) {
      return '账户名称已存在';
    }

    final account = Account(
      id: newId(),
      name: trimmedName,
      type: type,
      initialBalance: initialBalance,
      symbolText: trimmedName.substring(0, 1),
      colorHex: accountColorHexOf(type),
      order: _nextAccountOrder,
    );
    try {
      await repository.insertAccount(account);
    } catch (error) {
      return '保存失败：$error';
    }
    closeAccountEditor();
    await reload();
    return null;
  }

  Future<String?> updateAccountMeta({
    required String id,
    required String name,
    required AccountType type,
    required int initialBalance,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return '请输入账户名称';
    }
    if (accounts.any(
      (account) => account.id != id && account.name == trimmedName,
    )) {
      return '账户名称已存在';
    }

    final existing = _accountById(id);
    if (existing == null) {
      return '账户不存在';
    }

    try {
      await repository.updateAccount(
        existing.copyWith(
          name: trimmedName,
          type: type,
          initialBalance: initialBalance,
          symbolText: trimmedName.substring(0, 1),
          colorHex: accountColorHexOf(type),
        ),
      );
    } catch (error) {
      return '保存失败：$error';
    }
    closeAccountEditor();
    await reload();
    return null;
  }

  Future<String?> archiveAccount(String id) async {
    try {
      final transactionCount = await repository.countTransactionsOfAccount(id);
      if (transactionCount > 0) {
        return '该账户仍有 $transactionCount 笔账单，无法归档';
      }
      final trashedCount =
          await repository.countTrashedTransactionsOfAccount(id);
      if (trashedCount > 0) {
        return '该账户在回收站中仍有 $trashedCount 笔账单，请先彻底删除后再归档';
      }
      await repository.archiveAccount(id);
    } catch (error) {
      return '归档失败：$error';
    }
    await reload();
    return null;
  }

  /// 新建分类的配色池，按现有分类数轮转取色。
  static const List<String> categoryColorHexes = <String>[
    '#D97757',
    '#3F8A62',
    '#5B88A5',
    '#8C6BB1',
    '#C0605A',
    '#B08A3E',
  ];

  Future<String?> saveCategory({
    Category? editing,
    required String name,
    required TransactionType type,
    required bool isPinned,
    required bool isFixedExpense,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return '请输入分类名称';
    }
    final duplicated = categories.any(
      (category) =>
          category.id != editing?.id &&
          category.type == type &&
          category.name == trimmedName,
    );
    if (duplicated) {
      return '同类型下已存在同名分类';
    }

    try {
      if (editing != null) {
        await repository.updateCategory(
          editing.copyWith(
            name: trimmedName,
            type: type,
            isPinned: isPinned,
            isFixedExpense: isFixedExpense,
          ),
        );
      } else {
        await repository.insertCategory(
          Category(
            id: newId(),
            name: trimmedName,
            type: type,
            symbolText: trimmedName.substring(0, 1),
            colorHex: categoryColorHexes[
                categories.length % categoryColorHexes.length],
            isPinned: isPinned,
            isFixedExpense: isFixedExpense,
            order: _nextCategoryOrder,
            isDefault: false,
          ),
        );
      }
    } catch (error) {
      return '保存失败：$error';
    }
    await reload();
    return null;
  }

  Future<String?> archiveCategory(String categoryId) async {
    final category = _categoryById(categoryId);
    if (category == null) {
      return '分类不存在';
    }
    try {
      final transactionCount =
          await repository.countTransactionsOfCategory(categoryId);
      if (transactionCount > 0) {
        return '该分类仍有 $transactionCount 笔账单，无法删除';
      }
      final trashedCount =
          await repository.countTrashedTransactionsOfCategory(categoryId);
      if (trashedCount > 0) {
        return '该分类在回收站中仍有 $trashedCount 笔账单，请先彻底删除后再删除';
      }
      if (category.isDefault) {
        return '默认分类不可删除';
      }
      await repository.archiveCategory(categoryId);
    } catch (error) {
      return '删除失败：$error';
    }
    await reload();
    return null;
  }

  /// 回到当前月，供账单页月份标题点击时使用。
  void jumpToCurrentMonth() {
    final now = DateTime.now();
    _selectMonth(now.year, now.month);
  }

  void showMessage(String text) {
    message = text;
    notifyListeners();
  }

  void consumeMessage() {
    if (message == null) return;
    message = null;
    notifyListeners();
  }

  void dismissUndo() {
    _pendingUndo = null;
    if (undoMessage == null) return;
    undoMessage = null;
    notifyListeners();
  }

  Future<String?> saveTransaction({
    required TransactionType type,
    required int amountCents,
    required String accountId,
    String? toAccountId,
    String? categoryId,
    required int occurredAt,
    String? note,
  }) async {
    final editing = editingTransaction;

    if (accounts.isEmpty) {
      return '账户数据加载中，请稍后重试';
    }
    if (amountCents <= 0) {
      return '金额需大于 0';
    }
    if (accountId.trim().isEmpty) {
      return '请先选择账户';
    }
    final accountKnown =
        accounts.any((account) => account.id == accountId) ||
            editing?.accountId == accountId;
    if (!accountKnown) {
      return '所选账户不可用，请重新选择';
    }
    if (type == TransactionType.transfer) {
      final targetKnown = toAccountId != null &&
          toAccountId != accountId &&
          (accounts.any((account) => account.id == toAccountId) ||
              editing?.toAccountId == toAccountId);
      if (!targetKnown) {
        return '请选择不同的转入账户';
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      if (editing != null) {
        await repository.updateTransaction(
          editing.copyWith(
            type: type,
            amount: amountCents,
            accountId: accountId,
            toAccountId: toAccountId,
            categoryId: categoryId,
            occurredAt: occurredAt,
            note: note,
            updatedAt: now,
          ),
        );
      } else {
        await repository.insertTransaction(
          LedgerTransaction(
            id: newId(),
            type: type,
            amount: amountCents,
            accountId: accountId,
            toAccountId: toAccountId,
            categoryId: categoryId,
            occurredAt: occurredAt,
            note: note,
            createdAt: now,
            updatedAt: now,
          ),
        );
        lastUsedAccountId = accountId;
        await _rememberAccount(accountId);
      }
      closeQuickAdd();
      await reload();
      return null;
    } catch (error) {
      return '保存失败：$error';
    }
  }

  Future<void> deleteTransaction(LedgerTransaction tx) async {
    try {
      await repository.deleteTransaction(tx);
      _pendingUndo = tx;
      undoMessage = '已删除账单';
      await reload();
    } catch (error) {
      showMessage('删除失败：$error');
    }
  }

  Future<void> undoDelete() async {
    final pending = _pendingUndo;
    if (pending == null) return;
    try {
      await repository.restoreDeletedTransaction(pending.id);
      _pendingUndo = null;
      undoMessage = null;
      await reload();
    } catch (error) {
      showMessage('撤销失败：$error');
    }
  }

  Future<ClearSampleResult> clearSampleData() async {
    final result = await repository.clearSampleData();
    await reload();
    return result;
  }

  void openTrash() {
    trashVisible = true;
    notifyListeners();
    unawaited(reloadTrash());
  }

  void closeTrash() {
    trashVisible = false;
    notifyListeners();
  }

  Future<void> reloadTrash() async {
    try {
      deletedTransactions = await repository.loadDeletedTransactions();
    } catch (error) {
      showMessage('加载回收站失败：$error');
    }
    notifyListeners();
  }

  Future<String?> restoreTrashed(LedgerTransaction tx) async {
    try {
      await repository.restoreDeletedTransaction(tx.id);
    } catch (error) {
      return '恢复失败：$error';
    }
    await reload();
    await reloadTrash();
    return null;
  }

  Future<String?> purgeTrashed(LedgerTransaction tx) async {
    try {
      await repository.purgeTransaction(tx.id);
    } catch (error) {
      return '彻底删除失败：$error';
    }
    await reloadTrash();
    return null;
  }

  void openBudget() {
    budgetVisible = true;
    notifyListeners();
  }

  void closeBudget() {
    budgetVisible = false;
    notifyListeners();
  }

  Future<String?> saveMonthlyBudget(int totalBudgetCents) async {
    if (totalBudgetCents < 0) {
      return '预算不能为负数';
    }
    try {
      await repository.saveBudget(
        Budget(month: currentMonthKey, totalBudget: totalBudgetCents),
      );
    } catch (error) {
      return '保存失败：$error';
    }
    await reload();
    closeBudget();
    return null;
  }

  void openRecurring() {
    recurringVisible = true;
    notifyListeners();
  }

  void closeRecurring() {
    recurringVisible = false;
    notifyListeners();
  }

  Future<String?> saveRecurringRule({
    RecurringRule? editing,
    required String name,
    required TransactionType type,
    required int amountCents,
    required String accountId,
    String? categoryId,
    String? toAccountId,
    required int dayOfMonth,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return '请输入规则名称';
    }
    if (amountCents <= 0) {
      return '金额需大于 0';
    }
    if (!accounts.any((account) => account.id == accountId)) {
      return '请选择有效账户';
    }
    if (dayOfMonth < 1 || dayOfMonth > 28) {
      return '请选择 1–28 日';
    }

    try {
      await repository.saveRecurringRule(
        RecurringRule(
          id: editing?.id ?? newId(),
          name: trimmedName,
          type: type,
          amount: amountCents,
          accountId: accountId,
          toAccountId: toAccountId,
          categoryId: categoryId,
          frequency: 'MONTHLY',
          dayOfMonth: dayOfMonth,
          nextDueDate: _nextRecurringDueDate(dayOfMonth),
          isActive: true,
          isSample: editing?.isSample ?? false,
        ),
      );
    } catch (error) {
      return '保存失败：$error';
    }
    await reload();
    return null;
  }

  Future<String?> deleteRecurringRule(String id) async {
    try {
      await repository.deleteRecurringRule(id);
    } catch (error) {
      return '删除失败：$error';
    }
    await reload();
    return null;
  }

  /// 为到期规则补记当月流水，`dedupKey` 保证同一条规则每月只生成一次。
  Future<int> applyDueRecurringRules() async {
    final rules = await _loadRecurringRulesSafely();
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    var generated = 0;

    for (final rule in rules) {
      final occurredAt = DateTime(
        now.year,
        now.month,
        rule.dayOfMonth.clamp(1, daysInMonth),
        9,
      ).millisecondsSinceEpoch;
      if (occurredAt > now.millisecondsSinceEpoch) continue;

      final dedupKey = 'recurring:${rule.id}:$monthKey';
      try {
        if (await repository.hasTransactionWithDedupKey(dedupKey)) continue;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        await repository.insertTransaction(
          LedgerTransaction(
            id: newId(),
            type: rule.type,
            amount: rule.amount,
            accountId: rule.accountId,
            toAccountId: rule.toAccountId,
            categoryId: rule.categoryId,
            occurredAt: occurredAt,
            note: rule.name,
            source: TransactionSource.manual,
            dedupKey: dedupKey,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
        await repository.updateRecurringRuleNextDueDate(
          rule.id,
          _nextRecurringDueDate(rule.dayOfMonth),
        );
        generated++;
      } catch (_) {
        // 单条规则失败（如账户已归档触发外键）不阻断其余规则。
      }
    }

    if (generated > 0) {
      await reload();
    }
    return generated;
  }

  Future<String> exportCsv() async => ExportService.toCsv(
        transactions.where((tx) => !tx.isSample).toList(),
        accounts,
        categories,
      );

  Future<String> exportEncryptedBackup(String password) async =>
      ExportService.encryptJson(await repository.exportBackupJson(), password);

  Future<RestoreResult> restoreBackupWithPassword(
    String content,
    String password,
  ) async {
    if (!_isEncryptedBackup(content)) {
      return restoreBackup(content);
    }
    final plainJson = ExportService.tryDecryptJson(content, password);
    if (plainJson == null) {
      return const RestoreResult.failure('口令错误或文件已损坏');
    }
    return restoreBackup(plainJson);
  }

  Future<void> refreshLockState() async {
    try {
      final stored = await repository.getSetting(_appLockPinKey);
      _lockCredential = (stored == null || stored.isEmpty) ? null : stored;
    } catch (_) {
      _lockCredential = null;
    }
    lockEnabled = _lockCredential != null;
    unlocked = !lockEnabled;
    notifyListeners();
  }

  Future<String?> enableLock(String pin) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      return '请输入 6 位数字密码';
    }
    final salt = secureRandomBytes(16);
    final saltHex = bytesToHex(salt);
    final hash = pbkdf2HmacSha256(
      passwordBytes: utf8.encode(pin),
      salt: salt,
      iterations: _pinKdfIterations,
      keyLength: 32,
    );
    final credential = 'v2:$_pinKdfIterations:$saltHex:${bytesToHex(hash)}';
    try {
      await repository.setSetting(_appLockPinKey, credential);
    } catch (error) {
      return '保存失败：$error';
    }
    _lockCredential = credential;
    lockEnabled = true;
    unlocked = true;
    notifyListeners();
    return null;
  }

  Future<String?> disableLock(String currentPin) async {
    if (!verifyPin(currentPin)) {
      return '密码错误';
    }
    try {
      await repository.deleteSetting(_appLockPinKey);
    } catch (error) {
      return '关闭失败：$error';
    }
    _lockCredential = null;
    lockEnabled = false;
    unlocked = true;
    notifyListeners();
    return null;
  }

  bool verifyPin(String pin) {
    final credential = _lockCredential;
    if (credential == null) return true;
    if (credential.startsWith('v2:')) {
      final parts = credential.split(':');
      if (parts.length != 4) return false;
      final iterations = int.tryParse(parts[1]);
      final salt = _hexToBytes(parts[2]);
      final expected = _hexToBytes(parts[3]);
      if (iterations == null ||
          iterations <= 0 ||
          salt == null ||
          expected == null) {
        return false;
      }
      final actual = pbkdf2HmacSha256(
        passwordBytes: utf8.encode(pin),
        salt: salt,
        iterations: iterations,
        keyLength: expected.length,
      );
      return constantTimeBytesEqual(actual, expected);
    }

    final separator = credential.indexOf(':');
    if (separator <= 0) return false;
    final salt = credential.substring(0, separator);
    final actualHex = _legacyPinHashHex(salt, pin);
    final expectedHex = credential.substring(separator + 1);
    return constantTimeBytesEqual(
      utf8.encode(actualHex),
      utf8.encode(expectedHex),
    );
  }

  void unlock() {
    unlocked = true;
    notifyListeners();
  }

  void lockNow() {
    if (!lockEnabled) return;
    unlocked = false;
    notifyListeners();
  }

  /// 调用系统分享或文件选择器期间临时暂停切后台自动上锁，避免返回应用时被锁屏打断。
  Future<T> runWithoutAutoLock<T>(Future<T> Function() action) async {
    _autoLockSuppressDepth++;
    try {
      return await action();
    } finally {
      if (_autoLockSuppressDepth > 0) {
        _autoLockSuppressDepth--;
      }
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (themeMode == mode) return;
    themeMode = mode;
    notifyListeners();
    try {
      await repository.setSetting(_themeModeKey, _themeModeToSetting(mode));
    } catch (_) {}
  }

  Future<String> exportBackup() => repository.exportBackupJson();

  Future<RestoreResult> restoreBackup(String jsonString) async {
    final result = await repository.restoreBackupJson(jsonString);
    if (result.ok) {
      await reload();
    }
    return result;
  }

  void _selectMonth(int year, int month) {
    selectedYear = year;
    selectedMonth = month;
    selectedDay = null;
    budget = null;
    _recalculateRhythm();
    _recalculateAnalytics();
    notifyListeners();
    unawaited(_reloadBudgetForCurrentMonth());
  }

  /// 月份切换后 [budget] 需跟随新月份；回写到已切换走的月份时丢弃结果。
  Future<void> _reloadBudgetForCurrentMonth() async {
    final monthKey = currentMonthKey;
    final loaded = await _loadBudgetSafely();
    if (monthKey != currentMonthKey) return;
    budget = loaded;
    notifyListeners();
  }

  Future<Budget?> _loadBudgetSafely() async {
    try {
      return await repository.loadBudget(currentMonthKey);
    } catch (_) {
      // 旧 schema 升级到 v2 时 budgets 表可能缺失，预算功能降级为「未设置」。
      return null;
    }
  }

  Future<List<RecurringRule>> _loadRecurringRulesSafely() async {
    try {
      return await repository.loadRecurringRules();
    } catch (_) {
      return const <RecurringRule>[];
    }
  }

  /// 下一次应生成时间：本月该日 09:00 未过取本月，否则取下月同日。
  static int _nextRecurringDueDate(int dayOfMonth) {
    final now = DateTime.now();
    final thisMonthDays = DateTime(now.year, now.month + 1, 0).day;
    final day = dayOfMonth.clamp(1, thisMonthDays);
    var due = DateTime(now.year, now.month, day, 9);
    if (due.millisecondsSinceEpoch <= now.millisecondsSinceEpoch) {
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      final nextMonthDays = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
      due = DateTime(
        nextMonth.year,
        nextMonth.month,
        dayOfMonth.clamp(1, nextMonthDays),
        9,
      );
    }
    return due.millisecondsSinceEpoch;
  }

  static bool _isEncryptedBackup(String content) {
    try {
      final decoded = jsonDecode(content);
      return decoded is Map && decoded['encrypted'] == true;
    } catch (_) {
      return false;
    }
  }

  static const String _appLockPinKey = 'app_lock_pin';
  static const String _themeModeKey = 'theme_mode';
  static const int _pinKdfIterations = 50000;

  static ThemeMode _themeModeFromSetting(String? value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _themeModeToSetting(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'system',
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
      };

  static List<int>? _hexToBytes(String hex) {
    if (hex.isEmpty || hex.length.isOdd) return null;
    final result = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      final byte = int.tryParse(hex.substring(i, i + 2), radix: 16);
      if (byte == null) return null;
      result.add(byte);
    }
    return result;
  }

  static String _legacyPinHashHex(String saltHex, String pin) =>
      sha256.convert(utf8.encode('$saltHex$pin')).toString();

  /// 新账户颜色由类型决定，保证同类账户在资产页视觉一致。
  static String accountColorHexOf(AccountType type) => switch (type) {
        AccountType.wechat => '#07C160',
        AccountType.alipay => '#1677FF',
        AccountType.bank => '#5B88A5',
        AccountType.credit => '#C0605A',
        AccountType.cash => '#3F8A62',
        AccountType.other => '#8C867A',
      };

  Account? _accountById(String id) {
    for (final account in accounts) {
      if (account.id == id) {
        return account;
      }
    }
    return null;
  }

  int get _nextAccountOrder {
    var maxOrder = 0;
    for (final account in accounts) {
      if (account.order > maxOrder) {
        maxOrder = account.order;
      }
    }
    return maxOrder + 1;
  }

  Category? _categoryById(String id) {
    for (final category in categories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }

  int get _nextCategoryOrder {
    var maxOrder = 0;
    for (final category in categories) {
      if (category.order > maxOrder) {
        maxOrder = category.order;
      }
    }
    return maxOrder + 1;
  }

  /// 幂等清理历史版本遗留的示例流水/账户，失败不阻断启动。
  Future<void> _purgeLegacySampleData() async {
    try {
      await repository.clearSampleData();
    } catch (_) {}
  }

  /// 记住上次账户属于偏好写入，失败不应让已经落库的账单报错。
  Future<void> _rememberAccount(String accountId) async {
    try {
      await repository.setSetting('last_used_account_id', accountId);
    } catch (_) {}
  }

  void _recalculateAll() {
    balance = LedgerCalculators.computeBalances(accounts, transactions);
    _recalculateRhythm();
    _recalculateAnalytics();
  }

  void _recalculateRhythm() {
    rhythm = LedgerCalculators.computeMonthRhythm(
      transactions,
      year: selectedYear,
      month: selectedMonth,
      selectedDay: selectedDay,
    );
  }

  void _recalculateAnalytics() {
    analytics = LedgerCalculators.computeAnalytics(
      transactions,
      categories,
      year: selectedYear,
      month: selectedMonth,
      isExpense: analyticsIsExpense,
      excludeFixedExpense: analyticsExcludeFixed,
    );
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope.of() 必须在 AppScope 子树中调用');
    if (scope?.notifier == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('AppScope.of() 未找到 AppState'),
        ErrorDescription('请确认当前 widget 位于 StreamApp 提供的 AppScope 之下。'),
      ]);
    }
    return scope!.notifier!;
  }
}