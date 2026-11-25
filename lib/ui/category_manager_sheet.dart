import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models.dart';
import '../design/stream_icons.dart';
import '../design/stream_shapes.dart';
import '../design/stream_theme.dart';
import '../design/stream_typography.dart';

/// 分类管理：按支出/收入分组列出分类，支持置顶、固定支出标记、
/// 新增/编辑表单与删除。由 MainScreen 在 `state.categoryManagerVisible`
/// 为真时以对话框呈现，保存成功不关闭本弹窗。
class CategoryManagerSheet extends StatefulWidget {
  const CategoryManagerSheet({super.key});

  @override
  State<CategoryManagerSheet> createState() => _CategoryManagerSheetState();
}

class _CategoryManagerSheetState extends State<CategoryManagerSheet> {
  final TextEditingController _nameController = TextEditingController();

  bool _formVisible = false;
  Category? _editingCategory;
  TransactionType _formType = TransactionType.expense;
  bool _formPinned = false;
  bool _formFixedExpense = false;
  bool _saving = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// 关闭由 `categoryManagerVisible` 驱动，MainScreen 监听状态弹掉对话框。
  void _close() {
    AppScope.of(context).closeCategoryManager();
  }

  void _startCreate() {
    setState(() {
      _formVisible = true;
      _editingCategory = null;
      _nameController.text = '';
      _formType = TransactionType.expense;
      _formPinned = false;
      _formFixedExpense = false;
      _error = null;
    });
  }

  void _startEdit(Category category) {
    setState(() {
      _formVisible = true;
      _editingCategory = category;
      _nameController.text = category.name;
      _formType = category.type;
      _formPinned = category.isPinned;
      _formFixedExpense = category.isFixedExpense;
      _error = null;
    });
  }

  void _backToList() {
    setState(() {
      _formVisible = false;
      _editingCategory = null;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    final state = AppScope.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });

    final String? error = await state.saveCategory(
      editing: _editingCategory,
      name: _nameController.text.trim(),
      type: _formType,
      isPinned: _formPinned,
      isFixedExpense: _formType == TransactionType.expense && _formFixedExpense,
    );

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    setState(() {
      _saving = false;
      _formVisible = false;
      _editingCategory = null;
      _error = null;
    });
  }

