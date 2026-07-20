import 'dart:html' as html;

void reloadPage() {
  html.window.location.reload();
}

// Evita que la recarga automática se repita en bucle si el problema
// persiste después de recargar (ej. sin internet de verdad): solo se
// permite un intento por pestaña abierta.
bool shouldAutoReloadOnce() {
  const key = 'kapicua_auth_watchdog_reloaded';
  if (html.window.sessionStorage[key] == '1') return false;
  html.window.sessionStorage[key] = '1';
  return true;
}
