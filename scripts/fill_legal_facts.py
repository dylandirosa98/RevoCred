#!/usr/bin/env python3
"""Fill the owner placeholders in the public legal pages, then sync the API copy.

    python3 scripts/fill_legal_facts.py \
        --company "RevoCred LLC" --address "123 Main St, City, ST 00000" \
        --effective-date "December 1, 2026" --governing-state "New Jersey"

Refuses to run with an empty value or when a placeholder would be left behind.
Prints the matching iOS release-config values; it never edits .env.ios.json.
"""
import argparse
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
LEGAL = ROOT / 'docs/legal'
API_CONTENT = ROOT / 'revocred-api/internal/legal/content'
PAGES = ('privacy-policy.md', 'terms-of-use.md', 'support.md')
PLACEHOLDERS = {
    '[[COMPANY LEGAL NAME]]': 'company',
    '[[MAILING ADDRESS]]': 'address',
    '[[EFFECTIVE DATE]]': 'effective_date',
    '[[GOVERNING LAW STATE]]': 'governing_state',
}


def fill(text, facts):
    for placeholder, key in PLACEHOLDERS.items():
        text = text.replace(placeholder, facts[key])
    if '[[' in text:
        raise ValueError('An unknown [[placeholder]] remains; fill it by hand first.')
    return text


def main(argv=None, legal=LEGAL, api_content=API_CONTENT):
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--company', required=True, help='Legal entity; must match the Apple seller')
    parser.add_argument('--address', required=True, help='Postal address for legal notices')
    parser.add_argument('--effective-date', required=True, help='e.g. "December 1, 2026"')
    parser.add_argument('--governing-state', required=True, help='US state, e.g. "New Jersey"')
    args = parser.parse_args(argv)
    facts = {key: str(getattr(args, key)).strip() for key in PLACEHOLDERS.values()}
    empty = [key for key, value in facts.items() if not value or '[[' in value or ']]' in value]
    if empty:
        print('Every fact needs a real value: ' + ', '.join(sorted(empty)))
        return 1
    try:
        filled = {name: fill((legal / name).read_text(), facts) for name in PAGES}
    except (OSError, ValueError) as error:
        print(str(error))
        return 1
    for name, text in filled.items():
        (legal / name).write_text(text)
        shutil.copyfile(legal / name, api_content / name)
    print('Filled ' + ', '.join(PAGES) + ' and synced the API copy. Review the diff, commit and deploy the API.')
    print('Matching iOS release config values:')
    print('  REVOCRED_LEGAL_ENTITY=' + facts['company'])
    print('  REVOCRED_LEGAL_JURISDICTION=' + facts['governing_state'] + ', United States')
    print('  REVOCRED_LEGAL_EFFECTIVE_DATE=' + facts['effective_date'])
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
