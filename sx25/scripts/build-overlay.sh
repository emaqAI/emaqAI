#!/usr/bin/env bash
# SX25 — budowa nakładek apkovl dla Alpine netboot:
#   sx25-base.apkovl.tar.gz  — SSH + logowanie + narzędzia bazowe (dla obrazów Alpine)
#   toolbox.apkovl.tar.gz    — jak base + DOSBox + box64 + autostart
# Wynik trafia do $SX25_HTTP_ROOT/overlays/. Cały przebieg jest logowany.
set -euo pipefail
source "$(dirname "$0")/common.sh"
sx25_log_init "build-overlay" "$@"

SRC="$SX25_PROJECT_DIR/overlays/files"
[ -d "$SRC" ] || die "Brak katalogu źródłowego nakładki: $SRC"

OUT_DIR="${SX25_HTTP_ROOT}/overlays"
mkdir -p "$OUT_DIR"

# Zbuduj jedną nakładkę.
#   $1 = nazwa pliku wyjściowego
#   $2 = "toolbox", jeśli ma zawierać DOSBox/box64 (znacznik + pakiety)
build_one() {
  local out="$OUT_DIR/$1" kind="${2:-base}"
  local stage; stage="$(mktemp -d)"
  # sprzątanie tego etapu
  # (globalny trap ustawia się niżej dla całego skryptu)
  sx25_info "Składam nakładkę '$1' (typ: $kind) w $stage ..."
  cp -a "$SRC/." "$stage/"

  # Wykonywalne skrypty.
  chmod +x "$stage/etc/local.d/"*.start 2>/dev/null || true
  chmod +x "$stage/usr/local/bin/"* 2>/dev/null || true

  # Uprawnienia klucza SSH.
  if [ -d "$stage/root/.ssh" ]; then
    chmod 700 "$stage/root/.ssh"
    chmod 600 "$stage/root/.ssh/authorized_keys" 2>/dev/null || true
    sx25_ok "Ustawiono uprawnienia .ssh (700/600) w nakładce '$1'"
  else
    sx25_skip "Uprawnienia .ssh w '$1'" "Brak katalogu root/.ssh w źródłach nakładki."
  fi

  # Usługa 'local' w domyślnym runlevelu (uruchamia /etc/local.d/*.start).
  mkdir -p "$stage/etc/runlevels/default"
  ln -sf /etc/init.d/local "$stage/etc/runlevels/default/local"

  # Lista pakietów apk world.
  mkdir -p "$stage/etc/apk"
  echo openssh >> "$stage/etc/apk/world"
  if [ "$kind" = "toolbox" ]; then
    mkdir -p "$stage/etc/sx25"
    : > "$stage/etc/sx25/toolbox"        # znacznik trybu toolbox
    {
      echo dosbox
      echo box64
      echo xorg-server
      echo xinit
      echo xf86-video-fbdev
    } >> "$stage/etc/apk/world"
    sx25_saved "Znacznik /etc/sx25/toolbox + pakiety DOSBox/box64/X w '$1'"
  fi

  tar -C "$stage" -czf "$out" .
  rm -rf "$stage"
  sx25_saved "$out"
}

build_one "sx25-base.apkovl.tar.gz" "base"
build_one "toolbox.apkovl.tar.gz"   "toolbox"

sx25_ok "Nakładki gotowe w $OUT_DIR:"
sx25_info "  sx25-base.apkovl.tar.gz  → obrazy Alpine (SSH)"
sx25_info "  toolbox.apkovl.tar.gz    → menu Narzędzia (SSH + DOSBox + box64 + autostart)"
