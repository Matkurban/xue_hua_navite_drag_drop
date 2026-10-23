## 1.0.2

* Fix Windows builds with Visual Studio 2026 and Flutter 3.50 beta: raise the CMake policy range, fetch googletest v1.15.2, include `method_result_functions.h`, and silence PIDL alignment warnings that MSVC `/WX` treats as errors.

## 1.0.1

* Add an English README and move the original Chinese documentation to `README.zh-CN.md`, with links between the two.
* On Web, check dropped files with `isA<Blob>()` instead of a Dart `is Blob` runtime check, so the check is consistent across compilers.

## 1.0.0

* impl plugin
