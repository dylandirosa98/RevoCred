#!/usr/bin/env python3
"""Preview publishing must serve the current app, not cached bundle URLs."""
from functools import partial
import hashlib
from http.server import ThreadingHTTPServer
from io import BytesIO
import json
from pathlib import Path
import tempfile
from threading import Thread
import unittest
from unittest.mock import patch
import urllib.request

import share_preview


class PreviewResponse(BytesIO):
    status = 200

    def __init__(self, body, headers=None):
        super().__init__(body)
        self.headers = headers or {}


class PreviewBuildTests(unittest.TestCase):
    def test_readiness_requires_the_current_uncached_web_build_not_just_the_api(self):
        for served, cache, ready in (
            ('old', 'no-store, max-age=0', False),
            ('current', '', False),
            ('current', 'no-store, max-age=0', True),
        ):
            with self.subTest(served=served, cache=cache):
                api = PreviewResponse(b'{}')
                web = PreviewResponse(json.dumps({'build_id': served}).encode(), {'Cache-Control': cache})
                with patch('share_preview.urllib.request.urlopen', side_effect=[api, web]):
                    self.assertEqual(share_preview.preview_ready('current'), ready)

    def test_bundle_paths_are_versioned_by_actual_javascript_content(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / 'index.html').write_text('<script src="flutter_bootstrap.js" async></script>')
            (root / 'flutter_bootstrap.js').write_text('_flutter.buildConfig = {"builds":[{"mainJsPath":"main.dart.js"}]};')
            bundle = root / 'main.dart.js'
            bundle.write_text('window.rentFallback = true;')
            first = share_preview.prepare_preview_assets(root)
            self.assertEqual(first, hashlib.sha256(bundle.read_bytes()).hexdigest()[:16])
            self.assertIn(f'flutter_bootstrap.js?v={first}', (root / 'index.html').read_text())
            self.assertIn(f'main.dart.js?v={first}', (root / 'flutter_bootstrap.js').read_text())
            self.assertEqual(share_preview.prepare_preview_assets(root), first)
            bundle.write_text('window.rentFallback = true; window.revision = 2;')
            second = share_preview.prepare_preview_assets(root)
            self.assertNotEqual(first, second)
            self.assertNotIn(f'?v={first}', (root / 'index.html').read_text())
            self.assertIn(f'main.dart.js?v={second}', (root / 'flutter_bootstrap.js').read_text())
            self.assertEqual(json.loads((root / 'preview-build.json').read_text())['build_id'], second)

    def test_unknown_bootstrap_shape_is_not_silently_published(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            html = '<script src="flutter_bootstrap.js" async></script>'
            (root / 'index.html').write_text(html)
            (root / 'flutter_bootstrap.js').write_text('unexpected loader config')
            (root / 'main.dart.js').write_text('test build')
            with self.assertRaises(ValueError):
                share_preview.prepare_preview_assets(root)
            self.assertEqual((root / 'index.html').read_text(), html)

    def test_preview_responses_prevent_browser_and_proxy_caching(self):
        from preview_server import PreviewRequestHandler
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / 'index.html').write_text('fresh preview')
            handler = partial(PreviewRequestHandler, directory=d)
            server = ThreadingHTTPServer(('127.0.0.1', 0), handler)
            thread = Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                url = f'http://127.0.0.1:{server.server_port}/'
                for method in ('GET', 'HEAD'):
                    with urllib.request.urlopen(urllib.request.Request(url, method=method), timeout=5) as r:
                        self.assertIn('no-store', r.headers['Cache-Control'])
                        self.assertEqual(r.headers['Pragma'], 'no-cache')
                        self.assertEqual(r.headers['Expires'], '0')
            finally:
                server.shutdown()
                server.server_close()
                thread.join(timeout=5)


if __name__ == '__main__':
    unittest.main()
