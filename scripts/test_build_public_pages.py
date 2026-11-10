import json
from pathlib import Path
import tempfile
import unittest

from build_public_pages import package


class PublicPagesTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.manifest_path = self.root / 'approved.json'
        self.output = self.root / 'out'
        self.manifest = {
            'pages': {slug: f'{slug}.md' for slug in ('privacy', 'terms', 'support')},
        }
        for slug in self.manifest['pages']:
            (self.root / f'{slug}.md').write_text(f'# {slug}\n\nText <script>alert(1)</script>\n\n- Item\n')
        self.save()

    def save(self):
        self.manifest_path.write_text(json.dumps(self.manifest))

    def test_packages_all_routes_and_escapes_source(self):
        package(self.manifest_path, self.output)
        for slug in self.manifest['pages']:
            page = (self.output / slug / 'index.html').read_text()
            self.assertIn('&lt;script&gt;', page)
            self.assertNotIn('<script>', page)
            for destination in self.manifest['pages']:
                self.assertIn(f'href="/{destination}/"', page)
        self.assertTrue((self.output / 'index.html').exists())

    def test_missing_required_page_writes_nothing(self):
        del self.manifest['pages']['support']
        self.save()
        with self.assertRaises(KeyError):
            package(self.manifest_path, self.output)
        self.assertFalse(self.output.exists())

    def test_unresolved_content_writes_nothing(self):
        for marker in ['{{LEGAL_ENTITY}}', '[OWNER: confirm]', 'NOT APPROVED', '']:
            (self.root / 'support.md').write_text(marker)
            with self.assertRaises(ValueError):
                package(self.manifest_path, self.output)
            self.assertFalse(self.output.exists())

    def test_rejects_stale_output(self):
        self.output.mkdir()
        (self.output / 'stale.html').write_text('old policy')
        with self.assertRaises(ValueError):
            package(self.manifest_path, self.output)
        self.assertEqual((self.output / 'stale.html').read_text(), 'old policy')


if __name__ == '__main__':
    unittest.main()
