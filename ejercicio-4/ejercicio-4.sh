#!/usr/bin/env bash
#
# Ejercicio 4 - ABM de productos con TUI (Text User Interface)
# Basado en el ejercicio 3 (SQLite3 + logs + SHA-256) pero con interfaz
# tipo TUI usando el comando `dialog`.
#
# Requisitos:
#   - bash
#   - sqlite3  (sudo apt install sqlite3)
#   - dialog   (sudo apt install dialog)
#
# Los menus y la logica de negocio son identicos al ejercicio 3.
# Solo cambia la capa visual: en lugar de leer con read -rp y mostrar con
# printf, se usa dialog (menu, inputbox, passwordbox, msgbox, textbox).

export LC_ALL=C

declare -r -i MAX=3
declare -r DB_FILE="data.sq3"
declare -r SYSTEM_LOG="system.log"
declare -r ERROR_LOG="error.log"

declare -r -i OPCION_ALTA=1
declare -r -i OPCION_BAJA=2
declare -r -i OPCION_MOSTRAR=3
declare -r -i OPCION_EDITAR=4
declare -r -i OPCION_SALIR=5

declare -r -i OPCION_LOGIN=1
declare -r -i OPCION_REGISTRO=2

# Estado de sesion del usuario logueado
declare -i USUARIO_ID_LOGUEADO=-1
declare USUARIO_NOMBRE_LOGUEADO=""

# ----------------------------------------------------------------------------
# Utilidades de dialog
# ----------------------------------------------------------------------------

# dialog escribe su salida por stderr (fd 2). Con esta funcion capturamos
# correctamente lo que el usuario elige/escribe.
capturar_dialog() {
    # Ejecutar dialog y capturar su stderr (la respuesta del usuario)
    "$@" 2>&1 >/dev/tty
}

mostrar_mensaje() {
    local titulo="$1"
    local mensaje="$2"
    dialog --clear --title "$titulo" --msgbox "$mensaje" 0 0 2>&1 >/dev/tty
    return $?
}

mostrar_error() {
    local mensaje="$1"
    dialog --clear --title "Error" --msgbox "$mensaje" 0 0 2>&1 >/dev/tty
    return $?
}

# ----------------------------------------------------------------------------
# Utilidades de base de datos y logs (iguales al ejercicio 3)
# ----------------------------------------------------------------------------

verificar_sqlite3() {
    if ! command -v sqlite3 &>/dev/null; then
        mostrar_error "sqlite3 no esta instalado.\nInstalelo con: sudo apt install sqlite3"
        return 1
    fi
    return 0
}

verificar_dialog() {
    if ! command -v dialog &>/dev/null; then
        mostrar_error "dialog no esta instalado.\nInstalelo con: sudo apt install dialog"
        return 1
    fi
    return 0
}

ejecutar_sql() {
    local sql="$1"
    sqlite3 "$DB_FILE" "$sql" 2>>"$ERROR_LOG"
    return $?
}

consultar_sql() {
    local sql="$1"
    sqlite3 "$DB_FILE" "$sql" 2>>"$ERROR_LOG"
    return $?
}

escapar_sql() {
    local s="$1"
    s="${s//\'/\'\'}"
    printf '%s' "$s"
}

log_error() {
    local msg="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf '%s\t%s\n' "$timestamp" "$msg" >> "$ERROR_LOG"
}

log_sistema() {
    local accion="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf '%s\t%s\t%s\t%s\n' \
        "$timestamp" "$USUARIO_ID_LOGUEADO" "$USUARIO_NOMBRE_LOGUEADO" "$accion" \
        >> "$SYSTEM_LOG"
}

# ----------------------------------------------------------------------------
# Inicializacion de la base de datos
# ----------------------------------------------------------------------------

inicializar_bd() {
    if [[ ! -f "$DB_FILE" ]]; then
        sqlite3 "$DB_FILE" <<'SQL' 2>>"$ERROR_LOG"
CREATE TABLE IF NOT EXISTS usuarios (
    id_usuario   INTEGER PRIMARY KEY AUTOINCREMENT,
    usuario      TEXT    NOT NULL UNIQUE,
    hash_clave   TEXT    NOT NULL
);

CREATE TABLE IF NOT EXISTS productos (
    id_producto  INTEGER PRIMARY KEY,
    nombre       TEXT    NOT NULL,
    precio       REAL    NOT NULL,
    activo       INTEGER NOT NULL DEFAULT 0
);
SQL

        local i
        for ((i = 0; i < MAX; i++)); do
            sqlite3 "$DB_FILE" \
                "INSERT OR IGNORE INTO productos (id_producto, nombre, precio, activo) VALUES ($i, '', 0, 0);" \
                2>>"$ERROR_LOG"
        done
    fi
}

