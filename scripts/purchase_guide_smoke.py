#!/usr/bin/env python3
"""Exercise the real authenticated Home category guide using only disposable local QA data."""
import json
import os
import re
import secrets
import time
import urllib.error
import urllib.parse
from pathlib import Path
from playwright.sync_api import sync_playwright, expect
from browser_smoke import enable_accessibility
from local_e2e import ROOT, load_env, request


def main():
    local, shared = load_env(ROOT / '.env.local'), load_env(ROOT / '.env.share')
    for key in ('SUPABASE_URL', 'REVOCRED_API_URL'):
        assert urllib.parse.urlparse(local[key]).hostname in ('127.0.0.1', 'localhost'), 'Local stack only'
    for key in ('SUPABASE_URL', 'REVOCRED_API_URL', 'REVOCRED_AUTH_REDIRECT_URL'):
        parsed = urllib.parse.urlparse(shared[key])
        assert parsed.scheme == 'https' and (parsed.hostname or '').endswith('.trycloudflare.com')
    api, auth, web = local['REVOCRED_API_URL'], local['SUPABASE_URL'], shared['REVOCRED_AUTH_REDIRECT_URL']
    public = {'apikey': local['SUPABASE_ANON_KEY']}
    email, password = f'purchase-guide-smoke-{time.time_ns()}@example.test', secrets.token_urlsafe(28)
    request(auth + '/auth/v1/signup', 'POST', {'email': email, 'password': password}, public)
    _, session = request(auth + '/auth/v1/token?grant_type=password', 'POST', {'email': email, 'password': password}, public)
    headers = {'Authorization': 'Bearer ' + session['access_token']}
    ids = {'gold': '20000000-0000-4000-8000-000000000016', 'reserve': '20000000-0000-4000-8000-000000000013', 'quick': '20000000-0000-4000-8000-000000000008', 'platinum': '20000000-0000-4000-8000-000000000017'}
    screenshots = ROOT / '.local/purchase-guide-smoke'
    screenshots.mkdir(parents=True, exist_ok=True)
    errors, verified = [], []
    try:
        for name in ('gold', 'reserve', 'quick'):
            request(api + '/v1/wallet', 'POST', {'catalog_card_id': ids[name], 'nickname': '', 'status': 'active'}, headers)
        request(api + '/v1/recommendations', 'POST', {
            'monthly_category_spend': {'food': 60000, 'travel': 20000, 'everyday': 40000},
            'fee_tolerance_cents': 100000, 'travel_scope': 'both', 'rewards_goal': 'travel', 'credit_tier': 'good',
            'existing_card_ids': [ids[x] for x in ('gold', 'reserve', 'quick')],
        }, headers)

        def guide(query=''):
            _, reply = request(shared['REVOCRED_API_URL'] + '/v1/purchase-guide' + query, headers=headers)
            return {c['id']: c for c in reply['data']['categories']}

        current = guide()
        assert len(current) == 16
        expected = {'online-shopping': ('quick', 1.5), 'groceries': ('gold', 4), 'dining': ('gold', 4)}
        for category, (name, rate) in expected.items():
            assert current[category]['options'][0]['card_id'] == ids[name] and current[category]['options'][0]['rate'] == rate
            verified.append(f'{category}: {name} at {rate}')
        assert not current['rent']['options']
        assert all(o['card_id'] in {ids['gold'], ids['reserve'], ids['quick']} for c in current.values() for o in c['options'])
        assert guide('?travel_mode=chase-portal')['travel']['options'][0]['rate'] == 8
        assert guide('?travel_mode=flights-direct')['travel']['options'][0]['rate'] == 4
        assert guide('?caps_available=false')['groceries']['options'][0]['card_id'] == ids['quick']
        _, bootstrap = request(shared['REVOCRED_API_URL'] + '/v1/bootstrap', headers=headers)
        assert len(bootstrap['data']['purchase_guide']['categories']) == 16
        key = 'sb-' + (urllib.parse.urlparse(shared['SUPABASE_URL']).hostname or '').split('.')[0] + '-auth-token'
        init = f'localStorage.setItem({json.dumps(key)}, {json.dumps(json.dumps(session))});'
        installed = list((Path.home() / '.cache/ms-playwright').glob('chromium-*/chrome-linux*/chrome'))
        native = max(installed, key=lambda p: int(p.parts[-3].split('-')[1])) if installed else Path('/snap/bin/chromium')
        with sync_playwright() as p:
            browser = p.chromium.launch(executable_path=os.environ.get('CHROMIUM_PATH', str(native)), headless=True, args=['--no-sandbox'])
            context = browser.new_context(viewport={'width': 390, 'height': 844}, is_mobile=True, has_touch=True)
            context.add_init_script(init)
            page = context.new_page()
            page.on('pageerror', lambda error: errors.append(str(error)))
            page.goto(web + '/#/home')
            enable_accessibility(page)
            expect(page.get_by_text('Make the next swipe count.', exact=True)).to_be_attached(timeout=30000)
            page.get_by_text('Online shopping', exact=True).click()
            expect(page.get_by_label('1. Quicksilver', exact=True)).to_be_attached(timeout=15000)
            expect(page.get_by_text('1.5% cash back', exact=False)).to_be_attached()
            assert page.get_by_text('Venture X', exact=False).count() == 0, 'unowned card in comparison'
            page.get_by_label('1. Quicksilver', exact=True).scroll_into_view_if_needed()
            page.screenshot(path=str(screenshots / 'online-shopping-wallet-comparison.png'))
            page.mouse.click(8, 8)
            expect(page.get_by_text('Best known for Online shopping', exact=True)).to_be_attached()
            page.get_by_text('Best known for Online shopping', exact=True).scroll_into_view_if_needed()
            page.screenshot(path=str(screenshots / 'online-shopping-home.png'))
            page.get_by_text('Groceries', exact=True).click()
            expect(page.get_by_label('1. Amex Gold', exact=True)).to_be_attached()
            page.get_by_role('checkbox', name=re.compile('Spending caps still available')).click()
            page.wait_for_timeout(1200)
            page.mouse.move(195, 400)
            page.mouse.wheel(0, -1200)
            page.wait_for_timeout(400)
            page.screenshot(path=str(screenshots / 'groceries-cap-exhausted.png'))
            expect(page.get_by_label('1. Quicksilver', exact=True)).to_be_attached(timeout=15000)
            page.mouse.click(8, 8)
            page.get_by_text('Dining', exact=True).click()
            expect(page.get_by_label('1. Amex Gold', exact=True)).to_be_attached()
            expect(page.get_by_role('checkbox', name=re.compile('Spending caps still available'))).to_be_checked()
            page.mouse.click(8, 8)
            page.get_by_text('Travel', exact=True).click()
            page.get_by_role('button', name=re.compile('How are you booking')).click()
            page.wait_for_timeout(400)
            mode_ids = [m['id'] for m in bootstrap['data']['purchase_guide']['travel_modes']]
            for _ in range(mode_ids.index('chase-portal') - mode_ids.index('general')):
                page.keyboard.press('ArrowDown')
            page.keyboard.press('Enter')
            page.wait_for_timeout(800)
            page.screenshot(path=str(screenshots / 'travel-context-selected.png'))
            try:
                expect(page.get_by_label('1. Sapphire Reserve', exact=True)).to_be_attached(timeout=10000)
            except AssertionError:
                retry = page.get_by_role('button', name='Retry comparison', exact=True)
                if not retry.is_visible():
                    raise
                retry.click()
                expect(page.get_by_label('1. Sapphire Reserve', exact=True)).to_be_attached(timeout=15000)
            expect(page.get_by_text('8x Ultimate Rewards points', exact=False)).to_be_attached()
            page.get_by_label('1. Sapphire Reserve', exact=True).scroll_into_view_if_needed()
            page.screenshot(path=str(screenshots / 'chase-portal-comparison.png'))
            page.mouse.click(8, 8)
            # A wallet mutation must change the server comparison; no stale catalog fallback.
            _, added = request(api + '/v1/wallet', 'POST', {'catalog_card_id': ids['platinum'], 'nickname': '', 'status': 'active'}, headers)
            assert guide('?travel_mode=flights-direct')['travel']['options'][0]['card_id'] == ids['platinum']
            request(api + '/v1/wallet', 'DELETE', {'wallet_card_id': added['data']['id']}, headers)
            assert guide('?travel_mode=flights-direct')['travel']['options'][0]['card_id'] == ids['reserve']
            assert not errors, 'Runtime errors: ' + '; '.join(errors)
            context.close()
            browser.close()
        verified += ['16 categories covered; rent not guessed', 'owned cards only', 'portal/direct distinction', 'cap toggle reranks', 'wallet add/remove reranks', 'mobile UI and no runtime errors']
        print('Purchase guide live smoke PASSED: ' + '; '.join(verified))
        print('Screenshots:', screenshots)
        (screenshots / 'result.json').write_text(json.dumps({'passed': True, 'verified': verified}, indent=2))
    finally:
        status, _ = request(api + '/v1/account', 'DELETE', headers=headers)
        assert status == 204
        try:
            request(auth + '/auth/v1/user', headers={**headers, **public})
        except urllib.error.HTTPError as exc:
            assert exc.code in (401, 403, 404)
        else:
            raise AssertionError('QA user still exists')
        print('Disposable local QA account deletion verified.')

if __name__ == '__main__':
    main()
