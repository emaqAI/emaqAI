# SX25 — katalog dystrybucji i narzędzi

Wpisy pochodzą z `data/distros.list`. Adresy URL i wersje z czasem się
dezaktualizują — w razie błędu 404 sprawdź oficjalny katalog netboot danej
dystrybucji i zaktualizuj manifest.

## Lekkie Linuksy — x86-64

| id           | Dystrybucja        | Metoda netboot            | Uwagi                                  |
|--------------|--------------------|---------------------------|----------------------------------------|
| `alpine64`   | Alpine Linux LTS   | kernel + initramfs + modloop | Bardzo lekki; `modloop=` przez HTTP |
| `debian64`   | Debian Installer   | kernel + initrd.gz        | Instalator netinst (amd64)             |
| `tinycore64` | Tiny Core (pure64) | kernel + corepure64.gz    | Minimalny, w pełni w RAM               |
| `sysrescue64`| SystemRescue       | ISO (`sanboot`)           | System ratunkowy; emulacja ISO w iPXE  |

## Lekkie Linuksy — x86-32 (i386)

| id           | Dystrybucja      | Metoda netboot            | Uwagi                        |
|--------------|------------------|---------------------------|------------------------------|
| `alpine32`   | Alpine Linux LTS | kernel + initramfs + modloop | Wariant 32-bit            |
| `debian32`   | Debian Installer | kernel + initrd.gz        | Instalator netinst (i386)    |
| `tinycore32` | Tiny Core        | kernel + core.gz          | Klasyczny 32-bit             |

## Dostęp SSH wg obrazu

| Obraz               | SSH | Jak                                                        |
|---------------------|-----|-----------------------------------------------------------|
| Alpine 64/32        | ✅  | Nakładka `sx25-base` instaluje openssh i startuje sshd    |
| DOSBox/box64/toolbox/shell | ✅ | Nakładka `toolbox`/`sx25-base` (jak wyżej)          |
| Debian 64/32        | ✅  | Instalator: **network-console**, klucz z `authorized_keys`|
| Tiny Core 64/32     | ⚠️  | Ręcznie: `tce-load -wi openssh` + konfiguracja (brak persystencji) |
| SystemRescue        | ⚠️  | Startuje sshd, ale `sanboot` ISO nie wstrzykuje kluczy — ustaw hasło w konsoli lub remasteruj ISO |

Logowanie do Alpine/Debiana odbywa się **kluczem** (`workspace-17`) jako root/
instalator. IP klienta odczytasz z jego konsoli (`ip a`).

- **Debian:** parametry `anna/choose_modules=network-console` +
  `network-console/authorized_keys_url=.../overlays/authorized_keys` (ustawione
  w menu) włączają zdalne dokończenie instalacji przez SSH.
- **Tiny Core / SystemRescue:** SSH kluczem wymaga kroków ręcznych — patrz kolumna
  „Jak". Można je zautomatyzować remasterując obraz (poza zakresem szkieletu).

## Narzędzia / środowiska (menu `tools`)

Pozycje uruchamiają Alpine (x86-64) z nakładką `toolbox.apkovl.tar.gz`, która
przy starcie doinstalowuje narzędzia (patrz `overlays/`).

| Pozycja   | Co robi                                                          |
|-----------|------------------------------------------------------------------|
| `dosbox`  | Alpine + DOSBox; autostart emulatora DOS (`sx25_autostart=dosbox`)|
| `box64`   | Alpine + box64; uruchamianie binariów x86_64                      |
| `toolbox` | Alpine z DOSBox + box64 + narzędziami, powłoka                    |
| `shell`   | Czysty Alpine, powłoka                                            |

### DOSBox
Emulator środowiska DOS. Pakiet `dosbox` z repo Alpine **community**. Środowisko
jest ulotne — pliki/gry montuj z zasobu sieciowego lub pobieraj po starcie.

### box64
Uruchamia binaria **x86_64** na innych architekturach (głównie **ARM/RISC-V**).
Na kliencie x86 jest zwykle zbędny (host już jest x86_64), ale pozycję dodano
zgodnie z wymaganiem projektu. Dostępność pakietu zależy od architektury i repo.

## Dodawanie własnej dystrybucji

1. Znajdź oficjalne pliki netboot (kernel + initrd; opcjonalnie squashfs/modloop)
   lub obraz ISO z obsługą isohybrid.
2. Dodaj linię do `data/distros.list`:
   ```
   id | arch | kernel_url | initrd_url | extra_url
   ```
   Dla ISO: w polu `initrd_url` wpisz `_ISO_`, a `kernel_url` ustaw na adres ISO
   (zapisze się jako `distros/<id>/system.iso`).
3. Dodaj pozycję menu w `config/ipxe/linux64.ipxe` lub `linux32.ipxe`.
4. `fetch-distros.sh <id>` i restart `serve.sh`.

## Wariant awaryjny — netboot.xyz

W menu głównym jest pozycja **Chainload netboot.xyz**, która ładuje społeczne
menu netboot.xyz (setki systemów instalacyjnych i live). Przydatne, gdy któryś
z bezpośrednich adresów przestanie działać — wymaga dostępu do Internetu na
kliencie.
