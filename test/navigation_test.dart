import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_ledger/app.dart';
import 'package:stream_ledger/app_state.dart';
import 'package:stream_ledger/widgets/editorial.dart';

void main() {
  testWidgets('底栏为 208x56 磨砂玻璃并带模糊层', (tester) async {
    final state = AppState();
    await tester.pumpWidget(StreamApp(state: state));
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(EditorialDock));
    expect(size.width, 208);
    expect(size.height, 56);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(tester.getSize(find.byType(EditorialFab)), const Size(56, 56));
  });

  testWidgets('横滑切到下一页并同步 currentTab', (tester) async {
    final state = AppState();
    await tester.pumpWidget(StreamApp(state: state));
    await tester.pumpAndSettle();
    expect(state.currentTab, 0);

    await tester.fling(find.byType(PageView), const Offset(-320, 0), 1400);
    await tester.pumpAndSettle();

    expect(state.currentTab, 1);
  });

  testWidgets('点击底栏图标切页', (tester) async {
    final state = AppState();
    await tester.pumpWidget(StreamApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('资产'));
    await tester.pumpAndSettle();

    expect(state.currentTab, 2);
  });

  testWidgets('底栏不再使用矩形水波纹与高光块', (tester) async {
    final state = AppState();
    await tester.pumpWidget(StreamApp(state: state));
    await tester.pumpAndSettle();

    final dock = find.byType(EditorialDock);
    expect(find.descendant(of: dock, matching: find.byType(InkWell)), findsNothing);
    expect(find.descendant(of: dock, matching: find.byType(InkResponse)), findsNothing);
    // 指示器为药丸形（StadiumBorder），不再是小圆角方块
    final stadium = find.descendant(
      of: dock,
      matching: find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        if (decoration is ShapeDecoration) {
          return decoration.shape is StadiumBorder;
        }
        if (decoration is BoxDecoration) {
          return decoration.shape is StadiumBorder ||
              decoration.borderRadius == BorderRadius.circular(24);
        }
        return false;
      }),
    );
    expect(stadium, findsWidgets);
  });

  testWidgets('在底栏上横向拖动会切换页面', (tester) async {
    final state = AppState();
    await tester.pumpWidget(StreamApp(state: state));
    await tester.pumpAndSettle();

    // 先切到统计页，再从底栏向右拖，回到账单页
    state.setTab(1);
    await tester.pumpAndSettle();
    expect(state.currentTab, 1);

    await tester.drag(find.byType(EditorialDock), const Offset(-160, 0));
    await tester.pumpAndSettle();

    expect(state.currentTab, 0);
  });
}