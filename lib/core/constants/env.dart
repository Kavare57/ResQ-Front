class Env {
  static const String apiBaseUrl = 'https://resq-api-jj3j.onrender.com';
  static const String wsBaseUrl = 'wss://resq-api-jj3j.onrender.com';

  // Nominatim (OpenStreetMap) - Completamente gratuito, sin API key requerida
  static const String nominatimBaseUrl = 'https://nominatim.openstreetmap.org';

  // LiveKit Server URL (opcional, se usa para validación)
  // Si está configurada, se validará que las URLs recibidas del servidor coincidan
  // Dejar vacío para no validar
  static const String livekitServerUrl =
      "wss://resq-poyiq9j7.livekit.cloud"; // Ejemplo: 'wss://resq-poyiq9j7.livekit.cloud'
}