# ----------------------------------------------------------------------------
# Autenticacion (usuarios) - mismo criterio que el ejercicio 2 y 3 (SHA-256)
# ----------------------------------------------------------------------------

hash_clave() {
    printf '%s' "$1" | sha256sum | cut -d' ' -f1
}

usuario_existe() {
    local usuario="$1"
    local count
    count=$(consultar_sql "SELECT COUNT(*) FROM usuarios WHERE usuario = '$(escapar_sql "$usuario")';")
    [[ "$count" -gt 0 ]]
}

registrar_usuario() {
    local usuario=""
    local clave=""
    local clave_rep=""

    usuario=$(capturar_dialog dialog --clear --title "REGISTRO DE USUARIO" \
        --inputbox "Nombre de usuario:" 0 0 2>&1 >/dev/tty)
    local rc=$?
    [[ $rc -ne 0 ]] && return 1   # usuario cancelo

    if [[ -z $usuario ]]; then
        mostrar_error "El usuario no puede estar vacio."
        log_error "Intento de registro con usuario vacio"
        return 1
    fi

    if usuario_existe "$usuario"; then
        mostrar_error "El usuario $usuario ya existe."
        log_error "Intento de registro de usuario existente: $usuario"
        return 1
    fi

    clave=$(capturar_dialog dialog --clear --title "REGISTRO DE USUARIO" \
        --passwordbox "Clave:" 0 0 2>&1 >/dev/tty)
    rc=$?
    [[ $rc -ne 0 ]] && return 1

    if [[ -z $clave ]]; then
        mostrar_error "La clave no puede estar vacia."
        log_error "Intento de registro con clave vacia para usuario: $usuario"
        return 1
    fi

    clave_rep=$(capturar_dialog dialog --clear --title "REGISTRO DE USUARIO" \
        --passwordbox "Repita la clave:" 0 0 2>&1 >/dev/tty)
    rc=$?
    [[ $rc -ne 0 ]] && return 1

    if [[ $clave != "$clave_rep" ]]; then
        mostrar_error "Las claves no coinciden."
        log_error "Claves no coinciden para usuario: $usuario"
        return 1
    fi

    local hash
    hash=$(hash_clave "$clave")

    ejecutar_sql "INSERT INTO usuarios (usuario, hash_clave) VALUES ('$(escapar_sql "$usuario")', '$hash');"
    if [[ $? -ne 0 ]]; then
        mostrar_error "No se pudo registrar el usuario."
        log_error "Fallo al insertar usuario en BD: $usuario"
        return 1
    fi

    mostrar_mensaje "Registro exitoso" "Usuario $usuario registrado correctamente."
    return 0
}

iniciar_sesion() {
    local usuario=""
    local clave=""
    local hash_guardado=""
    local id_usuario=""

    usuario=$(capturar_dialog dialog --clear --title "INICIAR SESION" \
        --inputbox "Usuario:" 0 0 2>&1 >/dev/tty)
    local rc=$?
    [[ $rc -ne 0 ]] && return 1

    clave=$(capturar_dialog dialog --clear --title "INICIAR SESION" \
        --passwordbox "Clave:" 0 0 2>&1 >/dev/tty)
    rc=$?
    [[ $rc -ne 0 ]] && return 1

    if [[ -z $usuario || -z $clave ]]; then
        mostrar_error "Datos incompletos."
        log_error "Intento de login con datos incompletos"
        return 1
    fi

    hash_guardado=$(consultar_sql "SELECT hash_clave FROM usuarios WHERE usuario = '$(escapar_sql "$usuario")';")
    id_usuario=$(consultar_sql "SELECT id_usuario FROM usuarios WHERE usuario = '$(escapar_sql "$usuario")';")

    if [[ -z $hash_guardado ]]; then
        mostrar_error "Usuario inexistente."
        log_error "Login fallido: usuario inexistente: $usuario"
        return 1
    fi

    if [[ $(hash_clave "$clave") == "$hash_guardado" ]]; then
        USUARIO_ID_LOGUEADO=$id_usuario
        USUARIO_NOMBRE_LOGUEADO="$usuario"
        log_sistema "LOGIN usuario=$usuario"
        return 0
    fi

    mostrar_error "Clave incorrecta."
    log_error "Login fallido: clave incorrecta para usuario: $usuario"
    return 1
}

