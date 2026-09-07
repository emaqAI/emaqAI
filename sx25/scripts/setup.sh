#!/usr/bin/env bash
# SX25 — instalacja zależności i przygotowanie katalogów TFTP/HTTP.
# Uruchom jako root: sudo ./scripts/setup.sh
set -euo pipefail
source "$(dirname "$0")/common.sh"

[ "$(id -u)" -eq 0 ] || die "Uruchom przez sudo/root (potrzebne do instalacji pakietów i katalogów w $SX25_ROOT)."

# --- Zależności ---------------------------------------------------------------
install_pkgs() {
  if command -v apt-get >/dev/null 2>&1; then
    log "Instaluję zależności (apt)..."
    apt-get update -qq
    apt-get install -y dnsmasq wget curl ca-certificates
  elif command -v apk >/dev/null 2>&1; then
    log "Instaluję zależności (apk)..."
    apk add --no-cache dnsmasq wget curl ca-certificates
  elif command -v dnf >/dev/null 2>&1; then
    log "Instaluję zależności (dnf)..."
    dnf install -y dnsmasq wget curl ca-certificates
  else
    warn "Nieznany menedżer pakietów — zainstaluj ręcznie: dnsmasq wget curl."
  fi
}

# dnsmasq bywa uruchamiany jako usługa systemowa i zajmuje port 67 —
# tu używamy własnej instancji, więc systemową wyłączamy.
disable_system_dnsmasq() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl disable --now dnsmasq 2>/dev/null || true
  fi
}

# --- Katalogi -----------------------------------------------------------------
make_dirs() {
  log "Tworzę katalogi w $SX25_ROOT ..."
  mkdir -p "$SX25_TFTP_ROOT" \
           "$SX25_HTTP_ROOT/boot" \
           "$SX25_HTTP_ROOT/distros" \
           "$SX25_HTTP_ROOT/overlays"
}

# --- Binaria iPXE (pierwszy etap rozruchu, przez TFTP) -----------------------
fetch_ipxe() {
  log "Pobieram binaria iPXE do $SX25_TFTP_ROOT ..."
  local base="https://boot.ipxe.org"
  # BIOS (undionly) + UEFI x86_64.
  wget -q -O "$SX25_TFTP_ROOT/undionly.kpxe" "$base/undionly.kpxe" \
    || warn "Nie pobrano undionly.kpxe (BIOS)."
  wget -q -O "$SX25_TFTP_ROOT/ipxe.efi"      "$base/ipxe.efi" \
    || warn "Nie pobrano ipxe.efi (UEFI x86_64)."
  # UEFI IA32 — nie zawsze publikowane; próbujemy, w razie braku trzeba zbudować.
  if ! wget -q -O "$SX25_TFTP_ROOT/ipxe32.efi" "$base/ipxe32.efi"; then
    rm -f "$SX25_TFTP_ROOT/ipxe32.efi"
    warn "Brak gotowego ipxe32.efi (UEFI 32-bit). Zbuduj: scripts/build-ipxe.sh"
  fi
}

install_pkgs
disable_system_dnsmasq
make_dirs
fetch_ipxe

log "Gotowe. Dalej:"
log "  1) ./scripts/fetch-distros.sh        # pobierz obrazy dystrybucji"
log "  2) sudo ./scripts/serve.sh           # uruchom serwer"
