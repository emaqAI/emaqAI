# SX25 toolbox — autostart narzędzia wg parametru jądra sx25_autostart.
# Uruchamia się TYLKO na lokalnej konsoli tty1 (nie w sesji SSH), aby nie
# przechwytywać zdalnych logowań.

sx25_autostart=$(sed -n 's/.*sx25_autostart=\([^ ]*\).*/\1/p' /proc/cmdline 2>/dev/null)
sx25_tty=$(tty 2>/dev/null)

if [ "$sx25_tty" = "/dev/tty1" ]; then
  case "$sx25_autostart" in
    dosbox)
      command -v sx25-dosbox >/dev/null 2>&1 && exec sx25-dosbox
      echo "SX25: launcher DOSBox niedostępny — otwieram powłokę."
      ;;
    box64)
      if command -v box64 >/dev/null 2>&1; then
        box64 --version 2>/dev/null
        echo "SX25: uruchom binarium x86_64 przez: box64 ./program"
      else
        echo "SX25: box64 niedostępny na tej architekturze."
      fi
      ;;
    *)
      : # zwykła powłoka
      ;;
  esac
fi