menu_acceso() {
    while true; do
        local opcion
        opcion=$(capturar_dialog dialog --clear --title "ACCESO" \
            --menu "Seleccione una opcion:" 0 0 2 \
            1 "Iniciar sesion" \
            2 "Registrar usuario" \
            2>&1 >/dev/tty)
        local rc=$?
        [[ $rc -ne 0 ]] && return 1   # usuario cerro el dialog

        case $opcion in
            $OPCION_LOGIN)
                if iniciar_sesion; then
                    return 0
                fi
                ;;
            $OPCION_REGISTRO)
                registrar_usuario
                ;;
            *)
                mostrar_error "Opcion invalida."
                ;;
        esac
    done
}

# ----------------------------------------------------------------------------
# Validacion de ID de producto (rango 0 .. MAX-1)
# ----------------------------------------------------------------------------

es_id_valido() {
    declare -i id=$1
    if (( id < 0 || id >= MAX )); then
        mostrar_error "Error: ID fuera de rango (0 a $((MAX - 1)))."
        log_error "Intento de acceso con ID fuera de rango: $id"
        return 1
    fi
    return 0
}

# ----------------------------------------------------------------------------
# ABM de productos (ahora contra SQLite, con TUI)
# ----------------------------------------------------------------------------

alta() {
    declare -i id=$1
    declare -n prod_ref=$2

    if ! es_id_valido "$1"; then
        return 1
    fi

    local activo
    activo=$(consultar_sql "SELECT activo FROM productos WHERE id_producto = $id;")

    if [[ "$activo" -eq 1 ]]; then
        mostrar_error "El producto $id ya existe."
        log_error "Intento de alta de producto existente: ID=$id"
        return 1
    fi

    local nombre_esc precio
    nombre_esc=$(escapar_sql "${prod_ref[nombre]}")
    precio="${prod_ref[precio]}"

    ejecutar_sql "UPDATE productos SET nombre = '$nombre_esc', precio = $precio, activo = 1 WHERE id_producto = $id;"
    if [[ $? -ne 0 ]]; then
        mostrar_error "No se pudo guardar el producto."
        log_error "Fallo al guardar producto ID=$id"
        return 1
    fi

    mostrar_mensaje "Producto guardado" \
        "Producto $id (${prod_ref[nombre]}) guardado con precio \$$precio."
    log_sistema "ALTA producto ID=$id nombre=${prod_ref[nombre]}"
}

baja() {
    declare -i id=$1

    if ! es_id_valido "$1"; then
        return 1
    fi

    local activo
    activo=$(consultar_sql "SELECT activo FROM productos WHERE id_producto = $id;")

    if [[ "$activo" -eq 1 ]]; then
        ejecutar_sql "UPDATE productos SET activo = 0 WHERE id_producto = $id;"
        if [[ $? -ne 0 ]]; then
            mostrar_error "No se pudo eliminar el producto."
            log_error "Fallo al eliminar producto ID=$id"
            return 1
        fi
        mostrar_mensaje "Producto eliminado" "Producto $id eliminado."
        log_sistema "BAJA producto ID=$id"
    else
        mostrar_error "El producto no existe."
    fi
}

editar() {
    declare -i id=$1

    if ! es_id_valido "$1"; then
        return 1
    fi

    local activo
    activo=$(consultar_sql "SELECT activo FROM productos WHERE id_producto = $id;")

    if [[ "$activo" -ne 1 ]]; then
        mostrar_error "El producto no existe."
        return
    fi

    local nuevo_precio
    nuevo_precio=$(capturar_dialog dialog --clear --title "EDITAR PRODUCTO" \
        --inputbox "Ingrese nuevo precio para el producto $id:" 0 0 2>&1 >/dev/tty)
    local rc=$?
    [[ $rc -ne 0 ]] && return

    if [[ -z $nuevo_precio ]]; then
        mostrar_error "El precio no puede estar vacio."
        return
    fi

    ejecutar_sql "UPDATE productos SET precio = $nuevo_precio WHERE id_producto = $id;"
    if [[ $? -ne 0 ]]; then
        mostrar_error "No se pudo editar el producto."
        log_error "Fallo al editar producto ID=$id"
        return 1
    fi

    mostrar_mensaje "Producto editado" \
        "Producto $id editado con precio \$$nuevo_precio."
    log_sistema "EDITAR producto ID=$id precio=$nuevo_precio"
}

