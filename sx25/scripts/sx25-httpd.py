#!/usr/bin/env python3
# SX25 — serwer HTTP: serwuje pliki (kernel/initrd/menu/overlays) ORAZ przyjmuje
# zdalne dzienniki od klientów (PUT/POST na /upload/<nazwa>).
#
# Użycie:
#   sx25-httpd.py <katalog_http> <port> <katalog_logow>
#
# Upload: klient wysyła plik na /upload/<nazwa>. Ciało żądania (body) jest
# zapisywane do <katalog_logow>/clients/<nazwa-oczyszczona>. Nazwa jest
# sanityzowana (bez ścieżek, bez '..'), więc nie da się wyjść poza katalog.

import os
import re
import sys
import datetime
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler

HTTP_ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8080
LOG_DIR = sys.argv[3] if len(sys.argv) > 3 else os.path.join(HTTP_ROOT, "logs")
CLIENTS_DIR = os.path.join(LOG_DIR, "clients")
os.makedirs(CLIENTS_DIR, exist_ok=True)

MAX_UPLOAD = 32 * 1024 * 1024  # 32 MB — bezpiecznik na wypadek błędnego klienta.


def safe_name(raw: str) -> str:
    """Zredukuj do bezpiecznej nazwy pliku (bez ścieżek, bez '..')."""
    raw = raw.strip("/").split("/")[-1]
    raw = re.sub(r"[^A-Za-z0-9._-]", "_", raw)
    if not raw or raw in (".", ".."):
        raw = "log"
    ts = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    return f"{ts}_{raw}"


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=HTTP_ROOT, **kw)

    # Wspólna logika dla PUT i POST na /upload/...
    def _handle_upload(self):
        # Reason-phrase (linia statusu HTTP) musi być ASCII/latin-1 — polski
        # opis umieszczamy w treści (3. argument), która jest kodowana UTF-8.
        if not self.path.startswith("/upload/"):
            self.send_error(404, "Not Found", "Nieznana ścieżka uploadu — użyj /upload/<nazwa>.")
            return
        name = safe_name(self.path[len("/upload/"):])
        try:
            length = int(self.headers.get("Content-Length", 0))
        except ValueError:
            length = 0
        if length <= 0 or length > MAX_UPLOAD:
            self.send_error(413, "Payload Too Large", "Brak lub zbyt duże ciało żądania.")
            return
        dest = os.path.join(CLIENTS_DIR, name)
        remaining = length
        try:
            with open(dest, "wb") as f:
                while remaining > 0:
                    chunk = self.rfile.read(min(65536, remaining))
                    if not chunk:
                        break
                    f.write(chunk)
                    remaining -= len(chunk)
        except OSError as e:
            self.send_error(500, "Internal Server Error", f"Zapis nieudany: {e}")
            return
        client = self.client_address[0]
        print(f"[SX25-HTTPD] Zapisano dziennik klienta {client} -> {dest}")
        self.send_response(201)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.end_headers()
        self.wfile.write(f"OK: {name}\n".encode("utf-8"))

    def do_PUT(self):
        self._handle_upload()

    def do_POST(self):
        self._handle_upload()

    # Cichsze, jednolite logi dostępu (i tak trafiają do dziennika serve.sh).
    def log_message(self, fmt, *args):
        sys.stderr.write("[SX25-HTTPD] %s - %s\n" % (self.client_address[0], fmt % args))


if __name__ == "__main__":
    os.chdir(HTTP_ROOT)
    srv = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"[SX25-HTTPD] Serwuję {HTTP_ROOT} na :{PORT}; upload -> {CLIENTS_DIR}")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("[SX25-HTTPD] Zatrzymano.")
