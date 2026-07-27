import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Triggers a browser download of [bytes] as [filename].
///
/// Uses `package:web` + `dart:js_interop` (dart:html is deprecated): creates
/// a Blob, points a temporary anchor at an object URL, clicks it, cleans up.
void downloadFileBytes({
  required Uint8List bytes,
  required String filename,
  String mimeType = 'application/octet-stream',
}) {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

/// MIME type for `.xlsx` workbooks.
const String xlsxMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
