#!/bin/sh
# SX25 — biblioteka logowania po stronie KLIENTA (netboot Alpine).
# POSIX sh / busybox ash. Loguje do /var/log/sx25/*.txt i na konsolę.
# Znaczniki: INFO, KOMENDA, WYKONANO, ZAPISANO, NIEZREALIZOWANE, UWAGA, BŁĄD,
#            SUGESTIA, CRASH, KONIEC.

SX25_CLIENT_LOG_DIR="${SX25_CLIENT_LOG_DIR:-/var/log/sx25}"
SX25_CLIENT_LOG_FILE="${SX25_CLIENT_LOG_FILE:-}"

sx25c_now()  { date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo '?'; }
sx25c_time() { date '+%H:%M:%S' 2>/dev/null || echo '??:??:??'; }

sx25c_init() {
  name="${1:-klient}"
  if ! mkdir -p "$SX25_CLIENT_LOG_DIR" 2>/dev/null; then
    SX25_CLIENT_LOG_DIR=/tmp
  fi
  SX25_CLIENT_LOG_FILE="$SX25_CLIENT_LOG_DIR/${name}_$(date +%Y%m%d-%H%M%S 2>/dev/null || echo now)_$$.txt"
  {
    echo "==================================================================="
    echo " SX25 KLIENT — DZIENNIK: $name"
    echo " Start    : $(sx25c_now)"
    echo " Host     : $(hostname 2>/dev/null || echo '?')"
    echo " Adres IP : $(ip -4 addr show scope global 2>/dev/null | awk '/inet/{print $2; exit}')"
    echo " Cmdline  : $(cat /proc/cmdline 2>/dev/null)"
    echo "==================================================================="
  } >> "$SX25_CLIENT_LOG_FILE" 2>/dev/null
}

sx25c_log() {
  l="[$(sx25c_time)] [$1] $2"
  echo "$l"
  [ -n "$SX25_CLIENT_LOG_FILE" ] && echo "$l" >> "$SX25_CLIENT_LOG_FILE" 2>/dev/null
}
sx25c_info()  { sx25c_log "INFO" "$1"; }
sx25c_ok()    { sx25c_log "WYKONANO" "$1"; }
sx25c_saved() { sx25c_log "ZAPISANO" "$1"; }
sx25c_skip()  { sx25c_log "NIEZREALIZOWANE" "$1"; [ -n "${2:-}" ] && sx25c_log "SUGESTIA" "$2"; }
sx25c_err()   { sx25c_log "BŁĄD" "$1"; [ -n "${2:-}" ] && sx25c_log "SUGESTIA" "$2"; }

# sx25c_run "opis" "sugestia-przy-błędzie" komenda arg...
sx25c_run() {
  desc="$1"; hint="$2"; shift 2
  sx25c_log "KOMENDA" "$desc → $*"
  out="$("$@" 2>&1)"; rc=$?
  if [ -n "$out" ]; then
    echo "$out"
    [ -n "$SX25_CLIENT_LOG_FILE" ] && echo "$out" >> "$SX25_CLIENT_LOG_FILE" 2>/dev/null
  fi
  if [ "$rc" -eq 0 ]; then
    sx25c_ok "$desc"
  else
    sx25c_err "$desc (kod $rc)" "$hint"
  fi
  return "$rc"
}
