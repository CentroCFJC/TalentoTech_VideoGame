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

echo "Creando directorio remoto..."
ssh $SSH_OPTS "$PI_USER@$PI_IP" "mkdir -p '$REMOTE_DIR'"

echo "Copiando binario..."
scp $SSH_OPTS "$LOCAL_WIN" "$PI_USER@$PI_IP:$REMOTE_DIR/"

echo "Asignando permisos..."
ssh $SSH_OPTS "$PI_USER@$PI_IP" "chmod +x '$REMOTE'"

echo
echo "=========================================="
echo "DEPLOY COMPLETADO"
echo "=========================================="
