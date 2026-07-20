/// Estado compartido de "en qué espacio estamos": el de la familia o el
/// propio de un invitado anónimo (guestSpaces/{guestUid}). Los
/// repositorios lo consultan en cada operación para saber qué colección
/// de Firestore usar, igual que antes hacía `FirestoreService.isGuest`.
class GuestSession {
  bool isGuest = false;
  String? guestUid;
}
