import 'package:flutter_driver/driver_extension.dart';
import 'package:xue_hua_navite_drag_drop_example/driver_bridge.dart';
import 'package:xue_hua_navite_drag_drop_example/main.dart' as app;

void main() {
  enableFlutterDriverExtension(handler: DriverBridge.handle);
  app.main();
}
