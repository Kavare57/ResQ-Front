class Env {
  static const String apiBaseUrl = 'http://192.168.1.9:8000';
  static const String wsBaseUrl = 'ws://192.168.1.9:8000';

  // Nominatim (OpenStreetMap) - Completamente gratuito, sin API key requerida
  static const String nominatimBaseUrl = 'https://nominatim.openstreetmap.org';

  // LiveKit Server URL (opcional, se usa para validación)
  // Si está configurada, se validará que las URLs recibidas del servidor coincidan
  // Dejar vacío para no validar
  static const String livekitServerUrl =
      "wss://resq-poyiq9j7.livekit.cloud"; // Ejemplo: 'wss://resq-poyiq9j7.livekit.cloud'
}
