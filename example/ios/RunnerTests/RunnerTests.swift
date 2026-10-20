import Flutter
import UIKit
import XCTest

@testable import xue_hua_navite_drag_drop

class RunnerTests: XCTestCase {

  func testSetDropEffect() {
    let plugin = XueHuaNaviteDragDropPlugin()

    let call = FlutterMethodCall(
      methodName: "setDropEffect",
      arguments: ["operation": "copy"]
    )

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      XCTAssertNil(result)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

}
