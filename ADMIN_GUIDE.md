# Guía de Administración de Usuarios - ResQ

Esta guía explica cómo registrar y gestionar operadores de ambulancia y emergencia desde la consola Python.

## 1. Registrar un Operador de Ambulancia

### Paso 1: Accede a la consola Python del backend

```bash
cd c:\Users\USER\Desktop\backend-resq\ResQ
python
```

### Paso 2: Importa los módulos necesarios

```python
from src.dataLayer.dataAccesComponets.repositorioUsuarios import crearUsuario, actualizarUsuarioPersona
from src.dataLayer.dataAccesComponets.repositorioOperadorAmbulancia import crearOperadorAmbulancia
from src.security.entities.Usuario import Usuario, TipoUsuario
from src.businessLayer.businessEntities.persona import OperadorAmbulancia
from datetime import datetime

# Asegúrate de que la BD esté inicializada
from src.dataLayer.bd import SessionLocal
db = SessionLocal()
```

### Paso 3: Crea el usuario (cuenta)

```python
# Crear la cuenta del usuario
usuario = Usuario(
    nombreDeUsuario="operador_juan",
    email="operador_juan@example.com",
    contrasenaHasheada="mi_contraseña"  # Será hasheada automáticamente
)

usuario_creado = crearUsuario(usuario)
print(f"Usuario creado con ID: {usuario_creado.id}")
# Guarda este ID, lo necesitarás en el siguiente paso
```

### Paso 4: Crea el perfil del operador de ambulancia

```python
operador = OperadorAmbulancia(
    nombre="Juan",
    apellido="Pérez",
    nombre2=None,  # Opcional
    apellido2=None,  # Opcional
    tipoDocumento="CEDULA",
    numeroDocumento="1234567890",
    fechaNacimiento=datetime(1990, 5, 15),
    numerolicencia="ABC-123-456",
    disponibilidad=True
)

operador_creado = crearOperadorAmbulancia(operador, db)
print(f"Operador de ambulancia creado con ID: {operador_creado.id}")
# Guarda este ID para el siguiente paso
```

### Paso 5: Asocia el usuario con el operador

```python
actualizarUsuarioPersona(
    id_usuario=usuario_creado.id,      # ID del usuario creado en paso 3
    id_persona=operador_creado.id,     # ID del operador creado en paso 4
    tipoUsuario=TipoUsuario.OPERADOR_AMBULANCIA
)

print("Asociación completada exitosamente")
```

### Resumen: Operador de Ambulancia Creado ✅

| Campo | Valor |
|-------|-------|
| Email | operador_juan@example.com |
| Contraseña | mi_contraseña |
| Nombre | Juan Pérez |
| Licencia | ABC-123-456 |
| Tipo | OPERADOR_AMBULANCIA |

---

## 2. Registrar un Operador de Emergencias

El proceso es similar, pero usaremos `OperadorEmergencia` en lugar de `OperadorAmbulancia`.

### Paso 1-3: Igual a arriba (crear usuario)

```python
usuario = Usuario(
    nombreDeUsuario="operador_central_maria",
    email="operador_central@example.com",
    contrasenaHasheada="otra_contraseña"
)

usuario_creado = crearUsuario(usuario)
```

### Paso 4: Crea el perfil del operador de emergencias

```python
from src.businessLayer.businessEntities.persona import OperadorEmergencia

operador = OperadorEmergencia(
    nombre="María",
    apellido="García",
    nombre2=None,
    apellido2=None,
    tipoDocumento="CEDULA",
    numeroDocumento="9876543210",
    fechaNacimiento=datetime(1988, 3, 20),
    turno="NOCTURNO",  # MATUTINO, VESPERTINO, NOCTURNO, FLEXIBLE
    disponibilidad=True
)

operador_creado = crearOperadorEmergencia(operador, db)
```

### Paso 5: Asocia el usuario con el operador

```python
actualizarUsuarioPersona(
    id_usuario=usuario_creado.id,
    id_persona=operador_creado.id,
    tipoUsuario=TipoUsuario.OPERADOR_EMERGENCIA
)

print("Operador de emergencias registrado exitosamente")
```

---

## 3. Listar Todos los Usuarios

```python
from src.dataLayer.dataAccesComponets.repositorioUsuarios import listar_usuarios

usuarios = listar_usuarios()
for u in usuarios:
    print(f"ID: {u.id} | Email: {u.email} | Tipo: {u.tipoUsuario}")
```

---

## 4. Actualizar Disponibilidad de un Operador

```python
from src.dataLayer.dataAccesComponets.repositorioOperadorAmbulancia import actualizar_disponibilidad_operador

actualizar_disponibilidad_operador(
    id_operador=operador_creado.id,
    disponibilidad=False,  # Desactivar
    db=db
)

print("Disponibilidad actualizada")
```

---

## 5. Buscar un Usuario por Email

```python
from src.dataLayer.dataAccesComponets.repositorioUsuarios import obtenerUsuario

usuario = obtenerUsuario(email="operador_juan@example.com")
if usuario:
    print(f"Usuario encontrado: {usuario.nombreDeUsuario}")
    print(f"ID: {usuario.id}")
    print(f"Tipo: {usuario.tipoUsuario}")
    print(f"ID Persona: {usuario.id_persona}")
else:
    print("Usuario no encontrado")
```

---

## 6. Cambiar Contraseña de un Usuario (Para Testing)

