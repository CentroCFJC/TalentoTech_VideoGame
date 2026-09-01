#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

PI_USER="ccu-pi1"
PI_IP="10.15.1.233"

LOCAL="$SCRIPT_DIR/build/linux_arm64/"
REMOTE="/home/ccu-pi1/Desktop/linux_arm64/"

echo
echo "=========================================="
echo "     DEPLOY INFINITE RUNNER"
echo "=========================================="
echo

echo "Sincronizando archivos..."
echo

rsync -avh --progress \
    --delete \
    --rsync-path="mkdir -p $REMOTE && rsync" \
    -e ssh \
    "$LOCAL" \
    "$PI_USER@$PI_IP:$REMOTE"

echo
echo "Asignando permisos..."

ssh "$PI_USER@$PI_IP" \
"chmod +x '/home/ccu-pi1/Desktop/linux_arm64/Infinite Runner.arm64'"

echo
echo "=========================================="
echo "DEPLOY COMPLETADO"
echo "=========================================="
