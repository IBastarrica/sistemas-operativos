#!/usr/bin/env bash


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



verificar_sqlite3() {
    if ! command -v sqlite3 &>/dev/null; then
        printf "Error: sqlite3 no esta instalado.\n" >&2
        printf "Instalelo con: sudo apt install sqlite3\n" >&2
        return 1
    fi
    return 0
}

# Ejecuta una sentencia SQL sin esperar resultado. Registra errores en error.log.
ejecutar_sql() {
    local sql="$1"
    sqlite3 "$DB_FILE" "$sql" 2>>"$ERROR_LOG"
    return $?
}

# Ejecuta una consulta SQL y devuelve el resultado por stdout. Registra errores en error.log.
consultar_sql() {
    local sql="$1"
    sqlite3 "$DB_FILE" "$sql" 2>>"$ERROR_LOG"
    return $?
}

# Escapa comillas simples para SQL (duplicandolas).
escapar_sql() {
    local s="$1"
    s="${s//\'/\'\'}"
    printf '%s' "$s"
}

# Registra un error en error.log con timestamp.
log_error() {
    local msg="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf '%s\t%s\n' "$timestamp" "$msg" >> "$ERROR_LOG"
}

# Registra una accion del usuario en system.log con timestamp.
# Formato: fecha/hora | ID usuario | nombre usuario | accion
log_sistema() {
    local accion="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf '%s\t%s\t%s\t%s\n' \
        "$timestamp" "$USUARIO_ID_LOGUEADO" "$USUARIO_NOMBRE_LOGUEADO" "$accion" \
        >> "$SYSTEM_LOG"
}



inicializar_bd() {
    # Si el archivo de base de datos no existe, lo creamos con el esquema inicial.
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

        # Precargar los lugares de producto con IDs fijos 0..(MAX-1)
        local i
        for ((i = 0; i < MAX; i++)); do
            sqlite3 "$DB_FILE" \
                "INSERT OR IGNORE INTO productos (id_producto, nombre, precio, activo) VALUES ($i, '', 0, 0);" \
                2>>"$ERROR_LOG"
        done
    fi
}


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

    read -rp "Nombre de usuario: " usuario || return 1

    if [[ -z $usuario ]]; then
        printf "Error: el usuario no puede estar vacio.\n"
        log_error "Intento de registro con usuario vacio"
        return 1
    fi

    if usuario_existe "$usuario"; then
        printf "Error: el usuario %s ya existe.\n" "$usuario"
        log_error "Intento de registro de usuario existente: $usuario"
        return 1
    fi

    read -s -rp "Clave: " clave || return 1
    printf "\n"
    read -s -rp "Repita la clave: " clave_rep || return 1
    printf "\n"

    if [[ -z $clave ]]; then
        printf "Error: la clave no puede estar vacia.\n"
        log_error "Intento de registro con clave vacia para usuario: $usuario"
        return 1
    fi

    if [[ $clave != "$clave_rep" ]]; then
        printf "Error: las claves no coinciden.\n"
        log_error "Claves no coinciden para usuario: $usuario"
        return 1
    fi

    local hash
    hash=$(hash_clave "$clave")

    ejecutar_sql "INSERT INTO usuarios (usuario, hash_clave) VALUES ('$(escapar_sql "$usuario")', '$hash');"
    if [[ $? -ne 0 ]]; then
        printf "Error: no se pudo registrar el usuario.\n"
        log_error "Fallo al insertar usuario en BD: $usuario"
        return 1
    fi

    printf "Usuario %s registrado.\n" "$usuario"
    return 0
}

iniciar_sesion() {
    local usuario=""
    local clave=""
    local hash_guardado=""
    local id_usuario=""

    read -rp "Usuario: " usuario || return 1
    read -s -rp "Clave: " clave || return 1
    printf "\n"

    if [[ -z $usuario || -z $clave ]]; then
        printf "Datos incompletos.\n"
        log_error "Intento de login con datos incompletos"
        return 1
    fi

    hash_guardado=$(consultar_sql "SELECT hash_clave FROM usuarios WHERE usuario = '$(escapar_sql "$usuario")';")
    id_usuario=$(consultar_sql "SELECT id_usuario FROM usuarios WHERE usuario = '$(escapar_sql "$usuario")';")

    if [[ -z $hash_guardado ]]; then
        printf "Usuario inexistente.\n"
        log_error "Login fallido: usuario inexistente: $usuario"
        return 1
    fi

    if [[ $(hash_clave "$clave") == "$hash_guardado" ]]; then
        USUARIO_ID_LOGUEADO=$id_usuario
        USUARIO_NOMBRE_LOGUEADO="$usuario"
        printf "Acceso concedido. Bienvenido/a, %s.\n" "$usuario"
        log_sistema "LOGIN usuario=$usuario"
        return 0
    fi

    printf "Clave incorrecta.\n"
    log_error "Login fallido: clave incorrecta para usuario: $usuario"
    return 1
}

