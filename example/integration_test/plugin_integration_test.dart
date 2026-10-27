import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:xue_hua_navite_drag_drop/xue_hua_navite_drag_drop.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('initDragDrop prepares platform instance', (WidgetTester tester) async {
    final XueHuaNaviteDragDrop plugin = XueHuaNaviteDragDrop();
    await plugin.initDragDrop();
    expect(XueHuaNaviteDragDropPlatform.instance, isNotNull);
  });

  testWidgets('startDragOut with empty items fails cleanly', (WidgetTester tester) async {
    final XueHuaNaviteDragDrop plugin = XueHuaNaviteDragDrop();
    await plugin.initDragDrop();

    var completed = false;
    var success = true;
    final started = await plugin.startDragOut(
      items: const <DragOutItem>[],
      onDragCompleted: (bool ok) {
        completed = true;
        success = ok;
      },
    );

    expect(started, isFalse);
    expect(completed, isTrue);
    expect(success, isFalse);
  });
}
