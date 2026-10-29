# Ejercicio 4 - ABM de productos con TUI (Text User Interface)

Reimplementación del ejercicio 3 con una interfaz de menús alternativa tipo **TUI** usando el comando `dialog`.

## Estructura del repositorio

```
ejercicio-4/
├── ejercicio-4.sh   # Script principal con interfaz TUI
├── .gitignore       # Ignora archivos generados (.sq3, .log)
├── README.md        # Este archivo
└── notas.md         # Explicaciones de los ejercicios y parte técnica
```

## Requisitos

- Bash
- sqlite3 (`sudo apt install sqlite3`)
- dialog (`sudo apt install dialog`)

## Cómo ejecutar

```bash
chmod +x ejercicio-4.sh
./ejercicio-4.sh
```

Al ejecutarse por primera vez se crean automáticamente:
- `data.sq3` — base de datos SQLite con tablas `usuarios` y `productos`
- `system.log` — registro de acciones del usuario
- `error.log` — registro de errores (si ocurren)

## Menús TUI

**Acceso:**
1. Iniciar sesión
2. Registrar usuario

**Acciones (tras iniciar sesión):**
1. Alta producto (ID 0 a 2)
2. Baja producto
3. Mostrar inventario
4. Editar producto
5. Salir

## Notas

- Las contraseñas se almacenan hasheadas con SHA-256.
- Los menús son idénticos en opciones al ejercicio 2 y 3 (transparencia para el usuario).
- Cada acción queda registrada en `system.log` con formato TSV: `fecha/hora | ID usuario | nombre usuario | acción`.
- Toda la información se gestiona mediante SQLite (`data.sq3`), sin archivos TSV estáticos.