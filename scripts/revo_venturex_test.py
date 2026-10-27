#!/usr/bin/env python3
"""Ask REVO Javed's exact Venture X question with a disposable local QA account.

Owns Venture X, saves a plan, asks with AI consent, prints the verbatim reply,
then deletes the account. Local loopback stack only.
"""
import json
import secrets
import sys
import time
import urllib.error
import urllib.parse

sys.path.insert(0, 'scripts')
from local_e2e import ROOT, load_env
import urllib.request


def request(url, method='GET', body=None, headers=None):
    encoded = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(url, data=encoded, method=method, headers=headers or {})
    if encoded is not None:
        req.add_header('Content-Type', 'application/json')
    with urllib.request.urlopen(req, timeout=150) as response:
        payload = response.read()
        return response.status, json.loads(payload) if payload else {}


QUESTION = 'Explain the cell phone protection the Venture X provides'


def main():
    config = load_env(ROOT / '.env.local')
    for key in ('SUPABASE_URL', 'REVOCRED_API_URL'):
        if urllib.parse.urlparse(config[key]).hostname not in ('127.0.0.1', 'localhost'):
            raise SystemExit('Local test stack only')
    api, auth = config['REVOCRED_API_URL'], config['SUPABASE_URL']
    public = {'apikey': config['SUPABASE_ANON_KEY']}
    email = f'revo-venturex-{time.time_ns()}@example.test'
    password = secrets.token_urlsafe(28)
    request(auth + '/auth/v1/signup', 'POST', {'email': email, 'password': password}, public)
    _, session = request(auth + '/auth/v1/token?grant_type=password', 'POST',
                         {'email': email, 'password': password}, public)
    headers = {'Authorization': 'Bearer ' + session['access_token']}
    try:
        _, disclosure = request(api + '/v1/public/chat-disclosure', headers=headers)
        version = disclosure['data']['version']
        mode = disclosure['data'].get('recipient', '?') + ' / ' + disclosure['data'].get('model', '?')
        print(f'Chat mode: {mode}, disclosure version: {version}')
        request(api + '/v1/wallet', 'POST',
                {'catalog_card_id': '20000000-0000-4000-8000-000000000015',
                 'nickname': '', 'status': 'active'}, headers)
        request(api + '/v1/recommendations', 'POST', {
            'monthly_category_spend': {'food': 60000, 'travel': 20000, 'everyday': 40000},
            'fee_tolerance_cents': 100000, 'travel_scope': 'both',
            'rewards_goal': 'travel', 'credit_tier': 'excellent',
            'existing_card_ids': ['20000000-0000-4000-8000-000000000015'],
        }, headers)
        results = []
        for question in (
            QUESTION,
            'And what is the deductible?',
            'Explain how credit card utilization works in plain English.',
            'Compare the Robinhood Gold Card with Venture X for everyday purchases. It is okay if Robinhood is not in your catalog.',
            'Which cards do I already own and how does my wallet score work?',
        ):
            started = time.monotonic()
            status, reply = request(api + '/v1/chat/messages', 'POST',
                                    {'content': question, 'ai_consent_version': version}, headers)
            messages = reply['data']
            data = next((message for message in reversed(messages) if message.get('role') == 'assistant'), {}) if isinstance(messages, list) else messages
            elapsed = round(time.monotonic() - started, 2)
            print(f'HTTP {status}, {elapsed}s | {question}')
            print('=== REVO reply verbatim ===')
            print(data['content'] if isinstance(data, dict) else json.dumps(data, indent=2))
            print('=== end reply ===')
            results.append({'question': question, 'http_status': status,
                            'elapsed_seconds': elapsed, 'reply': data})
            # Save each real reply immediately, even if a later request fails.
            Path = __import__('pathlib').Path
            Path(ROOT / '.local/revo-venturex-reply.json').write_text(json.dumps(
                {'mode': mode, 'results': results}, indent=2))
            assert status == 201, f'Chat returned {status}'
            assert data.get('content', '').strip(), 'Empty chat answer'
            text = data['content'].lower()
            assert 'dsml' not in text, 'Raw provider tool protocol reached user'
            assert 'full answers are unavailable' not in text, 'Model did not answer'
            if question == QUESTION or question == 'And what is the deductible?':
                assert 'https://' in text, 'Current benefit answer has no source URL'
                assert 'deductible' in text, 'Benefit answer omitted deductible'
            elif 'Robinhood' in question:
                assert 'robinhood' in text and 'venture' in text, 'Unfamiliar card comparison missing'
            elif 'utilization' in question:
                assert 'utilization' in text, 'General education answer missing'
            elif 'already own' in question:
                assert 'venture x' in text and 'score' in text, 'Private wallet context missing'
    finally:
        status, _ = request(api + '/v1/account', 'DELETE', headers=headers)
        assert status == 204, 'QA account cleanup failed'
        try:
            request(auth + '/auth/v1/user', headers={**headers, **public})
        except urllib.error.HTTPError as exc:
            assert exc.code in (401, 403, 404), 'unexpected cleanup error'
        else:
            raise AssertionError('QA user still exists after cleanup')
        print('Disposable QA account deletion verified.')


if __name__ == '__main__':
    main()
