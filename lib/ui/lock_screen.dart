import 'package:flutter/material.dart';

import '../app_state.dart';
import '../design/stream_shapes.dart';
import '../design/stream_theme.dart';
import '../design/stream_typography.dart';

/// 应用锁门禁：启用应用锁且尚未解锁时，用 6 位 PIN 页覆盖 [child]；
/// 切到后台时自动重新上锁（调用系统文件选择/分享面板时除外）。
///
/// [child] 始终保留在树中，锁定时仅被不透明面板遮住，解锁后无需重建整棵
/// 主界面，避免切换时丢失滚动位置与输入状态。
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState != AppLifecycleState.paused) return;
    final state = AppScope.of(context);
    if (state.lockEnabled && state.unlocked && !state.autoLockSuppressed) {
      state.lockNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final locked = state.lockEnabled && !state.unlocked;

    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(excluding: locked, child: widget.child),
        if (locked) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}

/// 6 位数字 PIN 输入页：圆点进度 + 数字键盘，输入满 6 位即校验，
/// 失败就地提示并清空输入，成功后调用 [AppState.unlock] 进入主界面。
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  static const int _pinLength = 6;
  static const double _contentMaxWidth = 340;

  String _enteredPin = '';
  String? _errorMessage;

  void _appendDigit(String digit) {
    if (_enteredPin.length >= _pinLength) return;
    setState(() {
      _enteredPin += digit;
      _errorMessage = null;
    });
    if (_enteredPin.length == _pinLength) {
      _verifyEnteredPin();
    }
  }

  void _removeLastDigit() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = null;
    });
  }

  void _clearEnteredPin() {
    if (_enteredPin.isEmpty && _errorMessage == null) return;
    setState(() {
      _enteredPin = '';
      _errorMessage = null;
    });
  }

  void _verifyEnteredPin() {
    final state = AppScope.of(context);
    if (state.verifyPin(_enteredPin)) {
      // unlock() 会通知监听者，LockGate 随即移除本页，无需再 setState。
      state.unlock();
      return;
    }
    setState(() {
      _enteredPin = '';
      _errorMessage = '密码错误，请重试';
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = StreamPalette.of(context);
    final hasError = _errorMessage != null;

    return Scaffold(
      backgroundColor: palette.paperBase,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'STREAM',
                    textAlign: TextAlign.center,
                    style: StreamEditorialType.eyebrow.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '请输入密码',
                    textAlign: TextAlign.center,
                    style: StreamEditorialType.title.copyWith(
                      fontSize: 28,
                      height: 1.15,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '输入 6 位数字密码以继续',
                    textAlign: TextAlign.center,
                    style: StreamEditorialType.subtitle.copyWith(
                      fontSize: 12,
                      letterSpacing: 1.4,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _PinDots(
                    enteredCount: _enteredPin.length,
                    totalCount: _pinLength,
                    hasError: hasError,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 20,
                    child: Text(
                      _errorMessage ?? '',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.overBudgetRed,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildKeypad(palette),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(StreamPalette palette) {
    return Column(
      children: [
        _buildKeypadRow(palette, const ['1', '2', '3']),
        const SizedBox(height: 12),
        _buildKeypadRow(palette, const ['4', '5', '6']),
        const SizedBox(height: 12),
        _buildKeypadRow(palette, const ['7', '8', '9']),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KeypadKey(
                semanticLabel: '清空输入',
                onTap: _enteredPin.isEmpty ? null : _clearEnteredPin,
                child: Text(
                  '清空',
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 1,
                    color: _enteredPin.isEmpty
                        ? palette.textSecondary.withValues(alpha: 0.4)
                        : palette.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KeypadKey(
                semanticLabel: '数字 0',
                onTap: () => _appendDigit('0'),
                child: Text(
                  '0',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KeypadKey(
                semanticLabel: '删除一位',
                onTap: _enteredPin.isEmpty ? null : _removeLastDigit,
                child: Icon(
                  Icons.backspace_outlined,
                  size: 22,
                  color: _enteredPin.isEmpty
                      ? palette.textSecondary.withValues(alpha: 0.4)
                      : palette.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadRow(StreamPalette palette, List<String> digits) {
    return Row(
      children: [
        for (var index = 0; index < digits.length; index++) ...[
          if (index > 0) const SizedBox(width: 12),
          Expanded(
            child: _KeypadKey(
              semanticLabel: '数字 ${digits[index]}',
              onTap: () => _appendDigit(digits[index]),
              child: Text(
                digits[index],
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  color: palette.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({
    required this.enteredCount,
    required this.totalCount,
    required this.hasError,
  });

  final int enteredCount;
  final int totalCount;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final palette = StreamPalette.of(context);
    final filledColor = hasError ? palette.overBudgetRed : palette.textPrimary;
    final emptyBorderColor =
        hasError ? palette.overBudgetRed : palette.hairline;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < totalCount; index++)
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index < enteredCount
                  ? filledColor
                  : Colors.transparent,
              border: Border.all(color: emptyBorderColor, width: 1.2),
            ),
          ),
      ],
    );
  }
}

class _KeypadKey extends StatelessWidget {
  const _KeypadKey({
    required this.semanticLabel,
    required this.onTap,
    required this.child,
  });

  final String semanticLabel;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = StreamPalette.of(context);

    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: onTap != null,
      child: Material(
        color: onTap == null
            ? palette.inputBackground.withValues(alpha: 0.5)
            : palette.inputBackground,
        shape: const RoundedRectangleBorder(
          borderRadius: StreamShapes.smallCard,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(height: 60, child: Center(child: child)),
        ),
      ),
    );
  }
}