⚠️ **NOTA**: En producción, esto debe hacerse a través de la API con verificación de seguridad.

```python
from src.security.components.servicioHash import hasearContrasena
from src.dataLayer.dataAccesComponets.repositorioUsuarios import actualizar_usuario

# Hashear la nueva contraseña
nueva_contrasena_hasheada = hasearContrasena("nueva_contraseña")

# Actualizar
usuario_a_actualizar = obtenerUsuario(email="operador_juan@example.com")
usuario_a_actualizar.contrasenaHasheada = nueva_contrasena_hasheada

actualizar_usuario(usuario_a_actualizar)
print("Contraseña actualizada")
```

---

## 7. Eliminar un Usuario (Cuidado)

```python
from src.dataLayer.dataAccesComponets.repositorioUsuarios import eliminar_usuario

# Primero obtén el usuario
usuario = obtenerUsuario(email="operador_juan@example.com")

# Elimina
eliminar_usuario(usuario.id)
print("Usuario eliminado")
```

---

## Estructura de Datos

### Usuario
```python
class Usuario:
    id: int (auto-generated)
    nombreDeUsuario: str (unique)
    email: str (unique)
    contrasenaHasheada: str (hashed)
    id_persona: Optional[int]
    tipoUsuario: Optional[TipoUsuario]  # SOLICITANTE, OPERADOR_AMBULANCIA, OPERADOR_EMERGENCIA
```

### OperadorAmbulancia
```python
class OperadorAmbulancia:
    id: int (auto-generated)
    nombre: str
    apellido: str
    nombre2: Optional[str]
    apellido2: Optional[str]
    tipoDocumento: str (CEDULA, PASAPORTE, VISA)
    numeroDocumento: str
    fechaNacimiento: datetime
    numerolicencia: str
    disponibilidad: bool
```

### OperadorEmergencia
```python
class OperadorEmergencia:
    id: int (auto-generated)
    nombre: str
    apellido: str
    nombre2: Optional[str]
    apellido2: Optional[str]
    tipoDocumento: str (CEDULA, PASAPORTE, VISA)
    numeroDocumento: str
    fechaNacimiento: datetime
    turno: str (MATUTINO, VESPERTINO, NOCTURNO, FLEXIBLE)
    disponibilidad: bool
```

---

## Script Completo de Ejemplo

```python
#!/usr/bin/env python
"""Script de ejemplo para registrar un operador de ambulancia"""

from datetime import datetime
from src.dataLayer.dataAccesComponets.repositorioUsuarios import (
    crearUsuario, actualizarUsuarioPersona
)
from src.dataLayer.dataAccesComponets.repositorioOperadorAmbulancia import crearOperadorAmbulancia
from src.security.entities.Usuario import Usuario, TipoUsuario
from src.businessLayer.businessEntities.persona import OperadorAmbulancia
from src.dataLayer.bd import SessionLocal

# Conexión a BD
db = SessionLocal()

# Paso 1: Crear usuario (cuenta)
print("1. Creando usuario...")
usuario = Usuario(
    nombreDeUsuario="ambulancia_carlos",
    email="carlos_ambulancia@example.com",
    contrasenaHasheada="password123"
)
usuario_creado = crearUsuario(usuario)
print(f"   ✅ Usuario creado: ID={usuario_creado.id}")

# Paso 2: Crear perfil de operador
print("2. Creando perfil de operador...")
operador = OperadorAmbulancia(
    nombre="Carlos",
    apellido="López",
    tipoDocumento="CEDULA",
    numeroDocumento="1122334455",
    fechaNacimiento=datetime(1995, 7, 10),
    numerolicencia="XYZ-789-012",
    disponibilidad=True
)
operador_creado = crearOperadorAmbulancia(operador, db)
print(f"   ✅ Operador creado: ID={operador_creado.id}")

# Paso 3: Asociar usuario con operador
print("3. Asociando usuario con operador...")
actualizarUsuarioPersona(
    id_usuario=usuario_creado.id,
    id_persona=operador_creado.id,
    tipoUsuario=TipoUsuario.OPERADOR_AMBULANCIA
)
print("   ✅ Asociación completada")

print("\n✅ Operador registrado exitosamente!")
print(f"   Email: carlos_ambulancia@example.com")
print(f"   Contraseña: password123")

db.close()
```

---

## Notas Importantes

⚠️ **Seguridad:**
- Las contraseñas se hashean automáticamente usando bcrypt
- Nunca guardes contraseñas en texto plano
- Usa contraseñas fuertes en producción

⚠️ **Validación:**
- El email debe ser único en la tabla `usuarios`
- El nombreDeUsuario debe ser único en la tabla `usuarios`
- El numeroDocumento debe ser único en la tabla del tipo de persona
- La fechaNacimiento debe ser una fecha válida

⚠️ **Relaciones:**
- Un usuario solo puede asociarse a UNA persona
- El tipo de persona se determina por `tipoUsuario`
- `id_persona` es una referencia lógica, no una foreign key

---

## Panel de Admin (Futuro)

En un futuro, esto se simplificará con un panel de admin en la app:

```
[Dashboard Admin]
├─ Crear Operador de Ambulancia
├─ Crear Operador de Emergencias
├─ Listar Operadores
├─ Desactivar Operador
└─ Cambiar Contraseña
```

Por ahora, usa los comandos de consola anteriores.
