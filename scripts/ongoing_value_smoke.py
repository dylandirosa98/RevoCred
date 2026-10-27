#!/usr/bin/env python3
"""Local-only ongoing value API + real public-preview mobile QA, disposable user."""
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
    local, shared = load_env(ROOT / '.env.local'), load_env(ROOT / '.env.share')
    for key in ('SUPABASE_URL', 'REVOCRED_API_URL'):
        assert urllib.parse.urlparse(local[key]).hostname in ('localhost', '127.0.0.1'), 'local stack required'
    for key in ('SUPABASE_URL', 'REVOCRED_API_URL', 'REVOCRED_AUTH_REDIRECT_URL'):
        u = urllib.parse.urlparse(shared[key])
        assert u.scheme == 'https' and (u.hostname or '').endswith('.trycloudflare.com'), 'existing local tunnel required'
    api, auth, web = local['REVOCRED_API_URL'], local['SUPABASE_URL'], shared['REVOCRED_AUTH_REDIRECT_URL']
    public = {'apikey': local['SUPABASE_ANON_KEY']}
    credentials = {'email': f'ongoing-smoke-{time.time_ns()}@example.test', 'password': secrets.token_urlsafe(28)}
    request(auth + '/auth/v1/signup', 'POST', credentials, public)
    _, session = request(auth + '/auth/v1/token?grant_type=password', 'POST', credentials, public)
    headers = {'Authorization': 'Bearer ' + session['access_token']}
    evidence_dir = ROOT / '.local/ongoing-value'
    evidence_dir.mkdir(parents=True, exist_ok=True)
    report = {'checks': {}, 'screenshots': []}
    errors = []
    try:
        card_id = '20000000-0000-4000-8000-000000000015'
        request(api + '/v1/wallet', 'POST', {'catalog_card_id': card_id, 'nickname': '', 'status': 'active'}, headers)
        answers = {'monthly_category_spend': {'everyday': 100000, 'travel': 20000}, 'fee_tolerance_cents': 100000, 'travel_scope': 'both', 'rewards_goal': 'travel', 'credit_tier': 'excellent', 'existing_card_ids': [card_id]}
        request(api + '/v1/recommendations', 'POST', answers, headers)
        _, response = request(api + '/v1/bootstrap', headers=headers)
        metrics = response['data']['wallet_metrics']
        value = metrics['ongoing_value']
        expected = {'rewards_cents': 28800, 'credits_cents': 21000, 'anniversary_cents': 10000, 'fees_cents': 39500, 'total_cents': 20300}
        for key, amount in expected.items():
            assert value[key] == amount, (key, value[key], amount)
        assert metrics['yearly_value'] == 203
        report['bootstrap_wallet_metrics'] = metrics
        report['checks']['venture_x_203'] = True
        answers['travel_scope'] = 'none'
        request(api + '/v1/recommendations', 'POST', answers, headers)
        _, irrelevant = request(api + '/v1/bootstrap', headers=headers)
        assert irrelevant['data']['wallet_metrics']['ongoing_value']['credits_cents'] == 0
        report['checks']['incompatible_travel_excluded'] = True
        answers['travel_scope'] = 'both'
        request(api + '/v1/recommendations', 'POST', answers, headers)
        _, reread = request(shared['REVOCRED_API_URL'] + '/v1/bootstrap', headers=headers)
        assert reread['data']['wallet_metrics']['yearly_value'] == 203
        report['checks']['public_api_readback'] = True
        host = urllib.parse.urlparse(shared['SUPABASE_URL']).hostname or ''
        key = 'sb-' + host.split('.')[0] + '-auth-token'
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
            toggle = page.get_by_text('How this is estimated', exact=True)
            expect(toggle).to_be_attached(timeout=30000)
            toggle.scroll_into_view_if_needed()
            page.wait_for_timeout(500)
            assert '203' in page.inner_text('body')
            path = evidence_dir / 'home-mobile.png'
            page.screenshot(path=str(path))
            report['screenshots'].append(str(path.relative_to(ROOT)))
            toggle.click()
            page.wait_for_timeout(800)
            for label in ('Spending rewards', 'Credits at 70%', 'Anniversary rewards', 'Annual fees'):
                expect(page.get_by_text(label, exact=False).first).to_be_attached(timeout=10000)
            assert '$288.00' in page.inner_text('body') and '$210.00' in page.inner_text('body')
            path = evidence_dir / 'breakdown-mobile.png'
            page.screenshot(path=str(path))
            report['screenshots'].append(str(path.relative_to(ROOT)))
            source = page.get_by_text('Source · reviewed 2026-10-26', exact=False).first
            source.scroll_into_view_if_needed()
            page.wait_for_timeout(500)
            path = evidence_dir / 'conditions-source-mobile.png'
            page.screenshot(path=str(path))
            report['screenshots'].append(str(path.relative_to(ROOT)))
            body = page.inner_text('body')
            assert 'Capital One Travel' in body and 'welcome bonuses' in body.lower()
            assert not errors, errors
            report['checks']['real_mobile_breakdown_sources_and_assumptions'] = True
            report['browser_runtime_errors'] = errors
            report['viewport'] = {'width': 390, 'height': 844}
            context.close()
            browser.close()
    finally:
        status, _ = request(api + '/v1/account', 'DELETE', headers=headers)
        assert status == 204, 'cleanup failed'
        try:
            request(auth + '/auth/v1/user', headers={**headers, **public})
        except urllib.error.HTTPError as exc:
            assert exc.code in (401, 403, 404)
            report['checks']['qa_account_deleted_and_verified'] = True
        else:
            raise AssertionError('QA user remains after cleanup')
        (evidence_dir / 'qa.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'checks': report['checks'], 'evidence': str(evidence_dir), 'browser_runtime_errors': errors}, indent=2))


if __name__ == '__main__':
    main()
