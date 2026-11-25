import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_ledger/app.dart';
import 'package:stream_ledger/app_state.dart';
import 'package:stream_ledger/ui/main_screen.dart';

void main() {
  testWidgets('StreamApp 可构建并渲染应用外壳', (WidgetTester tester) async {
    final state = AppState();
    addTearDown(state.dispose);

    await tester.pumpWidget(StreamApp(state: state));
    await tester.pump();

    expect(find.byType(MainScreen), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(state.currentTab, 0);
  });
}