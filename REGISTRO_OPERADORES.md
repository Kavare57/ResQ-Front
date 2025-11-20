# Registro de Operadores de Ambulancia (Consola/Admin)

## Descripción
Los operadores de ambulancia y de emergencias NO se pueden registrar desde la app (por seguridad).
Deben ser registrados manualmente por administración usando la consola/scripts.

## Flujo de registro de un operador de ambulancia

### Paso 1: Crear el usuario (cuenta de login)
```python
# En una consola Python con el backend
from src.security.entities.Usuario import Usuario
from src.dataLayer.dataAccesComponets.repositorioUsuarios import crearUsuario

# Crear usuario
nuevo_usuario = Usuario(
    nombreDeUsuario='juan_ambulancia',
    email='juan@ambulancia.com',
    contrasenaHasheada='contraseña_segura_123'
)

usuario_creado = crearUsuario(nuevo_usuario)
print(f"Usuario creado con ID: {usuario_creado.id}")
# Output: Usuario creado con ID: 5
```

### Paso 2: Crear el perfil del operador de ambulancia
```python
from src.security.entities.Persona import Persona
from src.businessLayer.businessEntities.operador_ambulancia import OperadorAmbulancia
from src.dataLayer.dataAccesComponets.repositorioOperadoresAmbulancia import crearOperadorAmbulancia

# Crear perfil del operador
operador = OperadorAmbulancia(
    nombre='Juan',
    apellido='Pérez',
    nombre2=None,
    apellido2=None,
    tipoDocumento='CEDULA',
    numeroDocumento='1234567890',
    fechaNacimiento='1990-05-15',
    numerolicencia='ABC123456',
    disponibilidad=True
)

operador_creado = crearOperadorAmbulancia(operador)
print(f"Operador creado con ID: {operador_creado.id}")
# Output: Operador creado con ID: 3
```

### Paso 3: Asociar usuario con operador
```python
from src.dataLayer.dataAccesComponets.repositorioUsuarios import actualizarUsuarioPersona
from src.security.entities.Usuario import TipoUsuario

# Asociar
usuario_actualizado = actualizarUsuarioPersona(
    id_usuario=5,          # ID del usuario (paso 1)
    id_persona=3,          # ID del operador (paso 2)
    tipoUsuario=TipoUsuario.OPERADOR_AMBULANCIA
)

print(f"Usuario {usuario_actualizado.nombreDeUsuario} ahora es OPERADOR_AMBULANCIA")
```

## Script completo (Futuro: admin panel)

```python
# script_crear_operador.py
from src.security.entities.Usuario import Usuario, TipoUsuario
from src.businessLayer.businessEntities.operador_ambulancia import OperadorAmbulancia
from src.dataLayer.dataAccesComponets.repositorioUsuarios import (
    crearUsuario,
    actualizarUsuarioPersona
)
from src.dataLayer.dataAccesComponets.repositorioOperadoresAmbulancia import (
    crearOperadorAmbulancia
)

def registrar_operador_ambulancia(
    nombre_usuario: str,
    email: str,
    password: str,
    nombre: str,
    apellido: str,
    numero_documento: str,
    numero_licencia: str,
    disponibilidad: bool = True,
):
    """
    Registra un operador de ambulancia completo
    """
    # 1. Crear usuario
    usuario = Usuario(
        nombreDeUsuario=nombre_usuario,
        email=email,
        contrasenaHasheada=password  # Aquí va hasheada en la función
    )
    usuario_creado = crearUsuario(usuario)
    
    # 2. Crear operador
    operador = OperadorAmbulancia(
        nombre=nombre,
        apellido=apellido,
        tipoDocumento='CEDULA',
        numeroDocumento=numero_documento,
        fechaNacimiento='1990-01-01',  # Cambiar según caso
        numerolicencia=numero_licencia,
        disponibilidad=disponibilidad
    )
    operador_creado = crearOperadorAmbulancia(operador)
    
    # 3. Asociar
    usuario_final = actualizarUsuarioPersona(
        id_usuario=usuario_creado.id,
        id_persona=operador_creado.id,
        tipoUsuario=TipoUsuario.OPERADOR_AMBULANCIA
    )
    
    print(f"✅ Operador '{nombre_usuario}' registrado exitosamente")
    print(f"   - Usuario ID: {usuario_final.id}")
    print(f"   - Operador ID: {operador_creado.id}")
    return usuario_final

# Uso:
if __name__ == "__main__":
    registrar_operador_ambulancia(
        nombre_usuario='carlos_amb',
        email='carlos@ambulancia.com',
        password='password123',
        nombre='Carlos',
        apellido='López',
        numero_documento='9876543210',
        numero_licencia='XYZ789012',
    )
```

## Variables de entorno (si aplica)
- No requiere configuración especial, usa las mismas credenciales de BD

## Nota para el futuro
Cuando se implemente el panel de admin en la app, estos pasos se automatizarán y la UI será:
```
Admin Panel → Registrar Operador
├─ Nombre de usuario
├─ Email
├─ Password
├─ Tipo (Solicitante / Operador Ambulancia / Operador Emergencia)
└─ Datos personales específicos por tipo
```

## Casos de uso
1. **Agregar nuevo operador**: Usar el script completo
2. **Cambiar disponibilidad**: `PUT /operadores-ambulancia/{id}` (app)
3. **Ver operadores activos**: `GET /operadores-ambulancia` (app)
4. **Desactivar operador**: Cambiar `disponibilidad=False` (app o BD directa)
