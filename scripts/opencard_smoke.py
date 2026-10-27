#!/usr/bin/env python3
"""Real OpenCard UI smoke on the local stack and its own share tunnels.

Creates a disposable local QA account via Auth API, seeds only that account's
session in an isolated browser, then deletes it. Never uses saved user logins.
Run: uv run --no-project --with playwright python scripts/opencard_smoke.py
"""
import json
import os
import secrets
import time
import urllib.error
import urllib.parse
from pathlib import Path

from playwright.sync_api import sync_playwright, expect
from browser_smoke import enable_accessibility
from local_e2e import ROOT, load_env, request


def main():
    local = load_env(ROOT / '.env.local')
    shared = load_env(ROOT / '.env.share')
    for key in ('SUPABASE_URL', 'REVOCRED_API_URL'):
        if urllib.parse.urlparse(local[key]).hostname not in ('localhost', '127.0.0.1'):
            raise SystemExit('OpenCard smoke requires the loopback test stack')
    # Public endpoints must be the existing quick tunnels to this local stack.
    for key in ('SUPABASE_URL', 'REVOCRED_API_URL', 'REVOCRED_AUTH_REDIRECT_URL'):
        url = urllib.parse.urlparse(shared[key])
        if url.scheme != 'https' or not (url.hostname or '').endswith('.trycloudflare.com'):
            raise SystemExit('Unexpected shared test endpoint')
    api, auth = local['REVOCRED_API_URL'], local['SUPABASE_URL']
    web = shared['REVOCRED_AUTH_REDIRECT_URL']
    public = {'apikey': local['SUPABASE_ANON_KEY']}
    email = f'opencard-smoke-{time.time_ns()}@example.test'
    password = secrets.token_urlsafe(28)
    request(auth + '/auth/v1/signup', 'POST', {'email': email, 'password': password}, public)
    _, session = request(auth + '/auth/v1/token?grant_type=password', 'POST', {'email': email, 'password': password}, public)
    headers = {'Authorization': 'Bearer ' + session['access_token']}
    errors = []
    screenshots = ROOT / '.local' / 'opencard-smoke'
    screenshots.mkdir(parents=True, exist_ok=True)
    try:
        request(api + '/v1/wallet', 'POST', {'catalog_card_id': '20000000-0000-4000-8000-000000000013', 'nickname': '', 'status': 'active'}, headers)
        request(api + '/v1/recommendations', 'POST', {
            'monthly_category_spend': {'food': 60000, 'travel': 20000, 'everyday': 40000},
            'fee_tolerance_cents': 100000, 'travel_scope': 'both',
            'rewards_goal': 'travel', 'credit_tier': 'good',
            'existing_card_ids': ['20000000-0000-4000-8000-000000000013'],
        }, headers)
        _, response = request(shared['REVOCRED_API_URL'] + '/v1/bootstrap', headers=headers)
        wallet = response['data']['wallet']
        assert len(wallet) == 1 and len(wallet[0]['card']['community_data']['benefits']) >= 9
        auth_host = urllib.parse.urlparse(shared['SUPABASE_URL']).hostname or ''
        key = 'sb-' + auth_host.split('.')[0] + '-auth-token'
        # supabase_flutter 2.17 uses raw web localStorage, not the older
        # SharedPreferences flutter.* prefix / double-encoded session format.
        init = f'localStorage.setItem({json.dumps(key)}, {json.dumps(json.dumps(session))});'
        installed = list((Path.home() / '.cache/ms-playwright').glob('chromium-*/chrome-linux*/chrome'))
        native = max(installed, key=lambda path: int(path.parts[-3].split('-')[1])) if installed else Path('/snap/bin/chromium')
        with sync_playwright() as p:
            browser = p.chromium.launch(executable_path=os.environ.get('CHROMIUM_PATH', str(native)), headless=True, args=['--no-sandbox'])
            context = browser.new_context(viewport={'width': 390, 'height': 844}, is_mobile=True, has_touch=True)
            context.add_init_script(init)
            page = context.new_page()
            page.on('pageerror', lambda error: errors.append(str(error)))
            page.goto(web + '/#/cards')
            enable_accessibility(page)
            expect(page).to_have_url(web + '/#/cards', timeout=30000)
            attribution = page.get_by_text('OpenCard DB · CC BY 4.0 · adapted for display', exact=True)
            expect(attribution).to_be_attached(timeout=30000)
            attribution.scroll_into_view_if_needed()
            page.wait_for_timeout(700)
            page.screenshot(path=str(screenshots / 'source-and-rewards-mobile.png'))
            benefit = page.get_by_text('The Edit hotel statement credits', exact=False)
            expect(benefit).to_be_attached(timeout=10000)
            benefit.scroll_into_view_if_needed()
            page.wait_for_timeout(500)
            page.screenshot(path=str(screenshots / 'reserve-benefits-mobile.png'))
            text = page.inner_text('body')
            assert 'Ultimate Rewards points' in text and 'Source last verified:' in text
            assert '8x' in text and 'Community-maintained snapshot' in text
            assert 'Additional benefits from source'.upper() in text
            assert not errors, 'Browser runtime errors: ' + '; '.join(errors)
            context.close()
            browser.close()
        print('OpenCard browser smoke passed: public tunnel, authenticated wallet, mobile viewport, earning rules, expanded Reserve benefits, attribution, dates, no runtime errors.')
        print('Screenshots:', screenshots)
    finally:
        status, _ = request(api + '/v1/account', 'DELETE', headers=headers)
        assert status == 204, 'QA account cleanup failed'
        try:
            request(auth + '/auth/v1/user', headers={**headers, **public})
        except urllib.error.HTTPError as exc:
            assert exc.code in (401, 403, 404), 'unexpected cleanup verification error'
        else:
            raise AssertionError('QA user still exists after cleanup')
        print('Disposable QA account deletion verified.')


if __name__ == '__main__':
    main()
