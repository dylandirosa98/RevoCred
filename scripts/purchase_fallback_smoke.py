#!/usr/bin/env python3
"""Verify deterministic base fallbacks with a disposable local two-card wallet."""
import json
import os
from pathlib import Path
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
        assert urllib.parse.urlparse(local[key]).hostname in ('localhost', '127.0.0.1')
    for key in ('SUPABASE_URL', 'REVOCRED_API_URL', 'REVOCRED_AUTH_REDIRECT_URL'):
        parsed = urllib.parse.urlparse(shared[key])
        assert parsed.scheme == 'https' and (parsed.hostname or '').endswith('.trycloudflare.com')
    api, auth = local['REVOCRED_API_URL'], local['SUPABASE_URL']
    web = shared['REVOCRED_AUTH_REDIRECT_URL'].rstrip('/')
    public = {'apikey': local['SUPABASE_ANON_KEY']}
    email, password = f'purchase-fallback-{time.time_ns()}@example.test', secrets.token_urlsafe(28)
    request(auth + '/auth/v1/signup', 'POST', {'email': email, 'password': password}, public)
    _, session = request(auth + '/auth/v1/token?grant_type=password', 'POST', {'email': email, 'password': password}, public)
    headers = {'Authorization': 'Bearer ' + session['access_token']}
    out = ROOT / '.local/purchase-fallback-smoke'
    out.mkdir(parents=True, exist_ok=True)
    double, discover = '20000000-0000-4000-8000-000000000018', '20000000-0000-4000-8000-000000000021'
    verified, errors = [], []
    try:
        added = {}
        for card_id in (discover, double):
            _, result = request(api + '/v1/wallet', 'POST', {'catalog_card_id': card_id, 'nickname': '', 'status': 'active'}, headers)
            added[card_id] = result['data']['id']
        _, before = request(api + '/v1/bootstrap', headers=headers)

        def guide(caps):
            _, result = request(shared['REVOCRED_API_URL'] + '/v1/purchase-guide?travel_mode=general&caps_available=' + caps, headers=headers)
            return {c['id']: c for c in result['data']['categories']}

        for caps in ('true', 'false'):
            categories = guide(caps)
            assert len(categories) == 16
            for name, category in categories.items():
                if name == 'rent':
                    assert not category['options'], 'Unconfirmed rent must not become a supported earning rule'
                    assert [(o['card_id'], o['rate']) for o in category['fallback_options']] == [(double, 2), (discover, 1)]
                    assert 'fees' in category['fallback_options'][0]['reason']
                    assert 'unconfirmed' in category['assumptions']
                else:
                    assert category['options'][0]['card_id'] == double and category['options'][0]['rate'] == 2
                    assert not category['fallback_options']
        verified += ['All 16 categories: ordinary purchases use Double Cash 2%; rent shows conditional base 2% before fees', 'Cap settings do not invent activation or rent eligibility']
        _, after = request(api + '/v1/bootstrap', headers=headers)
        assert before['data']['wallet_metrics'] == after['data']['wallet_metrics'], 'Purchase guide changed wallet metrics'
        _, build = request(web + '/preview-build.json')
        fresh_url = web + '/?v=' + build['build_id'] + '#/home'
        host = urllib.parse.urlparse(shared['SUPABASE_URL']).hostname or ''
        key = 'sb-' + host.split('.')[0] + '-auth-token'
        init = f'localStorage.setItem({json.dumps(key)}, {json.dumps(json.dumps(session))});'
        installed = list((Path.home() / '.cache/ms-playwright').glob('chromium-*/chrome-linux*/chrome'))
        chromium = max(installed, key=lambda p: int(p.parts[-3].split('-')[1]))
        with sync_playwright() as p:
            browser = p.chromium.launch(executable_path=os.environ.get('CHROMIUM_PATH', str(chromium)), headless=True, args=['--no-sandbox'])
            context = browser.new_context(viewport={'width': 390, 'height': 844}, is_mobile=True, has_touch=True)
            context.add_init_script(init)
            page = context.new_page()
            bundles = []
            page.on('request', lambda r: bundles.append(r.url) if 'main.dart.js' in r.url else None)
            page.on('pageerror', lambda e: errors.append(str(e)))

            def open_rent():
                expect(page.get_by_text('Make the next swipe count.', exact=True)).to_be_attached(timeout=30000)
                page.get_by_text('More categories', exact=True).click()
                page.get_by_text('Rent', exact=True).click()
                expect(page.get_by_text('Base-rate option for Rent', exact=True)).to_be_attached()
                expect(page.get_by_text('Best cards for Rent', exact=True)).to_have_count(0)
                expect(page.get_by_text('No supported earning rule', exact=False)).to_have_count(0)

            page.goto(fresh_url)
            enable_accessibility(page)
            open_rent()
            assert any(urllib.parse.parse_qs(urllib.parse.urlparse(url).query).get('v') == [build['build_id']] for url in bundles), 'Browser did not load the versioned current bundle'
            verified.append('Fresh public build URL loads the content-versioned app bundle')
            expect(page.get_by_role('img', name='Double Cash, stylized card illustration', exact=True)).to_be_attached()
            expect(page.get_by_text('2% cash back before fees · Rent', exact=True)).to_be_attached()
            expect(page.get_by_text('Rent must qualify as a purchase. Check payment fees first.', exact=True)).to_be_attached()
            page.screenshot(path=str(out / 'rent-use-now-mobile.png'))
            page.get_by_role('button', name='Compare & options', exact=True).click()
            expect(page.get_by_label('Conditional Double Cash', exact=True)).to_be_attached()
            expect(page.get_by_text('1. Double Cash', exact=True)).to_have_count(0)
            expect(page.get_by_text('No supported earning rule', exact=False)).to_have_count(0)
            page.screenshot(path=str(out / 'rent-comparison-mobile.png'))
            request(api + '/v1/wallet', 'DELETE', {'wallet_card_id': added[double]}, headers)
            assert guide('true')['rent']['fallback_options'][0]['card_id'] == discover
            page.reload()
            enable_accessibility(page)
            open_rent()
            expect(page.get_by_role('img', name='Discover it Cash Back, stylized card illustration', exact=True)).to_be_attached()
            expect(page.get_by_text('1% cash back before fees · Rent', exact=True)).to_be_attached()
            page.screenshot(path=str(out / 'rent-after-wallet-removal-mobile.png'))
            assert not errors, errors
            verified += ['Mobile Home shows the card and short note with no comparison popup', 'Optional comparison labels the fallback conditional, not confirmed rent rewards', 'Removing Double Cash updates fallback to Discover 1%', 'No runtime errors; wallet score and yearly value unchanged by comparison']
            context.close()
            browser.close()
        (out / 'result.json').write_text(json.dumps({'passed': True, 'verified': verified}, indent=2))
        print('Purchase fallback browser smoke PASSED: ' + '; '.join(verified))
        print('Screenshots:', out)
    finally:
        status, _ = request(api + '/v1/account', 'DELETE', headers=headers)
        assert status == 204
        try:
            request(auth + '/auth/v1/user', headers={**public, **headers})
        except urllib.error.HTTPError as e:
            assert e.code in (401, 403, 404)
        else:
            raise AssertionError('QA user still exists')
        print('Disposable QA account deletion verified.')


if __name__ == '__main__':
    main()