menu_acceso() {
    local opcion=""

    while true; do
        printf "\nACCESO:\n"
        printf "1. Iniciar sesion\n"
        printf "2. Registrar usuario\n"
        read -rp "Opcion: " opcion || return 1

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
                printf "\nOpcion invalida.\n"
                ;;
        esac
    done
}


es_id_valido() {
    declare -i id=$1
    if (( id < 0 || id >= MAX )); then
        printf "Error: ID fuera de rango.\n"
        log_error "Intento de acceso con ID fuera de rango: $id"
        return 1
    fi
    return 0
}



alta() {
    declare -i id=$1
    declare -n prod_ref=$2

    if ! es_id_valido "$1"; then
        return 1
    fi

    local activo
    activo=$(consultar_sql "SELECT activo FROM productos WHERE id_producto = $id;")

    if [[ "$activo" -eq 1 ]]; then
        printf "Error: el producto %d ya existe.\n" "$id"
        log_error "Intento de alta de producto existente: ID=$id"
        return 1
    fi

    local nombre_esc precio
    nombre_esc=$(escapar_sql "${prod_ref[nombre]}")
    precio="${prod_ref[precio]}"

    ejecutar_sql "UPDATE productos SET nombre = '$nombre_esc', precio = $precio, activo = 1 WHERE id_producto = $id;"
    if [[ $? -ne 0 ]]; then
        printf "Error: no se pudo guardar el producto.\n"
        log_error "Fallo al guardar producto ID=$id"
        return 1
    fi

    printf "Producto %d (%s) guardado con precio $%.2f.\n" \
        "$id" "${prod_ref[nombre]}" "$precio"
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
            printf "Error: no se pudo eliminar el producto.\n"
            log_error "Fallo al eliminar producto ID=$id"
            return 1
        fi
        printf "Producto %d eliminado.\n" "$id"
        log_sistema "BAJA producto ID=$id"
    else
        printf "El producto no existe.\n"
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
        printf "El producto no existe.\n"
        return
    fi

    local nuevo_precio
    read -rp "Ingrese nuevo precio: " nuevo_precio

    ejecutar_sql "UPDATE productos SET precio = $nuevo_precio WHERE id_producto = $id;"
    if [[ $? -ne 0 ]]; then
        printf "Error: no se pudo editar el producto.\n"
        log_error "Fallo al editar producto ID=$id"
        return 1
    fi

    printf "Producto %d editado con precio $%.2f.\n" "$id" "$nuevo_precio"
    log_sistema "EDITAR producto ID=$id precio=$nuevo_precio"
}

mostrar() {
    printf "\nLISTADO:\n"

    local resultado
    resultado=$(consultar_sql "SELECT id_producto, nombre, precio FROM productos WHERE activo = 1 ORDER BY id_producto;")

    if [[ -z "$resultado" ]]; then
        log_sistema "MOSTRAR inventario (vacio)"
        return
    fi

    local id nombre precio
    while IFS='|' read -r id nombre precio; do
        printf "ID %s : $%.2f\n" "$id" "$precio"
    done <<< "$resultado"

    log_sistema "MOSTRAR inventario"
}

bienvenida() {
    printf "Bienvenido/a al sistema\n\n"
}



main() {
    # Verificar dependencia
    if ! verificar_sqlite3; then
        return 1
    fi

    # Inicializar base de datos (crea data.sq3 si no existe)
    inicializar_bd

    bienvenida

    if ! menu_acceso; then
        printf "\nAcceso denegado.\n"
        return 1
    fi

    declare opcion=0
    declare -i id=0
    declare -A p_temp

    while [[ "$opcion" != "$OPCION_SALIR" ]]; do
        printf "\nACCIONES:\n"
        printf "1. Alta producto (ID 0 a %d)\n" $((MAX - 1))
        printf "2. Baja producto\n"
        printf "3. Mostrar inventario\n"
        printf "4. Editar producto\n"
        printf "5. Salir\n"
        read -rp "Opcion: " opcion || break

        case $opcion in
            $OPCION_ALTA)
                read -rp "Ingrese ID (0-$((MAX - 1))): " id
                read -rp "Ingrese Nombre: " p_temp[nombre]
                read -rp "Ingrese Precio: " p_temp[precio]
                p_temp[activo]=1
                alta "$id" p_temp
                ;;
            $OPCION_BAJA)
                read -rp "Ingrese ID a eliminar (0-$((MAX - 1))): " id
                baja "$id"
                ;;
            $OPCION_MOSTRAR)
                mostrar
                ;;
            $OPCION_EDITAR)
                read -rp "Ingrese ID a editar (0-$((MAX - 1))): " id
                editar "$id"
                ;;
            $OPCION_SALIR)
                printf "\nSaliendo del programa...\n"
                ;;
            *)
                printf "\nOpcion invalida.\n"
                ;;
        esac
    done

    return 0
}

main