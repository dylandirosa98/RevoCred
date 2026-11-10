"""Package completed policy/support Markdown as a buildless static site.

No network access or deployment. Only headings, paragraphs and bullet lists are
rendered; all source text is escaped. This command never publishes pages.
"""
import argparse
import html
import json
from pathlib import Path
import re

PAGES = {'privacy': 'Privacy policy', 'terms': 'Terms of use', 'support': 'Support'}
UNRESOLVED = re.compile(r'\{\{|\[OWNER\b|\[CONFIRM\b|NOT APPROVED|NOT PUBLISHED|DO NOT SUBMIT', re.I)
STYLE = '''body{font:18px/1.65 system-ui,sans-serif;max-width:760px;margin:auto;padding:24px;color:#172a31;background:#fafcfb}a{color:#086353}nav{display:flex;gap:24px;flex-wrap:wrap}h1,h2,h3{line-height:1.25}main{padding:24px 0}footer{border-top:1px solid #bdccc7;padding-top:16px}'''


def render_markdown(source):
    output, paragraph = [], []
    in_list = False

    def flush():
        if paragraph:
            output.append('<p>' + html.escape(' '.join(paragraph)) + '</p>')
            paragraph.clear()

    for line in source.splitlines() + ['']:
        heading = re.match(r'^(#{1,3})\s+(.+)$', line)
        bullet = line.startswith('- ')
        if not line.strip() or heading or bullet:
            flush()
            if in_list and not bullet:
                output.append('</ul>')
                in_list = False
            if heading:
                level = len(heading[1])
                output.append(f'<h{level}>{html.escape(heading[2])}</h{level}>')
            elif bullet:
                if not in_list:
                    output.append('<ul>')
                    in_list = True
                output.append('<li>' + html.escape(line[2:]) + '</li>')
        else:
            paragraph.append(line.strip())
    return '\n'.join(output)


def package(manifest_path, output):
    manifest = json.loads(manifest_path.read_text())
    pages = {}
    for slug in PAGES:
        path = manifest_path.parent / manifest['pages'][slug]
        content = path.read_text()
        if not content.strip() or UNRESOLVED.search(content):
            raise ValueError(f'{slug}: empty content or unresolved draft markers; nothing generated.')
        pages[slug] = render_markdown(content)
    # Validate everything before creating output. Keep a clean destination so stale
    # artifacts cannot be mistaken for current approved pages.
    if output.exists() and any(output.iterdir()):
        raise ValueError('Output must be absent or empty; choose a fresh output directory.')
    navigation = '<nav aria-label="Policies and help">' + ''.join(
        f'<a href="/{slug}/">{title}</a>' for slug, title in PAGES.items()) + '</nav>'
    for slug, body in {**pages, '': '<h1>RevoCred policies and support</h1>'}.items():
        title = PAGES.get(slug, 'Policies and support')
        document = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>RevoCred — {title}</title><style>{STYLE}</style></head><body><header>RevoCred{navigation}</header><main>{body}</main><footer>{navigation}</footer></body></html>'''
        destination = output / slug / 'index.html'
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(document)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        package(args.manifest.resolve(), args.output.resolve())
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, f'Public-page packaging blocked: {error}\n')
    print(f'Packaged public pages at {args.output}; no deployment performed.')


if __name__ == '__main__':
    main()
