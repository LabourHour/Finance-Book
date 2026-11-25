import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stream_ledger/app.dart';
import 'package:stream_ledger/app_state.dart';
import 'package:stream_ledger/data/ledger_database.dart';
import 'package:stream_ledger/data/ledger_repository.dart';
import 'package:stream_ledger/data/models.dart';
import 'package:stream_ledger/design/stream_theme.dart';
import 'package:stream_ledger/ui/lock_screen.dart';
import 'package:stream_ledger/ui/settings_sheet.dart';
import 'package:stream_ledger/ui/timeline_screen.dart';

Future<(LedgerDatabase, AppState)> _createInitializedState(
  WidgetTester tester,
) async {
  late LedgerDatabase db;
  late AppState state;
  await tester.runAsync(() async {
    sqfliteFfiInit();
    db = LedgerDatabase.forTesting(
      path: inMemoryDatabasePath,
      databaseFactory: databaseFactoryFfi,
    );
    final repo = LedgerRepository(db);
    state = AppState(repo);
    await state.initialize();
  });
  addTearDown(() async {
    state.dispose();
    await tester.runAsync(db.close);
  });
  return (db, state);
}

void main() {
  testWidgets('设置页关闭不误弹主界面，且支持切换浅色/深色主题', (tester) async {
    final (_, state) = await _createInitializedState(tester);

    await tester.pumpWidget(StreamApp(state: state));
    await tester.pumpAndSettle();

    state.openSettings();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsSheet), findsOneWidget);

    // 切换为深色碳素主题（setThemeMode 内部写 SQLite，用 runAsync 推进真实 IO）
    await tester.ensureVisible(find.text('深色碳素'));
    await tester.runAsync(() async {
      await tester.tap(find.text('深色碳素'));
    });
    await tester.pumpAndSettle();
    expect(state.themeMode, ThemeMode.dark);
    final element = tester.element(find.byType(SettingsSheet));
    expect(StreamPalette.of(element).isDark, isTrue);

    // 滚回顶部再点击关闭按钮，验证关闭设置页后主界面仍然存在
    await tester.ensureVisible(find.byTooltip('关闭'));
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsSheet), findsNothing);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('应用锁在切后台时自动上锁，外部选择器期间抑制自动上锁', (tester) async {
    final (_, state) = await _createInitializedState(tester);
    await tester.runAsync(() => state.enableLock('123456'));

    await tester.pumpWidget(StreamApp(state: state));
    await tester.pumpAndSettle();
    expect(find.byType(LockScreen), findsNothing);

    // 调用系统分享/文件选择器期间切后台并回到前台，不应触发锁屏
    await state.runWithoutAutoLock(() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(state.unlocked, isTrue);
      expect(find.byType(LockScreen), findsNothing);
    });

    // 正常切后台再回到前台，应触发锁屏门禁
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(state.unlocked, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(LockScreen), findsOneWidget);

    // 输入 6 位正确密码后解锁
    for (final digit in const ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(
        find.descendant(
          of: find.byType(LockScreen),
          matching: find.text(digit),
        ),
      );
    }
    await tester.pumpAndSettle();
    expect(state.unlocked, isTrue);
    expect(find.byType(LockScreen), findsNothing);
  });

  testWidgets('账单行长按弹出操作菜单，而不是直接删除', (tester) async {
    final (_, state) = await _createInitializedState(tester);

    final err = await tester.runAsync(
      () => state.saveTransaction(
        type: TransactionType.expense,
        amountCents: 3600,
        accountId: state.accounts.first.id,
        categoryId: state.categories.first.id,
        occurredAt: DateTime.now().millisecondsSinceEpoch,
        note: '测试午餐',
      ),
    );
    expect(err, isNull);

    await tester.pumpWidget(StreamApp(state: state));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('测试午餐'),
      200,
      scrollable: find.descendant(
        of: find.byType(TimelineScreen),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('测试午餐'), findsOneWidget);

    await tester.longPress(find.text('测试午餐'));
    await tester.pumpAndSettle();

    // 应弹出菜单而非直接删除
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(state.transactions.length, 1);

    // 点击「删除」后关闭菜单并执行软删除
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(state.transactions, isEmpty);
  });
}
