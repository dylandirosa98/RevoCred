#!/usr/bin/env python3
"""Loopback-only static server for disposable preview builds, never production."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


class PreviewRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('port', type=int)
    parser.add_argument('--bind', choices=('127.0.0.1', 'localhost'), default='127.0.0.1')
    parser.add_argument('--directory', required=True)
    args = parser.parse_args()
    handler = partial(PreviewRequestHandler, directory=args.directory)
    with ThreadingHTTPServer((args.bind, args.port), handler) as server:
        server.serve_forever()


if __name__ == '__main__':
    main()
