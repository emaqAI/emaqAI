#!/usr/bin/env bash
# SX25 — wspólne ustawienia i funkcje pomocnicze (source'owane przez skrypty).
# Wartości można nadpisać zmiennymi środowiskowymi SX25_*.

set -euo pipefail

# Katalog projektu (rodzic katalogu scripts/).
SX25_PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Główny katalog roboczy serwera (poza repo — tu lądują pobrane obrazy).
SX25_ROOT="${SX25_ROOT:-/srv/sx25}"
SX25_TFTP_ROOT="${SX25_TFTP_ROOT:-$SX25_ROOT/tftp}"
SX25_HTTP_ROOT="${SX25_HTTP_ROOT:-$SX25_ROOT/http}"

# Port serwera HTTP (kernel/initrd/menu).
SX25_HTTP_PORT="${SX25_HTTP_PORT:-8080}"

# IP serwera i podsieć dla proxyDHCP. "auto" => wykryj z domyślnej trasy.
SX25_SERVER_IP="${SX25_SERVER_IP:-auto}"
SX25_SUBNET="${SX25_SUBNET:-auto}"

# Manifest dystrybucji.
SX25_DISTRO_LIST="${SX25_DISTRO_LIST:-$SX25_PROJECT_DIR/data/distros.list}"

log()  { printf '\033[1;32m[SX25]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[SX25] UWAGA:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[SX25] BŁĄD:\033[0m %s\n' "$*" >&2; exit 1; }

# Wykryj podstawowy adres IP (interfejs domyślnej trasy).
sx25_detect_ip() {
  local ip
  ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')" || true
  [ -n "$ip" ] && { printf '%s' "$ip"; return 0; }
  return 1
}

# Wykryj podsieć w formacie a.b.c.0/xx z interfejsu domyślnej trasy.
sx25_detect_subnet() {
  local dev net
  dev="$(ip -4 route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')" || true
  [ -z "$dev" ] && return 1
  net="$(ip -4 route show dev "$dev" scope link 2>/dev/null | awk 'NR==1{print $1}')" || true
  [ -n "$net" ] && { printf '%s' "$net"; return 0; }
  return 1
}

# Rozwiąż "auto" na realne wartości (ustawia SX25_SERVER_IP / SX25_SUBNET).
sx25_resolve_network() {
  if [ "$SX25_SERVER_IP" = "auto" ]; then
    SX25_SERVER_IP="$(sx25_detect_ip)" || die "Nie udało się wykryć IP — ustaw SX25_SERVER_IP=..."
  fi
  if [ "$SX25_SUBNET" = "auto" ]; then
    SX25_SUBNET="$(sx25_detect_subnet)" || die "Nie udało się wykryć podsieci — ustaw SX25_SUBNET=a.b.c.0/24"
  fi
}
