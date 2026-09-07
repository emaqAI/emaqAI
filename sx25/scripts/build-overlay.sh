#!/usr/bin/env bash
# SX25 — budowa nakładki apkovl (toolbox: dosbox + box64) dla Alpine netboot.
# Wynik: $SX25_HTTP_ROOT/overlays/toolbox.apkovl.tar.gz
set -euo pipefail
source "$(dirname "$0")/common.sh"

SRC="$SX25_PROJECT_DIR/overlays/files"
[ -d "$SRC" ] || die "Brak katalogu źródłowego nakładki: $SRC"

OUT_DIR="${SX25_HTTP_ROOT}/overlays"
OUT="$OUT_DIR/toolbox.apkovl.tar.gz"
mkdir -p "$OUT_DIR"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

log "Składam nakładkę w $STAGE ..."
cp -a "$SRC/." "$STAGE/"

# Skrypty local.d muszą być wykonywalne.
chmod +x "$STAGE/etc/local.d/"*.start 2>/dev/null || true

# Uprawnienia klucza SSH (sshd odrzuca zbyt otwarte pliki).
if [ -d "$STAGE/root/.ssh" ]; then
  chmod 700 "$STAGE/root/.ssh"
  chmod 600 "$STAGE/root/.ssh/authorized_keys" 2>/dev/null || true
fi

# Włącz usługę 'local' w domyślnym runlevelu (uruchamia /etc/local.d/*.start).
mkdir -p "$STAGE/etc/runlevels/default"
ln -sf /etc/init.d/local "$STAGE/etc/runlevels/default/local"

# Zadeklaruj pakiety w apk world (informacyjnie; instalacja i tak w local.d).
mkdir -p "$STAGE/etc/apk"
{
  echo dosbox
  echo box64
  echo openssh
} >> "$STAGE/etc/apk/world"

log "Pakuję do $OUT ..."
tar -C "$STAGE" -czf "$OUT" .

log "Gotowe: $OUT"
log "Menu iPXE (tools.ipxe) używa apkovl=.../overlays/toolbox.apkovl.tar.gz"
