from pathlib import Path
import tempfile
import unittest

import fill_legal_facts

FACTS = ['--company', 'Example Co LLC', '--address', '1 Main St, Town, NJ 08000',
         '--effective-date', 'December 1, 2026', '--governing-state', 'New Jersey']


class FillLegalFactsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        self.legal, self.api = base / 'legal', base / 'api'
        self.legal.mkdir()
        self.api.mkdir()
        for name in fill_legal_facts.PAGES:
            (self.legal / name).write_text(
                'Effective date: [[EFFECTIVE DATE]]\n[[COMPANY LEGAL NAME]], [[MAILING ADDRESS]]\n'
                'Laws of [[GOVERNING LAW STATE]].\n')

    def tearDown(self):
        self.tmp.cleanup()

    def test_fills_every_page_and_syncs_api_copy(self):
        self.assertEqual(fill_legal_facts.main(FACTS, self.legal, self.api), 0)
        for name in fill_legal_facts.PAGES:
            text = (self.legal / name).read_text()
            self.assertNotIn('[[', text)
            self.assertIn('Example Co LLC, 1 Main St, Town, NJ 08000', text)
            self.assertEqual((self.api / name).read_text(), text)

    def test_rejects_empty_values_without_writing(self):
        args = list(FACTS)
        args[1] = '  '
        before = (self.legal / 'support.md').read_text()
        self.assertEqual(fill_legal_facts.main(args, self.legal, self.api), 1)
        self.assertEqual((self.legal / 'support.md').read_text(), before)
        self.assertFalse((self.api / 'support.md').exists())

    def test_unknown_placeholder_stops_before_any_write(self):
        (self.legal / 'terms-of-use.md').write_text('[[SOMETHING NEW]]\n')
        before = (self.legal / 'privacy-policy.md').read_text()
        self.assertEqual(fill_legal_facts.main(FACTS, self.legal, self.api), 1)
        self.assertEqual((self.legal / 'privacy-policy.md').read_text(), before)

    def test_real_pages_have_only_known_placeholders(self):
        for name in fill_legal_facts.PAGES:
            text = (fill_legal_facts.LEGAL / name).read_text()
            for placeholder in fill_legal_facts.PLACEHOLDERS:
                text = text.replace(placeholder, 'x')
            self.assertNotIn('[[', text, name)


if __name__ == '__main__':
    unittest.main()
