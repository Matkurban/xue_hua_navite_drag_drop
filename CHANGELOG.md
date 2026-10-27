## 1.0.8

* Android Mode A `startDragOut` skips empty or missing file paths and returns false when nothing valid remains, aligned with other platforms.
* Android Mode B (`asyncFile` / `memory`) waits for async materialization before returning `startDragOut`, instead of always returning true early.
* Android reports drag-out completion from `ACTION_DRAG_ENDED`; when the OS refuses to start a drag without an active pointer (e.g. flutter_driver), the session is accepted then completed as unsuccessful, matching desktop driver contracts.
* Example flutter_driver coverage adds Mode B `asyncFile`.

## 1.0.7

* macOS and iOS Mode A `startDragOut` skips empty or missing file paths and returns false when nothing valid remains, aligned with Windows and Linux.
* The example sets version 1.0.0+1 so iOS builds have a build name and number.

## 1.0.6

* Windows avoids hanging in `DoDragDrop` when no mouse button is pressed, returning false and ending the drag-out.
* Windows `startDragOut` returns false when there are no valid paths, and skips invalid Mode A empty or missing paths.
* The example adds flutter_driver coverage for empty and missing file cases, and uses system temp paths on Windows.

## 1.0.5

* Linux drag-out stages async and memory items to a temp file so Mode B drag-out works.
* Linux reports drag-end success from the selected GDK action, so cancelled drags are false.
* Linux `startDragOut` returns false when there are no valid URIs.
* The example adds flutter_driver coverage for the drag-drop APIs.

## 1.0.4

* Windows drag-out now offers CF_HDROP so Desktop/Explorer no longer show a no-drop cursor.

## 1.0.3

* Fix Linux builds on CMake 4.x: fetch googletest v1.15.2 instead of release-1.11.0, set policy CMP0135, and allow CMake policy version 3.5 so the example unit tests can configure.

## 1.0.2

* Fix Windows builds with Visual Studio 2026 and Flutter 3.50 beta: raise the CMake policy range, fetch googletest v1.15.2, include `method_result_functions.h`, and silence PIDL alignment warnings that MSVC `/WX` treats as errors.

## 1.0.1

* Add an English README and move the original Chinese documentation to `README.zh-CN.md`, with links between the two.
* On Web, check dropped files with `isA<Blob>()` instead of a Dart `is Blob` runtime check, so the check is consistent across compilers.

## 1.0.0

* impl plugin
