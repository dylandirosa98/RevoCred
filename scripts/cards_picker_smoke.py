#!/usr/bin/env python3
"""Exercise both Cards add entry points and plan-first search on local QA data."""
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
    email, password = f'cards-picker-{time.time_ns()}@example.test', secrets.token_urlsafe(28)
    request(auth + '/auth/v1/signup', 'POST', {'email': email, 'password': password}, public)
    _, session = request(auth + '/auth/v1/token?grant_type=password', 'POST', {'email': email, 'password': password}, public)
    headers = {'Authorization': 'Bearer ' + session['access_token']}
    out = ROOT / '.local/cards-picker-smoke'
    out.mkdir(parents=True, exist_ok=True)
    errors, verified = [], []
    try:
        owned = {'20000000-0000-4000-8000-000000000011', '20000000-0000-4000-8000-000000000021'}
        for card_id in owned:
            request(api + '/v1/wallet', 'POST', {'catalog_card_id': card_id, 'nickname': '', 'status': 'active'}, headers)
        request(api + '/v1/recommendations', 'POST', {
            'monthly_category_spend': {'food': 60000, 'travel': 20000, 'everyday': 40000},
            'fee_tolerance_cents': 100000, 'travel_scope': 'both',
            'rewards_goal': 'travel', 'credit_tier': 'excellent',
            'existing_card_ids': [],
        }, headers)
        request(api + '/v1/strategy', 'PUT', {'strategy_code': 'S04'}, headers)
        _, response = request(api + '/v1/bootstrap', headers=headers)
        data = response['data']
        step = next(s for s in data['playbook']['steps'] if s['status'] == 'next')
        next_name = step['name']
        next_card = next(c for c in data['catalog'] if c['name'] == next_name)
        assert next_card['id'] not in owned
        other_name = next(c['name'] for c in data['catalog'] if c['id'] not in owned and c['id'] != next_card['id'])
        auth_host = urllib.parse.urlparse(shared['SUPABASE_URL']).hostname or ''
        assert auth_host
        key = 'sb-' + auth_host.split('.')[0] + '-auth-token'
        init = f'localStorage.setItem({json.dumps(key)}, {json.dumps(json.dumps(session))});'
        installed = list((Path.home() / '.cache/ms-playwright').glob('chromium-*/chrome-linux*/chrome'))
        chromium = max(installed, key=lambda p: int(p.parts[-3].split('-')[1]))
        with sync_playwright() as p:
            browser = p.chromium.launch(executable_path=os.environ.get('CHROMIUM_PATH', str(chromium)), headless=True, args=['--no-sandbox'])
            context = browser.new_context(viewport={'width': 390, 'height': 844}, is_mobile=True, has_touch=True)
            context.add_init_script(init)
            page = context.new_page()
            page.on('pageerror', lambda e: errors.append(str(e)))
            page.goto(web + '/#/cards')
            enable_accessibility(page)
            expect(page.get_by_text('Your card setup', exact=True)).to_be_attached(timeout=30000)
            buttons = page.get_by_role('button', name='Add a card to wallet', exact=True)
            expect(buttons).to_have_count(2)
            page.screenshot(path=str(out / 'cards-top-add-mobile.png'))
            buttons.first.click()
            search = page.get_by_role('textbox').first
            expect(search).to_be_focused(timeout=10000)
            snapshot = page.locator('body').aria_snapshot()
            assert 'Next in your strategy' in snapshot and next_name in snapshot
            assert snapshot.index('Next in your strategy') < snapshot.index(other_name), 'Plan next card is not first'
            assert page.get_by_role('button', name='Add', exact=True).count() == 6
            page.screenshot(path=str(out / 'next-card-first-picker-mobile.png'))
            verified.append('Top Add opens focused search; server plan next card leads')
            search.fill(other_name)
            page.wait_for_timeout(600)
            snapshot = page.locator('body').aria_snapshot()
            assert 'Next in your strategy' not in snapshot, 'Unrelated suggested card leaked into search'
            assert other_name in snapshot
            search.fill('')
            page.wait_for_timeout(600)
            assert 'Next in your strategy' in page.locator('body').aria_snapshot()
            page.get_by_role('button', name='Close card search', exact=True).click()
            expect(page.get_by_role('textbox')).to_have_count(0)
            # Scroll the real Flutter canvas, not only its semantics overlay.
            page.mouse.move(195, 500)
            page.mouse.wheel(0, 4500)
            page.wait_for_timeout(700)
            page.screenshot(path=str(out / 'cards-bottom-add-mobile.png'))
            buttons.last.click()
            expect(page.get_by_role('textbox').first).to_be_focused(timeout=10000)
            page.screenshot(path=str(out / 'bottom-add-opens-top-picker-mobile.png'))
            verified.append('Bottom Add returns to the same picker; close/search filtering work')
            page.get_by_role('button', name='Add', exact=True).first.click()
            expect(page.get_by_role('textbox')).to_have_count(0, timeout=15000)
            _, response = request(api + '/v1/bootstrap', headers=headers)
            actual = {w['card']['id'] for w in response['data']['wallet']}
            assert actual == owned | {next_card['id']}, 'Unexpected wallet mutation'
            following = [s['name'] for s in response['data']['playbook']['steps'] if s['status'] == 'next']
            assert next_name not in following, 'The added card is still marked as the next application'
            page.reload()
            enable_accessibility(page)
            expect(page.get_by_text('3 ACTIVE', exact=True)).to_be_attached(timeout=30000)
            expect(page.get_by_role('button', name='Add a card to wallet', exact=True)).to_have_count(2)
            page.goto(web + '/#/cards?search=1')
            expect(page.get_by_role('textbox').first).to_be_focused(timeout=10000)
            if following:
                assert following[0] in page.locator('body').aria_snapshot()
            else:
                assert 'Next in your strategy' not in page.locator('body').aria_snapshot()
            assert not errors, errors
            verified += ['Only explicitly selected card added; active wallet persists after reload', 'Next suggestion follows refreshed server plan without repeating owned card; search deep link remains focused', 'No browser runtime errors']
            context.close()
            browser.close()
        (out / 'result.json').write_text(json.dumps({'passed': True, 'verified': verified}, indent=2))
        print('Cards picker browser smoke PASSED: ' + '; '.join(verified))
        print('Screenshots:', out)
    finally:
        status, _ = request(api + '/v1/account', 'DELETE', headers=headers)
        assert status == 204
        try:
            request(auth + '/auth/v1/user', headers={**headers, **public})
        except urllib.error.HTTPError as e:
            assert e.code in (401, 403, 404)
        else:
            raise AssertionError('QA account still exists')
        print('Disposable QA account deletion verified.')


if __name__ == '__main__':
    main()
