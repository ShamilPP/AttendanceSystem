/// Browser file download, behind a conditional import.
///
/// The real implementation needs `dart:js_interop`, which only exists on the
/// web. Importing it unconditionally made every screen that offers an export
/// impossible to compile under `flutter test` (the VM has no js_interop), so
/// the whole People/Reports area was untestable. This facade picks the web
/// implementation when compiling for the browser and a throwing stub anywhere
/// else, which costs nothing in production and keeps the screens testable.
library;

export 'file_download_stub.dart'
    if (dart.library.js_interop) 'file_download_web.dart';
