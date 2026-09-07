# SX25 — architektura i przepływ rozruchu

## Elementy

| Element        | Rola                                                            |
|----------------|----------------------------------------------------------------|
| **dnsmasq**    | proxyDHCP (wskazuje plik startowy) + serwer TFTP (etap 1: iPXE) |
| **iPXE**       | bootloader sieciowy — pobiera i wyświetla menu SX25            |
| **HTTP**       | szybki transport menu, jąder, initrd, ISO i nakładek           |
| **manifest**   | `data/distros.list` — co i skąd pobrać                          |
| **nakładki**   | apkovl dla Alpine (DOSBox, box64)                               |

## Przepływ rozruchu (dwuetapowy)

```
1. Klient (PXE/UEFI) rozgłasza DHCPDISCOVER
        │
        ▼
2. Router/DHCP przydziela IP; dnsmasq (proxyDHCP) DODAJE informację o pliku
   startowym zależnie od firmware klienta (opcja 93):
        BIOS   → undionly.kpxe   (przez TFTP)
        UEFI64 → ipxe.efi        (przez TFTP)
        UEFI32 → ipxe32.efi      (przez TFTP)
        │
        ▼
3. Klient pobiera i uruchamia iPXE. iPXE zgłasza się ponownie (opcja 175).
        │
        ▼
4. dnsmasq widzi "to już iPXE" i wskazuje:
        http://<SERVER_IP>:<PORT>/boot/menu.ipxe
        │
        ▼
5. iPXE pobiera menu przez HTTP i je wyświetla. Wybór pozycji →
   pobranie kernela + initrd (+ modloop/ISO) przez HTTP i `boot`.
```

Dwuetapowość (najpierw małe iPXE przez TFTP, potem wszystko przez HTTP) daje
niezawodność PXE i szybkość HTTP dla dużych plików.

## Dlaczego proxyDHCP?

proxyDHCP **współistnieje** z istniejącym serwerem DHCP w sieci — nie
przydziela adresów IP, tylko dokłada informację o rozruchu sieciowym. Dzięki
temu nie trzeba przejmować ani rekonfigurować routera. Wymaga to działania
SX25 w tej samej warstwie L2 (broadcast) co klienci.

## Układ katalogów runtime (poza repo, domyślnie /srv/sx25)

```
/srv/sx25/
├── tftp/                       # etap 1
│   ├── undionly.kpxe
│   ├── ipxe.efi
│   └── ipxe32.efi
├── http/                       # etap 2 (serwowane po HTTP)
│   ├── boot/                   # wyrenderowane menu *.ipxe
│   ├── distros/<id>/           # jądra, initrd, modloop, ISO
│   └── overlays/               # sx25-base + toolbox apkovl, authorized_keys
├── logs/                       # dzienniki .txt (patrz docs/LOGI.md)
└── dnsmasq.runtime.conf        # wygenerowany z szablonu
```

## Konfiguracja

Zmienne środowiskowe (nadpisują domyślne z `scripts/common.sh`):

| Zmienna            | Domyślnie      | Znaczenie                          |
|--------------------|----------------|------------------------------------|
| `SX25_ROOT`        | `/srv/sx25`    | katalog roboczy serwera            |
| `SX25_HTTP_PORT`   | `8080`         | port serwera HTTP                  |
| `SX25_SERVER_IP`   | `auto`         | IP serwera (auto = z trasy domyśl.)|
| `SX25_SUBNET`      | `auto`         | podsieć proxyDHCP, np. `10.0.0.0/24`|

Przykład:

```bash
sudo SX25_SERVER_IP=10.0.0.5 SX25_SUBNET=10.0.0.0/24 ./scripts/serve.sh
```

## Diagnostyka

- **Klient nie widzi menu** — sprawdź, czy dnsmasq działa w tej samej sieci L2,
  a firewall przepuszcza UDP 67/68 (DHCP), 69 (TFTP) i port HTTP.
- **iPXE startuje, ale menu nie ładuje** — sprawdź `SX25_SERVER_IP`/port i czy
  HTTP serwuje `/boot/menu.ipxe`.
- **Kernel/initrd 404** — uruchom `fetch-distros.sh` i zweryfikuj adresy w
  `data/distros.list` (bywają dezaktualizowane).
- **Logi** — dnsmasq startuje z `log-dhcp` i `--no-daemon`, więc widać cały
  przebieg PXE w konsoli. Każdy skrypt zapisuje też pełny dziennik `.txt`
  (serwer: `/srv/sx25/logs/`, klient: `/var/log/sx25/`) — patrz
  [LOGI.md](LOGI.md).
- **SSH nie działa w Alpine** — sprawdź, czy nakładki zbudowano
  (`build-overlay.sh`) i czy HTTP serwuje `overlays/*.apkovl.tar.gz`; w logu
  klienta (`/var/log/sx25/toolbox_*.txt`) znajdziesz krok instalacji openssh.
- **DOSBox nie startuje graficznie** — zajrzyj do `/var/log/sx25/dosbox_*.txt`;
  launcher próbuje X, potem framebuffer. Na niektórych VM brakuje FB — użyj
  sprzętu z konsolą graficzną lub zainstaluj pełny X.
