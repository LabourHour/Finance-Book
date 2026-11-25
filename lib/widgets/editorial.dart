import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'package:stream_ledger/core/money.dart';
import 'package:stream_ledger/design/stream_icons.dart';
import 'package:stream_ledger/design/stream_theme.dart';
import 'package:stream_ledger/design/stream_typography.dart';

/// C 编辑风通用页头：衬线斜体大标题 + 宽字距眉题 + 右侧操作区。
class EditorialHeader extends StatelessWidget {
  const EditorialHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.actions = const <Widget>[],
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final palette = StreamPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 14, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: StreamEditorialType.eyebrow.copyWith(
                    color: palette.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: StreamEditorialType.title.copyWith(
                    color: palette.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle,
                    style: StreamEditorialType.subtitle.copyWith(
                      color: palette.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: actions,
          ),
        ],
      ),
    );
  }
}

class EditorialSectionLabel extends StatelessWidget {
  const EditorialSectionLabel({super.key, required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = StreamPalette.of(context);
    final style = StreamEditorialType.sectionLabel.copyWith(
      color: palette.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 22, 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: style),
          if (trailing != null) Text(trailing!, style: style),
        ],
      ),
    );
  }
}

class EditorialHairline extends StatelessWidget {
  const EditorialHairline({super.key, this.startPadding = 72});

  final double startPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: startPadding),
      child: SizedBox(
        width: double.infinity,
        height: 0.5,
        child: ColoredBox(color: StreamPalette.of(context).hairline),
      ),
    );
  }
}

/// 深色主卡（hero / 账户主卡），统一圆角与内边距。
class EditorialDeepCard extends StatelessWidget {
  const EditorialDeepCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = StreamPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.deepSurface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.hairline, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [child],
      ),
    );
  }
}

/// 大数字金额：整数 Light(300)，符号与小数小一号、取次要色。
class AmountText extends StatelessWidget {
  const AmountText({
    super.key,
    required this.cents,
    this.integerSize = 28,
    this.showSign = false,
    this.showSymbol = true,
    this.color,
    this.secondaryColor,
  });

  final int cents;
  final double integerSize;
  final bool showSign;
  final bool showSymbol;
  final Color? color;
  final Color? secondaryColor;

  @override
  Widget build(BuildContext context) {
    final palette = StreamPalette.of(context);
    final parts = MoneyFormat.formatParts(cents, showSign: showSign);
    final primaryColor = color ?? palette.textPrimary;
    final mutedColor = secondaryColor ?? palette.textSecondary;
    final symbolSize = integerSize * 0.65;
    final decimalSize = integerSize * 0.72;
    const tabular = <FontFeature>[FontFeature.tabularFigures()];

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (parts.prefix.isNotEmpty)
          Text(
            parts.prefix,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: symbolSize,
              color: primaryColor,
            ),
          ),
        if (showSymbol)
          Text(
            MoneyFormat.symbol,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: symbolSize,
              color: mutedColor,
            ),
          ),
        Text(
          parts.integerString,
          style: TextStyle(
            fontWeight: FontWeight.w300,
            fontSize: integerSize,
            color: primaryColor,
            fontFeatures: tabular,
          ),
        ),
        Text(
          parts.decimalString,
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: decimalSize,
            color: mutedColor,
            fontFeatures: tabular,
          ),
        ),
      ],
    );
  }
}

/// 208×56 磨砂玻璃悬浮胶囊，暖黄指示器随连续页码平移。
class EditorialDock extends StatefulWidget {
  const EditorialDock({
    super.key,
    required this.selectedTab,
    required this.onSelect,
    this.progress,
    this.onScrubUpdate,
    this.onScrubEnd,
  });

  final int selectedTab;
  final ValueChanged<int> onSelect;

  /// 0..2 连续页码；为 null 时吸附到 [selectedTab]。
  final double? progress;

  /// 手指在岛内水平拖动时的连续页码（0..2）。
  final ValueChanged<double>? onScrubUpdate;

