#!/usr/bin/env bash
# SX25 — (opcjonalnie) zbuduj własne binaria iPXE ze źródeł.
# Przydatne, gdy brakuje gotowego ipxe32.efi (UEFI 32-bit) lub chcesz
# wkompilować własne ustawienia/skrypt osadzony.
#
# Wymaga: git, gcc, binutils, make, perl, liblzma/xz-dev, mtools (dla .efi).
set -euo pipefail
source "$(dirname "$0")/common.sh"
sx25_log_init "build-ipxe" "$@"

WORK="${SX25_ROOT}/build/ipxe"
SRC="$WORK/src"

log "Buduję iPXE w $WORK ..."
mkdir -p "$WORK"

if [ ! -d "$SRC/.git" ]; then
  git clone --depth 1 https://github.com/ipxe/ipxe.git "$SRC"
else
  git -C "$SRC" pull --ff-only || true
fi

cd "$SRC/src"

build() {
  local target="$1" out="$2"
  log "make $target"
  make -j"$(nproc)" "$target"
  cp -f "bin${target#bin}" "$SX25_TFTP_ROOT/$out" 2>/dev/null || true
}

# BIOS (undionly), UEFI x86_64, UEFI IA32.
make -j"$(nproc)" bin/undionly.kpxe            && cp -f bin/undionly.kpxe            "$SX25_TFTP_ROOT/undionly.kpxe"
make -j"$(nproc)" bin-x86_64-efi/ipxe.efi      && cp -f bin-x86_64-efi/ipxe.efi      "$SX25_TFTP_ROOT/ipxe.efi"
make -j"$(nproc)" bin-i386-efi/ipxe.efi        && cp -f bin-i386-efi/ipxe.efi        "$SX25_TFTP_ROOT/ipxe32.efi"

log "Gotowe. Binaria w: $SX25_TFTP_ROOT"
