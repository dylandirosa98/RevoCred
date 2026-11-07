#!/usr/bin/env python3
"""Compare Strategy and Cards with an S03 two-card wallet, then add/remove next."""
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
        assert urllib.parse.urlparse(local[key]).hostname in ('localhost', '127.0.0.1')
    for key in ('SUPABASE_URL', 'REVOCRED_API_URL', 'REVOCRED_AUTH_REDIRECT_URL'):
        parsed = urllib.parse.urlparse(shared[key])
        assert parsed.scheme == 'https' and (parsed.hostname or '').endswith('.trycloudflare.com')
    api, auth = local['REVOCRED_API_URL'], local['SUPABASE_URL']
    web = shared['REVOCRED_AUTH_REDIRECT_URL'].rstrip('/')
    public = {'apikey': local['SUPABASE_ANON_KEY']}
    email, password = f'strategy-wallet-{time.time_ns()}@example.test', secrets.token_urlsafe(28)
    request(auth + '/auth/v1/signup', 'POST', {'email': email, 'password': password}, public)
    _, session = request(auth + '/auth/v1/token?grant_type=password', 'POST', {'email': email, 'password': password}, public)
    headers = {'Authorization': 'Bearer ' + session['access_token']}
    out = ROOT / '.local/strategy-wallet-smoke'
    out.mkdir(parents=True, exist_ok=True)
    states, errors = [], []

    def bootstrap():
        _, result = request(api + '/v1/bootstrap', headers=headers)
        data = result['data']
        assert data['profile']['credit_card_strategy'] == 'S03'
        assert data['profile']['next_application_target'] == data['playbook']['next_card']
        return data

    def record(data, phase):
        states.append({'phase': phase, 'owned': [w['card']['name'] for w in data['wallet']], 'next': data['playbook']['next_card'], 'roles': [{'name': s['name'], 'status': s['status'], 'covered_by': s.get('covered_by', '')} for s in data['playbook']['steps']]})

    try:
        for card_id in ('20000000-0000-4000-8000-000000000018', '20000000-0000-4000-8000-000000000021'):
            request(api + '/v1/wallet', 'POST', {'catalog_card_id': card_id, 'nickname': '', 'status': 'active'}, headers)
        request(api + '/v1/recommendations', 'POST', {'monthly_category_spend': dict.fromkeys(['gas', 'other', 'dining', 'travel', 'groceries', 'streaming'], 20000), 'fee_tolerance_cents': 0, 'travel_scope': 'none', 'rewards_goal': 'cash_back', 'credit_tier': 'good', 'life_stage': 'student', 'ideal_card_count': '', 'existing_card_ids': []}, headers)
        request(api + '/v1/strategy', 'PUT', {'strategy_code': 'S03'}, headers)
        before = bootstrap()
        first_next = before['playbook']['next_card']
        assert first_next == 'Savor for Students'
        record(before, 'initial')
        _, build = request(web + '/preview-build.json')
        fresh = web + '/?v=' + build['build_id']
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
            page.on('pageerror', lambda e: errors.append(str(e)))

            def check_strategy(data, filename):
                expect(page.get_by_text('Consider next: ' + data['playbook']['next_card'], exact=False)).to_be_attached(timeout=30000)
                owned = page.get_by_role('button', name=re.compile(r'^Already owned\b'))
                expect(owned).to_have_count(len(data['wallet']))
                for wallet_card in data['wallet']:
                    expect(page.get_by_role('button', name=re.compile(r'^Already owned.*' + re.escape(wallet_card['card']['name'])))).to_be_attached()
                # Flutter's semantics overlay can scroll without moving the
                # canvas. Move the actual scroll view for visual evidence.
                page.mouse.move(195, 500)
                page.mouse.wheel(0, -12000)
                page.wait_for_timeout(300)
                page.mouse.wheel(0, 500)
                page.wait_for_timeout(600)
                page.screenshot(path=str(out / filename))

            def open_picker(data):
                page.get_by_role('tab', name='Cards', exact=True).click()
                button = page.get_by_role('button', name='Add a card to wallet', exact=True).first
                button.scroll_into_view_if_needed()
                button.click()
                expected = data['playbook']['next_card']
                expect(page.get_by_role('textbox').first).to_be_focused(timeout=10000)
                snapshot = page.locator('body').aria_snapshot()
                picker = snapshot.split('CARDS TO ADD', 1)[1].split("Can't find it?", 1)[0]
                assert picker.count('Next in your strategy') == 1 and expected in picker
                available = [c for c in data['catalog'] if c['id'] not in {w['card']['id'] for w in data['wallet']}]
                shown = [c for c in available if c['name'] != expected][:5]
                for other in shown:
                    assert picker.index(expected) < picker.index(other['name'])
                for wallet_card in data['wallet']:
                    assert wallet_card['card']['name'] not in picker
                page.screenshot(path=str(out / ('picker-' + str(len(states)) + '.png')))

            page.goto(fresh + '#/strategy')
            enable_accessibility(page)
            check_strategy(before, 'strategy-two-owned-mobile.png')
            open_picker(before)
            assert bootstrap()['wallet_metrics'] == before['wallet_metrics']
            page.get_by_role('button', name='Add', exact=True).first.click()
            expect(page.get_by_role('textbox')).to_have_count(0, timeout=30000)
            after = bootstrap()
            assert len(after['wallet']) == 3
            assert after['playbook']['next_card'] != first_next
            completed = [s for s in after['playbook']['steps'] if s.get('completed_recommendation')]
            assert any(s.get('covered_by') == first_next and s.get('status') == 'have' for s in completed), after['playbook']['steps']
            assert completed[0]['completed_order'] == 1
            assert after['playbook']['next_card'] not in {s.get('covered_by') for s in completed}
            record(after, 'added-next')
            page.get_by_role('tab', name='Strategy', exact=True).click()
            check_strategy(after, 'strategy-three-owned-mobile.png')
            page.reload()
            enable_accessibility(page)
            check_strategy(after, 'strategy-owned-after-reload-mobile.png')
            open_picker(after)
            added = next(w for w in after['wallet'] if w['card']['name'] == first_next)
            request(api + '/v1/wallet', 'DELETE', {'wallet_card_id': added['id']}, headers)
            restored = bootstrap()
            assert len(restored['wallet']) == 2 and restored['playbook']['next_card'] == first_next
            record(restored, 'removed-next')
            page.goto(fresh + '#/strategy')
            page.reload()
            enable_accessibility(page)
            check_strategy(restored, 'strategy-after-removal-mobile.png')
            assert not errors, errors
            context.close()
            browser.close()
        (out / 'result.json').write_text(json.dumps({'passed': True, 'states': states, 'verified': ['Both screens use the current server-selected next card', 'All owned cards remain visible with Already owned labels', 'Owned cards never appear as addable recommendations', 'Adding next marks its strategy role owned and advances both surfaces', 'Reload preserves the new wallet and recommendation', 'Removing next restores the original recommendation', 'Opening screens alone leaves wallet metrics unchanged', 'No runtime errors']}, indent=2))
        print('Strategy wallet browser smoke PASSED. ' + json.dumps(states))
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
