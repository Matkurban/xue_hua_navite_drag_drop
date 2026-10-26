import 'dart:convert';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  group('xue_hua_navite_drag_drop example (flutter_driver)', () {
    late FlutterDriver driver;

    setUpAll(() async {
      driver = await FlutterDriver.connect();
      await driver.waitUntilFirstFrameRasterized();
    });

    tearDownAll(() async {
      await driver.close();
    });

    Future<Map<String, Object?>> requestJson(String command) async {
      final raw = await driver.requestData(command);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded.cast<String, Object?>();
      }
      throw StateError('Unexpected response for $command: $raw');
    }

    test('ping extension handler', () async {
      expect(await driver.requestData('ping'), 'pong');
    });

    test('app title and core UI keys are present', () async {
      await driver.waitFor(find.byValueKey('app_title'));
      await driver.waitFor(find.byValueKey('drop_region'));
      await driver.waitFor(find.byValueKey('drop_placeholder'));
      await driver.waitFor(find.byValueKey('drag_out_memory'));
      await driver.waitFor(find.byValueKey('drag_out_local'));
      await driver.waitFor(find.byValueKey('drag_out_status'));

      final title = await driver.getText(find.byValueKey('app_title'));
      expect(title, contains('XueHua'));

      final status = await driver.getText(find.byValueKey('drag_out_status'));
      expect(status, contains('等待拖出操作'));
    });

    test('initDragDrop succeeds on desktop', () async {
      expect(await driver.requestData('initDragDrop'), 'ok');
      final platform = await driver.requestData('platformReady');
      expect(platform, isNotEmpty);
      expect(platform.toLowerCase(), isNot(contains('unimplemented')));
    });

    test('simulate drag enter/update/exit updates hover state', () async {
      final enter = await requestJson('simulateDragEnter');
      expect(enter['hovering'], isTrue);

      final update = await requestJson('simulateDragUpdate');
      expect(update['hovering'], isTrue);
      expect(update['hasHoverPosition'], isTrue);

      final exit = await requestJson('simulateDragExit');
      expect(exit['hovering'], isFalse);
    });

    test('simulate performDrop populates dropped list', () async {
      final drop = await requestJson('simulatePerformDrop');
      expect(drop['droppedCount'], 2);
      expect(drop['firstDroppedName'], 'driver_sample.txt');
      expect(drop['hovering'], isFalse);

      await driver.waitFor(find.byValueKey('dropped_list'));
      await driver.waitFor(find.text('driver_sample.txt'));
      await driver.waitFor(find.text('driver_folder'));

      final state = await requestJson('uiState');
      expect(state['droppedCount'], 2);
      expect(state['firstDroppedName'], 'driver_sample.txt');
    });

    test('startDragOut memory invokes native path without hanging', () async {
      final result = await requestJson('startDragOutMemory');
      expect(result.containsKey('started'), isTrue);
      expect(result['callbackSeen'], isTrue);
      // Without a held mouse button, OLE drag-out cannot complete successfully.
      // The important contract is: no hang, and completion callback fires.
      expect(result['started'], isTrue);
    });

    test('startDragOut local file after simulated drop', () async {
      final result = await requestJson('startDragOutFile');
      expect(result.containsKey('started'), isTrue);
      // File exists after simulatePerformDrop; session starts, then ends cleanly
      // without a pressed mouse button.
      expect(result['started'], isTrue);
      expect(result['callbackSeen'], isTrue);
    });

    test('startDragOut empty items fails cleanly', () async {
      final result = await requestJson('startDragOutEmpty');
      expect(result['started'], isFalse);
      expect(result['callbackSeen'], isTrue);
      expect(result['success'], isFalse);
    });

    test('startDragOut missing file fails cleanly', () async {
      final result = await requestJson('startDragOutMissingFile');
      expect(result['started'], isFalse);
      expect(result['callbackSeen'], isTrue);
      expect(result['success'], isFalse);
    });

    test('cancelDragOut reports cancellation path', () async {
      await requestJson('startDragOutMemory');
      final cancelled = await requestJson('cancelDragOut');
      expect(cancelled.containsKey('status'), isTrue);
    });
  });
}
