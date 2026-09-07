# SX25 — nakładki Alpine (apkovl)

Nakładka (apkovl) to spakowany `.tar.gz` z fragmentem systemu plików, który
Alpine wczytuje przy rozruchu netboot (parametr jądra `apkovl=URL`). SX25
używa jej, by w locie skonfigurować SSH oraz (w wariancie toolbox) DOSBox i
box64 w ulotnym środowisku Alpine.

## Dwie nakładki (jedno źródło `files/`)

`build-overlay.sh` buduje z tych samych plików dwa warianty:

| Plik wynikowy               | Zawiera                              | Używany przez                 |
|-----------------------------|-------------------------------------|-------------------------------|
| `sx25-base.apkovl.tar.gz`   | SSH + logowanie                     | Alpine 64/32, `shell`         |
| `toolbox.apkovl.tar.gz`     | SSH + DOSBox + box64 + autostart    | `dosbox`, `box64`, `toolbox`  |

Różnicę robi znacznik `/etc/sx25/toolbox` (obecny tylko w toolbox) — skrypt
startowy instaluje wtedy DOSBox/box64 i przygotowuje autostart.

## Zawartość `files/`

```
files/
├── etc/local.d/sx25-tools.start        # start: SSH zawsze; DOSBox/box64 gdy toolbox; autologin
├── etc/ssh/sshd_config.d/10-sx25.conf  # SSH tylko kluczem (root, bez hasła)
├── etc/motd                            # komunikat powitalny
├── root/.ssh/authorized_keys           # klucze publiczne uprawnione do logowania
├── root/.profile                       # autostart wg sx25_autostart=dosbox|box64 (tylko tty1)
├── usr/local/bin/sx25-dosbox           # launcher DOSBox (X → framebuffer → powłoka)
└── usr/local/lib/sx25/log.sh           # biblioteka logowania klienta (PL, .txt)
```

## Autostart DOSBox

Pozycja „DOSBox" w menu ustawia `sx25_autostart=dosbox`. Skrypt startowy włącza
wtedy **autologin roota na tty1**, a `~/.profile` uruchamia `sx25-dosbox`, który
próbuje kolejno: sesji **X** (`startx`), następnie **SDL na framebufferze**, a w
razie niepowodzenia otwiera powłokę z sugestią. Wszystko jest logowane do
`/var/log/sx25/dosbox_*.txt`.

## Dostęp SSH

Nakładka instaluje `openssh`, generuje klucze hosta i startuje `sshd` przy
rozruchu. Logowanie jest **tylko kluczem** (root, bez hasła) — dozwolone klucze
publiczne są w `files/root/.ssh/authorized_keys`.

```bash
# z innej maszyny (IP klienta odczytasz z konsoli, np. `ip a`):
ssh root@<IP-klienta>
```

Aby dodać kolejny klucz, dopisz go w osobnej linii do `authorized_keys` i
przebuduj nakładkę (`build-overlay.sh`).

## Budowa nakładki

```bash
./scripts/build-overlay.sh
```

Skrypt składa `files/` w poprawne apkovl (włącza usługę `local`, dodaje pakiety
do `/etc/apk/world`, ustawia uprawnienia `.ssh`) i zapisuje oba pliki do
`$SX25_HTTP_ROOT/overlays/`, skąd serwuje je `serve.sh`. Cały przebieg budowy
jest logowany (patrz [../docs/LOGI.md](../docs/LOGI.md)).

## Uwagi

- Środowisko jest **ulotne** — po restarcie klienta zmiany znikają.
- `box64` ma sens głównie na hostach **ARM/RISC-V** (uruchamia binaria x86_64).
  Na kliencie x86 instalacja jest best-effort i zwykle zbędna — pozycja
  istnieje zgodnie z wymaganiem projektu.
- Instalacja pakietów wymaga działającej sieci i dostępu do repozytoriów Alpine.
