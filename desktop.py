"""Desktop launcher for the YouTube Subtitle Extractor.

Starts the bundled Flask server on a free local port and opens it in a
native window (via pywebview). If no GUI backend is available it falls
back to opening the system default web browser.

Run modes:
    python desktop.py            # native window, browser fallback
    python desktop.py --selftest # start server, verify it serves, exit
    GETWORDS_NO_GUI=1 ...        # force the browser-fallback path
"""

from __future__ import annotations

import os
import socket
import sys
import threading
import time
import urllib.request
import webbrowser

from werkzeug.serving import make_server

from app import app

HOST = "127.0.0.1"
APP_TITLE = "YouTube Subtitle Extractor"


def _free_port() -> int:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind((HOST, 0))
    port = s.getsockname()[1]
    s.close()
    return port


class ServerThread(threading.Thread):
    def __init__(self, host: str, port: int):
        super().__init__(daemon=True)
        self._srv = make_server(host, port, app, threaded=True)

    def run(self) -> None:
        self._srv.serve_forever()

    def shutdown(self) -> None:
        self._srv.shutdown()


def _wait_until_up(url: str, timeout: float = 15.0) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=2) as r:
                if r.status == 200:
                    return True
        except Exception:
            time.sleep(0.15)
    return False


def _run_selftest(url: str) -> int:
    if not _wait_until_up(url):
        print("SELFTEST FAILED: server did not come up", file=sys.stderr)
        return 1
    try:
        with urllib.request.urlopen(url, timeout=5) as r:
            body = r.read().decode("utf-8", "replace")
    except Exception as e:  # noqa: BLE001
        print(f"SELFTEST FAILED: {e}", file=sys.stderr)
        return 1
    if "YouTube Subtitle" not in body:
        print("SELFTEST FAILED: index page content missing", file=sys.stderr)
        return 1
    print(f"SELFTEST OK: server serving at {url} ({len(body)} bytes)")
    return 0


def main() -> int:
    port = int(os.environ.get("GETWORDS_PORT") or _free_port())
    url = f"http://{HOST}:{port}/"

    server = ServerThread(HOST, port)
    server.start()

    if "--selftest" in sys.argv:
        rc = _run_selftest(url)
        server.shutdown()
        return rc

    if not _wait_until_up(url):
        print("Error: the local server failed to start.", file=sys.stderr)
        return 1

    force_browser = os.environ.get("GETWORDS_NO_GUI") == "1"
    if not force_browser:
        try:
            import webview  # type: ignore

            webview.create_window(APP_TITLE, url, width=1040, height=780,
                                  min_size=(720, 560))
            webview.start()          # blocks until the window is closed
            server.shutdown()
            return 0
        except Exception as e:  # noqa: BLE001
            print(f"[desktop] Native window unavailable ({e}); "
                  "opening in your browser instead.", file=sys.stderr)

    # Browser fallback.
    print(f"{APP_TITLE} is running at {url}")
    try:
        webbrowser.open(url)
    except Exception:
        pass
    print("Leave this window open while you use the app. Press Ctrl+C to quit.")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        pass
    finally:
        server.shutdown()
    return 0


if __name__ == "__main__":
    sys.exit(main())
