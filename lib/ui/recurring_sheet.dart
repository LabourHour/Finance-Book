import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../core/money.dart';
import '../data/models.dart';
import '../design/stream_icons.dart';
import '../design/stream_shapes.dart';
import '../design/stream_theme.dart';
import '../design/stream_typography.dart';

/// 周期记账：列出已保存的周期规则，并支持新增、行内编辑与删除。
/// 可见性由外壳（`ui/main_screen.dart`）根据 `state.recurringVisible` 决定，
/// 关闭时回写 `closeRecurring()`。
class RecurringSheet extends StatefulWidget {
  const RecurringSheet({super.key});

  @override
  State<RecurringSheet> createState() => _RecurringSheetState();
}

class _RecurringSheetState extends State<RecurringSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  bool _formVisible = false;
  RecurringRule? _editingRule;
  TransactionType _formType = TransactionType.expense;
  String _accountId = '';
  String _toAccountId = '';
  String? _categoryId;
  int _dayOfMonth = 1;
  bool _saving = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _close() {
    AppScope.of(context).closeRecurring();
  }

  void _startCreate(AppState state) {
    setState(() {
      _formVisible = true;
      _editingRule = null;
      _nameController.text = '';
      _amountController.text = '';
      _formType = TransactionType.expense;
      _accountId = _defaultAccountId(state);
      _toAccountId = '';
      _categoryId = _defaultCategoryId(state, TransactionType.expense);
      _dayOfMonth = DateTime.now().day.clamp(1, 28).toInt();
      _error = null;
    });
  }

  void _startEdit(RecurringRule rule) {
    setState(() {
      _formVisible = true;
      _editingRule = rule;
      _nameController.text = rule.name;
      _amountController.text =
          ArithmeticParser.centsToDisplayInput(rule.amount);
      _formType = rule.type;
      _accountId = rule.accountId;
      _toAccountId = rule.toAccountId ?? '';
      _categoryId = rule.categoryId;
      _dayOfMonth = rule.dayOfMonth.clamp(1, 28).toInt();
      _error = null;
    });
  }

  void _backToList() {
    setState(() {
      _formVisible = false;
      _editingRule = null;
      _error = null;
    });
  }

  void _onTypeSelected(TransactionType next, AppState state) {
    if (next == _formType) return;
    if (next == TransactionType.transfer && state.accounts.length < 2) {
      return;
    }
    setState(() {
      _formType = next;
      _error = null;
      if (next == TransactionType.transfer) {
        _categoryId = null;
        final other = _otherAccountId(state, _accountId);
        if (other != null) _toAccountId = other;
      } else {
        _toAccountId = '';
        _categoryId = _defaultCategoryId(state, next);
      }
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    final state = AppScope.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });

    final String? error = await state.saveRecurringRule(
      editing: _editingRule,
      name: _nameController.text.trim(),
      type: _formType,
      amountCents: ArithmeticParser.evaluate(_amountController.text),
      accountId: _accountId,
      categoryId: _formType == TransactionType.transfer ? null : _categoryId,
      toAccountId:
          _formType == TransactionType.transfer ? _toAccountId : null,
      dayOfMonth: _dayOfMonth,
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
      if (error != null) {
        _error = error;
        return;
      }
      _formVisible = false;
      _editingRule = null;
    });
  }

  Future<void> _delete(RecurringRule rule) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final String? error = await AppScope.of(context)
        .deleteRecurringRule(rule.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  String _defaultAccountId(AppState state) {
    if (state.accounts.isEmpty) return '';
    if (state.accounts.any((a) => a.id == state.lastUsedAccountId)) {
      return state.lastUsedAccountId;
    }
    return state.accounts.first.id;
  }

  String? _otherAccountId(AppState state, String exceptId) {
    for (final account in state.accounts) {
      if (account.id != exceptId) return account.id;
    }
    return null;
  }

  String? _defaultCategoryId(AppState state, TransactionType type) {
    final matching =
        state.categories.where((category) => category.type == type);
    for (final category in matching) {
      if (category.isPinned) return category.id;
    }
    return matching.isEmpty ? null : matching.first.id;
  }

  List<Category> _categoriesOf(AppState state) {
    if (_formType == TransactionType.transfer) return const <Category>[];
    return state.categories
        .where((category) => category.type == _formType)
        .toList();
  }

  String _accountName(AppState state, String id, String fallback) {
    for (final account in state.accounts) {
      if (account.id == id) return account.name;
    }
    return fallback;
  }

  String _typeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return '支出';
      case TransactionType.income:
        return '收入';
      case TransactionType.transfer:
        return '转账';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final palette = StreamPalette.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Material(
          color: palette.cardBackground,
          borderRadius: StreamShapes.mainCard,
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(palette),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                  child: _formVisible
                      ? _buildForm(state, palette)
                      : _buildList(state, palette),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(StreamPalette palette) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 12, 6),
      child: Row(
        children: [
          if (_formVisible)
            IconButton(
              padding: EdgeInsets.zero,
              iconSize: 18,
              tooltip: '返回列表',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: _saving ? null : _backToList,
              icon: Icon(StreamIcons.close, color: palette.textSecondary),
            )
          else
            Expanded(
              child: Text(
                '周期记账',
                style: textTheme.titleLarge?.copyWith(
                  color: palette.textPrimary,
                ),
              ),
            ),
          if (_formVisible)
            Expanded(
              child: Text(
                _editingRule == null ? '新增规则' : '编辑规则',
                style: textTheme.titleLarge?.copyWith(
                  color: palette.textPrimary,
                ),
              ),
            ),
          IconButton(
            padding: EdgeInsets.zero,
            iconSize: 20,
            tooltip: '关闭',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: _close,
            icon: Icon(StreamIcons.close, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildList(AppState state, StreamPalette palette) {
    final rules = state.recurringRules;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '每月按规则自动生成一笔账单',
          style: textTheme.labelSmall?.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: 12),
        if (_error != null) ...[
          _RecurringErrorText(text: _error!, palette: palette),
          const SizedBox(height: 12),
        ],
        if (rules.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              '暂无周期规则，点击下方按钮新增',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          )
        else
          for (var index = 0; index < rules.length; index++) ...[
            _buildRuleRow(state, palette, rules[index]),
            if (index != rules.length - 1)
              Container(height: 0.5, color: palette.hairline),
          ],
        const SizedBox(height: 22),
        SizedBox(
          height: 44,
          child: FilledButton(
            onPressed: _busy ? null : () => _startCreate(state),
            style: FilledButton.styleFrom(
              backgroundColor: palette.accentWarmYellow,
              foregroundColor: palette.textOnAccent,
              shape: const RoundedRectangleBorder(
                borderRadius: StreamShapes.smallCard,
              ),
            ),
            child: const Text('新增周期规则'),
          ),
        ),
      ],
    );
  }

  Widget _buildRuleRow(
    AppState state,
    StreamPalette palette,
    RecurringRule rule,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final accountName = _accountName(state, rule.accountId, '账户已删除');
    final transferName = rule.type == TransactionType.transfer
        ? _accountName(state, rule.toAccountId ?? '', '转入账户')
        : null;
    final meta = StringBuffer()
      ..write('每月 ${rule.dayOfMonth} 日 · $accountName');
    if (transferName != null) {
      meta.write(' → $transferName');
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : () => _startEdit(rule),
        borderRadius: StreamShapes.tag,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
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
                  Text(
                    MoneyFormat.formatPlain(rule.amount),
                    style: textTheme.bodyMedium?.copyWith(
                      color: rule.type == TransactionType.income
                          ? palette.incomeGreen
                          : palette.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _typeLabel(rule.type),
                    style: textTheme.labelSmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              IconButton(
                padding: EdgeInsets.zero,
                iconSize: 18,
                tooltip: '删除规则',
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                onPressed: _busy ? null : () => _delete(rule),
                icon: Icon(StreamIcons.delete, color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AppState state, StreamPalette palette) {
    final textTheme = Theme.of(context).textTheme;
    final categories = _categoriesOf(state);
    final categoryValue = categories.any((c) => c.id == _categoryId)
        ? _categoryId
        : '';
    final accountValue = state.accounts.any((a) => a.id == _accountId)
        ? _accountId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _RecurringFieldLabel(text: '规则名称'),
        const SizedBox(height: 6),
        TextField(
          controller: _nameController,
          textInputAction: TextInputAction.next,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          style: textTheme.bodyMedium?.copyWith(color: palette.textPrimary),
          decoration: _inputDecoration(palette, '例如：房租'),
        ),
        const SizedBox(height: 16),
        const _RecurringFieldLabel(text: '类型'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in TransactionType.values)
              _RecurringTypeCapsule(
                label: _typeLabel(type),
                selected: _formType == type,
                onTap: () => _onTypeSelected(type, state),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const _RecurringFieldLabel(text: '金额'),
        const SizedBox(height: 6),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.+\-]')),
          ],
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          style: textTheme.bodyMedium?.copyWith(color: palette.textPrimary),
          decoration: _inputDecoration(palette, '0.00'),
        ),
        const SizedBox(height: 16),
        const _RecurringFieldLabel(text: '账户'),
        const SizedBox(height: 6),
        if (state.accounts.isEmpty)
          Text(
            '暂无账户，请先在资产页添加账户',
            style: textTheme.labelSmall?.copyWith(color: palette.overBudgetRed),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: accountValue,
            isExpanded: true,
            decoration: _inputDecoration(palette, '选择账户'),
            style: textTheme.bodyMedium?.copyWith(color: palette.textPrimary),
            dropdownColor: palette.cardBackground,
            items: [
              for (final account in state.accounts)
                DropdownMenuItem<String>(
                  value: account.id,
                  child: Text(
                    account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() {
              _accountId = value ?? '';
              _error = null;
            }),
          ),
        if (_formType == TransactionType.transfer) ...[
          const SizedBox(height: 16),
          const _RecurringFieldLabel(text: '转入账户'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue:
                state.accounts.any((a) => a.id == _toAccountId) &&
                    _toAccountId != _accountId
                ? _toAccountId
                : null,
            isExpanded: true,
            decoration: _inputDecoration(palette, '选择转入账户'),
            style: textTheme.bodyMedium?.copyWith(color: palette.textPrimary),
            dropdownColor: palette.cardBackground,
            items: [
              for (final account in state.accounts)
                if (account.id != _accountId)
                  DropdownMenuItem<String>(
                    value: account.id,
                    child: Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
            ],
            onChanged: (value) => setState(() {
              _toAccountId = value ?? '';
              _error = null;
            }),
          ),
        ] else ...[
          const SizedBox(height: 16),
          const _RecurringFieldLabel(text: '分类'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: categoryValue,
            isExpanded: true,
            decoration: _inputDecoration(palette, '选择分类'),
            style: textTheme.bodyMedium?.copyWith(color: palette.textPrimary),
            dropdownColor: palette.cardBackground,
            items: [
              const DropdownMenuItem<String>(value: '', child: Text('不选分类')),
              for (final category in categories)
                DropdownMenuItem<String>(
                  value: category.id,
                  child: Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() {
              _categoryId = (value == null || value.isEmpty) ? null : value;
              _error = null;
            }),
          ),
        ],
        const SizedBox(height: 16),
        const _RecurringFieldLabel(text: '每月日期'),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          initialValue: _dayOfMonth,
          isExpanded: true,
          decoration: _inputDecoration(palette, '选择每月日期'),
          style: textTheme.bodyMedium?.copyWith(color: palette.textPrimary),
          dropdownColor: palette.cardBackground,
          items: [
            for (var day = 1; day <= 28; day++)
              DropdownMenuItem<int>(
                value: day,
                child: Text('每月 $day 日'),
              ),
          ],
          onChanged: (value) => setState(() {
            _dayOfMonth = value ?? 1;
            _error = null;
          }),
        ),
        const SizedBox(height: 10),
        if (_error != null) ...[
          _RecurringErrorText(text: _error!, palette: palette),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: 44,
          child: FilledButton(
            onPressed: _saving ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: palette.accentWarmYellow,
              foregroundColor: palette.textOnAccent,
              shape: const RoundedRectangleBorder(
                borderRadius: StreamShapes.smallCard,
              ),
            ),
            child: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.textOnAccent,
                    ),
                  )
                : Text(_editingRule == null ? '保存规则' : '保存修改'),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(StreamPalette palette, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: palette.textSecondary),
      filled: true,
      fillColor: palette.inputBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: StreamShapes.smallCard,
        borderSide: BorderSide(color: palette.hairline, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: StreamShapes.smallCard,
        borderSide: BorderSide(color: palette.hairline, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: StreamShapes.smallCard,
        borderSide: BorderSide(color: palette.accentWarmYellow, width: 1),
      ),
    );
  }
}

class _RecurringTypeCapsule extends StatelessWidget {
  const _RecurringTypeCapsule({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = StreamPalette.of(context);
    return Material(
      color: selected ? palette.accentPillBackground : palette.inputBackground,
      shape: StreamShapes.capsule,
      child: InkWell(
        customBorder: StreamShapes.capsule,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? palette.textPrimary : palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecurringFieldLabel extends StatelessWidget {
  const _RecurringFieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: StreamEditorialType.sectionLabel.copyWith(
        color: StreamPalette.of(context).textSecondary,
      ),
    );
  }
}

class _RecurringErrorText extends StatelessWidget {
  const _RecurringErrorText({required this.text, required this.palette});

  final String text;
  final StreamPalette palette;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: palette.overBudgetRed,
      ),
    );
  }
}