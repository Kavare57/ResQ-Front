import 'package:geolocator/geolocator.dart';

/// Servicio singleton para manejar la ubicación GPS en segundo plano
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _preciseLocation;
  Position? _lastKnownLocation;
  bool _isInitializing = false;
  bool _isUpdating = false;

  /// Inicializa la obtención de ubicación precisa en segundo plano
  /// No bloquea, se ejecuta de forma asíncrona
  Future<void> initialize() async {
    if (_isInitializing) {
      print('[LOCATION_SERVICE] Ya se está inicializando, ignorando llamada');
      return;
    }

    _isInitializing = true;
    print('[LOCATION_SERVICE] Iniciando obtención de ubicación en segundo plano...');

    try {
      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('[LOCATION_SERVICE] Permisos denegados, no se puede obtener ubicación');
          _isInitializing = false;
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('[LOCATION_SERVICE] Permisos denegados permanentemente');
        _isInitializing = false;
        return;
      }

      // Verificar si el servicio de ubicación está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('[LOCATION_SERVICE] Servicio de ubicación deshabilitado');
        _isInitializing = false;
        return;
      }

      // Obtener última ubicación conocida primero (rápido)
      _lastKnownLocation = await Geolocator.getLastKnownPosition();
      if (_lastKnownLocation != null) {
        print('[LOCATION_SERVICE] Última ubicación conocida: ${_lastKnownLocation!.latitude}, ${_lastKnownLocation!.longitude}');
      }

      // Obtener ubicación precisa en segundo plano (puede tardar)
      _preciseLocation = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 20),
      );

      print('[LOCATION_SERVICE] Ubicación precisa obtenida: ${_preciseLocation!.latitude}, ${_preciseLocation!.longitude}');
    } catch (e) {
      print('[LOCATION_SERVICE] Error obteniendo ubicación: $e');
      // Si falla, mantener la última conocida si existe
    } finally {
      _isInitializing = false;
    }
  }

  /// Obtiene la ubicación actual (precisa si está lista, última conocida si no)
  /// Retorna null si no hay ninguna ubicación disponible
  Position? getCurrentLocation() {
    if (_preciseLocation != null) {
      print('[LOCATION_SERVICE] Retornando ubicación precisa');
      return _preciseLocation;
    }
    if (_lastKnownLocation != null) {
      print('[LOCATION_SERVICE] Retornando última ubicación conocida (precisa aún no disponible)');
      return _lastKnownLocation;
    }
    print('[LOCATION_SERVICE] No hay ubicación disponible');
    return null;
  }

  /// Retorna la última ubicación conocida
  Position? getLastKnownLocation() {
    return _lastKnownLocation;
  }

  /// Retorna la ubicación precisa si está disponible
  Position? getPreciseLocation() {
    return _preciseLocation;
  }

  /// Fuerza la actualización manual de la ubicación
  /// Útil cuando el usuario presiona el botón "Usar mi ubicación"
  Future<Position?> updateLocation() async {
    if (_isUpdating) {
      print('[LOCATION_SERVICE] Ya se está actualizando, esperando...');
      // Esperar a que termine la actualización actual
      while (_isUpdating) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return getCurrentLocation();
    }

    _isUpdating = true;
    print('[LOCATION_SERVICE] Actualizando ubicación manualmente...');

    try {
      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('[LOCATION_SERVICE] Permisos denegados');
          _isUpdating = false;
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('[LOCATION_SERVICE] Permisos denegados permanentemente');
        _isUpdating = false;
        return null;
      }

      // Verificar si el servicio de ubicación está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('[LOCATION_SERVICE] Servicio de ubicación deshabilitado');
        _isUpdating = false;
        return null;
      }

      // Obtener ubicación precisa
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );

      _preciseLocation = position;
      _lastKnownLocation = position; // También actualizar la última conocida
      
      print('[LOCATION_SERVICE] Ubicación actualizada: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('[LOCATION_SERVICE] Error actualizando ubicación: $e');
      return getCurrentLocation(); // Retornar la que tengamos disponible
    } finally {
      _isUpdating = false;
    }
  }

  /// Verifica si hay una ubicación precisa disponible
  bool hasPreciseLocation() {
    return _preciseLocation != null;
  }

  /// Verifica si hay alguna ubicación disponible (precisa o última conocida)
  bool hasLocation() {
    return _preciseLocation != null || _lastKnownLocation != null;
  }
}

