import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/money.dart';
import '../data/models.dart';
import '../design/stream_icons.dart';
import '../design/stream_shapes.dart';
import '../design/stream_theme.dart';
import '../design/stream_typography.dart';

/// 账户编辑器：由 MainScreen 在 `state.accountEditorVisible` 为真时以对话框呈现。
/// 新建或编辑目标账户由 `state.editingAccount` 决定，本组件只负责字段与提交。
class AccountEditorSheet extends StatefulWidget {
  const AccountEditorSheet({super.key});

  @override
  State<AccountEditorSheet> createState() => _AccountEditorSheetState();
}

class _AccountEditorSheetState extends State<AccountEditorSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();
  AccountType _type = AccountType.wechat;
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final editing = AppScope.of(context).editingAccount;
    if (editing == null) return;
    _nameController.text = editing.name;
    _type = editing.type;
    _balanceController.text = _balanceInputOf(editing.initialBalance);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  /// `centsToDisplayInput` 不处理负数，信用卡初始欠款需要自行补上负号。
  String _balanceInputOf(int cents) {
    if (cents >= 0) return ArithmeticParser.centsToDisplayInput(cents);
    return '-${ArithmeticParser.centsToDisplayInput(-cents)}';
  }

  int _parsedInitialBalance() {
    final raw = _balanceController.text.trim();
    if (raw.isEmpty) return 0;
    return ArithmeticParser.parseNumberToCents(raw);
  }

  /// 关闭由 `accountEditorVisible` 驱动，MainScreen 监听状态弹掉对话框；
  /// 这里不额外 pop，避免与监听逻辑重复关闭路由。
  void _close() {
    AppScope.of(context).closeAccountEditor();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final state = AppScope.of(context);
    final editing = state.editingAccount;
    setState(() {
      _saving = true;
      _error = null;
    });

    final name = _nameController.text.trim();
    final initialBalance = _parsedInitialBalance();
    final String? error = editing == null
        ? await state.createAccount(
            name: name,
            type: _type,
            initialBalance: initialBalance,
          )
        : await state.updateAccountMeta(
            id: editing.id,
            name: name,
            type: _type,
            initialBalance: initialBalance,
          );

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    // 成功时 AppState 已 closeAccountEditor，保持 _saving 为真直到对话框被移除。
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final palette = StreamPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isEditing = state.editingAccount != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          color: palette.cardBackground,
          borderRadius: StreamShapes.mainCard,
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEditing ? '编辑账户' : '新建账户',
                        style: textTheme.titleLarge?.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      padding: const EdgeInsets.all(6),
                      iconSize: 20,
                      tooltip: '关闭',
                      constraints:
                          const BoxConstraints.tightFor(width: 44, height: 44),
                      onPressed: _close,
                      icon: Icon(
                        StreamIcons.close,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _FieldLabel(text: '账户名称'),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  style: textTheme.bodyMedium?.copyWith(
                    color: palette.textPrimary,
                  ),
                  decoration: _inputDecoration(palette, '例如：招商银行'),
                ),
                const SizedBox(height: 18),
                const _FieldLabel(text: '账户类型'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in AccountType.values)
                      _TypeCapsule(
                        label: accountTypeDisplayName(type),
                        selected: _type == type,
                        onTap: () => setState(() => _type = type),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const _FieldLabel(text: '初始余额'),
                const SizedBox(height: 6),
                TextField(
                  controller: _balanceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  style: textTheme.bodyMedium?.copyWith(
                    color: palette.textPrimary,
                  ),
                  decoration: _inputDecoration(
                    palette,
                    '0.00，欠款可填负数',
                  ).copyWith(prefixText: '${MoneyFormat.symbol} '),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _error!,
                      style: textTheme.labelSmall?.copyWith(
                        color: palette.overBudgetRed,
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
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
                        : Text(isEditing ? '保存修改' : '添加账户'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

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

class _TypeCapsule extends StatelessWidget {
  const _TypeCapsule({
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

/// 账户类型中文名，编辑器与资产页共用。
String accountTypeDisplayName(AccountType type) {
  switch (type) {
    case AccountType.wechat:
      return '微信';
    case AccountType.alipay:
      return '支付宝';
    case AccountType.bank:
      return '银行卡';
    case AccountType.credit:
      return '信用卡';
    case AccountType.cash:
      return '现金';
    case AccountType.other:
      return '其他';
  }
}