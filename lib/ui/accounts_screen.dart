import 'package:flutter/material.dart';

import 'package:stream_ledger/app_state.dart';
import 'package:stream_ledger/core/money.dart';
import 'package:stream_ledger/data/models.dart';

import 'package:stream_ledger/design/stream_shapes.dart';
import 'package:stream_ledger/design/stream_theme.dart';
import 'package:stream_ledger/design/stream_typography.dart';
import 'package:stream_ledger/ui/account_editor_sheet.dart';
import 'package:stream_ledger/widgets/editorial.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final palette = StreamPalette.of(context);
    final year = state.selectedYear;
    final month = state.selectedMonth;

    final grouped = <AccountType, List<Account>>{};
    for (final account in state.accounts) {
      grouped.putIfAbsent(account.type, () => <Account>[]).add(account);
    }
    final monthExpenses = _monthlyExpensesByAccount(
      state.transactions,
      year,
      month,
    );

    return Container(
      color: palette.paperBase,
      child: ListView(
        key: const PageStorageKey('accounts'),
        padding: const EdgeInsets.only(bottom: 114),
        children: [
          EditorialHeader(
            eyebrow: 'PORTFOLIO',
            title: 'Accounts',
            subtitle: '${month.toString().padLeft(2, '0')} / $year',
            actions: [
              TextButton(
                onPressed: () => state.openAccountEditor(),
                style: TextButton.styleFrom(
                  foregroundColor: palette.accentWarmYellow,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const RoundedRectangleBorder(
                    borderRadius: StreamShapes.tag,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('＋ 账户'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: _NetWorthHero(balance: state.balance),
          ),
          for (final type in AccountType.values)
            if (grouped[type] != null)
              ..._buildAccountSection(
                context,
                type: type,
                accounts: grouped[type]!,
                balances: state.balance.accountBalances,
                monthExpenses: monthExpenses,
              ),
          if (state.accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Center(
                child: Text(
                  '暂无账户，点击右上角「＋ 账户」添加',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildAccountSection(
    BuildContext context, {
    required AccountType type,
    required List<Account> accounts,
    required Map<String, int> balances,
    required Map<String, int> monthExpenses,
  }) {
    return [
      EditorialSectionLabel(
        title: accountTypeDisplayName(type),
        trailing: '${accounts.length} 个',
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: _AccountGroupCard(
          accounts: accounts,
          balances: balances,
          monthExpenses: monthExpenses,
        ),
      ),
    ];
  }
}

class _NetWorthHero extends StatelessWidget {
  const _NetWorthHero({required this.balance});

  final BalanceSummary balance;

  @override
  Widget build(BuildContext context) {
    final palette = StreamPalette.of(context);
    final liabilities = balance.totalLiabilities;
    final total = balance.totalAssets + liabilities;
    final assetWeight =
        total <= 0 ? 1.0 : (balance.totalAssets / total).clamp(0.02, 1.0);
    final liabilityWeight =
        liabilities > 0 ? (1.0 - assetWeight).clamp(0.02, 1.0) : 0.0;

    return EditorialDeepCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '净资产',
            style: StreamEditorialType.sectionLabel
                .copyWith(color: palette.onDeepMuted),
          ),
          const SizedBox(height: 3),
          AmountText(
            cents: balance.netAssets,
            integerSize: 34,
            color: palette.onDeep,
            secondaryColor: palette.onDeepMuted,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: (assetWeight * 1000).round(),
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.incomeGreen,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (liabilityWeight > 0) ...[
                const SizedBox(width: 2),
                Expanded(
                  flex: (liabilityWeight * 1000).round(),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.overBudgetRed,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _HeroFootnote(
                text: '正资产 ${MoneyFormat.formatPlain(balance.totalAssets)}',
                color: palette.onDeepMuted,
              ),
              _HeroFootnote(
                text: '负债 ${MoneyFormat.formatPlain(liabilities)}',
                color: palette.onDeepMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroFootnote extends StatelessWidget {
  const _HeroFootnote({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(fontSize: 9.5, color: color));
  }
}

class _AccountGroupCard extends StatelessWidget {
  const _AccountGroupCard({
    required this.accounts,
    required this.balances,
    required this.monthExpenses,
  });

  final List<Account> accounts;
  final Map<String, int> balances;
  final Map<String, int> monthExpenses;

  @override
  Widget build(BuildContext context) {
    final palette = StreamPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: StreamShapes.listCard,
      ),
      child: Column(
        children: [
          for (var i = 0; i < accounts.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(height: 0.5, color: palette.hairline),
              ),
            _AccountRow(
              account: accounts[i],
              balance: balances[accounts[i].id] ?? accounts[i].initialBalance,
              monthExpense: monthExpenses[accounts[i].id] ?? 0,
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.balance,
    required this.monthExpense,
  });

  final Account account;
  final int balance;
  final int monthExpense;

  Future<void> _showActions(BuildContext context) async {
    final state = AppScope.of(context);
    final palette = StreamPalette.of(context);
    final selected = await showModalBottomSheet<_AccountAction>(
      context: context,
      backgroundColor: palette.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: StreamShapes.listCard,
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit_outlined, color: palette.textSecondary),
              title: Text(
                '编辑账户',
                style: TextStyle(color: palette.textPrimary),
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_AccountAction.edit),
            ),
            ListTile(
              leading: Icon(Icons.inventory_2_outlined,
                  color: palette.textSecondary),
              title: Text(
                '归档账户',
                style: TextStyle(color: palette.textPrimary),
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_AccountAction.archive),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;

    if (selected == _AccountAction.edit) {
      state.openAccountEditor(account);
      return;
    }
    final error = await state.archiveAccount(account.id);
    if (error != null) state.showMessage(error);
  }

  @override
  Widget build(BuildContext context) {
    final palette = StreamPalette.of(context);
    final accent = _parseHex(
      account.colorHex,
      palette.textSecondary,
    );
    final symbolColor =
        account.type == AccountType.credit ? palette.overBudgetRed : accent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: symbolColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              account.symbolText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: symbolColor,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _typeLabel(account.type),
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.2,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AmountText(
                cents: balance,
                integerSize: 16,
                showSymbol: false,
                color:
                    balance < 0 ? palette.overBudgetRed : palette.textPrimary,
                secondaryColor: palette.textSecondary,
              ),
              const SizedBox(height: 2),
              Text(
                monthExpense > 0
                    ? '本月 -${MoneyFormat.formatPlain(monthExpense, withSymbol: false)}'
                    : '本月无支出',
                maxLines: 1,
                style: TextStyle(fontSize: 9.5, color: palette.textSecondary),
              ),
            ],
          ),
          IconButton(
            padding: const EdgeInsets.all(6),
            iconSize: 18,
            tooltip: '更多操作',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () => _showActions(context),
            icon: Icon(Icons.more_horiz, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

enum _AccountAction { edit, archive }

Map<String, int> _monthlyExpensesByAccount(
  List<LedgerTransaction> transactions,
  int year,
  int month,
) {
  final expenses = <String, int>{};
  for (final tx in transactions) {
    if (tx.type != TransactionType.expense) continue;
    final occurredAt = DateTime.fromMillisecondsSinceEpoch(tx.occurredAt);
    if (occurredAt.year != year || occurredAt.month != month) continue;
    expenses[tx.accountId] = (expenses[tx.accountId] ?? 0) + tx.amount;
  }
  return expenses;
}

String _typeLabel(AccountType type) {
  switch (type) {
    case AccountType.wechat:
      return 'WECHAT';
    case AccountType.alipay:
      return 'ALIPAY';
    case AccountType.bank:
      return 'BANK';
    case AccountType.credit:
      return 'CREDIT';
    case AccountType.cash:
      return 'CASH';
    case AccountType.other:
      return 'OTHER';
  }
}

Color _parseHex(String hex, Color fallback) {
  final cleaned = hex.replaceFirst('#', '');
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return fallback;
  return Color(cleaned.length <= 6 ? 0xFF000000 | value : value);
}