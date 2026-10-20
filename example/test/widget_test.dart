import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xue_hua_navite_drag_drop_example/main.dart';

void main() {
  testWidgets('Verify drag drop demo UI renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.contains('XueHua 6端原生拖拽演示'),
      ),
      findsOneWidget,
    );
  });
}