mostrar() {
    local resultado
    resultado=$(consultar_sql "SELECT id_producto, nombre, precio FROM productos WHERE activo = 1 ORDER BY id_producto;")

    local texto="LISTADO DE PRODUCTOS ACTIVOS:\n\n"
    if [[ -z "$resultado" ]]; then
        texto+="(no hay productos activos)"
    else
        local id nombre precio
        while IFS='|' read -r id nombre precio; do
            texto+="ID $id : \$$precio - $nombre\n"
        done <<< "$resultado"
    fi

    dialog --clear --title "INVENTARIO" --msgbox "$texto" 0 0 2>&1 >/dev/tty
    log_sistema "MOSTRAR inventario"
}

bienvenida() {
    dialog --clear --title "BIENVENIDO" \
        --msgbox "Bienvenido/a al sistema de inventario (TUI).\n\nBase de datos: $DB_FILE" 0 0 2>&1 >/dev/tty
}

# ----------------------------------------------------------------------------
# Punto de entrada
# ----------------------------------------------------------------------------

main() {
    # Verificar dependencias
    if ! verificar_dialog; then
        return 1
    fi
    if ! verificar_sqlite3; then
        return 1
    fi

    # Inicializar base de datos (crea data.sq3 si no existe)
    inicializar_bd

    bienvenida

    if ! menu_acceso; then
        mostrar_mensaje "Acceso denegado" "No se pudo iniciar sesion."
        return 1
    fi

    declare opcion=0
    declare -i id=0
    declare -A p_temp

    while [[ "$opcion" != "$OPCION_SALIR" ]]; do
        opcion=$(capturar_dialog dialog --clear --title "ACCIONES" \
            --menu "Usuario: $USUARIO_NOMBRE_LOGUEADO\nSeleccione una opcion:" 0 0 5 \
            1 "Alta producto (ID 0 a $((MAX - 1)))" \
            2 "Baja producto" \
            3 "Mostrar inventario" \
            4 "Editar producto" \
            5 "Salir" \
            2>&1 >/dev/tty)
        local rc=$?
        [[ $rc -ne 0 ]] && break   # usuario cerro el dialog

        case $opcion in
            $OPCION_ALTA)
                id=$(capturar_dialog dialog --clear --title "ALTA PRODUCTO" \
                    --inputbox "Ingrese ID (0-$((MAX - 1))):" 0 0 2>&1 >/dev/tty)
                [[ $? -ne 0 ]] && continue

                p_temp[nombre]=$(capturar_dialog dialog --clear --title "ALTA PRODUCTO" \
                    --inputbox "Ingrese Nombre:" 0 0 2>&1 >/dev/tty)
                [[ $? -ne 0 ]] && continue

                p_temp[precio]=$(capturar_dialog dialog --clear --title "ALTA PRODUCTO" \
                    --inputbox "Ingrese Precio:" 0 0 2>&1 >/dev/tty)
                [[ $? -ne 0 ]] && continue

                p_temp[activo]=1
                alta "$id" p_temp
                ;;
            $OPCION_BAJA)
                id=$(capturar_dialog dialog --clear --title "BAJA PRODUCTO" \
                    --inputbox "Ingrese ID a eliminar (0-$((MAX - 1))):" 0 0 2>&1 >/dev/tty)
                [[ $? -ne 0 ]] && continue
                baja "$id"
                ;;
            $OPCION_MOSTRAR)
                mostrar
                ;;
            $OPCION_EDITAR)
                id=$(capturar_dialog dialog --clear --title "EDITAR PRODUCTO" \
                    --inputbox "Ingrese ID a editar (0-$((MAX - 1))):" 0 0 2>&1 >/dev/tty)
                [[ $? -ne 0 ]] && continue
                editar "$id"
                ;;
            $OPCION_SALIR)
                mostrar_mensaje "Salida" "Saliendo del programa..."
                ;;
            *)
                mostrar_error "Opcion invalida."
                ;;
        esac
    done

    return 0
}

main