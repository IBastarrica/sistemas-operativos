# Notas técnicas - Ejercicios 2, 3 y 4

Este documento explica los tres ejercicios de la serie de Sistemas Operativos, su parte técnica y cómo ejecutar cada uno.

---

## Ejercicio 2 - ABM con archivos TSV estáticos (Bash)

**Archivo:** `ejercicio-2/ejercicio-2.sh`

### Descripción
Sistema de gestión de inventario (ABM: Alta, Baja, Mostrar y Editar de productos) con autenticación de usuarios. Toda la información se guarda en archivos TSV estáticos en disco:
- `productos.tsv` — inventario de productos
- `usuarios.tsv` — usuarios registrados con contraseñas hasheadas

### Parte técnica
- Lenguaje: Bash puro
- Almacenamiento: archivos TSV (valores separados por tabuladores)
- Estructura de datos: arrays asociativos de Bash (`declare -A inventario`)
- IDs de producto: fijos del 0 al 2 (`MAX=3`)
- Contraseñas: hash SHA-256 mediante `sha256sum`
- Validaciones: usuario no vacío, único, clave no vacía, claves coinciden, ID en rango válido
- Logs: no tiene logs externos (se agregan en el ejercicio 3)

### Cómo ejecutar
```bash
cd ejercicio-2
chmod +x ejercicio-2.sh
./ejercicio-2.sh
```

---

## Ejercicio 3 - ABM con SQLite3 (Bash + SQL)

**Archivo:** `ejercicio-3/ejercicio-3.sh`

### Descripción
Reimplementación del ejercicio 2 donde los archivos TSV estáticos se reemplazan por una base de datos SQLite llamada `data.sq3`. Se agregan registros de auditoría mediante logs externos.

### Parte técnica
- Lenguaje: Bash + SQLite3
- Almacenamiento: base de datos SQLite (`data.sq3`)
- Tablas SQL:
  - `usuarios(id_usuario, usuario, hash_clave)`
  - `productos(id_producto, nombre, precio, activo)`
- Inicialización automática: si `data.sq3` no existe, se crea con el esquema SQL y se precargan los lugares de producto con IDs 0, 1, 2
- Contraseñas: hash SHA-256 (`sha256sum`), mismo criterio que ejercicio 2
- Logs:
  - `system.log` — `fecha/hora | ID usuario | nombre usuario | acción`
  - `error.log` — `fecha/hora | mensaje de error`
- Transparencia: los menús y forma de uso son idénticos al ejercicio 2

### Cómo ejecutar
```bash
sudo apt install sqlite3   # si no esta instalado
cd ejercicio-3
chmod +x ejercicio-3.sh
./ejercicio-3.sh
```

Archivos generados automáticamente al ejecutar: `data.sq3`, `system.log`, `error.log`.

---

## Ejercicio 4 - ABM con interfaz TUI (Bash + dialog + SQLite3)

**Archivo:** `ejercicio-4/ejercicio-4.sh`

### Descripción
Toma el resultado del ejercicio 3 y construye una interfaz de menús alternativa aplicando el modelo **TUI** (Text User Interface) usando el comando `dialog`. Emula una interfaz gráfica más convencional dentro de la terminal, manteniendo toda la lógica de backend (SQLite3, logs, SHA-256) intacta.

### Parte técnica
- Lenguaje: Bash + `dialog` + SQLite3
- Herramienta TUI: `dialog` (ventanas, menús, inputbox, passwordbox, msgbox)
- Captura de entrada: `dialog` escribe por stderr, se redirige con `2>&1 >/dev/tty`
- Almacenamiento: base de datos SQLite (`data.sq3`) igual que ejercicio 3
- Tablas SQL: idénticas al ejercicio 3
- Contraseñas: hash SHA-256, mismo criterio
- Logs: `system.log` y `error.log` igual que ejercicio 3
- Transparencia total: los menús tienen las mismas opciones que los ejercicios anteriores, solo cambia la capa visual

### Pantallas TUI implementadas
| Pantalla | Widget de dialog |
|----------|-----------------|
| Menú de acceso | `--menu` |
| Inicio de sesión | `--inputbox` + `--passwordbox` |
| Registro de usuario | `--inputbox` + `--passwordbox` |
| Menú principal | `--menu` |
| Alta producto | `--inputbox` (ID, Nombre, Precio) |
| Baja producto | `--inputbox` (ID) |
| Editar producto | `--inputbox` (nuevo precio) |
| Mostrar inventario | `--msgbox` con listado |
| Mensajes de éxito/error | `--msgbox` |

### Cómo ejecutar
```bash
sudo apt install sqlite3 dialog   # si no estan instalados
cd ejercicio-4
chmod +x ejercicio-4.sh
./ejercicio-4.sh
```

Archivos generados automáticamente al ejecutar: `data.sq3`, `system.log`, `error.log`.

---

## Diferencias resumidas entre los tres ejercicios

| Característica | Ejercicio 2 | Ejercicio 3 | Ejercicio 4 |
|----------------|-------------|-------------|-------------|
| Interfaz | CLI (`read`, `printf`) | CLI (`read`, `printf`) | TUI (`dialog`) |
| Almacenamiento | TSV estáticos | SQLite3 (`data.sq3`) | SQLite3 (`data.sq3`) |
| Logs externos | No | Sí (`system.log`, `error.log`) | Sí (`system.log`, `error.log`) |
| Contraseñas | SHA-256 | SHA-256 | SHA-256 |
| IDs producto | 0 a 2 | 0 a 2 | 0 a 2 |
| Menús | Idénticos | Idénticos | Idénticos en opciones, distintos en presentación |

---

## Requisitos del sistema (para los tres ejercicios)

- Sistema operativo: Debian / Parrot / Ubuntu (o derivados)
- Shell: Bash
- Paquetes necesarios:
  - `sqlite3` (obligatorio para ejercicios 3 y 4)
  - `dialog` (obligatorio solo para ejercicio 4)

Instalación de dependencias:
```bash
sudo apt update
sudo apt install sqlite3 dialog
```

---

## Estructura de entrega en GitHub

```
sistemas-operativos/ (repositorio)
├── ejercicio-2/
│   └── ejercicio-2.sh
├── ejercicio-3/
│   ├── ejercicio-3.sh
│   ├── .gitignore
│   └── README.md
└── ejercicio-4/
    ├── ejercicio-4.sh
    ├── .gitignore
    ├── README.md
    └── notas.md
```

> Nota: los archivos `data.sq3`, `system.log` y `error.log` no se suben al repositorio porque se generan automáticamente al ejecutar cada script.