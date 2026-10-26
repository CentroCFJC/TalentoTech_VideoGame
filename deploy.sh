#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

PI_USER="ccu-pi1"
PI_IP="10.15.1.157"

LOCAL="$SCRIPT_DIR/build/linux_arm64/Infinite Runner.arm64"
REMOTE_DIR="/home/ccu-pi1/Desktop/linux_arm64"
REMOTE="$REMOTE_DIR/Infinite Runner.arm64"

# Keepalive para evitar cortes en transferencias largas.
SSH_OPTS="-o ServerAliveInterval=15 -o ServerAliveCountMax=4"

echo
echo "=========================================="
echo "     DEPLOY INFINITE RUNNER"
echo "=========================================="
echo

if [ ! -f "$LOCAL" ]; then
    echo "ERROR: no existe el binario: $LOCAL"
    echo "Exporta primero el preset 'Linux' en Godot."
    exit 1
fi

# Convertir la ruta local a formato Windows para el scp nativo de Windows.
# (scp de OpenSSH en Windows no entiende las rutas POSIX de Git Bash.)
LOCAL_WIN=$(cygpath -m "$LOCAL" 2>/dev/null || printf '%s' "$LOCAL")

# Crear el directorio remoto y detener el juego si sigue corriendo:
# scp no puede sobrescribir un binario en ejecucion y falla con un
# generico "dest open ... Failure" (ETXTBSY). El patron con corchetes
# evita que pkill encuentre su propia linea de comando.
echo "Creando directorio remoto y deteniendo el juego si esta corriendo..."
ssh $SSH_OPTS "$PI_USER@$PI_IP" "mkdir -p '$REMOTE_DIR'; pkill -f '[I]nfinite Runner.arm64' 2>/dev/null; true"

# Diagnostico visible del remoto: espacio, permisos y escritura. Asi un
# fallo posterior de scp tiene causa identificable en la salida.
echo "Diagnostico del remoto..."
ssh $SSH_OPTS "$PI_USER@$PI_IP" "
    echo -n 'Espacio en /home: '
    df -h /home | tail -1
    echo -n 'Destino: '
    ls -ld '$REMOTE_DIR'
    if touch '$REMOTE_DIR/.deploy_test' 2>/dev/null; then
        rm -f '$REMOTE_DIR/.deploy_test'
        echo 'Prueba de escritura: OK'
    else
        echo 'ERROR: sin permiso de escritura en $REMOTE_DIR'
        exit 1
    fi
"

echo "Copiando binario..."
if ! scp $SSH_OPTS "$LOCAL_WIN" "$PI_USER@$PI_IP:$REMOTE_DIR/"; then
    echo
    echo "ERROR: scp fallo al copiar el binario. Causas tipicas:"
    echo "  - El juego seguia corriendo en la Pi (ya se intento detenerlo)."
    echo "  - Disco lleno (revisar 'Espacio en /home' arriba)."
    echo "  - Sin permisos en el destino (revisar 'Prueba de escritura' arriba)."
    exit 1
fi

echo "Asignando permisos..."
ssh $SSH_OPTS "$PI_USER@$PI_IP" "chmod +x '$REMOTE'"

echo
echo "=========================================="
echo "DEPLOY COMPLETADO"
echo "=========================================="
