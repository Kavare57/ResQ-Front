class Env {
  static const String apiBaseUrl = 'http://192.168.1.6:8000'; // <- CAMBIA AQUÍ  
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );
}
