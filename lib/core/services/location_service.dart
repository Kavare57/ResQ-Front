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
      return;
    }

    _isInitializing = true;

    try {
      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _isInitializing = false;
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _isInitializing = false;
        return;
      }

      // Verificar si el servicio de ubicación está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _isInitializing = false;
        return;
      }

      // Obtener última ubicación conocida primero (rápido)
      _lastKnownLocation = await Geolocator.getLastKnownPosition();

      // Obtener ubicación precisa en segundo plano (puede tardar)
      _preciseLocation = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 20),
      );
    } catch (e) {
      // Si falla, mantener la última conocida si existe
    } finally {
      _isInitializing = false;
    }
  }

  /// Obtiene la ubicación actual (precisa si está lista, última conocida si no)
  /// Retorna null si no hay ninguna ubicación disponible
  Position? getCurrentLocation() {
    if (_preciseLocation != null) {
      return _preciseLocation;
    }
    if (_lastKnownLocation != null) {
      return _lastKnownLocation;
    }
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
      // Esperar a que termine la actualización actual
      while (_isUpdating) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return getCurrentLocation();
    }

    _isUpdating = true;

    try {
      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _isUpdating = false;
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _isUpdating = false;
        return null;
      }

      // Verificar si el servicio de ubicación está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
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
      return position;
    } catch (e) {
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

