import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

/// Envuelve [child] en un [Showcase] del tour de bienvenida si se le pasa
/// una llave; si no, lo deja tal cual. Así el mismo widget sirve para el
/// uso normal y para cuando le toca ser señalado en el recorrido.
Widget maybeShowcase({
  required GlobalKey? key,
  required String title,
  required String description,
  required Widget child,
}) {
  if (key == null) return child;
  return Showcase(
    key: key,
    title: title,
    description: description,
    child: child,
  );
}
