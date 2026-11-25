import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../core/money.dart';
import '../data/models.dart';
import '../design/stream_theme.dart';
import '../widgets/editorial.dart';

/// 统计屏：支出/收入切换、不含固定支出开关、占比分段条 + 图例 + 分类进度卡 + 分类明细。
/// 占比只用横向分段/进度条表达，禁止饼图与环形图。
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _AnalyticsBody();
}

class _AnalyticsBody extends StatefulWidget {
  const _AnalyticsBody();

  @override
  State<_AnalyticsBody> createState() => _AnalyticsBodyState();
}

class _AnalyticsBodyState extends State<_AnalyticsBody> {
  String? _selectedCategoryId;

  /// 月份变更后下钻明细来自另一批交易，必须丢弃旧的分类选中态。
  void _clearCategorySelection() {
    if (_selectedCategoryId == null) return;
    setState(() => _selectedCategoryId = null);
  }

  void _switchMonth(VoidCallback applyMonth) {
    _clearCategorySelection();
    applyMonth();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final palette = StreamPalette.of(context);
    final analytics = state.analytics;
    final isExpense = state.analyticsIsExpense;

    final categoryMap = <String, Category>{
      for (final category in state.categories) category.id: category,
    };
    final accountMap = <String, Account>{
      for (final account in state.accounts) account.id: account,
    };
    final legend = _buildLegend(analytics.proportionItems, palette);

    final selectedId = _selectedCategoryId;
    final drillDown = selectedId == null
        ? const <LedgerTransaction>[]
        : analytics.filteredTransactions
            .where((tx) => tx.categoryId == selectedId)
            .toList(growable: false);

    return Container(
      color: palette.paperBase,
      child: ListView(
        key: const PageStorageKey('analytics'),
        padding: EdgeInsets.only(
          bottom: 114 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          EditorialHeader(
            eyebrow: 'COMPOSITION',
            title: 'Overview',
            subtitle:
                '${state.selectedMonth.toString().padLeft(2, '0')} / ${state.selectedYear}',
            actions: <Widget>[
              _MonthSwitchButton(
                icon: Icons.chevron_left_rounded,
                tooltip: '上月',
                onPressed: () => _switchMonth(state.prevMonth),
              ),
              _MonthSwitchButton(
                icon: Icons.chevron_right_rounded,
                tooltip: '下月',
                onPressed: () => _switchMonth(state.nextMonth),
              ),
            ],
          ),
          _totalRow(palette, analytics, isExpense),
          _toggleRow(state, palette, isExpense),
          _proportionSection(palette, legend),
          if (analytics.proportionItems.isNotEmpty)
            _progressCards(palette, analytics.proportionItems),
          if (analytics.insightSentence.isNotEmpty)
            _insightRow(palette, analytics.insightSentence),
          const EditorialSectionLabel(
            title: '全部分类',
            trailing: '金额 / 占比',
          ),
          for (final item in analytics.proportionItems)
            _categoryLine(
              palette,
              item,
              selected: item.categoryId == selectedId,
            ),
          if (drillDown.isNotEmpty && selectedId != null) ...[
            EditorialSectionLabel(
              title: '对应明细 (${drillDown.length} 笔)',
              trailing: '收起',
            ),
            for (final tx in drillDown) ...[
              _drillDownRow(
                palette,
                state,
                tx,
                categoryMap[tx.categoryId],
                accountMap[tx.accountId],
              ),
              const EditorialHairline(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _totalRow(StreamPalette palette, AnalyticsData analytics, bool isExpense) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _microLabel(palette, isExpense ? '总支出' : '总收入'),
                const SizedBox(height: 3),
                AmountText(
                  cents: analytics.totalAmount,
                  integerSize: 30,
                  color: isExpense ? palette.textPrimary : palette.incomeGreen,
                ),
              ],
            ),
          ),
          if (isExpense)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _microLabel(palette, '日均'),
                const SizedBox(height: 3),
                AmountText(
                  cents: analytics.dailyAverage,
                  integerSize: 15,
                  color: palette.textPrimary,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _toggleRow(AppState state, StreamPalette palette, bool isExpense) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      child: Row(
        children: [
          _TypeTab(
            text: '支出',
            selected: isExpense,
            palette: palette,
            onTap: () {
              if (!isExpense) {
                state.setAnalyticsType(true);
                setState(() => _selectedCategoryId = null);
              }
            },
          ),
          const SizedBox(width: 18),
          _TypeTab(
            text: '收入',
            selected: !isExpense,
            palette: palette,
            onTap: () {
              if (isExpense) {
                state.setAnalyticsType(false);
                setState(() => _selectedCategoryId = null);
              }
            },
          ),
          const Spacer(),
          if (isExpense)
            _ExcludeFixedToggle(
              palette: palette,
              selected: state.analyticsExcludeFixed,
              onTap: state.toggleExcludeFixedExpense,
            ),
        ],
      ),
    );
  }

  Widget _proportionSection(StreamPalette palette, List<_LegendItem> legend) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (legend.isEmpty)
            Text(
              '本月暂无统计数据',
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 7,
                child: Row(
                  children: [
                    for (var i = 0; i < legend.length; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(
                        flex: _flexOf(legend[i].percentage),
                        child: Container(color: legend[i].color),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _legendWrap(palette, legend),
          ],
        ],
      ),
    );
  }

  Widget _legendWrap(StreamPalette palette, List<_LegendItem> legend) {
    if (legend.length <= 3) {
      return Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          for (final item in legend) _legendChip(palette, item),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final chipWidth = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            for (final item in legend)
              SizedBox(
                width: chipWidth,
                child: _legendChip(palette, item),
              ),
          ],
        );
      },
    );
  }

