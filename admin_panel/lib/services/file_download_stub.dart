import 'dart:typed_data';

/// Non-web stand-in for the browser download helper.
///
/// The admin panel only ships as Flutter Web, so this is never reached in
/// production — it exists so the screens that offer Excel exports can be
/// compiled and rendered by the VM-based test harness.
void downloadFileBytes({
  required Uint8List bytes,
  required String filename,
  String mimeType = 'application/octet-stream',
}) {
  throw UnsupportedError(
      'File downloads are only available in the browser build.');
}

/// MIME type for `.xlsx` workbooks.
const String xlsxMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
