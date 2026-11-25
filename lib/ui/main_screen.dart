import 'package:flutter/material.dart';


import '../app_state.dart';
import '../design/stream_shapes.dart';
import '../design/stream_theme.dart';
import '../widgets/editorial.dart';
import 'account_editor_sheet.dart';
import 'accounts_screen.dart';
import 'analytics_screen.dart';
import 'budget_sheet.dart';
import 'category_manager_sheet.dart';
import 'quick_add_sheet.dart';
import 'recurring_sheet.dart';
import 'settings_sheet.dart';
import 'timeline_screen.dart';
import 'trash_sheet.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const double _dockBarHeight = 90;
  static const double _snackBarDockGap = 8;
  static const double _maxContentWidth = 560;
  static const Duration _pageAnimationDuration = Duration(milliseconds: 430);
  static const Duration _scrubSettleDuration = Duration(milliseconds: 400);
  static const double _scrubVelocityToPages = 3200;

  String? _shownMessage;
  String? _shownUndo;
  bool _quickAddOpen = false;
  bool _settingsOpen = false;
  bool _accountEditorOpen = false;
  bool _categoryManagerOpen = false;
  bool _trashOpen = false;
  bool _budgetOpen = false;
  bool _recurringOpen = false;
  AppState? _state;

  PageController? _pageController;
  // 指示器进度走 ValueNotifier：页面横滑只刷新底栏，不重建整屏。
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  int _lastSyncedTab = 0;
  int? _pendingTab;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    _state = state;
    _ensurePageController(state);
    _syncPage(state);
    _syncMessage(state);
    _syncUndo(state);
    _syncOverlays(state);
  }

  void _ensurePageController(AppState state) {
    if (_pageController != null) return;
    _lastSyncedTab = state.currentTab;
    _progress.value = state.currentTab.toDouble();
    _pageController = PageController(initialPage: state.currentTab)
      ..addListener(_onPageScroll);
  }

  void _onPageScroll() {
    final controller = _pageController;
    if (controller == null || !controller.hasClients) return;
    final page = controller.page;
    if (page == null) return;
    _progress.value = page;
  }

  /// 岛内拖动：用 jumpTo 实时带动 PageView，跟随手指不做动画。
  void _onScrubUpdate(double page) {
    final state = _state;
    if (state != null && state.timelineSearchActive) return;
    final controller = _pageController;
    if (controller == null || !controller.hasClients) return;
    controller.jumpTo(page * controller.position.viewportDimension);
  }

  /// 松手：按页码 + 速度投影吸附到最近页，再同步 tab 状态。
  void _onScrubEnd(double page, double velocity) {
    final state = _state;
    if (state != null && state.timelineSearchActive) return;
    final controller = _pageController;
    if (controller == null || !controller.hasClients) return;
    final int target = (page + velocity / _scrubVelocityToPages)
        .round()
        .clamp(0, 2)
        .toInt();
    _lastSyncedTab = target;
    controller.animateToPage(
      target,
      duration: _scrubSettleDuration,
      curve: Curves.easeOutCubic,
    );
    state?.setTab(target);
  }

  /// 外部点击底栏切换 tab 时，把 PageView 动画到目标页；禁止在 build 内直接动画。
  void _syncPage(AppState state) {
    final target = state.currentTab;
    if (target == _lastSyncedTab || target == _pendingTab) return;
    _pendingTab = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingTab = null;
      if (!mounted) return;
      _lastSyncedTab = target;
      final controller = _pageController;
      if (controller == null || !controller.hasClients) return;
      if (controller.page?.round() == target) return;
      controller.animateToPage(
        target,
        duration: _pageAnimationDuration,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _pageController?.removeListener(_onPageScroll);
    _pageController?.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _syncMessage(AppState state) {
    final message = state.message;
    if (message == null) {
      _shownMessage = null;
      return;
    }
    if (message == _shownMessage) return;
    _shownMessage = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = _state;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (current == null || messenger == null) return;
      messenger.showSnackBar(
        _snackBar(text: message, palette: StreamPalette.of(context)),
      );
      current.consumeMessage();
    });
  }

  void _syncUndo(AppState state) {
    final undoMessage = state.undoMessage;
    if (undoMessage == null) {
      _shownUndo = null;
      return;
    }
    if (undoMessage == _shownUndo) return;
    _shownUndo = undoMessage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      final controller = messenger.showSnackBar(
        _snackBar(
          text: undoMessage,
          palette: StreamPalette.of(context),
          actionLabel: '撤销',
          onAction: () => state.undoDelete(),
        ),
      );
      controller.closed.then((reason) {
        if (reason != SnackBarClosedReason.action) state.dismissUndo();
      });
    });
  }

  void _syncOverlays(AppState state) {
    if (state.quickAddVisible) {
      if (!_quickAddOpen) {
        _quickAddOpen = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _presentQuickAdd());
      }
    } else if (_quickAddOpen) {
      _quickAddOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }

    if (state.settingsVisible) {
      if (!_settingsOpen) {
        _settingsOpen = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _presentSettings());
      }
    } else if (_settingsOpen) {
      _settingsOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }

    if (state.accountEditorVisible) {
      if (!_accountEditorOpen) {
        _accountEditorOpen = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _presentAccountEditor());
      }
    } else if (_accountEditorOpen) {
      _accountEditorOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }

    if (state.categoryManagerVisible) {
      if (!_categoryManagerOpen) {
        _categoryManagerOpen = true;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _presentCategoryManager(),
        );
      }
    } else if (_categoryManagerOpen) {
      _categoryManagerOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }

    if (state.trashVisible) {
      if (!_trashOpen) {
        _trashOpen = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _presentTrash());
      }
    } else if (_trashOpen) {
      _trashOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }

    if (state.budgetVisible) {
      if (!_budgetOpen) {
        _budgetOpen = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _presentBudget());
      }
    } else if (_budgetOpen) {
      _budgetOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }

    if (state.recurringVisible) {
      if (!_recurringOpen) {
        _recurringOpen = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _presentRecurring());
      }
    } else if (_recurringOpen) {
      _recurringOpen = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  Future<void> _presentQuickAdd() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: StreamPalette.of(context).cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (_) => const QuickAddSheet(),
    );
    _quickAddOpen = false;
    final state = _state;
    if (state != null && state.quickAddVisible) state.closeQuickAdd();
  }

  Future<void> _presentSettings() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => const SettingsSheet(),
    );
    _settingsOpen = false;
    final state = _state;
    if (state != null && state.settingsVisible) state.closeSettings();
  }

  Future<void> _presentAccountEditor() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => const AccountEditorSheet(),
    );
    _accountEditorOpen = false;
    final state = _state;
    if (state != null && state.accountEditorVisible) state.closeAccountEditor();
  }

  Future<void> _presentCategoryManager() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => const CategoryManagerSheet(),
    );
    _categoryManagerOpen = false;
    final state = _state;
    if (state != null && state.categoryManagerVisible) {
      state.closeCategoryManager();
    }
  }

  Future<void> _presentTrash() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => const TrashSheet(),
    );
    _trashOpen = false;
    final state = _state;
    if (state != null && state.trashVisible) state.closeTrash();
  }

  Future<void> _presentBudget() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => const BudgetSheet(),
    );
    _budgetOpen = false;
    final state = _state;
    if (state != null && state.budgetVisible) state.closeBudget();
  }

  Future<void> _presentRecurring() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => const RecurringSheet(),
    );
    _recurringOpen = false;
    final state = _state;
    if (state != null && state.recurringVisible) state.closeRecurring();
  }

  SnackBar _snackBar({
    required String text,
    required StreamPalette palette,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return SnackBar(
      backgroundColor: palette.textPrimary,
      behavior: SnackBarBehavior.floating,
      elevation: 6,
      margin: const EdgeInsets.fromLTRB(
        24,
        0,
        24,
        _dockBarHeight + _snackBarDockGap,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: StreamShapes.capsule,
      duration: const Duration(seconds: 4),
      content: Text(
        text,
        style: TextStyle(color: palette.cardBackground, fontSize: 14),
      ),
      action: actionLabel == null || onAction == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              textColor: palette.accentWarmYellow,
              onPressed: onAction,
            ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final palette = StreamPalette.of(context);
    final controller = _pageController;

    return Scaffold(
      backgroundColor: palette.paperBase,
      // 正文延伸到底栏之后，Dock 的 BackdropFilter 才能透出真实内容。
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: PageView(
              controller: controller,
              physics: state.timelineSearchActive
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
              onPageChanged: (index) {
                _lastSyncedTab = index;
                state.setTab(index);
              },
              children: const <Widget>[
                TimelineScreen(),
                AnalyticsScreen(),
                AccountsScreen(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: SizedBox(
          height: _dockBarHeight,
          width: double.infinity,
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: Center(
                  child: RepaintBoundary(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _progress,
                      builder: (context, progress, _) => EditorialDock(
                        selectedTab: state.currentTab,
                        progress: progress,
                        onSelect: state.setTab,
                        onScrubUpdate: _onScrubUpdate,
                        onScrubEnd: _onScrubEnd,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 18,
                bottom: 16,
                child: EditorialFab(onTap: () => state.openQuickAdd()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}