  Widget _legendChip(StreamPalette palette, _LegendItem item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: item.color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '${item.name} ${_formatPercent(item.percentage)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9.5, color: palette.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _progressCards(
      StreamPalette palette, List<CategoryProportionItem> items) {
    final leading = items.take(2).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < leading.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(
              child: _CategoryProgressCard(item: leading[i], palette: palette),
            ),
          ],
        ],
      ),
    );
  }

  Widget _insightRow(StreamPalette palette, String insight) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: palette.accentWarmYellow.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: palette.accentWarmYellow,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              insight,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.56,
                color: palette.isDark ? palette.textPrimary : palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryLine(
    StreamPalette palette,
    CategoryProportionItem item, {
    required bool selected,
  }) {
    return InkWell(
      onTap: () => setState(() {
        _selectedCategoryId =
            _selectedCategoryId == item.categoryId ? null : item.categoryId;
      }),
      child: Container(
        color: selected
            ? palette.accentPillBackground.withValues(alpha: 0.55)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: _parseHexColor(item.colorHex),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: palette.textPrimary),
              ),
            ),
            SizedBox(
              width: 42,
              child: Text(
                _formatPercent(item.percentage),
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 10.5, color: palette.textSecondary),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 64),
              child: Text(
                MoneyFormat.formatPlain(item.amountCents, withSymbol: false),
                textAlign: TextAlign.end,
                maxLines: 1,
                style: TextStyle(fontSize: 12.5, color: palette.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drillDownRow(
    StreamPalette palette,
    AppState state,
    LedgerTransaction tx,
    Category? category,
    Account? account,
  ) {
    final isIncome = tx.type == TransactionType.income;
    final timeLabel =
        DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(tx.occurredAt));
    final title = (tx.note != null && tx.note!.isNotEmpty)
        ? tx.note!
        : (category?.name ?? '未分类');
    final subtitle = <String>[
      if (category != null) category.name,
      if (account != null) account.name,
      timeLabel,
    ].join(' · ');

    return InkWell(
      onTap: () => state.openQuickAdd(tx),
      onLongPress: () => state.deleteTransaction(tx),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.cardBackground,
                shape: BoxShape.circle,
              ),
              child: Text(
                category?.symbolText ?? '他',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _parseHexColor(category?.colorHex ?? ''),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: palette.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: palette.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AmountText(
              cents: isIncome ? tx.amount : -tx.amount,
              integerSize: 14,
              showSign: isIncome,
              color: isIncome ? palette.incomeGreen : palette.textPrimary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _microLabel(StreamPalette palette, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 9.5,
        letterSpacing: 1.6,
        color: palette.textSecondary,
      ),
    );
  }
}

/// 与账单页共用全局选中月份，月份切换会重算统计并清空账单页选中日。
class _MonthSwitchButton extends StatelessWidget {
  const _MonthSwitchButton({
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
      padding: const EdgeInsets.all(6),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    );
  }
}

class _TypeTab extends StatelessWidget {
  const _TypeTab({
    required this.text,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final StreamPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? palette.textPrimary : palette.textSecondary,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: 18,
              height: 1.5,
              color: selected ? palette.textPrimary : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExcludeFixedToggle extends StatelessWidget {
  const _ExcludeFixedToggle({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final StreamPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: selected ? palette.accentWarmYellow : palette.hairline,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '不含固定支出',
              style: TextStyle(
                fontSize: 10.5,
                color: selected ? palette.textPrimary : palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryProgressCard extends StatelessWidget {
  const _CategoryProgressCard({required this.item, required this.palette});

  final CategoryProportionItem item;
  final StreamPalette palette;

  @override
  Widget build(BuildContext context) {
    final itemColor = _parseHexColor(item.colorHex);
    final fraction = item.percentage.clamp(0.01, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: palette.textSecondary),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _formatPercent(item.percentage),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            MoneyFormat.formatPlain(item.amountCents),
            maxLines: 1,
            style: TextStyle(fontSize: 15, color: palette.textPrimary),
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: Row(
                children: [
                  Expanded(
                    flex: _flexOf(fraction),
                    child: Container(color: itemColor),
                  ),
                  Expanded(
                    flex: _flexOf(1 - fraction),
                    child: Container(color: palette.hairline),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '占本月金额',
            style: TextStyle(fontSize: 9.5, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _LegendItem {
  const _LegendItem(this.name, this.percentage, this.color);

  final String name;
  final double percentage;
  final Color color;
}

List<_LegendItem> _buildLegend(
    List<CategoryProportionItem> items, StreamPalette palette) {
  if (items.isEmpty) return const <_LegendItem>[];
  if (items.length <= 4) {
    return [
      for (final item in items)
        _LegendItem(item.name, item.percentage, _parseHexColor(item.colorHex)),
    ];
  }
  final top = [
    for (final item in items.take(3))
      _LegendItem(item.name, item.percentage, _parseHexColor(item.colorHex)),
  ];
  final rest = items.skip(3).fold<double>(0, (sum, item) => sum + item.percentage);
  return [...top, _LegendItem('其他', rest, palette.accentWarmYellow)];
}

int _flexOf(double fraction) {
  final flex = (fraction * 1000).round();
  return flex < 1 ? 1 : flex;
}

String _formatPercent(double percentage) =>
    '${(percentage * 100).toStringAsFixed(1)}%';

Color _parseHexColor(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return const Color(0xFF8C867A);
  if (cleaned.length == 6) return Color(0xFF000000 | value);
  return Color(value);
}