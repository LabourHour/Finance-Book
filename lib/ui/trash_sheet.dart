import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models.dart';
import '../design/stream_icons.dart';
import '../design/stream_shapes.dart';
import '../design/stream_theme.dart';
import '../design/stream_typography.dart';
import '../widgets/editorial.dart';

/// 回收站：列出软删除的账单，支持单条恢复或彻底删除，两者均需二次确认。
/// 由 MainScreen 在 `state.trashVisible` 为真时以对话框呈现。
class TrashSheet extends StatefulWidget {
  const TrashSheet({super.key});

  @override
  State<TrashSheet> createState() => _TrashSheetState();
}

class _TrashSheetState extends State<TrashSheet> {
  static const double _maxHeight = 560;

  bool _reloadRequested = false;
  bool _busy = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reloadRequested) return;
    _reloadRequested = true;
    final state = AppScope.of(context);
    // 打开时主动刷新，避免展示上次遗留的快照；放到帧末，避开 build 期间的 notify。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) state.reloadTrash();
    });
  }

  /// 关闭由 `trashVisible` 驱动，MainScreen 监听状态弹掉对话框。
  void _close() {
    AppScope.of(context).closeTrash();
  }

  Future<bool> _confirm({
    required String title,
    required String content,
    required String confirmLabel,
    required bool destructive,
  }) async {
    final palette = StreamPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.cardBackground,
        title: Text(
          title,
          style: textTheme.titleMedium?.copyWith(color: palette.textPrimary),
        ),
        content: Text(
          content,
          style: textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('取消', style: TextStyle(color: palette.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: destructive ? palette.overBudgetRed : palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _restore(LedgerTransaction transaction) async {
    if (_busy) return;
    final confirmed = await _confirm(
      title: '恢复这条账单？',
      content: '「${_describe(transaction)}」将重新计入账本。',
      confirmLabel: '恢复',
      destructive: false,
    );
    if (!confirmed || !mounted) return;
    await _run(() => AppScope.of(context).restoreTrashed(transaction));
  }

  Future<void> _purge(LedgerTransaction transaction) async {
    if (_busy) return;
    final confirmed = await _confirm(
      title: '彻底删除这条账单？',
      content: '「${_describe(transaction)}」将被永久删除，无法恢复。',
      confirmLabel: '彻底删除',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run(() => AppScope.of(context).purgeTrashed(transaction));
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final String? error = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  String _describe(LedgerTransaction transaction) {
    final note = transaction.note?.trim();
    if (note != null && note.isNotEmpty) return note;
    if (transaction.type == TransactionType.transfer) return '转账';
    final category = _categoryOf(AppScope.of(context), transaction.categoryId);
    return category?.name ?? '未分类账单';
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
        constraints: const BoxConstraints(
          maxWidth: 420,
          maxHeight: _maxHeight,
        ),
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
                    Expanded(
                      child: Text(
                        '回收站',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: palette.textPrimary,
                        ),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(
                  '已删除的账单保留在此，可恢复或彻底删除。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: _buildBody(state, palette),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppState state, StreamPalette palette) {
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ErrorText(text: _error!, palette: palette),
          const SizedBox(height: 12),
          ..._buildRows(state, palette),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _buildRows(state, palette),
    );
  }

  List<Widget> _buildRows(AppState state, StreamPalette palette) {
    final transactions = state.deletedTransactions;
    if (transactions.isEmpty) {
      return <Widget>[_TrashEmptyState(palette: palette)];
    }
    return <Widget>[
      for (var index = 0; index < transactions.length; index++) ...[
        _TrashRow(
          transaction: transactions[index],
          title: _describe(transactions[index]),
          subtitle: '删除于 ${_formatDateTime(transactions[index].deletedAt)}',
          palette: palette,
          busy: _busy,
          onRestore: () => _restore(transactions[index]),
          onPurge: () => _purge(transactions[index]),
        ),
        if (index != transactions.length - 1) const EditorialHairline(),
      ],
    ];
  }
}

Category? _categoryOf(AppState state, String? categoryId) {
  if (categoryId == null) return null;
  for (final category in state.categories) {
    if (category.id == categoryId) return category;
  }
  return null;
}

String _formatDateTime(int millisecondsSinceEpoch) {
  final date = DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
  return '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)} '
      '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

class _TrashRow extends StatelessWidget {
  const _TrashRow({
    required this.transaction,
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.busy,
    required this.onRestore,
    required this.onPurge,
  });

  final LedgerTransaction transaction;
  final String title;
  final String subtitle;
  final StreamPalette palette;
  final bool busy;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  @override
  Widget build(BuildContext context) {
    final isTransfer = transaction.type == TransactionType.transfer;
    final amountColor = switch (transaction.type) {
      TransactionType.expense => palette.textPrimary,
      TransactionType.income => palette.incomeGreen,
      TransactionType.transfer => palette.textSecondary,
    };
    final signedCents = transaction.type == TransactionType.expense
        ? -transaction.amount
        : transaction.amount;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.inputBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  StreamIcons.delete,
                  size: 18,
                  color: palette.textSecondary,
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
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: palette.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
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
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: busy ? null : onRestore,
                child: Text(
                  '恢复',
                  style: TextStyle(color: palette.textPrimary),
                ),
              ),
              TextButton(
                onPressed: busy ? null : onPurge,
                child: Text(
                  '彻底删除',
                  style: TextStyle(color: palette.overBudgetRed),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrashEmptyState extends StatelessWidget {
  const _TrashEmptyState({required this.palette});

  final StreamPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: <Widget>[
          Icon(StreamIcons.delete, size: 28, color: palette.textSecondary),
          const SizedBox(height: 12),
          Text(
            '回收站是空的',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '删除的账单会先放到这里，再也不会丢。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
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
      style: StreamEditorialType.sectionLabel.copyWith(
        color: palette.overBudgetRed,
      ),
    );
  }
}