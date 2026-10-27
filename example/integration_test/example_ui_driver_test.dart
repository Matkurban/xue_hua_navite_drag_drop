import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_navite_drag_drop_example/driver_bridge.dart';
import 'package:xue_hua_navite_drag_drop_example/main.dart' as app;

/// WidgetTester-driven coverage of the example app and plugin hooks.
///
/// Mirrors the legacy `test_driver/app_test.dart` flutter_driver suite using
/// the recommended [integration_test] package.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<Map<String, Object?>> requestJson(String command) async {
    final raw = await DriverBridge.handle(command);
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded.cast<String, Object?>();
    }
    throw StateError('Unexpected response for $command: $raw');
  }

  Future<void> pumpSettle(
    WidgetTester tester, [
    Duration d = const Duration(milliseconds: 400),
  ]) async {
    await tester.pumpAndSettle(d);
  }

  testWidgets('example UI keys, drop simulation, and drag-out paths', (
    WidgetTester tester,
  ) async {
    app.main();
    await pumpSettle(tester, const Duration(seconds: 1));

    expect(find.byKey(const ValueKey('app_title')), findsOneWidget);
    expect(find.byKey(const ValueKey('drop_region')), findsOneWidget);
    expect(find.byKey(const ValueKey('drop_placeholder')), findsOneWidget);
    expect(find.byKey(const ValueKey('drag_out_memory')), findsOneWidget);
    expect(find.byKey(const ValueKey('drag_out_local')), findsOneWidget);
    expect(find.byKey(const ValueKey('drag_out_status')), findsOneWidget);

    final title = tester.widget<Text>(find.byKey(const ValueKey('app_title')));
    expect(title.data, contains('XueHua'));

    final statusBefore =
        tester.widget<Text>(find.byKey(const ValueKey('drag_out_status')));
    expect(statusBefore.data, contains('等待拖出操作'));

    expect(await DriverBridge.handle('ping'), 'pong');
    expect(await DriverBridge.handle('initDragDrop'), 'ok');
    final platform = await DriverBridge.handle('platformReady');
    expect(platform, isNotEmpty);
    expect(platform.toLowerCase(), isNot(contains('unimplemented')));

    final enter = await requestJson('simulateDragEnter');
    expect(enter['hovering'], isTrue);
    await pumpSettle(tester);

    final update = await requestJson('simulateDragUpdate');
    expect(update['hovering'], isTrue);
    expect(update['hasHoverPosition'], isTrue);
    await pumpSettle(tester);

    final exit = await requestJson('simulateDragExit');
    expect(exit['hovering'], isFalse);
    await pumpSettle(tester);

    final drop = await requestJson('simulatePerformDrop');
    expect(drop['droppedCount'], 2);
    expect(drop['firstDroppedName'], 'driver_sample.txt');
    expect(drop['hovering'], isFalse);
    await pumpSettle(tester);

    expect(find.byKey(const ValueKey('dropped_list')), findsOneWidget);
    expect(find.text('driver_sample.txt'), findsWidgets);
    expect(find.text('driver_folder'), findsWidgets);

    final state = await requestJson('uiState');
    expect(state['droppedCount'], 2);
    expect(state['firstDroppedName'], 'driver_sample.txt');

    final memory = await requestJson('startDragOutMemory');
    expect(memory['started'], isTrue);
    expect(memory['callbackSeen'], isTrue);
    await pumpSettle(tester);

    final asyncOut = await requestJson('startDragOutAsync');
    expect(asyncOut['started'], isTrue);
    expect(asyncOut['callbackSeen'], isTrue);
    await pumpSettle(tester);

    final fileOut = await requestJson('startDragOutFile');
    expect(fileOut['started'], isTrue);
    expect(fileOut['callbackSeen'], isTrue);
    await pumpSettle(tester);

    final empty = await requestJson('startDragOutEmpty');
    expect(empty['started'], isFalse);
    expect(empty['callbackSeen'], isTrue);
    expect(empty['success'], isFalse);

    final missing = await requestJson('startDragOutMissingFile');
    expect(missing['started'], isFalse);
    expect(missing['callbackSeen'], isTrue);
    expect(missing['success'], isFalse);

    await requestJson('startDragOutMemory');
    final cancelled = await requestJson('cancelDragOut');
    expect(cancelled.containsKey('status'), isTrue);
    await pumpSettle(tester);
  });
}
