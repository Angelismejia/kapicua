# Kapicua 

Anotador de dominó para mi grupo de amigos, hecho en Flutter con Firebase.

## ¿Qué hace?

- **Jugadores**: agrega y elimina participantes de la liga (nombre completo + apodo opcional).
- **Nueva partida**: elige quiénes juegan y la meta de puntos.
- **Anotador en vivo**: anota los puntos de cada ronda; la app suma el total y detecta al ganador automáticamente.
- **Historial**: consulta todas las partidas jugadas, ronda por ronda.
- **Estadísticas**: ganadas, perdidas, total de partidas y porcentaje de victorias de cada jugador.
- **Ganador del mes**: se calcula solo según las partidas ganadas cada mes.
- **Certificado de campeón**: genera un certificado con el nombre, mes y puntaje del ganador, listo para descargar, compartir o imprimir.
- **Modo oscuro** y datos sincronizados en tiempo real para todo el grupo (Firebase Firestore).

## Tecnología

- Flutter (Android)
- Firebase (Firestore + Authentication)
- Paquete `printing` para generar e imprimir el certificado
