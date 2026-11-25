import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../data/models.dart';
import '../design/stream_icons.dart';
import '../design/stream_shapes.dart';
import '../design/stream_theme.dart';

/// 设置与数据面板：回收站/预算/周期记账入口、CSV 与加密备份、应用锁与清理演示数据。
/// 可见性由外部（MainScreen）决定，本组件只负责内容与 AppState 调用。
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  bool _busy = false;
  String? _message;

  void _setMessage(String text) {
    if (!mounted) return;
    setState(() => _message = text);
  }

  /// 关闭由 `settingsVisible` 驱动，MainScreen 监听状态弹掉对话框；
  /// 这里不额外 pop，避免与监听逻辑重复关闭路由。
  void _close() {
    AppScope.of(context).closeSettings();
  }

  /// 串行执行面板内的数据操作：避免重复点击，并把异常转成面板内的提示文案。
  Future<void> _run(
    String failurePrefix,
    Future<void> Function(AppState state) action,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    final state = AppScope.of(context);
    try {
      await action(state);
    } catch (e) {
      _setMessage('$failurePrefix：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 二次确认：破坏性操作（清理演示数据、恢复备份）必须显式同意后才继续。
  Future<bool> _confirm({
    required String title,
    required String content,
    required String confirmLabel,
  }) async {
    final colors = StreamPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.cardBackground,
        title: Text(
          title,
          style: textTheme.titleMedium?.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          content,
          style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              '取消',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              confirmLabel,
              style: TextStyle(color: colors.overBudgetRed),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _openCategoryManager() {
    AppScope.of(context).openCategoryManager();
  }

  void _openTrash() {
    AppScope.of(context).openTrash();
  }

  void _openBudget() {
    AppScope.of(context).openBudget();
  }

  void _openRecurring() {
    AppScope.of(context).openRecurring();
  }

  Future<void> _clearSampleData() async {
    final confirmed = await _confirm(
      title: '清理历史演示数据',
      content: '将删除内置示例流水与未被引用的示例账户，是否继续？',
      confirmLabel: '继续清理',
    );
    if (!confirmed || !mounted) return;
    await _run('清除失败', (state) async {
      final ClearSampleResult result = await state.clearSampleData();
      final buffer = StringBuffer('已清除 ${result.deletedTransactions} 条演示流水');
      if (result.removedAccounts > 0) {
        buffer.write('，移除 ${result.removedAccounts} 个示例账户');
      }
      if (result.keptAccounts > 0) {
        buffer.write('，保留 ${result.keptAccounts} 个仍被使用的示例账户');
      }
      _setMessage(buffer.toString());
    });
  }

  /// 写入应用文档目录并交给系统分享面板；文件名带秒级时间戳避免覆盖。
  Future<void> _saveAndShare({
    required String content,
    required String fileNamePrefix,
    required String extension,
    required String mimeType,
    required String subject,
    required String successPrefix,
  }) async {
    final state = AppScope.of(context);
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final file = File(
      p.join(directory.path, '${fileNamePrefix}_$timestamp.$extension'),
    );
    await file.writeAsString(content, flush: true);
    await state.runWithoutAutoLock(
      () => Share.shareXFiles(
        [XFile(file.path, mimeType: mimeType)],
        subject: subject,
      ),
    );
    _setMessage('$successPrefix：${p.basename(file.path)}');
  }

  Future<void> _exportCsv() async {
    await _run('导出失败', (state) async {
      final csv = await state.exportCsv();
      await _saveAndShare(
        content: csv,
        fileNamePrefix: 'stream_ledger',
        extension: 'csv',
        mimeType: 'text/csv',
        subject: 'Stream 账单 CSV',
        successPrefix: 'CSV 导出成功',
      );
    });
  }

  Future<void> _exportJson() async {
    await _run('导出失败', (state) async {
      final json = await state.exportBackup();
      await _saveAndShare(
        content: json,
        fileNamePrefix: 'stream_backup',
        extension: 'json',
        mimeType: 'application/json',
        subject: 'Stream 账单备份',
        successPrefix: '备份导出成功',
      );
    });
  }

  Future<void> _exportEncryptedBackup() async {
    final password = await _promptPassword(
      title: '设置备份口令',
      description: '口令用于加密整份备份，恢复时必须输入同一口令。',
    );
    if (password == null || !mounted) return;
    final confirmation = await _promptPassword(
      title: '确认备份口令',
      description: '再次输入相同口令，避免录错后无法恢复。',
    );
    if (confirmation == null || !mounted) return;
    if (password != confirmation) {
      _setMessage('两次输入的口令不一致');
      return;
    }

    await _run('加密备份失败', (state) async {
      final json = await state.exportEncryptedBackup(password);
      await _saveAndShare(
        content: json,
        fileNamePrefix: 'stream_backup_encrypted',
        extension: 'json',
        mimeType: 'application/json',
        subject: 'Stream 加密账单备份',
        successPrefix: '加密备份导出成功',
      );
    });
  }

  Future<void> _restoreJson() async {
    await _run('恢复失败', (state) async {
      final picked = await state.runWithoutAutoLock(
        () => FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['json'],
        ),
      );
      final path = picked?.files.single.path;
      if (path == null || path.isEmpty || !mounted) return;

      final confirmed = await _confirm(
        title: '恢复 JSON 备份',
        content: '将清空并替换当前全部账单，是否继续？',
        confirmLabel: '继续恢复',
      );
      if (!confirmed || !mounted) return;

      String content;
      try {
        content = await File(path).readAsString();
      } catch (e) {
        _setMessage('读取文件失败：$e');
        return;
      }

      var password = '';
      if (_isEncryptedBackup(content)) {
        final input = await _promptPassword(
          title: '输入备份口令',
          description: '该备份已加密，请输入导出时设置的口令。',
        );
        if (input == null || !mounted) return;
        password = input;
      }

      final RestoreResult result =
          await state.restoreBackupWithPassword(content, password);
      if (!result.ok) {
        _setMessage('恢复失败：${result.error ?? '未知错误'}');
        return;
      }
      _setMessage('成功恢复 ${result.count} 条账单');
    });
  }

  static bool _isEncryptedBackup(String content) {
    try {
      final decoded = jsonDecode(content);
      return decoded is Map && decoded['encrypted'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _manageLock() async {
    final state = AppScope.of(context);
    if (!state.lockEnabled) {
      final pin = await _promptPin(
        title: '启用应用锁',
        description: '设置 6 位数字密码，冷启动时需要输入。',
      );
      if (pin == null || !mounted) return;
      final confirmation = await _promptPin(
        title: '确认密码',
        description: '再次输入相同的 6 位数字密码。',
      );
      if (confirmation == null || !mounted) return;
      if (pin != confirmation) {
        _setMessage('两次输入的密码不一致');
        return;
      }

      await _run('启用失败', (state) async {
        final error = await state.enableLock(pin);
        _setMessage(error == null ? '应用锁已启用' : '启用失败：$error');
      });
      return;
    }

    final action = await _promptLockAction();
    if (action == null || !mounted) return;
    if (action == _LockAction.changePin) {
      await _changeLockPin(state);
    } else {
      await _disableLock(state);
    }
  }

  Future<void> _changeLockPin(AppState state) async {
    final currentPin = await _promptPin(
      title: '验证当前密码',
      description: '请输入当前 6 位数字密码。',
    );
    if (currentPin == null || !mounted) return;
    if (!state.verifyPin(currentPin)) {
      _setMessage('密码错误');
      return;
    }

    final newPin = await _promptPin(
      title: '设置新密码',
      description: '请输入新的 6 位数字密码。',
    );
    if (newPin == null || !mounted) return;
    final confirmation = await _promptPin(
      title: '确认新密码',
      description: '再次输入新的 6 位数字密码。',
    );
    if (confirmation == null || !mounted) return;
    if (newPin != confirmation) {
      _setMessage('两次输入的密码不一致');
      return;
    }

    await _run('修改失败', (state) async {
      final error = await state.enableLock(newPin);
      _setMessage(error == null ? '应用锁密码已修改' : '修改失败：$error');
    });
  }

  Future<void> _disableLock(AppState state) async {
    final currentPin = await _promptPin(
      title: '关闭应用锁',
      description: '输入当前 6 位数字密码以关闭应用锁。',
    );
    if (currentPin == null || !mounted) return;

    await _run('关闭失败', (state) async {
      final error = await state.disableLock(currentPin);
      _setMessage(error == null ? '应用锁已关闭' : '关闭失败：$error');
    });
  }

  Future<_LockAction?> _promptLockAction() {
    final colors = StreamPalette.of(context);
    final textTheme = Theme.of(context).textTheme;
    return showDialog<_LockAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.cardBackground,
        title: Text(
          '应用锁已启用',
          style: textTheme.titleMedium?.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          '冷启动时需要输入 6 位数字密码。',
          style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('取消', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_LockAction.disable),
            child: Text(
              '关闭应用锁',
              style: TextStyle(color: colors.overBudgetRed),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_LockAction.changePin),
            child: Text(
              '修改密码',
              style: TextStyle(color: colors.accentWarmYellow),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptPassword({
    required String title,
    required String description,
  }) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _TextPromptDialog(
        title: title,
        description: description,
        obscureText: true,
        validate: (input) => input.isEmpty ? '请输入口令' : null,
      ),
    );
    if (value == null || !mounted) return null;
    return value;
  }

  Future<String?> _promptPin({
    required String title,
    required String description,
  }) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _TextPromptDialog(
        title: title,
        description: description,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
        ],
        validate: (input) =>
            RegExp(r'^\d{6}$').hasMatch(input) ? null : '请输入 6 位数字密码',
      ),
    );
    if (value == null || !mounted) return null;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final colors = StreamPalette.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          color: colors.cardBackground,
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
                        '设置与数据',
                        style: textTheme.titleLarge?.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        tooltip: '关闭',
                        onPressed: _close,
                        icon: Icon(
                          StreamIcons.close,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SettingsAction(
                  icon: StreamIcons.delete,
                  iconColor: colors.textSecondary,
                  title: '回收站',
                  titleColor: colors.textPrimary,
                  subtitle: '恢复或彻底删除已移除的账单',
                  onTap: _busy ? null : _openTrash,
                ),
                const SizedBox(height: 10),
                _SettingsAction(
                  icon: StreamIcons.analytics,
                  iconColor: colors.accentWarmYellow,
                  title: '月度预算',
                  titleColor: colors.textPrimary,
                  subtitle: '设置本月支出上限，账单页展示执行进度',
                  onTap: _busy ? null : _openBudget,
                ),
                const SizedBox(height: 10),
                _SettingsAction(
                  icon: StreamIcons.timeline,
                  iconColor: colors.incomeGreen,
                  title: '周期记账',
                  titleColor: colors.textPrimary,
                  subtitle: '每月固定日期自动生成账单',
                  onTap: _busy ? null : _openRecurring,
                ),
                const SizedBox(height: 10),
                _SettingsAction(
                  icon: StreamIcons.timeline,
                  iconColor: colors.accentWarmYellow,
                  title: '分类管理',
                  titleColor: colors.textPrimary,
                  subtitle: '新增、改名、置顶与固定支出标记',
                  onTap: _busy ? null : _openCategoryManager,
                ),
                const SizedBox(height: 10),
                _SettingsAction(
                  icon: StreamIcons.exportFile,
                  iconColor: colors.accentWarmYellow,
                  title: '导出 CSV',
                  titleColor: colors.textPrimary,
                  subtitle: '表格格式，含日期、类型、金额、账户与分类',
                  onTap: _busy ? null : _exportCsv,
                ),
                const SizedBox(height: 10),
                _SettingsAction(
                  icon: StreamIcons.exportFile,
                  iconColor: colors.accentWarmYellow,
                  title: '导出 JSON 全量备份',
                  titleColor: colors.textPrimary,
                  subtitle: '排除示例数据，包含 schemaVersion 校验',
                  onTap: _busy ? null : _exportJson,
                ),
                const SizedBox(height: 10),
                _SettingsAction(
                  icon: StreamIcons.shield,
                  iconColor: colors.incomeGreen,
                  title: '加密备份',
                  titleColor: colors.textPrimary,
                  subtitle: '设置口令并用 PBKDF2 + AES-256 加密导出',
                  onTap: _busy ? null : _exportEncryptedBackup,
                ),
                const SizedBox(height: 10),
                _SettingsAction(
                  icon: StreamIcons.importFile,
                  iconColor: colors.textPrimary,
                  title: '恢复 JSON 备份',
                  titleColor: colors.textPrimary,
                  subtitle: '支持明文与加密备份，在事务中原子写入',
                  onTap: _busy ? null : _restoreJson,
                ),
                const SizedBox(height: 10),
                _SettingsAction(
                  icon: Icons.lock_outline_rounded,
                  iconColor: colors.textPrimary,
                  title: '应用锁',
                  titleColor: colors.textPrimary,
                  subtitle: state.lockEnabled
                      ? '已启用 · 点击修改密码或关闭'
                      : '未启用 · 启动与切回应用需输入 6 位密码',
                  onTap: _busy ? null : _manageLock,
                ),
                const SizedBox(height: 10),
                _ThemeModeCard(
                  selected: state.themeMode,
                  onChanged: _busy ? null : state.setThemeMode,
                ),
                const SizedBox(height: 10),
                _SettingsAction(
                  icon: StreamIcons.delete,
                  iconColor: colors.overBudgetRed,
                  title: '清理历史演示数据',
                  titleColor: colors.overBudgetRed,
                  subtitle: '清空内置 sample 流水，保留真实账目与默认分类',
                  onTap: _busy ? null : _clearSampleData,
                ),
                if (_message != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _message!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.accentWarmYellow,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Container(height: 0.5, color: colors.hairline),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      StreamIcons.shield,
                      size: 14,
                      color: colors.incomeGreen,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '无 INTERNET 权限 · 纯本地私密存储',
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.textSecondary,
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
}

class _ThemeModeCard extends StatelessWidget {
  const _ThemeModeCard({
    required this.selected,
    required this.onChanged,
  });

  final ThemeMode selected;
  final ValueChanged<ThemeMode>? onChanged;

  static const List<(ThemeMode, String)> _options = <(ThemeMode, String)>[
    (ThemeMode.system, '跟随系统'),
    (ThemeMode.light, '浅色纸张'),
    (ThemeMode.dark, '深色碳素'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = StreamPalette.of(context);
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.paperBase,
        borderRadius: StreamShapes.smallCard,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined, color: colors.textSecondary),
                const SizedBox(width: 12),
                Text(
                  '外观主题',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < _options.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _ThemeOptionPill(
                      label: _options[i].$2,
                      isSelected: selected == _options[i].$1,
                      onTap: onChanged == null
                          ? null
                          : () => onChanged!(_options[i].$1),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOptionPill extends StatelessWidget {
  const _ThemeOptionPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = StreamPalette.of(context);
    return Material(
      color: isSelected ? colors.accentWarmYellow : colors.cardBackground,
      borderRadius: StreamShapes.tag,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color:
                      isSelected ? colors.textOnAccent : colors.textSecondary,
                ),
          ),
        ),
      ),
    );
  }
}

enum _LockAction { changePin, disable }

/// 口令 / PIN 输入：校验失败就地显示错误，确认后才 pop 出输入值。
class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.description,
    required this.validate,
    this.obscureText = false,
    this.keyboardType,
    this.maxLength,
    this.inputFormatters,
  });

  final String title;
  final String description;
  final String? Function(String input) validate;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final input = _controller.text;
    final error = widget.validate(input);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    Navigator.of(context).pop(input);
  }

  @override
  Widget build(BuildContext context) {
    final colors = StreamPalette.of(context);
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      backgroundColor: colors.cardBackground,
      title: Text(
        widget.title,
        style: textTheme.titleMedium?.copyWith(color: colors.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.description,
            style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            maxLength: widget.maxLength,
            inputFormatters: widget.inputFormatters,
            style: TextStyle(color: colors.textPrimary),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: colors.inputBackground,
              errorText: _errorText,
              border: const OutlineInputBorder(
                borderRadius: StreamShapes.tag,
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('取消', style: TextStyle(color: colors.textSecondary)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            '确定',
            style: TextStyle(color: colors.accentWarmYellow),
          ),
        ),
      ],
    );
  }
}

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.titleColor,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Color titleColor;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = StreamPalette.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colors.paperBase,
      borderRadius: StreamShapes.smallCard,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.bodyLarge?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}