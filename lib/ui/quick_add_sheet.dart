import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:stream_ledger/app_state.dart';
import 'package:stream_ledger/core/money.dart';
import 'package:stream_ledger/data/models.dart';
import 'package:stream_ledger/design/stream_icons.dart';
import 'package:stream_ledger/design/stream_shapes.dart';
import 'package:stream_ledger/design/stream_theme.dart';

/// 「记一笔」面板内容。可见性由外壳（`ui/main_screen.dart`）通过
/// `showModalBottomSheet` 决定，本组件只负责编辑与提交。
class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key});

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  TransactionType _type = TransactionType.expense;
  String _expression = '';
  String? _categoryId;
  String _accountId = '';
  String _toAccountId = '';
  int _occurredAt = DateTime.now().millisecondsSinceEpoch;
  final TextEditingController _noteController = TextEditingController();
  bool _noteExpanded = false;
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final state = AppScope.of(context);
    final editing = state.editingTransaction;
    if (editing != null) {
      _type = editing.type;
      _expression = ArithmeticParser.centsToDisplayInput(editing.amount);
      _categoryId = editing.categoryId;
      _accountId = editing.accountId;
      _toAccountId = editing.toAccountId ?? '';
      _occurredAt = editing.occurredAt;
      _noteController.text = editing.note ?? '';
      _noteExpanded = _noteController.text.isNotEmpty;
      return;
    }
    _occurredAt = DateTime.now().millisecondsSinceEpoch;
    _applyDefaults(state);
  }

  /// 账户/分类可能晚于面板打开到达，这里补齐默认选择，避免无法保存。
  void _applyDefaults(AppState state) {
    if (_accountId.isEmpty && state.accounts.isNotEmpty) {
      _accountId = state.accounts.any((a) => a.id == state.lastUsedAccountId)
          ? state.lastUsedAccountId
          : state.accounts.first.id;
    }
    if (_type == TransactionType.transfer) {
      if (state.accounts.length >= 2 &&
          (_toAccountId.isEmpty || _toAccountId == _accountId)) {
        _toAccountId = state.accounts
            .firstWhere((a) => a.id != _accountId,
                orElse: () => state.accounts.first)
            .id;
      }
    } else if (_categoryId == null || _categoryId!.isEmpty) {
      _categoryId = _defaultCategoryId(state);
    }
  }

  String? _defaultCategoryId(AppState state) {
    final matching = state.categories.where((c) => c.type == _type).toList();
    if (matching.isEmpty) return null;
    for (final c in matching) {
      if (c.isPinned) return c.id;
    }
    return matching.first.id;
  }

  List<Category> _filteredCategories(AppState state) {
    final target =
        _type == TransactionType.transfer ? TransactionType.expense : _type;
    final list = state.categories.where((c) => c.type == target).toList();
    // 置顶分类优先，其余保持数据层顺序。
    final pinned = list.where((c) => c.isPinned).toList();
    final rest = list.where((c) => !c.isPinned).toList();
    return [...pinned, ...rest];
  }

  void _onTypeSelected(TransactionType next, AppState state) {
    if (next == _type) return;
    if (next == TransactionType.transfer && state.accounts.length < 2) return;
    setState(() {
      _type = next;
      _error = null;
      if (next != TransactionType.transfer) {
        _categoryId = _defaultCategoryId(state);
      }
      if (next == TransactionType.transfer &&
          state.accounts.length >= 2 &&
          (_toAccountId.isEmpty || _toAccountId == _accountId)) {
        _toAccountId = state.accounts
            .firstWhere((a) => a.id != _accountId,
                orElse: () => state.accounts.first)
            .id;
      }
    });
  }

  void _onKey(String key) {
    if (key == 'OK') {
      _submit();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _error = null;
      switch (key) {
        case 'DEL':
          if (_expression.isNotEmpty) {
            _expression = _expression.substring(0, _expression.length - 1);
          }
        case 'C':
          _expression = '';
        case '+':
          if (_expression.isNotEmpty &&
              !_expression.endsWith('+') &&
              !_expression.endsWith('-')) {
            _expression = '$_expression+';
          }
        case '-':
          if (!_expression.endsWith('-') && !_expression.endsWith('+')) {
            _expression = '$_expression-';
          }
        case '.':
          final lastSegment = _expression.split(RegExp(r'[+-]')).last;
          if (!lastSegment.contains('.')) {
            _expression = '$_expression.';
          }
        default:
          _expression = '$_expression$key';
      }
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    _saving = true;
    final state = AppScope.of(context);
    final note = _noteController.text.trim();
    final error = await state.saveTransaction(
      type: _type,
      amountCents: ArithmeticParser.evaluate(_expression),
      accountId: _accountId,
      toAccountId: _type == TransactionType.transfer ? _toAccountId : null,
      categoryId: _type != TransactionType.transfer ? _categoryId : null,
      occurredAt: _occurredAt,
      note: note.isEmpty ? null : note,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (error != null) _error = error;
    });
  }

  Future<void> _pickDate() async {
    final current = DateTime.fromMillisecondsSinceEpoch(_occurredAt);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _occurredAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        current.hour,
        current.minute,
        current.second,
      ).millisecondsSinceEpoch;
    });
  }

  String _dateLabel(int occurredAt) {
    final date = DateTime.fromMillisecondsSinceEpoch(occurredAt);
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '今天';
    }
    return '${date.month}月${date.day}日';
  }

  Color _colorOf(String hex) {
    final value = hex.replaceFirst('#', '');
    if (value.length != 6) return const Color(0xFF8C867A);
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? const Color(0xFF8C867A) : Color(0xFF000000 | parsed);
  }

  String _accountName(AppState state, String id, String fallback) {
    for (final account in state.accounts) {
      if (account.id == id) return account.name;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    _applyDefaults(state);

    final palette = StreamPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final evaluatedCents = ArithmeticParser.evaluate(_expression);
    final hasOperator = _expression.contains('+') || _expression.contains('-');

    // 键盘固定为 Column 的非 flex 子项，上半区在剩余空间内独立滚动，
    // 保证数字键与 OK 始终可见。
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dragHandle(palette),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _topBar(state, palette, textTheme),
                  _amountDisplay(
                      palette, textTheme, evaluatedCents, hasOperator),
                  _attributeRow(state, palette, textTheme),
                  if (_noteExpanded)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 6),
                      child: TextField(
                        controller: _noteController,
                        onChanged: (_) => setState(() {}),
                        style: textTheme.bodyMedium
                            ?.copyWith(color: palette.textPrimary),
                        decoration: InputDecoration(
                          hintText: '写点备注...',
                          hintStyle: textTheme.bodySmall
                              ?.copyWith(color: palette.textSecondary),
                          filled: true,
                          fillColor: palette.inputBackground,
                          border: OutlineInputBorder(
                            borderRadius: StreamShapes.smallCard,
                            borderSide:
                                BorderSide(color: palette.hairline, width: 0.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: StreamShapes.smallCard,
                            borderSide:
                                BorderSide(color: palette.hairline, width: 0.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: StreamShapes.smallCard,
                            borderSide: BorderSide(
                                color: palette.accentWarmYellow, width: 1),
                          ),
                        ),
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 4),
                      child: Text(
                        _error!,
                        style: textTheme.labelSmall
                            ?.copyWith(color: palette.overBudgetRed),
                      ),
                    ),
                  if (_type != TransactionType.transfer)
                    _categoryStrip(state, palette, textTheme),
                ],
              ),
            ),
          ),
          _keypad(palette, textTheme),
          SizedBox(height: 16 + safeBottom),
        ],
      ),
    );
  }

  Widget _dragHandle(StreamPalette palette) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: palette.hairline,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _topBar(AppState state, StreamPalette palette, TextTheme textTheme) {
    const items = [
      (TransactionType.expense, '支出'),
      (TransactionType.income, '收入'),
      (TransactionType.transfer, '转账'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 20,
              onPressed: state.closeQuickAdd,
              icon: Icon(StreamIcons.close, color: palette.textSecondary),
              tooltip: '取消',
            ),
          ),
          const Spacer(),
          Container(
            height: 34,
            padding: const EdgeInsets.all(2),
            decoration: ShapeDecoration(
              color: palette.cardBackground,
              shape: StreamShapes.capsule,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in items)
                  GestureDetector(
                    onTap: () => _onTypeSelected(item.$1, state),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: ShapeDecoration(
                        color: _type == item.$1
                            ? palette.accentPillBackground
                            : Colors.transparent,
                        shape: StreamShapes.capsule,
                      ),
                      child: Text(
                        item.$2,
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: _type == item.$1
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: _type == item.$1
                              ? palette.textPrimary
                              : palette.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          const SizedBox(width: 32, height: 32),
        ],
      ),
    );
  }

  Widget _amountDisplay(StreamPalette palette, TextTheme textTheme,
      int evaluatedCents, bool hasOperator) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(
            hasOperator
                ? '= ${MoneyFormat.formatPlain(evaluatedCents)}'
                : '输入金额',
            style: textTheme.labelSmall?.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4, right: 2),
                child: Text(
                  MoneyFormat.symbol,
                  style: textTheme.headlineSmall
                      ?.copyWith(color: palette.textSecondary),
                ),
              ),
              Text(
                _expression.isEmpty ? '0.00' : _expression,
                style: textTheme.headlineLarge?.copyWith(
                  fontSize: 42,
                  fontWeight: FontWeight.w300,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attributeRow(
      AppState state, StreamPalette palette, TextTheme textTheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          if (_type == TransactionType.transfer) ...[
            _pill(
              palette: palette,
              onTap: state.accounts.isEmpty
                  ? null
                  : () => setState(() {
                        _error = null;
                        final index =
                            state.accounts.indexWhere((a) => a.id == _accountId);
                        _accountId = state.accounts[
                                index >= 0 ? (index + 1) % state.accounts.length : 0]
                            .id;
                      }),
              child: Text(
                _accountName(state, _accountId, '转出账户'),
                style: textTheme.labelSmall?.copyWith(color: palette.textPrimary),
              ),
            ),
            const SizedBox(width: 8),
            _pill(
              palette: palette,
              onTap: state.accounts.length < 2
                  ? null
                  : () => setState(() {
                        _error = null;
                        final others = state.accounts
                            .where((a) => a.id != _accountId)
                            .toList();
                        if (others.isEmpty) return;
                        final index =
                            others.indexWhere((a) => a.id == _toAccountId);
                        _toAccountId = others[(index + 1) % others.length].id;
                      }),
              child: Text(
                _accountName(state, _toAccountId, '转入账户'),
                style: textTheme.labelSmall?.copyWith(color: palette.textPrimary),
              ),
            ),
          ] else
            _pill(
              palette: palette,
              onTap: state.accounts.isEmpty
                  ? null
                  : () => setState(() {
                        _error = null;
                        final index =
                            state.accounts.indexWhere((a) => a.id == _accountId);
                        _accountId = state.accounts[
                                index >= 0 ? (index + 1) % state.accounts.length : 0]
                            .id;
                      }),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.accounts.isNotEmpty) ...[
                    Text(
                      _symbolOf(state, _accountId) ?? '账',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: palette.accentWarmYellow,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    state.accounts.isEmpty
                        ? '暂无账户，请先在资产页添加账户'
                        : _accountName(state, _accountId, '选择账户'),
                    style: textTheme.labelSmall?.copyWith(
                      color: state.accounts.isEmpty
                          ? palette.overBudgetRed
                          : palette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          _pill(
            palette: palette,
            onTap: _pickDate,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 12, color: palette.textSecondary),
                const SizedBox(width: 4),
                Text(
                  _dateLabel(_occurredAt),
                  style: textTheme.labelSmall?.copyWith(color: palette.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _pill(
            palette: palette,
            onTap: () => setState(() => _noteExpanded = !_noteExpanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_outlined, size: 12, color: palette.textSecondary),
                const SizedBox(width: 4),
                Text(
                  _noteController.text.trim().isEmpty
                      ? '添加备注'
                      : _noteController.text.trim(),
                  style: textTheme.labelSmall?.copyWith(
                    color: _noteController.text.trim().isEmpty
                        ? palette.textSecondary
                        : palette.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _symbolOf(AppState state, String accountId) {
    for (final account in state.accounts) {
      if (account.id == accountId) return account.symbolText;
    }
    return null;
  }

  Widget _pill({
    required StreamPalette palette,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: ShapeDecoration(
          color: palette.cardBackground,
          shape: StadiumBorder(
            side: BorderSide(color: palette.hairline, width: 0.5),
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _categoryStrip(
      AppState state, StreamPalette palette, TextTheme textTheme) {
    final categories = _filteredCategories(state);
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) => SizedBox(
          width: 64,
          child: _categoryTile(categories[index], palette, textTheme),
        ),
      ),
    );
  }

  Widget _categoryTile(
      Category category, StreamPalette palette, TextTheme textTheme) {
    final isSelected = category.id == _categoryId;
    final categoryColor = _colorOf(category.colorHex);
    return GestureDetector(
      onTap: () => setState(() => _categoryId = category.id),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? palette.accentWarmYellow
                  : categoryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              category.symbolText,
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color:
                    isSelected ? palette.textOnAccent : categoryColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            category.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color:
                  isSelected ? palette.textPrimary : palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _keypad(StreamPalette palette, TextTheme textTheme) {
    const rows = [
      ['7', '8', '9', '+'],
      ['4', '5', '6', '-'],
      ['1', '2', '3', 'C'],
      ['.', '0', 'DEL', 'OK'],
    ];
    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: palette.cardBackground,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  for (final key in row)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: key == row.last ? 0 : 8),
                        child: _key(key, palette, textTheme),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _key(String key, StreamPalette palette, TextTheme textTheme) {
    final isOk = key == 'OK';
    final isOperator = key == '+' || key == '-' || key == 'C';
    final background = isOk
        ? palette.accentWarmYellow
        : isOperator
            ? palette.paperBase
            : palette.paperBase.withValues(alpha: 0.6);
    return Material(
      color: background,
      borderRadius: StreamShapes.smallCard,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onKey(key),
        splashColor: palette.accentPillBackground,
        highlightColor: palette.accentPillBackground,
        child: SizedBox(
          height: 48,
          child: Center(
            child: key == 'DEL'
                ? Icon(Icons.backspace_outlined,
                    size: 18, color: palette.textPrimary)
                : isOk
                    ? Icon(Icons.check_rounded,
                        size: 24, color: palette.textOnAccent)
                    : Text(
                        key,
                        style: textTheme.titleMedium?.copyWith(
                          fontSize: 20,
                          fontWeight:
                              isOperator ? FontWeight.w600 : FontWeight.w400,
                          color: palette.textPrimary,
                        ),
                      ),
          ),
        ),
      ),
    );
  }
}