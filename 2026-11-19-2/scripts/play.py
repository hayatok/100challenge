"""Serve the packaged Web player. Use --lan to play it on a phone on the same Wi-Fi."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import socket

def main():
    args = argparse.ArgumentParser()
    args.add_argument("--lan", action="store_true", help="Listen on the PC's local network address")
    args.add_argument("--port", type=int, default=8198)
    args.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1] / "web-player")
    cfg = args.parse_args()
    root = cfg.root.resolve()
    if not (root / "index.html").is_file() or not (root / "Build").is_dir():
        args.error("The Web player is missing from " + str(root))
    host = "127.0.0.1"
    if cfg.lan:
        # UDP connect obtains the route's local address without sending game data.
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as route:
            route.connect(("192.0.2.1", 9))
            host = route.getsockname()[0]
    server = ThreadingHTTPServer((host, cfg.port), partial(SimpleHTTPRequestHandler, directory=str(root)))
    print(f"Open http://{host}:{cfg.port}/", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()

if __name__ == "__main__":
    main()
