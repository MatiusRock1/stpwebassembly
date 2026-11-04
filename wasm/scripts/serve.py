"""Serve the packaged game on localhost with the headers of the public site.

This build needs no threads, so the page does not depend on COOP/COEP; they are
sent anyway because the site that hosts the game sets them on every response,
and they change what a page may load. Adapted from stkwebassembly.

  python wasm/scripts/serve.py <work>/web [--port 8093] [--host 0.0.0.0]

--host 0.0.0.0 lets a phone on the same network open http://<this computer>:8093/.
Only for testing: the player then has no Cache Storage, which needs HTTPS.
"""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class IsolatedHandler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map,
                      '.wasm': 'application/wasm', '.mjs': 'text/javascript', '.js': 'text/javascript',
                      '.pck': 'application/octet-stream'}

    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cross-Origin-Resource-Policy', 'same-origin')
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('directory', type=Path, help='output directory of wasm/package.py')
    parser.add_argument('--port', type=int, default=8093)
    parser.add_argument('--host', default='127.0.0.1')
    args = parser.parse_args()
    directory = args.directory.resolve()
    handler = partial(IsolatedHandler, directory=str(directory))
    print(f'Serving {directory} on http://localhost:{args.port}/index.html', flush=True)
    ThreadingHTTPServer((args.host, args.port), handler).serve_forever()


if __name__ == '__main__':
    main()