  /// 松手：最终页码 + 像素/秒速度。
  final void Function(double page, double velocity)? onScrubEnd;

  static const double _width = 208;
  static const double _height = 56;
  static const double _radius = 28;
  static const double _indicatorHeight = 52;
  static const double _horizontalPadding = 12;
  static const double _indicatorInset = 2.5;
  static const int _itemCount = 3;
  static const double _slotWidth =
      (_width - _horizontalPadding * 2) / _itemCount;
  static const double _indicatorWidth = _slotWidth - _indicatorInset * 2;
  static const double _maxStretch = 6;
  static const List<_DockItem> _items = <_DockItem>[
    _DockItem(0, '账单', StreamIcons.timeline),
    _DockItem(1, '统计', StreamIcons.analytics),
    _DockItem(2, '资产', StreamIcons.assets),
  ];

  @override
  State<EditorialDock> createState() => _EditorialDockState();
}

class _EditorialDockState extends State<EditorialDock>
    with TickerProviderStateMixin {
  static const SpringDescription _spring = SpringDescription(
    mass: 1,
    stiffness: 320,
    damping: 30,
  );
  static const Tolerance _springTolerance = Tolerance(
    distance: 0.001,
    velocity: 0.001,
  );
  static const double _maxOvershootPixels = 2.0;
  static const Duration _pressDownDuration = Duration(milliseconds: 120);
  static const Duration _pressReleaseDuration = Duration(milliseconds: 160);
  static const Duration _rapidProgressWindow = Duration(milliseconds: 120);

  late final AnimationController _positionSpring;
  late final AnimationController _pressController;
  late final AnimationController _stretchSpring;
  late final Listenable _indicatorRepaint;

  /// 归一化位置：0 = [_fromPage]，1 = [_toPage]，允许轻微过冲。
  double _fromPage = 0;
  double _toPage = 0;

  /// 拖动中直接跟手的页码。
  final ValueNotifier<double> _livePage = ValueNotifier<double>(0);

  /// 拖动中按手指速度产生的拉伸像素。
  final ValueNotifier<double> _liveStretch = ValueNotifier<double>(0);

  double _stretchFrom = 0;
  bool _scrubbing = false;
  bool _pressed = false;
  int? _scrubSnapIndex;
  DateTime? _lastProgressChangeAt;
  Duration? _lastDragTimestamp;
  double? _lastDragX;

  @override
  void initState() {
    super.initState();
    final start = _targetPage;
    _fromPage = start;
    _toPage = start;
    _livePage.value = start;
    _positionSpring = AnimationController.unbounded(vsync: this)..value = 1;
    _pressController = AnimationController(
      vsync: this,
      duration: _pressDownDuration,
    );
    _stretchSpring = AnimationController.unbounded(vsync: this);
    _indicatorRepaint = Listenable.merge(<Listenable>[
      _positionSpring,
      _pressController,
      _stretchSpring,
      _livePage,
      _liveStretch,
    ]);
  }

  @override
  void didUpdateWidget(EditorialDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_scrubbing) return;
    final changed = oldWidget.progress != widget.progress ||
        oldWidget.selectedTab != widget.selectedTab;
    if (!changed) return;
    final now = DateTime.now();
    final previous = _lastProgressChangeAt;
    _lastProgressChangeAt = now;
    final target = _targetPage;
    if ((target - _toPage).abs() < 0.001) return;
    // 页面横滑会高频推送 progress，此时直接跟手，避免动画落后于手指。
    if (previous != null && now.difference(previous) < _rapidProgressWindow) {
      _positionSpring.stop();
      _fromPage = target;
      _toPage = target;
      _livePage.value = target;
      return;
    }
    _animateTo(_displayedPage, target);
  }

  @override
  void dispose() {
    _positionSpring.dispose();
    _pressController.dispose();
    _stretchSpring.dispose();
    _livePage.dispose();
    _liveStretch.dispose();
    super.dispose();
  }

  double get _targetPage =>
      (widget.progress ?? widget.selectedTab.toDouble()).clamp(0.0, 2.0).toDouble();

  double get _displayedPage {
    if (_scrubbing) return _livePage.value;
    final t = _positionSpring.value;
    if (t == 1) return _toPage;
    final page = _fromPage + (_toPage - _fromPage) * t;
    if (t <= 1) return page;
    final overshootLimit = _maxOvershootPixels / EditorialDock._slotWidth;
    final upper = _toPage + overshootLimit;
    final lower = _toPage - overshootLimit;
    return page.clamp(lower, upper).toDouble();
  }

  double get _displayedStretch {
    if (_liveStretch.value > 0 || _scrubbing) return _liveStretch.value;
    return _stretchFrom * (1 - _stretchSpring.value.clamp(0.0, 1.0).toDouble());
  }

  void _animateTo(double from, double to) {
    _fromPage = from;
    _toPage = to;
    _positionSpring.stop();
    _positionSpring.value = 0;
    _positionSpring.animateWith(
      SpringSimulation(_spring, 0, 1, 0)..tolerance = _springTolerance,
    );
  }

  void _releaseStretch() {
    final from = _liveStretch.value;
    _liveStretch.value = 0;
    _stretchFrom = from;
    _stretchSpring.stop();
    if (from < 0.5) {
      _stretchSpring.value = 1;
      return;
    }
    _stretchSpring.value = 0;
    _stretchSpring.animateWith(
      SpringSimulation(_spring, 0, 1, 0)..tolerance = _springTolerance,
    );
  }

  void _beginPress() {
    if (_pressed) return;
    _pressed = true;
    HapticFeedback.selectionClick();
    _pressController.animateTo(
      1,
      duration: _pressDownDuration,
      curve: Curves.easeOut,
    );
  }

  void _endPress() {
    if (!_pressed) return;
    _pressed = false;
    _pressController.animateBack(
      0,
      duration: _pressReleaseDuration,
      curve: Curves.easeOut,
    );
  }

  int _indexForX(double localX) {
    final slot =
        (localX - EditorialDock._horizontalPadding) / EditorialDock._slotWidth;
    return slot.round().clamp(0, EditorialDock._itemCount - 1).toInt();
  }

  double _pageForX(double localX) {
    final slot =
        (localX - EditorialDock._horizontalPadding) / EditorialDock._slotWidth;
    return slot.clamp(0.0, 2.0).toDouble();
  }

  void _handleTapDown(TapDownDetails _) => _beginPress();

  void _handleTapUp(TapUpDetails details) {
    _endPress();
    widget.onSelect(_indexForX(details.localPosition.dx));
  }

  void _handleTapCancel() => _endPress();

  void _handleDragStart(DragStartDetails details) {
    final current = _displayedPage;
    _positionSpring.stop();
    _releaseStretch();
    _livePage.value = current;
    _scrubbing = true;
    _scrubSnapIndex = null;
    _lastDragTimestamp = details.sourceTimeStamp;
    _lastDragX = details.localPosition.dx;
    _beginPress();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final page = _pageForX(details.localPosition.dx);
    _livePage.value = page;
    widget.onScrubUpdate?.call(page);
    if (widget.onScrubUpdate == null) {
      final index = _indexForX(details.localPosition.dx);
      if (_scrubSnapIndex != index) {
        _scrubSnapIndex = index;
        widget.onSelect(index);
      }
    }
    final now = details.sourceTimeStamp;
    final previousTime = _lastDragTimestamp;
    final previousX = _lastDragX;
    if (now != null && previousTime != null && previousX != null) {
      final seconds = (now - previousTime).inMicroseconds / 1000000;
      if (seconds > 0.001) {
        final velocity = (details.localPosition.dx - previousX) / seconds;
        _liveStretch.value =
            math.min(EditorialDock._maxStretch, velocity.abs() / 600);
      }
    }
    _lastDragTimestamp = now;
    _lastDragX = details.localPosition.dx;
  }

  void _handleDragEnd(DragEndDetails details) {
    final page = _livePage.value;
    _endPress();
    widget.onScrubEnd?.call(page, details.primaryVelocity ?? 0);
    _scrubbing = false;
    _releaseStretch();
    final target = _targetPage;
    if ((target - page).abs() < 0.001) {
      _positionSpring.stop();
      _fromPage = target;
      _toPage = target;
      _positionSpring.value = 1;
      return;
    }
    _animateTo(page, target);
  }

  @override
  Widget build(BuildContext context) {
    final palette = StreamPalette.of(context);
    final radius = BorderRadius.circular(EditorialDock._radius);

    return RepaintBoundary(
      child: Container(
        width: EditorialDock._width,
        height: EditorialDock._height,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        // 模糊必须被裁在胶囊内，页面其他区域保持清晰。
        child: ClipRRect(
          borderRadius: radius,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            onHorizontalDragStart: _handleDragStart,
            onHorizontalDragUpdate: _handleDragUpdate,
            onHorizontalDragEnd: _handleDragEnd,
            child: Stack(
              children: [
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.deepSurface.withValues(alpha: 0.62),
                      borderRadius: radius,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.20),
                        width: 1.0,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: EditorialDock._height * 0.4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(EditorialDock._radius),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.10),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left:
                      EditorialDock._horizontalPadding + EditorialDock._indicatorInset,
                  top: (EditorialDock._height - EditorialDock._indicatorHeight) / 2,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: AnimatedBuilder(
                        animation: _indicatorRepaint,
                        builder: (context, child) {
                          final stretch = _displayedStretch;
                          final press = _pressController.value;
                          return Transform.translate(
                            offset: Offset(
                              _displayedPage * EditorialDock._slotWidth - stretch / 2,
                              0,
                            ),
                            child: Transform.scale(
                              scale: 1 - 0.04 * press,
                              child: Container(
                                width: EditorialDock._indicatorWidth + stretch,
                                height: EditorialDock._indicatorHeight,
                                decoration: ShapeDecoration(
                                  color: palette.accentWarmYellow,
                                  shape: const StadiumBorder(),
                                ),
                                child: press <= 0.001
                                    ? null
                                    : DecoratedBox(
                                        decoration: ShapeDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.08 * press),
                                          shape: const StadiumBorder(),
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: EditorialDock._horizontalPadding,
                    ),
                    child: Row(
                      children: [
                        for (final item in EditorialDock._items)
                          Expanded(
                            child: _DockSlot(
                              item: item,
                              selected: widget.selectedTab == item.id,
                              palette: palette,
                              onTap: () => widget.onSelect(item.id),
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
      ),
    );
  }
}

class _DockItem {
  final int id;
  final String label;
  final IconData icon;

  const _DockItem(this.id, this.label, this.icon);
}

/// 纯展示格子：无水波纹、无 highlight，指针手势由底栏整体接管。
class _DockSlot extends StatelessWidget {
  const _DockSlot({
    required this.item,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final _DockItem item;
  final bool selected;
  final StreamPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = selected ? palette.textOnAccent : palette.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      onTap: onTap,
      child: SizedBox(
        height: EditorialDock._height,
        child: Center(child: Icon(item.icon, size: 20, color: tint)),
      ),
    );
  }
}

/// 56dp 圆形暖黄 FAB。
class EditorialFab extends StatelessWidget {
  const EditorialFab({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = StreamPalette.of(context);
    return Semantics(
      button: true,
      label: '记一笔',
      child: SizedBox(
        width: 56,
        height: 56,
        child: Material(
          color: palette.accentWarmYellow,
          shape: const CircleBorder(),
          elevation: 10,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: Icon(
                StreamIcons.add,
                size: 24,
                color: palette.textOnAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}