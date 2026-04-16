#!/usr/bin/env bash
set -e

FLUTTER="/home/aleja/flutter/bin/flutter"
BUILD_DIR="/mnt/c/Users/aleja/Repositories/Folio/build"
LINUX_BUILD_DIR="/home/aleja/folio_linux_build"

# Asegurar que el directorio de build en el filesystem Linux existe
mkdir -p "$LINUX_BUILD_DIR"

# Montar el directorio de build si no está ya montado (evita el error "Operation not permitted" de CMake en NTFS)
if ! mountpoint -q "$BUILD_DIR"; then
  echo "Montando build/ en filesystem Linux..."
  sudo mount --bind "$LINUX_BUILD_DIR" "$BUILD_DIR"
fi

export PATH="/home/aleja/flutter/bin:$PATH"

cd "/mnt/c/Users/aleja/Repositories/Folio"
exec "$FLUTTER" run -d linux "$@"
