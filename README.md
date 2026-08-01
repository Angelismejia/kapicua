# Kapicua

https://kapicua.web.app/

Anotador de dominó para llevar el control de partidas, jugadores y
estadísticas de una liga familiar. Nació para reemplazar el cuaderno y
la calculadora de cada partida en casa, y hoy lo usa toda la liga de
mi papá en cada mesa.

## Capturas

<!-- TODO: agregar screenshots/GIF de Inicio, partida activa y certificado -->

## Funciones

- Jugar sin cuenta (modo invitado, con tu propio espacio de jugadores
  y partidas), o registrarte con el PIN familiar para unirte a la liga.
- Agregar jugadores, editarlos, fusionar duplicados y desactivar sin
  perder su historial (nunca se borra a alguien que ya jugó partidas).
- Crear partidas (Casa vs Visita) y anotar puntos ronda por ronda,
  varias mesas a la vez, con edición o borrado de rondas ya jugadas.
- Historial de partidas terminadas.
- Estadísticas de cada jugador (ganadas, perdidas, %), con revisión
  del admin antes de que una partida cuente oficialmente.
- Campeón del mes con calendario para revisar meses anteriores, y la
  opción de declararlo a mano para meses sin datos cargados.
- Certificado de campeón descargable e imprimible, o generado a mano
  para cualquier nombre/mes/puntaje.
- Reglas de la liga: las agrega y edita el admin, se pueden compartir
  como PDF paginado, e incluyen un versículo fijo (1 Corintios 10:31)
  arriba de todo.
- Notificaciones y mensajes personalizados en Inicio: rachas de
  ganadas/perdidas, cuánto te falta para alcanzar al líder del mes,
  aniversario de tu cuenta, hitos de la liga.
- Gestión de administradores desde la app (otorgar o quitar permisos).
- Perfil con foto y cambio de contraseña.
- Modo oscuro.
- Datos sincronizados en tiempo real en todos los dispositivos.

## Próximamente

- Crear tu propio PIN y tener tu propio Kapicua familiar independiente.

## Arquitectura

Clean architecture en tres capas, para que la lógica de negocio no
dependa de Firebase ni de Flutter:

- **domain/**: entidades y reglas de negocio puras (por ejemplo, quién
  gana el mes, o cuándo se puede fusionar o borrar un jugador), sin
  ninguna dependencia externa.
- **data/**: implementaciones concretas contra Firestore de los
  repositorios que define `domain/`.
- **presentation/**: pantallas, widgets y controladores de Flutter.
  Solo hablan con `domain/` a través de sus interfaces, nunca
  directamente con Firestore.

Todo el cableado (qué implementación usa cada pantalla) se arma una
sola vez en `main.dart` con `provider`.

## Aspectos técnicos

- Sincronización en tiempo real con streams de Firestore (partidas,
  jugadores y estadísticas se actualizan solos en todos los
  dispositivos).
- Reglas de seguridad de Firestore: solo cuentas con documento propio
  en la colección `admins` pueden editar estadísticas, reglas o
  declarar campeones a mano, incluyendo consultas `collectionGroup`.
- Dos flujos de autenticación separados: cuentas familiares vinculadas
  a un jugador, y modo invitado anónimo con su propio espacio de datos
  aislado en Firestore.
- El campeón del mes exige un mínimo de partidas jugadas a partir del
  día 25 del mes, para que alguien con pocas partidas y una racha alta
  no aparente ir ganando toda la liga.
- Generación de certificados en PDF, rotando la imagen para que llene
  una hoja vertical completa sin recortes; las reglas de la liga se
  comparten como PDF paginado en vez de una sola imagen larga.
- Fotos de perfil comprimidas y guardadas como base64 en Firestore,
  para no depender de un servicio de archivos de pago.
- Una sola base de código Flutter para Web y Android, instalable como
  PWA.

## Tecnologías

- Flutter (Web + Android)
- Firebase Authentication
- Firebase Firestore
- Provider (inyección de dependencias)
- pdf / printing / share_plus
