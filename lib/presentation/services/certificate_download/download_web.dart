import 'dart:typed_data';
import 'dart:html' as html;

Future<void> saveCertificateBytes(Uint8List bytes, String filename) async {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = '$filename.png'
    ..style.display = 'none'
    ..click();
  html.Url.revokeObjectUrl(url);
}
