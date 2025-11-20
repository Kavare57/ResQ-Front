# ResQ App - Frontend

Aplicación móvil Flutter para el sistema ResQ, una plataforma de solicitud de ambulancias y comunicación de emergencias con integración de llamadas de audio en tiempo real usando LiveKit.

## 📱 Características

- ✅ Autenticación de usuarios (registro e login)
- ✅ Completar perfil de solicitante (datos personales y documentación)
- ✅ Interfaz de llamadas de audio con LiveKit (solo audio, sin vídeo)
- ✅ Solicitud de ambulancias (SOS)
- ✅ Gestión de sesión con tokens JWT
- ✅ Logging detallado para debugging
- ✅ Timeouts configurados en todas las peticiones API

## 🛠️ Tecnologías

- **Flutter** 3.24.0 - Framework de desarrollo multiplataforma
- **Dart** - Lenguaje de programación
- **HTTP** - Cliente HTTP para peticiones REST
- **LiveKit Client** ^2.5.3 - Integración de llamadas de audio
- **Shared Preferences** - Almacenamiento local de sesión
- **Material Design 3** - Diseño de interfaz

## 📋 Requisitos

- Flutter 3.24.0 o superior
- Dart SDK (incluido con Flutter)
- Android SDK (para compilar en Android)
- Xcode (para compilar en iOS, solo en macOS)

## 🚀 Instalación

1. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/Kavare57/ResQ-Front.git
   cd ResQ-Front/FrontEnd/resq_app
   ```

2. **Instalar dependencias:**
   ```bash
   flutter pub get
   ```

3. **Configurar variables de entorno:**
   ```bash
   cp lib/core/constants/env.dart.example lib/core/constants/env.dart
   ```
   Editar `lib/core/constants/env.dart` con la URL correcta del backend:
   ```dart
   static const String apiBaseUrl = 'http://192.168.1.6:8000'; // O tu URL del backend
   ```

4. **Ejecutar la aplicación:**
   ```bash
   flutter run
   ```

## 📁 Estructura del Proyecto

```
lib/
├── core/
│   ├── api/                      # Clientes HTTP para endpoints
│   │   ├── auth_api.dart        # Endpoints de autenticación
│   │   ├── solicitantes_api.dart # Endpoints de perfil
│   │   └── emergencias_api.dart  # Endpoints de ambulancias
│   ├── constants/
│   │   └── env.dart             # Configuración de URL del backend
│   ├── services/
│   │   └── storage_service.dart # Almacenamiento local (SharedPreferences)
│   └── widgets/                 # Widgets reutilizables
├── features/
│   ├── auth/
│   │   ├── application/
│   │   │   └── auth_controller.dart    # Lógica de autenticación
│   │   └── presentation/
│   │       └── pages/
│   │           ├── login_page.dart
│   │           └── register_page.dart
│   ├── solicitante/
│   │   └── presentation/
│   │       └── pages/
│   │           ├── home_solicitante_page.dart
│   │           ├── perfil_solicitante_page.dart
│   │           └── nueva_emergencia_page.dart
│   └── llamada/
│       └── presentation/
│           └── pages/
│               └── llamada_page.dart   # Interfaz de llamadas de audio
├── main.dart                    # Punto de entrada
└── routes.dart                  # Configuración de rutas
```

## 🔐 Autenticación

### Flujo de Registro

1. Usuario ingresa nombre, email y contraseña
2. Backend crea usuario en BD
3. Se inicia sesión automáticamente (token guardado)
4. Se redirige a página de perfil para completar datos
5. Se guardan datos personales
6. Se limpia el token y se redirige a login para iniciar sesión formal

### Flujo de Login

1. Usuario ingresa email y contraseña
2. Backend verifica credenciales y genera token JWT
3. Token se guarda en storage local
4. ID de usuario se extrae del token y se guarda en storage
5. Se redirige a Home

### Opciones de Sesión

- **Con "Recuérdame":** Token persiste entre reinicios de la app
- **Sin "Recuérdame":** Token persiste durante la sesión actual

## 📞 Llamadas de Audio

### Características

- ✅ Solo audio (sin vídeo)
- ✅ Botón de muteo/desmuteo
- ✅ Botón para colgar la llamada
- ✅ Indicador visual del estado de conexión

### Integración LiveKit

```dart
// Ejemplo de cómo conectar a LiveKit
final credentials = await _emergenciasApi.solicitarAmbulancia();
final room = livekit.Room();
await room.connect(
  credentials.server_url,
  credentials.token,
);
```

## 🔗 Endpoints API Utilizados

### Autenticación
- `POST /auth/login` - Login de usuario
- `POST /usuarios` - Registro de nuevo usuario

### Perfil
- `GET /solicitantes/{id}` - Obtener perfil del solicitante
- `PUT /solicitantes/{id}` - Actualizar perfil del solicitante

### Emergencias
- `POST /emergencias` - Solicitar ambulancia (retorna credenciales LiveKit)

## 📊 Logging

La aplicación incluye logging detallado con prefijos específicos:

- `[LOGIN]` - Eventos de inicio de sesión
- `[REGISTER]` - Eventos de registro
- `[SOLICITANTE]` - Eventos de perfil
- `[EMERGENCIA]` - Eventos de solicitud de ambulancia
- `[HOME]` - Eventos de página principal
- `[AUTH]` - Eventos generales de autenticación
- `[PERFIL]` - Eventos de página de perfil
- `[LLAMADA]` - Eventos de llamadas de audio

## ⏱️ Timeouts

Todas las peticiones HTTP tienen timeouts configurados:
- **Auth & Perfil:** 10 segundos
- **Emergencias:** 15 segundos (mayor duración para operaciones críticas)

## 🐛 Debugging

### Ver logs en terminal:
```bash
flutter logs
```

### Ejecutar en modo debug:
```bash
flutter run -v
```

## 🤝 Contribuir

1. Fork el repositorio
2. Crear rama para feature (`git checkout -b feature/AmazingFeature`)
3. Commit cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abrir Pull Request

## 📝 Notas Importantes

- El backend debe estar corriendo en `http://192.168.1.6:8000` (o configurar URL en `env.dart`)
- LiveKit Cloud debe estar configurado en el backend
- CORS debe estar habilitado en el backend para permitir conexiones desde dispositivos móviles
- Usar dispositivo físico para probar, no emulador (para mejor rendimiento)

## 🔄 Estado de Desarrollo

### Completado ✅
- Autenticación (login/registro)
- Perfil de usuario
- Interfaz de llamadas de audio con LiveKit
- Solicitud de ambulancias
- Logging y debugging

### Pendiente ⏳
- Backend debe proporcionar endpoint `/solicitantes/me` para sincronización automática de ID
- Mejorar manejo de caché de perfiles
- Tests unitarios y de integración

## 📞 Soporte

Para reportar bugs o solicitar features, abrir un issue en el repositorio.

## 📄 Licencia

Este proyecto es parte del sistema ResQ. Consultar LICENSE para más detalles.

---

**Desarrollado con ❤️ usando Flutter**
