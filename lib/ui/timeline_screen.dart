import 'package:flutter/material.dart';

import 'package:stream_ledger/app_state.dart';
import 'package:stream_ledger/core/money.dart';
import 'package:stream_ledger/data/models.dart';
import 'package:stream_ledger/design/stream_icons.dart';
import 'package:stream_ledger/design/stream_shapes.dart';
import 'package:stream_ledger/design/stream_theme.dart';
import 'package:stream_ledger/design/stream_typography.dart';

import 'package:stream_ledger/widgets/editorial.dart';

const List<String> _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> _weekdayLabels = <String>[
  '周一',
  '周二',
  '周三',
  '周四',
  '周五',
  '周六',
  '周日',
];

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _searchVisible = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    final state = AppScope.of(context);
    final nextVisible = !_searchVisible;
    setState(() {
      _searchVisible = nextVisible;
      if (!nextVisible) _query = '';
    });
    if (!nextVisible) _searchController.clear();
    state.setTimelineSearchActive(nextVisible);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _returnToCurrentMonth(AppState state) {
    if (_searchVisible) {
      setState(() {
        _searchVisible = false;
        _query = '';
      });
      _searchController.clear();
      state.setTimelineSearchActive(false);
    }
    state.jumpToCurrentMonth();
  }


  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final palette = StreamPalette.of(context);
    final searchQuery = _query.trim();
    final isSearching = searchQuery.isNotEmpty;

    final categoryMap = <String, Category>{
      for (final category in state.categories) category.id: category,
    };
    final accountMap = <String, Account>{
      for (final account in state.accounts) account.id: account,
    };

    final groups = isSearching
        ? _buildDayGroups(
            _matchTransactions(
              state.transactions,
              searchQuery,
              categoryMap,
              accountMap,
            ),
          )
        : _buildDayGroups(
            state.transactions,
            year: state.selectedYear,
            month: state.selectedMonth,
            selectedDay: state.selectedDay,
          );
    final entries = _buildEntries(groups);
    final searchCount = groups.fold<int>(
      0,
      (total, group) => total + group.transactions.length,
    );

    return ColoredBox(
      color: palette.paperBase,
      child: CustomScrollView(
        key: const PageStorageKey('timeline'),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: _buildHeader(
              context,
              state,
              palette,
              isSearching: isSearching,
              searchCount: searchCount,
            ),
          ),
          if (!isSearching)
            SliverToBoxAdapter(
              child: _buildMonthSummary(context, state, palette),
            ),
          if (!isSearching && state.selectedDay != null)
            SliverToBoxAdapter(
              child: _FilterBanner(
                month: state.selectedMonth,
                day: state.selectedDay!,
                onClear: () => state.selectDay(null),
              ),
            ),
          if (entries.isEmpty)
            SliverToBoxAdapter(
              child: _TimelineEmptyState(
                message: isSearching ? '没有匹配的账单' : '本月暂无记录',
                showAddAction: !isSearching,
                onAdd: state.openQuickAdd,
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final entry = entries[index];
                if (entry.isGap) return const SizedBox(height: 10);
                final group = entry.group;
                if (group != null) {
                  return _DayGroupHeader(
                    group: group,
                    showMonth: isSearching,
                    isFiltered:
                        !isSearching && state.selectedDay == group.dayOfMonth,
                    onTap: isSearching
                        ? null
                        : () => state.selectDay(
                            state.selectedDay == group.dayOfMonth
                                ? null
                                : group.dayOfMonth,
                          ),
                  );
                }
                final transaction = entry.transaction!;
                return Column(
                  children: <Widget>[
                    _TimelineRow(
                      transaction: transaction,
                      category: categoryMap[transaction.categoryId],
                      account: accountMap[transaction.accountId],
                      toAccount: accountMap[transaction.toAccountId],
                      onEdit: () => state.openQuickAdd(transaction),
                      onDelete: () => state.deleteTransaction(transaction),
                    ),
                    if (entry.showDivider) const EditorialHairline(),
                  ],
                );
              }, childCount: entries.length),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 114)),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppState state,
    StreamPalette palette, {
    required bool isSearching,
    required int searchCount,
  }) {
    final month = state.selectedMonth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onTap: () => _returnToCurrentMonth(state),

          child: EditorialHeader(
            eyebrow: 'MONTHLY LEDGER',
            title: _monthNames[(month - 1).clamp(0, 11)],
            subtitle: '${_twoDigits(month)} / ${state.selectedYear}',
            actions: <Widget>[
              _HeaderAction(
                icon: Icons.search_rounded,
                tooltip: _searchVisible ? '关闭搜索' : '搜索',
                onPressed: _toggleSearch,
              ),
              _HeaderAction(
                icon: Icons.chevron_left_rounded,
                tooltip: '上月',
                onPressed: state.prevMonth,
              ),
              _HeaderAction(
                icon: Icons.chevron_right_rounded,
                tooltip: '下月',
                onPressed: state.nextMonth,
              ),
              _HeaderAction(
                icon: StreamIcons.settings,
                tooltip: '设置',
                onPressed: state.openSettings,
              ),
            ],
          ),
        ),
        if (_searchVisible) _buildSearchField(context, palette),
        if (isSearching)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 2),
            child: Text(
              '搜索 $searchCount 条',
              style: StreamEditorialType.sectionLabel.copyWith(
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w400,
                color: palette.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchField(BuildContext context, StreamPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: (value) => setState(() => _query = value),
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: palette.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          hintText: '搜索备注、分类、账户或金额',
          hintStyle: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: palette.textSecondary),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: palette.textSecondary,
          ),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(
                    StreamIcons.close,
                    size: 18,
                    color: palette.textSecondary,
                  ),
                  tooltip: '清空搜索',
                  onPressed: _clearSearch,
                ),
          filled: true,
          fillColor: palette.inputBackground,
          border: OutlineInputBorder(
            borderRadius: StreamShapes.smallCard,
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildMonthSummary(
    BuildContext context,
    AppState state,
    StreamPalette palette,
  ) {
    final selectedDay = state.selectedDay;
    final dailyAverage = _dailyAverage(
      year: state.selectedYear,
      month: state.selectedMonth,
      totalExpense: state.rhythm.monthTotalExpense,
    );
    final heroAmount = selectedDay != null
        ? (state.rhythm.selectedDayExpense ?? state.rhythm.monthTotalExpense)
        : state.rhythm.monthTotalExpense;
    final heroKicker = selectedDay != null
        ? '${state.selectedMonth}月$selectedDay日 支出'
        : '本月支出';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: EditorialDeepCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  heroKicker,
                  style: StreamEditorialType.sectionLabel.copyWith(
                    fontSize: 9.5,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w500,
                    color: palette.onDeepMuted,
                  ),
                ),
                const SizedBox(height: 10),
                AmountText(
                  cents: heroAmount,
                  integerSize: 50,
                  showSymbol: false,
                  color: palette.onDeep,
                  secondaryColor: palette.onDeepMuted,
                ),
                const SizedBox(height: 14),
                Container(height: 0.5, color: palette.onDeep.withAlpha(36)),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _DeepMetric(
                        label: '收入',
                        value:
                            '+${MoneyFormat.formatPlain(state.rhythm.monthIncome, withSymbol: false)}',
                        valueColor: palette.incomeGreen,
                      ),
                    ),
                    Expanded(
                      child: _DeepMetric(
                        label: '结余',
                        value: MoneyFormat.formatPlain(
                          state.rhythm.monthBalance,
                          withSymbol: false,
                        ),
                        valueColor: palette.onDeep,
                      ),
                    ),
                    Expanded(
                      child: _DeepMetric(
                        label: '日均',
                        value: MoneyFormat.formatPlain(
                          dailyAverage,
                          withSymbol: false,
                        ),
                        valueColor: palette.onDeep,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            state.rhythm.comparisonSentence,
            style: StreamEditorialType.sectionLabel.copyWith(
              fontSize: 11,
              letterSpacing: 0.2,
              fontWeight: FontWeight.w400,
              color: palette.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _BudgetStrip(
          budget: state.budget,
          monthExpenseCents: state.monthExpenseCents,
          onSetBudget: state.openBudget,
        ),
        const SizedBox(height: 18),
        _RhythmBars(
          month: state.selectedMonth,
          bars: state.rhythm.bars,
          selectedDay: selectedDay,
          onSelectDay: state.selectDay,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = StreamPalette.of(context);
    return IconButton(
      icon: Icon(icon, size: 18, color: palette.textSecondary),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
    );
  }
}

class _DeepMetric extends StatelessWidget {
  const _DeepMetric({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final palette = StreamPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: StreamEditorialType.sectionLabel.copyWith(
            fontSize: 9,
            letterSpacing: 1,
            fontWeight: FontWeight.w400,
            color: palette.onDeepMuted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _BudgetStrip extends StatelessWidget {
  const _BudgetStrip({
    required this.budget,
    required this.monthExpenseCents,
    required this.onSetBudget,
  });

  final Budget? budget;
  final int monthExpenseCents;
  final VoidCallback onSetBudget;

  @override
  Widget build(BuildContext context) {
    final palette = StreamPalette.of(context);
    final totalBudgetCents = budget?.totalBudget ?? 0;
    final hasBudget = totalBudgetCents > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: palette.cardBackground,
        borderRadius: StreamShapes.listCard,
        child: InkWell(
          onTap: onSetBudget,
          borderRadius: StreamShapes.listCard,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              borderRadius: StreamShapes.listCard,
              border: Border.all(color: palette.hairline, width: 0.5),
            ),
            child: hasBudget
                ? _budgetProgress(context, palette, totalBudgetCents)
                : Row(
                    children: <Widget>[
                      Icon(
                        Icons.savings_outlined,
                        size: 18,
                        color: palette.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '设置本月预算',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: palette.textPrimary,
                              ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: palette.textSecondary,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _budgetProgress(
    BuildContext context,
    StreamPalette palette,
    int totalBudgetCents,
  ) {
    final overBudget = monthExpenseCents > totalBudgetCents;
    final progressColor = overBudget
        ? palette.overBudgetRed
        : palette.accentWarmYellow;
    final ratio = monthExpenseCents / totalBudgetCents;
    final percent = (ratio * 100).round();
    final remaining = totalBudgetCents - monthExpenseCents;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '月度预算',
              style: StreamEditorialType.sectionLabel.copyWith(
                fontSize: 9.5,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w500,
                color: palette.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              MoneyFormat.formatPlain(monthExpenseCents),
              style: textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: overBudget ? palette.overBudgetRed : palette.textPrimary,
              ),
            ),
            Text(
              ' / ${MoneyFormat.formatPlain(totalBudgetCents, withSymbol: false)}',
              style: textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ColoredBox(color: palette.inputBackground),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: ratio.clamp(0.0, 1.0).toDouble(),
                  child: ColoredBox(color: progressColor),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Text(
              '$percent%',
              style: textTheme.bodySmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: progressColor,
              ),
            ),
            const Spacer(),
            Text(
              overBudget
                  ? '超支 ${MoneyFormat.formatPlain(-remaining)}'
                  : '剩余 ${MoneyFormat.formatPlain(remaining)}',
              style: textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: overBudget
                    ? palette.overBudgetRed
                    : palette.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RhythmBars extends StatelessWidget {
  const _RhythmBars({
    required this.month,
    required this.bars,
    required this.selectedDay,
    required this.onSelectDay,
  });

  final int month;
  final List<DayRhythmBar> bars;
  final int? selectedDay;
  final ValueChanged<int?> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final palette = StreamPalette.of(context);
    if (bars.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: EditorialSectionLabel(title: '每日节奏', trailing: '$month 月'),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            height: 64,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (final bar in bars)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelectDay(
                        selectedDay == bar.dayOfMonth ? null : bar.dayOfMonth,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          if (bar.isCapped)
                            Container(
                              width: 8,
                              height: 2,
                              color: palette.accentWarmYellow,
                            ),
                          if (bar.isCapped) const SizedBox(height: 2),
                          Container(
                            height: 6 + bar.heightFraction * 48,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: _barColor(palette, bar),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(height: 0.5, color: palette.hairline),
        ),
      ],
    );
  }

  Color _barColor(StreamPalette palette, DayRhythmBar bar) {
    if (bar.isToday) return palette.accentWarmYellow;
    if (selectedDay == bar.dayOfMonth) return palette.textPrimary;
    if (bar.isFuture) return palette.textSecondary.withAlpha(36);
    return palette.textSecondary.withAlpha(120);
  }
}

class _FilterBanner extends StatelessWidget {
  const _FilterBanner({
    required this.month,
    required this.day,
    required this.onClear,
  });

  final int month;
  final int day;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final palette = StreamPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: InkWell(
        onTap: onClear,
        borderRadius: StreamShapes.tag,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: palette.accentPillBackground,
            borderRadius: StreamShapes.tag,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '已筛选 $month 月 $day 日',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '取消筛选',
                style: StreamEditorialType.sectionLabel.copyWith(
                  fontSize: 9.5,
                  letterSpacing: 1.2,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineEmptyState extends StatelessWidget {
  const _TimelineEmptyState({
    required this.message,
    required this.showAddAction,
    required this.onAdd,
  });

  final String message;
  final bool showAddAction;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = StreamPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: palette.textSecondary),
            ),
            if (showAddAction) ...<Widget>[
              const SizedBox(height: 16),
              Material(
                color: palette.accentWarmYellow,
                shape: StreamShapes.capsule,
                child: InkWell(
                  onTap: onAdd,
                  customBorder: StreamShapes.capsule,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          StreamIcons.add,
                          size: 18,
                          color: palette.textOnAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '记一笔',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: palette.textOnAccent,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayGroupHeader extends StatelessWidget {
  const _DayGroupHeader({
    required this.group,
    required this.isFiltered,
    required this.onTap,
    this.showMonth = false,
  });

  final _DayGroup group;
  final bool isFiltered;
  final bool showMonth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = StreamPalette.of(context);
    final summaryText = group.expenseCents > 0
        ? '-${MoneyFormat.formatPlain(group.expenseCents, withSymbol: false)}'
        : group.incomeCents > 0
        ? '+${MoneyFormat.formatPlain(group.incomeCents, withSymbol: false)}'
        : '0.00';
    final summaryColor = group.expenseCents > 0
        ? palette.textSecondary
        : group.incomeCents > 0
        ? palette.incomeGreen
        : palette.textSecondary;
    final labelColor = isFiltered
        ? palette.accentWarmYellow
        : palette.textPrimary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 22, 6),
        child: Row(
          children: <Widget>[
            Text(
              showMonth
                  ? '${group.month} 月 ${group.dayOfMonth} 日'
                  : '${group.dayOfMonth}',
              style: showMonth
                  ? StreamEditorialType.dayNumber.copyWith(
                      fontSize: 15,
                      color: labelColor,
                    )
                  : StreamEditorialType.dayNumber.copyWith(color: labelColor),
            ),
            const SizedBox(width: 8),
            Text(
              group.weekdayLabel,
              style: StreamEditorialType.dayLabel.copyWith(
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 0.5, color: palette.hairline)),
            const SizedBox(width: 10),
            Text(
              summaryText,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontSize: 11, color: summaryColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.transaction,
    this.category,
    this.account,
    this.toAccount,
    required this.onEdit,
    required this.onDelete,
  });

  final LedgerTransaction transaction;
  final Category? category;
  final Account? account;
  final Account? toAccount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Future<void> _presentRowMenu(BuildContext context) async {
    final palette = StreamPalette.of(context);
    final action = await showModalBottomSheet<_TimelineRowAction>(
      context: context,
      backgroundColor: palette.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: Icon(
                Icons.edit_outlined,
                size: 20,
                color: palette.textSecondary,
              ),
              title: Text(
                '编辑',
                style: Theme.of(sheetContext).textTheme.bodyMedium
                    ?.copyWith(color: palette.textPrimary),
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_TimelineRowAction.edit),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                size: 20,
                color: palette.overBudgetRed,
              ),
              title: Text(
                '删除',
                style: Theme.of(sheetContext).textTheme.bodyMedium
                    ?.copyWith(color: palette.overBudgetRed),
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_TimelineRowAction.delete),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == _TimelineRowAction.edit) {
      onEdit();
    } else if (action == _TimelineRowAction.delete) {
      onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = StreamPalette.of(context);
    final isTransfer = transaction.type == TransactionType.transfer;
    final note = transaction.note?.trim();
    final title = note != null && note.isNotEmpty
        ? note
        : isTransfer
        ? '转账到 ${toAccount?.name ?? '账户'}'
        : category?.name ?? '未分类';

    final subtitle = isTransfer
        ? '${account?.name ?? '账户'} ➔ ${toAccount?.name ?? '账户'}'
        : <String>[
            if (category != null) category!.name,
            if (account != null) account!.name,
            _timeLabel(transaction.occurredAt),
          ].join(' · ');

    final symbolColor = isTransfer
        ? palette.textSecondary
        : _colorFromHex(category?.colorHex, palette.textSecondary);
    final amountColor = switch (transaction.type) {
      TransactionType.expense => palette.textPrimary,
      TransactionType.income => palette.incomeGreen,
      TransactionType.transfer => palette.textSecondary,
    };
    final signedCents = transaction.type == TransactionType.expense
        ? -transaction.amount
        : transaction.amount;

    return InkWell(
      onTap: onEdit,
      onLongPress: () => _presentRowMenu(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.cardBackground,
                shape: BoxShape.circle,
              ),
              child: Text(
                isTransfer ? '转' : category?.symbolText ?? '他',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: symbolColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: palette.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10.5,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AmountText(
              cents: signedCents,
              integerSize: 14,
              showSign: !isTransfer,
              showSymbol: false,
              color: amountColor,
            ),
            IconButton(
              icon: Icon(
                Icons.more_horiz,
                size: 18,
                color: palette.textSecondary,
              ),
              tooltip: '更多',
              onPressed: () => _presentRowMenu(context),
              padding: const EdgeInsets.all(6),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            ),
          ],
        ),
      ),
    );
  }
}

enum _TimelineRowAction { edit, delete }

class _TimelineEntry {
  const _TimelineEntry._({
    this.group,
    this.transaction,
    this.showDivider = false,
  });

  const _TimelineEntry.header(_DayGroup group) : this._(group: group);

  const _TimelineEntry.transaction(
    LedgerTransaction transaction, {
    bool showDivider = false,
  }) : this._(transaction: transaction, showDivider: showDivider);

  const _TimelineEntry.gap() : this._();

  final _DayGroup? group;
  final LedgerTransaction? transaction;
  final bool showDivider;

  bool get isGap => group == null && transaction == null;
}

class _DayGroup {
  const _DayGroup({
    required this.dateKey,
    required this.month,
    required this.dayOfMonth,
    required this.weekdayLabel,
    required this.transactions,
    required this.expenseCents,
    required this.incomeCents,
  });

  final String dateKey;
  final int month;
  final int dayOfMonth;
  final String weekdayLabel;
  final List<LedgerTransaction> transactions;
  final int expenseCents;
  final int incomeCents;
}

List<_TimelineEntry> _buildEntries(List<_DayGroup> groups) {
  final entries = <_TimelineEntry>[];
  for (final group in groups) {
    entries.add(_TimelineEntry.header(group));
    for (var index = 0; index < group.transactions.length; index++) {
      entries.add(
        _TimelineEntry.transaction(
          group.transactions[index],
          showDivider: index < group.transactions.length - 1,
        ),
      );
    }
    entries.add(const _TimelineEntry.gap());
  }
  return entries;
}

List<LedgerTransaction> _matchTransactions(
  List<LedgerTransaction> transactions,
  String query,
  Map<String, Category> categories,
  Map<String, Account> accounts,
) {
  final needle = query.toLowerCase();
  return <LedgerTransaction>[
    for (final transaction in transactions)
      if (_matchesQuery(transaction, needle, categories, accounts)) transaction,
  ];
}

bool _matchesQuery(
  LedgerTransaction transaction,
  String needle,
  Map<String, Category> categories,
  Map<String, Account> accounts,
) {
  final note = transaction.note?.toLowerCase() ?? '';
  final categoryName =
      categories[transaction.categoryId]?.name.toLowerCase() ?? '';
  final accountName = accounts[transaction.accountId]?.name.toLowerCase() ?? '';
  final toAccountName =
      accounts[transaction.toAccountId]?.name.toLowerCase() ?? '';
  final amount = MoneyFormat.formatYuanPlain(transaction.amount).toLowerCase();
  return note.contains(needle) ||
      categoryName.contains(needle) ||
      accountName.contains(needle) ||
      toAccountName.contains(needle) ||
      amount.contains(needle);
}

List<_DayGroup> _buildDayGroups(
  List<LedgerTransaction> transactions, {
  int? year,
  int? month,
  int? selectedDay,
}) {
  final buckets = <String, List<LedgerTransaction>>{};
  for (final transaction in transactions) {
    final date = DateTime.fromMillisecondsSinceEpoch(transaction.occurredAt);
    if (year != null && date.year != year) continue;
    if (month != null && date.month != month) continue;
    if (selectedDay != null && date.day != selectedDay) continue;
    buckets
        .putIfAbsent(_dateKey(date), () => <LedgerTransaction>[])
        .add(transaction);
  }

  final groups = <_DayGroup>[];
  for (final entry in buckets.entries) {
    final items = List<LedgerTransaction>.from(entry.value)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final date = DateTime.fromMillisecondsSinceEpoch(items.first.occurredAt);
    var expense = 0;
    var income = 0;
    for (final transaction in items) {
      if (transaction.type == TransactionType.expense) {
        expense += transaction.amount;
      } else if (transaction.type == TransactionType.income) {
        income += transaction.amount;
      }
    }
    groups.add(
      _DayGroup(
        dateKey: entry.key,
        month: date.month,
        dayOfMonth: date.day,
        weekdayLabel: _weekdayLabels[date.weekday - 1],
        transactions: items,
        expenseCents: expense,
        incomeCents: income,
      ),
    );
  }
  groups.sort((a, b) => b.dateKey.compareTo(a.dateKey));
  return groups;
}

int _dailyAverage({
  required int year,
  required int month,
  required int totalExpense,
}) {
  final now = DateTime.now();
  final isCurrentMonth = now.year == year && now.month == month;
  final days = isCurrentMonth
      ? (now.day < 1 ? 1 : now.day)
      : DateTime(year, month + 1, 0).day;
  return totalExpense ~/ (days < 1 ? 1 : days);
}

String _dateKey(DateTime date) =>
    '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _timeLabel(int millisecondsSinceEpoch) {
  final date = DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
  return '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
}

Color _colorFromHex(String? hex, Color fallback) {
  if (hex == null) return fallback;
  final cleaned = hex.trim().replaceFirst('#', '');
  if (cleaned.length != 6 && cleaned.length != 8) return fallback;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return fallback;
  return Color(cleaned.length == 6 ? 0xFF000000 | value : value);
}
