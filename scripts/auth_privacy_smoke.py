#!/usr/bin/env python3
"""Disposable loopback-only auth/privacy check; never print tokens or emails."""
import html
import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from local_e2e import ROOT, load_env, request


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def main():
    config = load_env(ROOT / '.env.local')
    auth, api = config['SUPABASE_URL'], config['REVOCRED_API_URL']
    for url in (auth, api):
        if urllib.parse.urlparse(url).hostname not in ('127.0.0.1', 'localhost'):
            raise SystemExit('Refusing non-loopback service')
    public = {'apikey': config['SUPABASE_ANON_KEY']}
    email = f'privacy-{time.time_ns()}@example.test'
    password = 'Disposable-Privacy-Initial-7291!'
    token = None
    deleted = False
    results = {}
    try:
        _, signup = request(auth + '/auth/v1/signup', 'POST',
                            {'email': email, 'password': password}, public)
        results['signup'] = bool(signup.get('user') or signup.get('id'))
        results['confirmation_email'] = 'not exercised: local confirmations disabled'
        def login(secret):
            return request(auth + '/auth/v1/token?grant_type=password', 'POST',
                           {'email': email, 'password': secret}, public)[1]['access_token']
        token = login(password)
        results['login'] = True
        request(auth + '/auth/v1/logout?scope=local', 'POST', headers={
            **public, 'Authorization': 'Bearer ' + token})
        token = login(password)
        results['logout_and_relogin'] = True
        callback = 'com.revocred.app://auth-callback/?recovery=true'
        request(auth + '/auth/v1/recover?redirect_to=' + urllib.parse.quote(callback, safe=''),
                'POST', {'email': email}, public)
        message = None
        for _ in range(40):
            _, matches = request('http://127.0.0.1:54324/api/v1/search?query=' +
                                 urllib.parse.quote('to:' + email))
            messages = matches.get('messages', [])
            if messages:
                _, message = request('http://127.0.0.1:54324/api/v1/message/' + messages[0]['ID'])
                break
            time.sleep(.25)
        assert message, 'No local recovery email'
        links = re.findall(r'href=["\']([^"\']+)', message.get('HTML') or message.get('Text') or '')
        link = next(html.unescape(s) for s in links if '/auth/v1/verify' in s)
        parsed = urllib.parse.urlparse(link)
        query = urllib.parse.parse_qs(parsed.query)
        assert query.get('redirect_to') == [callback], 'Email callback mismatch'
        # Consume only our local token through loopback, regardless of local site_url.
        local_link = auth + '/auth/v1/verify?' + parsed.query
        try:
            urllib.request.build_opener(NoRedirect()).open(local_link, timeout=15)
            raise AssertionError('Expected callback redirect')
        except urllib.error.HTTPError as response:
            assert response.code in (302, 303), 'Expected recovery redirect'
            returned = urllib.parse.urlparse(response.headers['Location'])
        assert (returned.scheme, returned.netloc, returned.path) == (
            'com.revocred.app', 'auth-callback', '/'), 'Native callback structure mismatch'
        assert urllib.parse.parse_qs(returned.query).get('recovery') == ['true']
        fields = urllib.parse.parse_qs(returned.fragment)
        assert fields.get('type') == ['recovery']
        recovery_token = fields['access_token'][0]
        password = 'Disposable-Privacy-Recovered-8302!'
        request(auth + '/auth/v1/user', 'PUT', {'password': password}, {
            **public, 'Authorization': 'Bearer ' + recovery_token})
        token = login(password)
        results['local_recovery_email_and_password_update'] = True
        results['native_callback_structure'] = True
        results['native_app_execution'] = 'UNTESTED'
        headers = {'Authorization': 'Bearer ' + token}
        _, catalog = request(api + '/v1/public/cards')
        request(api + '/v1/wallet', 'POST', {
            'catalog_card_id': catalog['data'][0]['id'], 'nickname': '', 'status': 'active'}, headers)
        _, exported = request(api + '/v1/account/export', headers=headers)
        assert exported['data']['records']['wallet_cards'], 'Expected account wallet in export'
        results['export'] = True
        request(api + '/v1/account', 'DELETE', headers=headers)
        deleted = True
        for target, extra in ((auth + '/auth/v1/user', public), (api + '/v1/bootstrap', {})):
            try:
                request(target, headers={**extra, **headers})
                raise AssertionError('Deleted account remained accessible')
            except urllib.error.HTTPError as error:
                assert error.code in (401, 403), 'Unexpected deleted-account response'
        try:
            login(password)
            raise AssertionError('Deleted account could sign in')
        except urllib.error.HTTPError as error:
            assert error.code in (400, 401), 'Unexpected deleted-login response'
        results['deletion_readback_and_login_denied'] = True
        print(json.dumps(results, indent=2))
    finally:
        if token and not deleted:
            request(api + '/v1/account', 'DELETE', headers={'Authorization': 'Bearer ' + token})


if __name__ == '__main__':
    main()
