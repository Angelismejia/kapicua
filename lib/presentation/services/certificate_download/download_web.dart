// dart:html sigue siendo la forma más simple de disparar una descarga
// desde el navegador; este archivo solo se compila en la build web
// (conditional import), así que el aviso de "librería solo-web" no aplica.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
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
