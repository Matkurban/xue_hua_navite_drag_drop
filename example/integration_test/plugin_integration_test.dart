import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:xue_hua_navite_drag_drop/xue_hua_navite_drag_drop.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('initDragDrop integration test', (WidgetTester tester) async {
    final XueHuaNaviteDragDrop plugin = XueHuaNaviteDragDrop();
    await plugin.initDragDrop();
    expect(XueHuaNaviteDragDropPlatform.instance, isNotNull);
  });
}
