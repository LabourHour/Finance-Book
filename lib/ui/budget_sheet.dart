import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/money.dart';
import '../design/stream_icons.dart';
import '../design/stream_shapes.dart';
import '../design/stream_theme.dart';
import '../design/stream_typography.dart';

/// 月度总预算设置弹窗：输入金额后保存，或清除本月预算。
/// 由 MainScreen 在 `state.budgetVisible` 为真时以对话框呈现；
/// 保存成功时 AppState 会自行关闭弹窗，本组件只负责输入与提交。
class BudgetSheet extends StatefulWidget {
  const BudgetSheet({super.key});

  @override
  State<BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<BudgetSheet> {
  final TextEditingController _amountController = TextEditingController();
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final budget = AppScope.of(context).budget;
    _amountController.text = ArithmeticParser.centsToDisplayInput(
      budget?.totalBudget ?? 0,
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _close() {
    AppScope.of(context).closeBudget();
  }

  Future<void> _submit() async {
    final raw = _amountController.text.trim();
    final cents = raw.isEmpty
        ? 0
        : ArithmeticParser.parseNumberToCents(raw);
    await _persist(cents);
  }

  Future<void> _clear() => _persist(0);

  Future<void> _persist(int totalBudgetCents) async {
    if (_saving) return;
    final state = AppScope.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });

    final String? error = await state.saveMonthlyBudget(totalBudgetCents);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    // 成功时 AppState 已 closeBudget，保持 _saving 为真直到对话框被移除。
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final palette = StreamPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final hasBudget = (state.budget?.totalBudget ?? 0) > 0;

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
                        '月度预算',
                        style: textTheme.titleLarge?.copyWith(
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      padding: const EdgeInsets.all(6),
                      iconSize: 20,
                      tooltip: '关闭',
                      constraints: const BoxConstraints.tightFor(
                        width: 44,
                        height: 44,
                      ),
                      onPressed: _close,
                      icon: Icon(StreamIcons.close, color: palette.textSecondary),
                    ),
                  ],
                ),
                Text(
                  '${state.selectedYear} 年 ${state.selectedMonth} 月 · 已花 '
                  '${MoneyFormat.formatPlain(state.monthExpenseCents)}',
                  style: StreamEditorialType.sectionLabel.copyWith(
                    fontSize: 11,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w400,
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '本月预算总额',
                  style: StreamEditorialType.sectionLabel.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  style: textTheme.bodyMedium?.copyWith(
                    color: palette.textPrimary,
                  ),
                  decoration:
                      _inputDecoration(palette, '例如：3000').copyWith(
                    prefixText: '${MoneyFormat.symbol} ',
                  ),
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
                Row(
                  children: [
                    if (hasBudget) ...[
                      SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: _saving ? null : _clear,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.textSecondary,
                            side: BorderSide(color: palette.hairline),
                            shape: const RoundedRectangleBorder(
                              borderRadius: StreamShapes.smallCard,
                            ),
                          ),
                          child: const Text('清除'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: SizedBox(
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
                              : const Text('保存'),
                        ),
                      ),
                    ),
                  ],
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