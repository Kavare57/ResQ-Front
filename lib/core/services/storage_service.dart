import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _tokenKey = 'access_token';
  static const _userIdKey = 'user_id';
  static const _nombreUsuarioKey = 'nombre_usuario';
  static const _tipoUsuarioKey = 'tipo_usuario';
  static const _personaIdKey = 'persona_id';
  static const _rememberKey = 'remember_me';

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, userId);
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  Future<void> saveNombreUsuario(String nombreUsuario) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nombreUsuarioKey, nombreUsuario);
  }

  Future<String?> getNombreUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nombreUsuarioKey);
  }

  Future<void> saveTipoUsuario(String tipoUsuario) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tipoUsuarioKey, tipoUsuario);
  }

  Future<String?> getTipoUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tipoUsuarioKey);
  }

  Future<void> savePersonaId(int personaId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_personaIdKey, personaId);
  }

  Future<int?> getPersonaId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_personaIdKey);
  }

  Future<void> saveRemember(bool remember) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, remember);
  }

  Future<bool?> getRemember() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberKey);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_nombreUsuarioKey);
    await prefs.remove(_tipoUsuarioKey);
    await prefs.remove(_personaIdKey);
    await prefs.remove(_rememberKey);
  }
}

