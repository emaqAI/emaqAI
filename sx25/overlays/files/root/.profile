# SX25 toolbox — automatyczne uruchomienie narzędzia wg parametru jądra
# sx25_autostart=dosbox|box64|shell (przekazywany z menu iPXE).
sx25_autostart=$(cat /proc/cmdline 2>/dev/null | tr ' ' '\n' | sed -n 's/^sx25_autostart=//p')

case "$sx25_autostart" in
  dosbox)
    command -v dosbox >/dev/null 2>&1 && exec dosbox
    echo "SX25: dosbox niezainstalowany — sprawdź sieć/repo."
    ;;
  box64)
    if command -v box64 >/dev/null 2>&1; then
      box64 --version
      echo "SX25: uruchom binarium x86_64 przez: box64 ./program"
    else
      echo "SX25: box64 niedostępny na tej architekturze."
    fi
    ;;
  *)
    : # zwykła powłoka
    ;;
esac
