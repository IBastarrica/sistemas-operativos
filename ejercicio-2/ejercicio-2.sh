#!/usr/bin/env bash

export LC_ALL=C

declare -r -i MAX=3
declare -A inventario

declare -r -i OPCION_ALTA=1
declare -r -i OPCION_BAJA=2
declare -r -i OPCION_MOSTRAR=3
declare -r -i OPCION_EDITAR=4
declare -r -i OPCION_SALIR=5

declare -r -i OPCION_LOGIN=1
declare -r -i OPCION_REGISTRO=2

declare -r ARCHIVO_TSV="productos.tsv"
declare -r ARCHIVO_USUARIOS="usuarios.tsv"


bienvenida() {
    printf "Bienvenido/a al sistema\n\n"
}

es_id_valido() {
    declare -i id=$1
    if (( id < 0 || id >= MAX )); then
        printf "Error: ID fuera de rango.\n"
        return 1
    fi

    return 0
}

cargar_inventario() {
    declare -i i=0
    declare col_id=""
    declare col_nombre=""
    declare col_precio=""

    for ((i=0; i<MAX; i++)); do
        inventario[$i,activo]=0
        inventario[$i,precio]=0
        inventario[$i,nombre]=""
    done

    if [[ ! -f $ARCHIVO_TSV ]]; then
        : > $ARCHIVO_TSV
        return 0
    fi

    while IFS=$'\t' read -r col_id col_nombre col_precio; do
        if [[ -z $col_id ]]; then
            continue
        fi

        if ! es_id_valido "$col_id"; then
            continue
        fi

        declare -i id=$col_id
        inventario[$id,nombre]=$col_nombre
        inventario[$id,precio]=$col_precio
        inventario[$id,activo]=1
    done < $ARCHIVO_TSV

    return 0
}

guardar_inventario() {
    declare -i i=0

    : > $ARCHIVO_TSV

    for ((i=0; i<MAX; i++)); do
        if [[ ${inventario[$i,activo]} -eq 1 ]]; then
            printf '%s\t%s\t%s\n' \
            "$i" "${inventario[$i,nombre]}" "${inventario[$i,precio]}" \
            >> $ARCHIVO_TSV
        fi
    done

    return 0
}

hash_clave() {
    printf '%s' "$1" | sha256sum | cut -d' ' -f1
}

usuario_existe() {
    declare usuario="$1"

    if [[ ! -f $ARCHIVO_USUARIOS ]]; then
        return 1
    fi

    while IFS=$'\t' read -r col_usuario col_hash; do
        if [[ $col_usuario == "$usuario" ]]; then
            return 0
        fi
    done < $ARCHIVO_USUARIOS

    return 1
}

registrar_usuario() {
    declare usuario=""
    declare clave=""
    declare clave_rep=""

    read -rp "Nombre de usuario: " usuario || return 1

    if [[ -z $usuario ]]; then
        printf "Error: el usuario no puede estar vacio.\n"
        return 1
    fi

    if usuario_existe "$usuario"; then
        printf "Error: el usuario %s ya existe.\n" "$usuario"
        return 1
    fi

    read -s -rp "Clave: " clave || return 1
    printf "\n"
    read -s -rp "Repita la clave: " clave_rep || return 1
    printf "\n"

    if [[ -z $clave ]]; then
        printf "Error: la clave no puede estar vacia.\n"
        return 1
    fi

    if [[ $clave != "$clave_rep" ]]; then
        printf "Error: las claves no coinciden.\n"
        return 1
    fi

    printf '%s\t%s\n' "$usuario" "$(hash_clave "$clave")" >> $ARCHIVO_USUARIOS

    printf "Usuario %s registrado.\n" "$usuario"
    return 0
}

iniciar_sesion() {
    declare usuario=""
    declare clave=""
    declare hash_guardado=""

    read -rp "Usuario: " usuario || return 1
    read -s -rp "Clave: " clave || return 1
    printf "\n"

    if [[ -z $usuario || -z $clave ]]; then
        printf "Datos incompletos.\n"
        return 1
    fi

    while IFS=$'\t' read -r col_usuario col_hash; do
        if [[ $col_usuario == "$usuario" ]]; then
            hash_guardado=$col_hash
            break
        fi
    done < $ARCHIVO_USUARIOS

    if [[ -z $hash_guardado ]]; then
        printf "Usuario inexistente.\n"
        return 1
    fi

    if [[ $(hash_clave "$clave") == "$hash_guardado" ]]; then
        printf "Acceso concedido. Bienvenido/a, %s.\n" "$usuario"
        return 0
    fi

    printf "Clave incorrecta.\n"
    return 1
}

menu_acceso() {
    declare opcion=""

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

alta() {
    declare -i id=$1
    declare -n prod_ref=$2

    if ! es_id_valido "$1"; then
        return 1
    fi

    if [[ ${inventario[$id,activo]} -eq 1 ]]; then
        printf "Error: el producto %d ya existe.\n" "$id"
        return 1
    fi

    inventario[$id,nombre]=${prod_ref[nombre]}
    inventario[$id,precio]=${prod_ref[precio]}
    inventario[$id,activo]=${prod_ref[activo]}

    guardar_inventario

    printf "Producto %d (%s) guardado con precio $%.2f.\n" \
    "$id" "${prod_ref[nombre]}" "${prod_ref[precio]}"
}

baja() {
    declare -i id=$1

    if ! es_id_valido "$1"; then
        return 1
    fi

    if [[ ${inventario[$id,activo]} -eq 1 ]]; then
        inventario[$id,activo]=0
        guardar_inventario
        printf "Producto %d eliminado.\n" "$id"
    else
        printf "El producto no existe.\n"
    fi
}

editar() {
    declare -i id=$1

    if ! es_id_valido "$1"; then
        return 1
    fi

    if [[ ${inventario[$id,activo]} -ne 1 ]]; then
        printf "El producto no existe.\n"
        return
    fi

    read -rp "Ingrese nuevo precio: " inventario[$id,precio]
    guardar_inventario
    printf "Producto %d editado con precio $%.2f.\n" "$id" "${inventario[$id,precio]}"
}

mostrar() {
    declare -i i=0

    printf "\nLISTADO:\n"
    for ((i=0; i<MAX; i++)); do
        if [[ ${inventario[$i,activo]} -eq 1 ]]; then
            printf "ID %d : $%.2f\n" "$i" "${inventario[$i,precio]}"
        fi
    done
}

main() {
    cargar_inventario

    bienvenida

    if [[ ! -f $ARCHIVO_USUARIOS ]]; then
        : > $ARCHIVO_USUARIOS
    fi

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
