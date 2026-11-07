#!/usr/bin/env python3
"""Verify readable card terms and separate attribution in the local shared preview.

Creates/deletes only a disposable QA account; never uses a saved user session.
Run: uv run --no-project --with playwright python scripts/opencard_smoke.py
"""
import json
import os
from pathlib import Path
import re
import secrets
import time
import urllib.error
import urllib.parse

from playwright.sync_api import sync_playwright, expect
from browser_smoke import enable_accessibility
from local_e2e import ROOT, load_env, request


def main():
    local, shared = load_env(ROOT / '.env.local'), load_env(ROOT / '.env.share')
    for key in ('SUPABASE_URL', 'REVOCRED_API_URL'):
        assert urllib.parse.urlparse(local[key]).hostname in ('localhost', '127.0.0.1'), 'Local stack only'
    for key in ('SUPABASE_URL', 'REVOCRED_API_URL', 'REVOCRED_AUTH_REDIRECT_URL'):
        url = urllib.parse.urlparse(shared[key])
        assert url.scheme == 'https' and (url.hostname or '').endswith('.trycloudflare.com'), 'Existing preview tunnels only'
    api, auth = local['REVOCRED_API_URL'], local['SUPABASE_URL']
    web = shared['REVOCRED_AUTH_REDIRECT_URL'].rstrip('/')
    public = {'apikey': local['SUPABASE_ANON_KEY']}
    email, password = f'card-details-smoke-{time.time_ns()}@example.test', secrets.token_urlsafe(28)
    request(auth + '/auth/v1/signup', 'POST', {'email': email, 'password': password}, public)
    _, session = request(auth + '/auth/v1/token?grant_type=password', 'POST', {'email': email, 'password': password}, public)
    headers = {'Authorization': 'Bearer ' + session['access_token']}
    screenshots = ROOT / '.local' / 'opencard-smoke'
    screenshots.mkdir(parents=True, exist_ok=True)
    verified, errors = [], []
    try:
        _, reply = request(api + '/v1/public/cards')
        catalog_before = {c['id']: c for c in reply['data']}
        cases = [
            ('discover', '20000000-0000-4000-8000-000000000021', 'Spending limit: $1,500 per quarter'),
            ('gold', '20000000-0000-4000-8000-000000000016', 'Spending limit: $25,000 per calendar year'),
            ('reserve', '20000000-0000-4000-8000-000000000013', 'IHG One Rewards Platinum Elite'),
        ]
        auth_host = urllib.parse.urlparse(shared['SUPABASE_URL']).hostname or ''
        key = 'sb-' + auth_host.split('.')[0] + '-auth-token'
        init = f'localStorage.setItem({json.dumps(key)}, {json.dumps(json.dumps(session))});'
        installed = list((Path.home() / '.cache/ms-playwright').glob('chromium-*/chrome-linux*/chrome'))
        native = max(installed, key=lambda p: int(p.parts[-3].split('-')[1])) if installed else Path('/snap/bin/chromium')
        with sync_playwright() as p:
            browser = p.chromium.launch(executable_path=os.environ.get('CHROMIUM_PATH', str(native)), headless=True, args=['--no-sandbox'])
            context = browser.new_context(viewport={'width': 390, 'height': 844}, is_mobile=True, has_touch=True)
            context.add_init_script(init)
            page = context.new_page()
            page.on('pageerror', lambda error: errors.append(str(error)))
            for name, card_id, expected_text in cases:
                _, added = request(api + '/v1/wallet', 'POST', {'catalog_card_id': card_id, 'nickname': '', 'status': 'active'}, headers)
                page.goto(web + '/#/cards')
                enable_accessibility(page)
                expect(page.get_by_text('Your card setup', exact=True)).to_be_attached(timeout=30000)
                # The shell reuses CardsScreen across visits; reload its real bootstrap.
                page.reload()
                enable_accessibility(page)
                expect(page.get_by_text(catalog_before[card_id]['name'], exact=True).first).to_be_attached(timeout=30000)
                page.get_by_text('Annual fee', exact=True).scroll_into_view_if_needed()
                page.wait_for_timeout(400)
                page.screenshot(path=str(screenshots / f'{name}-card-overview-mobile.png'))
                terms = page.get_by_text(expected_text, exact=False).first
                expect(terms).to_be_attached(timeout=15000)
                terms.scroll_into_view_if_needed()
                page.wait_for_timeout(400)
                page.screenshot(path=str(screenshots / f'{name}-readable-terms-mobile.png'))
                text = page.inner_text('body')
                assert 'OpenCard' not in text and 'CC BY' not in text, 'Provider branding leaked into card details'
                assert not re.search(r'map\[|[{}]|"(?:amount|currency|period)"|\b(?:true|false|null)\b', text), 'Technical field/code leaked into card details'
                assert 'Retrieved:' not in text and 'snapshot_sha256' not in text
                assert re.search(r'(checked|verified|reviewed)', text, re.I), 'Missing terms verification notice'
                expect(page.get_by_role('button', name=re.compile(r'^(View )?[Ii]ssuer terms$'))).to_be_attached()
                if name == 'discover':
                    assert 'activation required' in text.lower()
                if name == 'reserve':
                    assert 'The Edit' in text and 'two' in text.lower()
                    assert 'Enrollment required' in text or 'enrollment required' in text
                verified.append(name + ': readable conditions, no provider branding/code, date and issuer link retained')
                request(api + '/v1/wallet', 'DELETE', {'wallet_card_id': added['data']['id']}, headers)
            page.goto(web + '/#/legal')
            enable_accessibility(page)
            credits = page.get_by_role('group', name=re.compile(r'^Data credits Some card information'))
            # Legal is a lazy ListView; its offscreen children are not yet
            # represented in Flutter's accessibility tree.
            for _ in range(10):
                if credits.count():
                    break
                page.mouse.move(195, 500)
                page.mouse.wheel(0, 600)
                page.wait_for_timeout(250)
            expect(credits).to_be_attached(timeout=15000)
            credits.scroll_into_view_if_needed()
            expect(credits).to_have_accessible_name(re.compile(r'OpenCard DB.*CC BY 4\.0'))
            expect(page.get_by_role('button', name='Original card data', exact=True)).to_be_attached()
            expect(page.get_by_role('button', name='CC BY 4.0 license', exact=True)).to_be_attached()
            page.screenshot(path=str(screenshots / 'legal-data-credits-mobile.png'))
            assert not errors, 'Runtime errors: ' + '; '.join(errors)
            verified.append('Attribution, adaptation disclosure and license accessible in Legal')
            context.close()
            browser.close()
        _, reply = request(api + '/v1/public/cards')
        catalog_after = {c['id']: c for c in reply['data']}
        for _, card_id, _ in cases:
            for field in ('reward_rates', 'annual_fee_cents', 'benefits'):
                assert catalog_after[card_id][field] == catalog_before[card_id][field]
            for field in ('reward_rates', 'benefits', 'snapshot_sha256'):
                assert catalog_after[card_id]['community_data'][field] == catalog_before[card_id]['community_data'][field]
        verified.append('Source evidence and financial inputs unchanged')
        print('Card details browser smoke PASSED: ' + '; '.join(verified))
        (screenshots / 'result.json').write_text(json.dumps({'passed': True, 'verified': verified}, indent=2))
        print('Screenshots:', screenshots)
    finally:
        status, _ = request(api + '/v1/account', 'DELETE', headers=headers)
        assert status == 204, 'QA account cleanup failed'
        try:
            request(auth + '/auth/v1/user', headers={**headers, **public})
        except urllib.error.HTTPError as exc:
            assert exc.code in (401, 403, 404)
        else:
            raise AssertionError('QA user still exists after cleanup')
        print('Disposable QA account deletion verified.')


if __name__ == '__main__':
    main()