  Future<void> _togglePinned(Category category, bool pinned) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final String? error = await AppScope.of(context).saveCategory(
      editing: category,
      name: category.name,
      type: category.type,
      isPinned: pinned,
      isFixedExpense: category.isFixedExpense,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  Future<void> _toggleFixedExpense(Category category, bool fixedExpense) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final String? error = await AppScope.of(context).saveCategory(
      editing: category,
      name: category.name,
      type: category.type,
      isPinned: category.isPinned,
      isFixedExpense: fixedExpense,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  Future<void> _archive(Category category) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final String? error = await AppScope.of(context)
        .archiveCategory(category.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  static List<Category> _sortedCategoriesOf(
    List<Category> all,
    TransactionType type,
  ) {
    final items = all
        .where((category) => category.type == type && !category.isArchived)
        .toList();
    items.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return a.order.compareTo(b.order);
    });
    return items;
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
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 12, 6),
                child: Row(
                  children: [
                    if (_formVisible)
                      IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        tooltip: '返回列表',
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        onPressed: _saving ? null : _backToList,
                        icon: Icon(
                          StreamIcons.close,
                          color: palette.textSecondary,
                        ),
                      )
                    else
                      Expanded(
                        child: Text(
                          '分类管理',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: palette.textPrimary),
                        ),
                      ),
                    if (_formVisible)
                      Expanded(
                        child: Text(
                          _editingCategory == null ? '新增分类' : '编辑分类',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: palette.textPrimary),
                        ),
                      ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 20,
                      tooltip: '关闭',
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      onPressed: _close,
                      icon: Icon(
                        StreamIcons.close,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                  child: _formVisible
                      ? _buildForm(palette)
                      : _buildList(state, palette),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(AppState state, StreamPalette palette) {
    final textTheme = Theme.of(context).textTheme;
    final expenses = _sortedCategoriesOf(
      state.categories,
      TransactionType.expense,
    );
    final incomes = _sortedCategoriesOf(
      state.categories,
      TransactionType.income,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          _ErrorText(text: _error!, palette: palette),
          const SizedBox(height: 12),
        ],
        _CategoryGroup(
          title: '支出分类',
          categories: expenses,
          palette: palette,
          busy: _busy,
          onEdit: _startEdit,
          onTogglePinned: _togglePinned,
          onToggleFixedExpense: _toggleFixedExpense,
          onArchive: _archive,
        ),
        const SizedBox(height: 18),
        _CategoryGroup(
          title: '收入分类',
          categories: incomes,
          palette: palette,
          busy: _busy,
          onEdit: _startEdit,
          onTogglePinned: _togglePinned,
          onToggleFixedExpense: _toggleFixedExpense,
          onArchive: _archive,
        ),
        if (expenses.isEmpty && incomes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              '暂无分类，点击下方按钮新增',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
        const SizedBox(height: 22),
        SizedBox(
          height: 44,
          child: FilledButton(
            onPressed: _busy ? null : _startCreate,
            style: FilledButton.styleFrom(
              backgroundColor: palette.accentWarmYellow,
              foregroundColor: palette.textOnAccent,
              shape: const RoundedRectangleBorder(
                borderRadius: StreamShapes.smallCard,
              ),
            ),
            child: const Text('新增分类'),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(StreamPalette palette) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CategoryFieldLabel(text: '分类名称'),
        const SizedBox(height: 6),
        TextField(
          controller: _nameController,
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          style: textTheme.bodyMedium?.copyWith(color: palette.textPrimary),
          decoration: _inputDecoration(palette, '例如：餐饮'),
        ),
        const SizedBox(height: 16),
        const _CategoryFieldLabel(text: '类型'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _CategoryTypeCapsule(
              label: '支出',
              selected: _formType == TransactionType.expense,
              onTap: () => setState(() {
                _formType = TransactionType.expense;
                if (_error != null) _error = null;
              }),
            ),
            _CategoryTypeCapsule(
              label: '收入',
              selected: _formType == TransactionType.income,
              onTap: () => setState(() {
                _formType = TransactionType.income;
                _formFixedExpense = false;
                if (_error != null) _error = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: _formPinned,
          onChanged: (value) => setState(() => _formPinned = value),
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeThumbColor: palette.accentWarmYellow,
          title: Text(
            '置顶',
            style: textTheme.bodyMedium?.copyWith(color: palette.textPrimary),
          ),
          subtitle: Text(
            '置顶分类排在同类最前',
            style: textTheme.labelSmall?.copyWith(color: palette.textSecondary),
          ),
        ),
        if (_formType == TransactionType.expense)
          SwitchListTile(
            value: _formFixedExpense,
            onChanged: (value) => setState(() => _formFixedExpense = value),
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeThumbColor: palette.accentWarmYellow,
            title: Text(
              '固定支出',
              style: textTheme.bodyMedium?.copyWith(color: palette.textPrimary),
            ),
            subtitle: Text(
              '统计时可选择排除固定支出',
              style: textTheme.labelSmall?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
        const SizedBox(height: 10),
        if (_error != null) ...[
          _ErrorText(text: _error!, palette: palette),
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
                : Text(_editingCategory == null ? '保存分类' : '保存修改'),
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

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({
    required this.title,
    required this.categories,
    required this.palette,
    required this.busy,
    required this.onEdit,
    required this.onTogglePinned,
    required this.onToggleFixedExpense,
    required this.onArchive,
  });

  final String title;
  final List<Category> categories;
  final StreamPalette palette;
  final bool busy;
  final ValueChanged<Category> onEdit;
  final void Function(Category category, bool pinned) onTogglePinned;
  final void Function(Category category, bool fixedExpense)
  onToggleFixedExpense;
  final ValueChanged<Category> onArchive;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: StreamEditorialType.sectionLabel.copyWith(
                color: palette.textSecondary,
              ),
            ),
            Text(
              '${categories.length} 个',
              style: StreamEditorialType.sectionLabel.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (categories.isEmpty)
          Text(
            '暂无分类',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: palette.textSecondary),
          )
        else
          for (var index = 0; index < categories.length; index++) ...[
            _CategoryRow(
              category: categories[index],
              palette: palette,
              busy: busy,
              onEdit: () => onEdit(categories[index]),
              onTogglePinned: (value) =>
                  onTogglePinned(categories[index], value),
              onToggleFixedExpense: (value) =>
                  onToggleFixedExpense(categories[index], value),
              onArchive: () => onArchive(categories[index]),
            ),
            if (index != categories.length - 1)
              Container(height: 0.5, color: palette.hairline),
          ],
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.palette,
    required this.busy,
    required this.onEdit,
    required this.onTogglePinned,
    required this.onToggleFixedExpense,
    required this.onArchive,
  });

  final Category category;
  final StreamPalette palette;
  final bool busy;
  final VoidCallback onEdit;
  final ValueChanged<bool> onTogglePinned;
  final ValueChanged<bool> onToggleFixedExpense;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = _colorOfHex(category.colorHex, palette);
    final symbol = category.symbolText.isNotEmpty
        ? category.symbolText
        : category.name.substring(0, 1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onEdit,
        borderRadius: StreamShapes.tag,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: StreamShapes.tag,
                ),
                child: Text(
                  symbol,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge?.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        _CategoryToggleChip(
                          label: '置顶',
                          selected: category.isPinned,
                          enabled: !busy,
                          onTap: () => onTogglePinned(!category.isPinned),
                        ),
                        if (category.type == TransactionType.expense)
                          _CategoryToggleChip(
                            label: '固定支出',
                            selected: category.isFixedExpense,
                            enabled: !busy,
                            onTap: () =>
                                onToggleFixedExpense(!category.isFixedExpense),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                iconSize: 18,
                tooltip: '删除分类',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: busy ? null : onArchive,
                icon: Icon(StreamIcons.delete, color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryToggleChip extends StatelessWidget {
  const _CategoryToggleChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = StreamPalette.of(context);
    return Material(
      color: selected ? palette.accentPillBackground : palette.inputBackground,
      shape: StreamShapes.capsule,
      child: InkWell(
        customBorder: StreamShapes.capsule,
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? palette.textPrimary : palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryTypeCapsule extends StatelessWidget {
  const _CategoryTypeCapsule({
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

class _CategoryFieldLabel extends StatelessWidget {
  const _CategoryFieldLabel({required this.text});

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

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.text, required this.palette});

  final String text;
  final StreamPalette palette;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: palette.overBudgetRed),
    );
  }
}

/// 分类色以 `#RRGGBB` 存库；解析失败时退回次要文字色。
Color _colorOfHex(String hex, StreamPalette palette) {
  final normalized = hex.replaceFirst('#', '').trim();
  final value = int.tryParse(normalized, radix: 16);
  if (value == null || normalized.length != 6) return palette.textSecondary;
  return Color(0xFF000000 | value);
}
