# Kapicua

https://kapicua.web.app/

Anotador de dominó para llevar el control de partidas, jugadores y
estadísticas de una liga familiar.

## Funciones

- Jugar sin cuenta, o registrarte con el PIN familiar para unirte a la liga.
- Agregar jugadores y ver la liga completa.
- Crear partidas (Casa vs Visita) y anotar puntos ronda por ronda, varias
  mesas a la vez.
- Historial de partidas terminadas.
- Estadísticas de cada jugador (ganadas, perdidas, %).
- Campeón del mes con calendario para revisar meses anteriores.
- Certificado de campeón descargable e imprimible.
- Perfil con foto y cambio de contraseña.
- Modo oscuro.
- Datos sincronizados en tiempo real.

## Próximamente

- Crear tu propio PIN y tener tu propio Kapicua familiar independiente.

## Aspectos técnicos

- Sincronización en tiempo real con streams de Firestore (partidas,
  jugadores y estadísticas se actualizan solos en todos los dispositivos).
- Reglas de seguridad de Firestore: solo cuentas admin (por correo) pueden
  editar estadísticas, incluyendo consultas `collectionGroup`.
- Dos flujos de autenticación separados: cuentas familiares vinculadas a
  un jugador, y modo invitado anónimo con su propio espacio de datos.
- Generación de certificados en PDF, rotando la imagen para que llene
  una hoja vertical completa sin recortes.
- Fotos de perfil comprimidas y guardadas como base64 en Firestore, para
  no depender de un servicio de archivos de pago.
- Una sola base de código Flutter para Web y Android.

## Tecnologías

- Flutter (Web + Android)
- Firebase Authentication
- Firebase Firestore
- Printing package
