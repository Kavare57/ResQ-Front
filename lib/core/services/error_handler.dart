class ErrorHandler {
  static String getErrorMessage(dynamic error) {
    if (error is Exception) {
      final message = error.toString();
      
      // LiveKit errors
      if (message.contains('WebSocket')) {
        return 'Error de conexión con el servidor. Verifica tu conexión a internet.';
      }
      if (message.contains('timeout')) {
        return 'La operación tardó demasiado. Intenta de nuevo.';
      }
      if (message.contains('SSL')) {
        return 'Error de seguridad en la conexión. Contacta al administrador.';
      }
      if (message.contains('Permission')) {
        return 'Permiso denegado. Revisa los permisos de la aplicación.';
      }
      
      // DNS and network errors
      if (message.contains('SocketException') || 
          message.contains('No address associated with hostname') ||
          message.contains('Failed host lookup') ||
          message.contains('getaddrinfo failed')) {
        return 'Error de DNS: No se pudo resolver el hostname. Verifica tu conexión a internet y la configuración de DNS del emulador/dispositivo.';
      }
      if (message.contains('FormatException')) {
        return 'Respuesta inválida del servidor. Intenta de nuevo.';
      }
      if (message.contains('401') || message.contains('Unauthorized')) {
        return 'Tu sesión ha expirado. Inicia sesión de nuevo.';
      }
      if (message.contains('403') || message.contains('Forbidden')) {
        return 'No tienes permiso para realizar esta acción.';
      }
      if (message.contains('404') || message.contains('NotFound')) {
        return 'El recurso solicitado no existe.';
      }
      if (message.contains('500')) {
        return 'Error del servidor. Intenta de nuevo más tarde.';
      }
      
      // Generic error - return cleaned message
      return _cleanErrorMessage(message);
    }
    
    return 'Ocurrió un error inesperado. Intenta de nuevo.';
  }
  
  static String _cleanErrorMessage(String message) {
    // Remover "Exception: " o "Error: " del inicio
    if (message.startsWith('Exception: ')) {
      message = message.replaceFirst('Exception: ', '');
    }
    if (message.startsWith('Error: ')) {
      message = message.replaceFirst('Error: ', '');
    }
    
    // Truncar si es muy largo
    if (message.length > 150) {
      message = '${message.substring(0, 147)}...';
    }
    
    return message;
  }
  
  static void logError(String context, dynamic error, StackTrace? stackTrace) {
    print('❌ [$context] ERROR: $error');
    if (stackTrace != null) {
      print('Stack: $stackTrace');
    }
  }
}
