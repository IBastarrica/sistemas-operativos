# Ejercicio 3 - ABM de productos con SQLite3 (Bash)

Reimplementación del ejercicio 2 reemplazando archivos TSV estáticos por una base de datos SQLite (`data.sq3`).

## Estructura del repositorio

```
ejercicio-3/
├── ejercicio-3.sh   # Script principal
├── .gitignore       # Ignora archivos generados (.sq3, .log)
└── README.md        # Este archivo
```

## Requisitos

- Bash
- sqlite3 (`sudo apt install sqlite3`)

## Cómo ejecutar

```bash
chmod +x ejercicio-3.sh
./ejercicio-3.sh
```

Al ejecutarse por primera vez se crean automáticamente:
- `data.sq3` — base de datos SQLite con tablas `usuarios` y `productos`
- `system.log` — registro de acciones del usuario
- `error.log` — registro de errores (si ocurren)

## Menús

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
- Los menús son idénticos al ejercicio 2 (transparencia para el usuario).
- Cada acción queda registrada en `system.log` con formato TSV: `fecha/hora | ID usuario | nombre usuario | acción`.