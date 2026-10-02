# Ejercicio 1 — Inventario en Bash

Repositorio de trabajo de la materia Sistemas Operativos (ISFT151 - 2026)

Script de consola que gestiona un inventario de productos con **persistencia en archivos TSV** y
**autenticación de usuarios con contraseñas cifradas en SHA-256**.

El código vive en la máquina virtual Debian: `~/c++ybash/ejercicio-1.sh` (329 líneas).

---

## Índice

1. [Requisitos](#requisitos)
2. [Cómo ejecutarlo](#cómo-ejecutarlo)
3. [Archivos que genera](#archivos-que-genera)
4. [Menú del programa](#menú-del-programa)
5. [Glosario de sintaxis](#glosario-de-sintaxis)
6. [Explicación línea por línea](#explicación-línea-por-línea)
7. [Detalles que se pueden pasar por alto](#detalles-que-se-pueden-pasar-por-alto)

---

## Requisitos

- Bash 5.2 o superior
- `sha256sum` (viene con coreutils, ya está en cualquier Linux)
- No requiere librerías externas ni instalación de nada

---

## Cómo ejecutarlo

### Desde VS Code (Remote-SSH a la VM)

Abrir la terminal integrada y:

```bash
cd ~/c++ybash
./ejercicio-1.sh
```

### Desde Parrot, por SSH

```bash
ssh debian-vm
cd ~/c++ybash
./ejercicio-1.sh
```

### Ejecución directa por SSH (sin entrar al shell)

```bash
ssh -t debian-vm 'cd ~/c++ybash && ./ejercicio-1.sh'
```

El flag `-t` es importante: reserva una pseudo-terminal para que los `read` puedan leer del teclado.

### Verificar sintaxis antes de correr

```bash
bash -n ejercicio-1.sh && echo "sintaxis OK"
```

---

## Archivos que genera

| Archivo | Cuándo se crea | Contenido |
|---|---|---|
| `productos.tsv` | Al primer arranque, si no existe | `ID<TAB>Nombre<TAB>Precio` |
| `usuarios.tsv` | Al primer arranque, si no existe | `Usuario<TAB>sha256_de_la_clave` |

Ambos se guardan **en el directorio desde donde se ejecuta el script**. Si lo corrés desde otro lugar,
se crean allá.

### Ejemplo de `productos.tsv`

```
0	Café	1500.5
1	Pan	800
```

### Ejemplo de `usuarios.tsv`

```
ana	c0f412f85ec51c2c293357ce84e0aea910bc6b368d1cd772f278dd11acb708eb
```

La contraseña **nunca** se escribe en texto plano. Solo su hash SHA-256.

---

## Menú del programa

### Pantalla de acceso (arranque)

```
ACCESO:
1. Iniciar sesion
2. Registrar usuario
```

### Menú principal (después de loguearse)

```
ACCIONES:
1. Alta producto (ID 0 a 2)
2. Baja producto
3. Mostrar inventario
4. Editar producto
5. Salir
```

---

## Glosario de sintaxis

Antes de leer el código, estas son las construcciones que se usan:

| Construcción | Qué hace |
|---|---|
| `#!/usr/bin/env bash` | Shebang. Le dice al kernel con qué intérprete correr el archivo |
| `export LC_ALL=C` | Fuerza el locale "C". Sin esto, con `LANG=es_AR` el `printf "%.2f"` falla |
| `declare -r -i MAX=3` | Declara una constante entera de solo lectura |
| `declare -A inventario` | Declara un **array asociativo** (clave → valor) |
| `declare -n ref=$2` | **Nameref**: `ref` pasa a ser otro nombre para la variable del segundo argumento |
| `${inventario[$id,precio]}` | Subíndice compuesto: en un array asociativo la clave puede ser `"0,precio"` |
| `[[ ... ]]` | Test de Bash. Más seguro que `[ ]`: no hace expansión de globs ni de palabras |
| `-eq -ne -z -f` | Operadores de `[[ ]]`: igual, distinto, vacío, archivo existe |
| `(( ... ))` | Contexto aritmético. Más rápido que `$(( ))` para condiciones |
| `$((MAX - 1))` | Expansión aritmética: devuelve un número |
| `case ... esac` | Selección por patrón, equivalente a un `switch` |
| `$'\t'` | Comillas ANSI-C: produce un **tabulador** real |
| `IFS=$'\t' read -r a b c` | Lee una línea y la parte en campos separados por tabulador |
| `-r` en `read` | No interpreta los `\` escapes (obligatorio con `IFS` custom) |
| `: > archivo` | Crea el archivo o lo **trunca** a cero bytes |
| `>> archivo` | Redirección de **append** (agrega al final) |
| `$(comando)` | Sustitución de comando: guarda la salida en una variable |
| `printf '%s\t%s\n'` | Imprime con formato. `\t` = tabulador, `\n` = salto de línea |
| `printf "%.2f"` | Formato de punto flotante con 2 decimales |
| `read -s -rp "Prompt: " var` | Lee **sin eco** (la clave no aparece en pantalla). `-r` = lectura cruda, `-p` = prompt |
| `cmd \|\| return 1` | Si `cmd` falla, ejecutá lo de la derecha. Sirve para detectar EOF |
| `return 0` / `return 1` | Código de salida: `0` = éxito, `1` = error |

---

## Explicación línea por línea

### Encabezado y constantes (líneas 1-18)

```bash
#!/usr/bin/env bash
```
Shebang. `env bash` busca `bash` en el `PATH` en vez de hardcodear `/bin/bash`.

```bash
export LC_ALL=C
```
Fuerza el locale inglés. Es **imprescindible**: con `LANG=es_AR.UTF-8` el sistema espera coma decimal,
y `printf "%.2f" 12.5` falla con `número inválido`. Con `LC_ALL=C` el separador es el punto.

```bash
declare -r -i MAX=3
```
`-r` = solo lectura. `-i` = entero. El inventario tiene 3 lugares: IDs `0`, `1` y `2`.

```bash
declare -A inventario
```
Array asociativo. No guarda lo de un array normal (índices 0,1,2) sino pares clave→valor, y las
claves son **strings**. Por eso `inventario[0,activo]` y `inventario[0,precio]` son dos entradas
distintas: las claves literales son `"0,activo"` y `"0,precio"`.

```bash
declare -r -i OPCION_ALTA=1
declare -r -i OPCION_BAJA=2
declare -r -i OPCION_MOSTRAR=3
declare -r -i OPCION_EDITAR=4
declare -r -i OPCION_SALIR=5

declare -r -i OPCION_LOGIN=1
declare -r -i OPCION_REGISTRO=2
```
Constantes de las dos pantallas de menú. Son números distintos con el mismo valor a propósito: cada
menú tiene su propio espacio de numeración.

```bash
declare -r ARCHIVO_TSV="productos.tsv"
declare -r ARCHIVO_USUARIOS="usuarios.tsv"
```
Nombres de los archivos. Centralizados en constantes para no repetirlos en cada función.

### `bienvenida()` (líneas 21-23)

```bash
printf "Bienvenido/a al sistema\n\n"
```
Imprime el saludo. El primer `\n` corta la línea, el segundo deja una línea en blanco.

### `es_id_valido()` (líneas 25-33)

```bash
declare -i id=$1
if (( id < 0 || id >= MAX )); then
```
Toma el ID del primer argumento. `(( ))` hace la comparación aritmética: el `||` es un OR lógico.

```bash
    printf "Error: ID fuera de rango.\n"
    return 1
```
`return 1` = fallo. Quien la llama usa `if ! es_id_valido ...` para abortar.

```bash
return 0
```
Success. Convención de Unix: `0` es éxito, cualquier otro número es error.

### `cargar_inventario()` (líneas 35-68)

Esta es la función que cumple la consigna 2: leer los productos del archivo.

```bash
declare col_id=""
declare col_nombre=""
declare col_precio=""
```
Variables temporales donde `read` deposita cada campo. Sin tipo `-i` a propósito: si el ID viniera
como `007`, `declare -i` lo convertiría a octal.

```bash
for ((i=0; i<MAX; i++)); do
    inventario[$i,activo]=0
    inventario[$i,precio]=0
    inventario[$i,nombre]=""
done
```
Inicializa los 3 slots como "inexistente". Así todas las claves existen siempre y nunca se
evalúa una referencia vacía. El `activo=0` es la bandera de "no existe".

```bash
if [[ ! -f $ARCHIVO_TSV ]]; then
    : > $ARCHIVO_TSV
    return 0
fi
```
Si el archivo no existe, lo crea vacío con `: >`. El `:` es un comando vacío de Bash: sirve
solo para usar la redirección sin ejecutar nada. Lo importante es el `>` que trunca el archivo.

```bash
while IFS=$'\t' read -r col_id col_nombre col_precio; do
```
Acá está el patrón del enunciado. `IFS=$'\t'` parte la línea por tabuladores en vez de por
espacios, y `read -r` evita interpretar backslashes. **El `-r` es obligatorio**: sin él, un
`\` en un nombre rompería la lectura.

```bash
    if [[ -z $col_id ]]; then
        continue
    fi
```
Salta líneas vacías. `continue` en vez de `break`: no corta el archivo entero.

```bash
    if ! es_id_valido "$col_id"; then
        continue
    fi
```
Descarta IDs fuera de rango. Si alguien editó el TSV a mano y puso un ID 99, se ignora en vez
de romper el script.

```bash
    declare -i id=$col_id
    inventario[$id,nombre]=$col_nombre
    inventario[$id,precio]=$col_precio
    inventario[$id,activo]=1
```
Carga el producto y lo marca como existente (`activo=1`).

```bash
done < $ARCHIVO_TSV
```
La redirección va **en el `done`**, no en el `while`. Por eso el loop corre en el shell actual y
`continue`/`break` funcionan. Si la redirección estuviera en el `while`, correría en un subshell.

### `guardar_inventario()` (líneas 70-84)

```bash
: > $ARCHIVO_TSV
```
Trunca el archivo a cero. Después se reescribe completo. Así las bajas desaparecen del archivo:
el TSV es la lista de lo que existe, no un historial.

```bash
printf '%s\t%s\t%s\n' \
"$i" "${inventario[$i,nombre]}" "${inventario[$i,precio]}" \
>> $ARCHIVO_TSV
```
`%s` tres veces, con un `\t` entre ellos y un `\n` al final. El `\` al final de línea es
continuación: sigue en la línea siguiente.

Los valores van entre comillas dobles `${...}` porque un precio o un nombre con espacios se
romperían sin ellas.

### `hash_clave()` (líneas 86-88)

```bash
printf '%s' "$1" | sha256sum | cut -d' ' -f1
```
Pipeline de tres etapas:

1. `printf '%s' "$1"` imprime la clave. El `%s` **sin `\n`** es clave: si usáramos `echo`, agregaría
   un salto de línea y el hash sería distinto al calcular el login.
2. `sha256sum` calcula el hash y devuelve `hash  -` (hash, dos espacios, y un guion).
3. `cut -d' ' -f1` se queda solo con la primera parte separada por espacio: el hash limpio.

### `usuario_existe()` (líneas 90-104)

```bash
if [[ ! -f $ARCHIVO_USUARIOS ]]; then
    return 1
fi
```
Si no hay archivo, no existe ningún usuario. `return 1` = "no lo encontré".

```bash
while IFS=$'\t' read -r col_usuario col_hash; do
    if [[ $col_usuario == "$usuario" ]]; then
        return 0
    fi
done < $ARCHIVO_USUARIOS

return 1
```
Recorre el TSV buscando coincidencia exacta. `==` entre comillas es comparación de string literal.
Si encuentra, `return 0` (existe); si termina el archivo, `return 1` (no existe).

### `registrar_usuario()` (líneas 106-142)

```bash
read -rp "Nombre de usuario: " usuario || return 1
```
`-p` escribe el prompt, `read` lee la línea. El `|| return 1` corta si hay EOF (Ctrl+D).

```bash
if [[ -z $usuario ]]; then
    printf "Error: el usuario no puede estar vacio.\n"
    return 1
fi
```
Rechaza usuario vacío.

```bash
if usuario_existe "$usuario"; then
    printf "Error: el usuario %s ya existe.\n" "$usuario"
    return 1
fi
```
**Esta es la validación que pide la consigna 3**: no agregar un usuario ya existente.

```bash
read -s -rp "Clave: " clave || return 1
printf "\n"
read -s -rp "Repita la clave: " clave_rep || return 1
printf "\n"
```
`-s` = **silent**: no eco lo que se tipea, así la clave no queda expuesta en pantalla.
El `printf "\n"` es porque `read -s` no hace el salto de línea solo: sin eso, el segundo prompt
aparecería pegado en la misma línea. Se pide la clave dos veces para confirmar.

```bash
if [[ -z $clave ]]; then ... return 1; fi
if [[ $clave != "$clave_rep" ]]; then ... return 1; fi
```
Rechaza clave vacía y claves que no coinciden.

```bash
printf '%s\t%s\n' "$usuario" "$(hash_clave "$clave")" >> $ARCHIVO_USUARIOS
```
**Agrega** (`>>`, no `>`) el usuario con su hash. El `$(hash_clave "$clave")` es sustitución de
comando: ejecuta la función y guarda su salida en el lugar.

### `iniciar_sesion()` (líneas 144-177)

```bash
read -rp "Usuario: " usuario || return 1
read -s -rp "Clave: " clave || return 1
printf "\n"
```
Pide credenciales. La clave otra vez con `-s`.

```bash
if [[ -z $usuario || -z $clave ]]; then
```
El `||` permite evaluar dos condiciones: usuario vacío **o** clave vacía.

```bash
while IFS=$'\t' read -r col_usuario col_hash; do
    if [[ $col_usuario == "$usuario" ]]; then
        hash_guardado=$col_hash
        break
    fi
done < $ARCHIVO_USUARIOS
```
Busca el usuario y **guarda su hash** para comparar después. `break` porque solo hay un usuario
con ese nombre.

```bash
if [[ -z $hash_guardado ]]; then
    printf "Usuario inexistente.\n"
    return 1
fi
```
No se encontró el usuario.

```bash
if [[ $(hash_clave "$clave") == "$hash_guardado" ]]; then
    printf "Acceso concedido. Bienvenido/a, %s.\n" "$usuario"
    return 0
fi
```
**La comparación clave**: hasheá la clave tipeada y la comparás con la guardada. Si son iguales,
entra. Nunca se compara la clave en sí, solo sus hashes.

```bash
printf "Clave incorrecta.\n"
return 1
```

### `menu_acceso()` (líneas 179-202)

```bash
while true; do
```
Loop infinito controlado con `break`, en vez de una condición. Se sale con `return 0` (login
exitoso) o `return 1` (EOF).

```bash
    read -rp "Opcion: " opcion || return 1

    case $opcion in
        $OPCION_LOGIN)
            if iniciar_sesion; then
                return 0
            fi
            ;;
```
Si el login falla, no sale del menú: vuelve a mostrarlo para reintentar.

```bash
        $OPCION_REGISTRO)
            registrar_usuario
            ;;
```
Registra y vuelve al menú de acceso.

```bash
        *)
            printf "\nOpcion invalida.\n"
            ;;
```
El `*` es el default: cualquier otra cosa.

### `alta()` (líneas 204-225)

```bash
declare -i id=$1
declare -n prod_ref=$2
```
El segundo argumento es un array asociativo. `declare -n` crea una **referencia**: `prod_ref`
apunta al array recibido, así que `${prod_ref[nombre]}` accede al dato real sin copiarlo.

```bash
if ! es_id_valido "$1"; then
    return 1
fi
```
Valida el rango. Importante: sin el `if !`, el error se imprimiría pero la función seguiría
escribiendo datos basura.

```bash
if [[ ${inventario[$id,activo]} -eq 1 ]]; then
    printf "Error: el producto %d ya existe.\n" "$id"
    return 1
fi
```
**Validación de producto duplicado** (consigna 2). `-eq` compara como enteros.

```bash
inventario[$id,nombre]=${prod_ref[nombre]}
inventario[$id,precio]=${prod_ref[precio]}
inventario[$id,activo]=${prod_ref[activo]}

guardar_inventario
```
Guarda en memoria y **después persiste en disco**.

```bash
printf "Producto %d (%s) guardado con precio $%.2f.\n" \
"$id" "${prod_ref[nombre]}" "${prod_ref[precio]}"
```
`%d` entero, `%s` texto, `%.2f` flotante con 2 decimales. El `$` antes del `%.2f` es un signo
pesos literal (el `printf` no lo interpreta como variable).

### `baja()` (líneas 227-241)

```bash
if [[ ${inventario[$id,activo]} -eq 1 ]]; then
    inventario[$id,activo]=0
    guardar_inventario
    printf "Producto %d eliminado.\n" "$id"
else
    printf "El producto no existe.\n"
fi
```
Marca `activo=0` y persiste. Como `guardar_inventario()` solo escribe los activos, el producto
desaparece del TSV.

### `editar()` (líneas 243-258)

```bash
if [[ ${inventario[$id,activo]} -ne 1 ]]; then
    printf "El producto no existe.\n"
    return
fi
```
`-ne` = "no es igual a 1". Solo se edita lo que existe.

```bash
read -rp "Ingrese nuevo precio: " inventario[$id,precio]
```
`read` puede escribir **directamente en un elemento de array**. El `read` asigna el valor tipeado
y el `return` de `read` se descarta.

```bash
guardar_inventario
```
Persiste el cambio.

### `mostrar()` (líneas 260-269)

```bash
for ((i=0; i<MAX; i++)); do
    if [[ ${inventario[$i,activo]} -eq 1 ]]; then
        printf "ID %d : $%.2f\n" "$i" "${inventario[$i,precio]}"
    fi
done
```
Recorre los 3 slots y muestra solo los activos.

### `main()` (líneas 271-327)

```bash
cargar_inventario
```
**Orden importante**: primero carga los productos del disco, después autentica.

```bash
if [[ ! -f $ARCHIVO_USUARIOS ]]; then
    : > $ARCHIVO_USUARIOS
fi
```
Crea el archivo de usuarios vacío si es la primera vez. Sin esto, el `read` de la línea 101 fallaría
con "No such file or directory".

```bash
if ! menu_acceso; then
    printf "\nAcceso denegado.\n"
    return 1
fi
```
Solo entra al inventario si `menu_acceso` devuelve 0.

```bash
declare opcion=0
declare -i id=0
declare -A p_temp
```
`opcion` arranca en 0 para que el `while` entre al menos una vez.
`p_temp` es el array temporal donde se cargan los datos del alta antes de pasarlos a `alta()`.

```bash
while [[ "$opcion" != "$OPCION_SALIR" ]]; do
```
Compara con `"5"`. Las comillas evitan que Bash intente hacer expansión aritmética.

```bash
    read -rp "Opcion: " opcion || break
```
**Crítico**: el `|| break` evita un cuelgue infinito. Cuando `read` recibe EOF, Bash **vacía** la
variable, así que `opcion` queda en `""`, el `while` nunca ve "5" y el `case` cae en el default
en bucle eterno. Con el `break`, EOF cierra el programa limpio.

```bash
$OPCION_ALTA)
    read -rp "Ingrese ID (0-$((MAX - 1))): " id
```
`$((MAX - 1))` = 2. El mensaje del prompt calcula el rango real desde `MAX`.

```bash
    read -rp "Ingrese Nombre: " p_temp[nombre]
    read -rp "Ingrese Precio: " p_temp[precio]
    p_temp[activo]=1
    alta "$id" p_temp
```
Carga el producto temporal y lo pasa. El nombre se lee **antes** del precio, y ambos antes de
llamar a `alta`.

```bash
$OPCION_EDITAR)
read -rp "Ingrese ID a editar (0-$((MAX - 1))): " id
editar "$id"
    ;;
```
Las dos líneas del `read` están sin indentar (no afecta al comportamiento, pero es un detalle de
formato que convendría arreglar).

### Cierre (línea 329)

```bash
main
```
Última línea: llama a `main` para arrancar. Sin esto el script define funciones y no hace nada.

---

## Detalles que se pueden pasar por alto

### El bug del cuelgue infinito

Si se corre el script redirigiendo input y los datos se agotan, `read` devuelve error y vacía la
variable. Sin el `|| break`, el programa imprime "Opcion invalida" para siempre. Está presente
también en `menu_acceso()` con `|| return 1` y en `autenticar` original con `|| return 1`.

### Por qué `printf '%s'` y no `echo`

`echo "1234"` agrega un salto de línea, así que hashearía `"1234\n"`, que es distinto de `"1234"`.
Si el registro usara `echo` y el login `printf`, los hashes no coincidirían nunca.

### La clave nunca se escribe en texto plano

Doble protección:

1. **En disco**: solo el hash SHA-256.
2. **En pantalla**: `read -s` evita el eco de lo tipeado.

### `declare` dentro de una función crea variables locales

A diferencia de una asignación normal (`x=5`), un `declare` dentro de una función es local a esa
función. Por eso `declare clave=""` en `registrar_usuario()` no pisa la `clave` de otra función.

### Los datos del TSV son volátiles en memoria

`inventario` es un array en RAM. Si el script se corta sin pasar por `guardar_inventario`, esos
cambios se pierden. Por eso se persiste dentro de `alta`, `baja` y `editar`, no al salir.

### El TSV se reescribe completo

No es un log incremental. `guardar_inventario()` trunca y reescribe. Consecuencia: los productos
dados de baja **no quedan registrados** en el archivo. Si el enunciado pidiera conservar las bajas,
habría que agregar una columna de estado (`activo`).

### Límite de intentos

`menu_acceso()` no tiene contador de intentos: se puede probar la clave indefinidamente. La
versión anterior (`autenticar()`) sí tenía 3. Si se requiere un límite, hay que reincorporar el
contador.

---

## Verificación rápida

```bash
# sintaxis
bash -n ejercicio-1.sh && echo OK

# hash de una clave, para comparar con el del TSV
printf '%s' "miClave" | sha256sum | cut -d' ' -f1

# ver usuarios y hashes
cat usuarios.tsv

# ver el TSV con los tabuladores visibles
cat -A productos.tsv | sed 's/\^I/->/g'

# probar sin tocar los datos reales
mkdir -p /tmp/prueba && cp ejercicio-1.sh productos.tsv /tmp/prueba/ && cd /tmp/prueba
```