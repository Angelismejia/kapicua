/// Invitados fuera de la familia: cuentas anónimas ("Jugar sin cuenta")
/// que tienen su propio espacio de datos (guestSpaces/{uid}).
abstract class GuestRepository {
  Future<bool> hasGuestProfile(String uid);

  Future<void> createGuestProfile(String uid);
}
