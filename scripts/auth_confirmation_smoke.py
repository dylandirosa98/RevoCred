#!/usr/bin/env python3
"""Production-style confirmation tests in disposable Auth/Postgres/Mailpit only.

No application env files or existing database/users are read or modified.
Uses the same GoTrue version as the local stack, with confirmations and secure
email changes enabled. Requires Docker; never uses external email or hosting.
"""
import base64
import hashlib
import hmac
import html
import json
from pathlib import Path
import re
import secrets
import socket
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def docker(*args):
    return subprocess.check_output(['docker', *args], stderr=subprocess.DEVNULL, text=True).strip()


def free_port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def request(url, method='GET', payload=None, token=None):
    assert urllib.parse.urlparse(url).hostname == '127.0.0.1', 'Only isolated loopback URLs allowed'
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(url, method=method, headers=headers,
                                 data=json.dumps(payload).encode() if payload is not None else None)
    try:
        response = urllib.request.build_opener(NoRedirect()).open(req, timeout=10)
    except urllib.error.HTTPError as error:
        response = error
    data = response.read()
    return response.code, json.loads(data) if data and data[:1] in (b'{', b'[') else {}, response.headers


def jwt(secret):
    enc = lambda value: base64.urlsafe_b64encode(json.dumps(value).encode()).decode().rstrip('=')
    body = enc({'alg': 'HS256', 'typ': 'JWT'}) + '.' + enc({
        'role': 'service_role', 'aud': 'authenticated', 'iss': 'supabase',
        'iat': int(time.time()), 'exp': int(time.time()) + 3600})
    signature = base64.urlsafe_b64encode(hmac.new(secret.encode(), body.encode(), hashlib.sha256).digest()).decode().rstrip('=')
    return body + '.' + signature


def main():
    suffix = secrets.token_hex(5)
    network = 'revocred-auth-review-' + suffix
    db, mail, auth = (network + '-' + kind for kind in ('db', 'mail', 'auth'))
    resources = []
    results = {'scope': 'isolated-production-style-auth-not-hosted-or-native', 'checks': {}}
    checks = results['checks']
    secret, password = secrets.token_urlsafe(40), secrets.token_urlsafe(24)
    auth_port, mail_port = free_port(), free_port()
    base, inbox = f'http://127.0.0.1:{auth_port}', f'http://127.0.0.1:{mail_port}'
    callback = 'com.revocred.app://auth-callback/'
    try:
        docker('network', 'create', network)
        docker('run', '-d', '--name', db, '--network', network,
               '-e', 'POSTGRES_PASSWORD=' + password, '-e', 'POSTGRES_DB=auth_review', 'postgres:15-alpine')
        resources.append(db)
        for _ in range(60):
            if subprocess.run(['docker', 'exec', db, 'pg_isready', '-h', '127.0.0.1', '-U', 'postgres'],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                break
            time.sleep(1)
        else:
            raise AssertionError('Isolated database startup failed')
        docker('exec', db, 'psql', '-U', 'postgres', '-d', 'auth_review', '-v', 'ON_ERROR_STOP=1',
               '-c', 'CREATE SCHEMA auth; ALTER ROLE postgres SET search_path TO auth, public;')
        docker('run', '-d', '--name', mail, '--network', network,
               '-p', f'127.0.0.1:{mail_port}:8025', 'public.ecr.aws/supabase/mailpit:v1.30.2')
        resources.append(mail)
        env = {
            'GOTRUE_API_HOST': '0.0.0.0', 'GOTRUE_API_PORT': '9999',
            'API_EXTERNAL_URL': base, 'GOTRUE_SITE_URL': callback,
            'GOTRUE_URI_ALLOW_LIST': 'com.revocred.app://auth-callback/**',
            'GOTRUE_DB_DRIVER': 'postgres',
            'GOTRUE_DB_DATABASE_URL': f'postgres://postgres:{password}@{db}:5432/auth_review?sslmode=disable',
            'GOTRUE_JWT_SECRET': secret, 'GOTRUE_JWT_AUD': 'authenticated',
            'GOTRUE_JWT_ADMIN_ROLES': 'service_role', 'GOTRUE_JWT_EXP': '3600',
            'GOTRUE_JWT_DEFAULT_GROUP_NAME': 'authenticated',
            'GOTRUE_EXTERNAL_EMAIL_ENABLED': 'true', 'GOTRUE_DISABLE_SIGNUP': 'false',
            'GOTRUE_MAILER_AUTOCONFIRM': 'false', 'GOTRUE_MAILER_SECURE_EMAIL_CHANGE_ENABLED': 'true',
            'GOTRUE_SMTP_HOST': mail, 'GOTRUE_SMTP_PORT': '1025',
            'GOTRUE_SMTP_ADMIN_EMAIL': 'auth@example.test', 'GOTRUE_SMTP_SENDER_NAME': 'Isolated RevoCred QA',
            'GOTRUE_SMTP_MAX_FREQUENCY': '1s', 'GOTRUE_RATE_LIMIT_EMAIL_SENT': '1000',
            'GOTRUE_PASSWORD_MIN_LENGTH': '12',
            'GOTRUE_MAILER_URLPATHS_CONFIRMATION': '/verify',
            'GOTRUE_MAILER_URLPATHS_RECOVERY': '/verify',
            'GOTRUE_MAILER_URLPATHS_EMAIL_CHANGE': '/verify',
            'GOTRUE_SECURITY_REFRESH_TOKEN_ROTATION_ENABLED': 'true',
            'GOTRUE_SECURITY_REFRESH_TOKEN_REUSE_INTERVAL': '0',
        }
        args = ['run', '-d', '--name', auth, '--network', network, '-p', f'127.0.0.1:{auth_port}:9999']
        for key, value in env.items():
            args.extend(['-e', key + '=' + value])
        docker(*args, 'public.ecr.aws/supabase/gotrue:v2.196.0')
        resources.append(auth)
        for _ in range(60):
            try:
                if request(base + '/health')[0] == 200:
                    break
            except (OSError, urllib.error.URLError):
                pass
            time.sleep(1)
        else:
            diagnostic = subprocess.run(['docker', 'logs', auth], capture_output=True, text=True)
            safe = (diagnostic.stdout + diagnostic.stderr).replace(secret, '[REDACTED]').replace(password, '[REDACTED]')
            safe = re.sub(r'postgres(?:ql)?://[^\s"\\]+', '[REDACTED_DATABASE_URL]', safe)
            results['startup_diagnostic'] = safe[-2500:]
            print(safe[-2500:])
            raise AssertionError('Isolated confirmation Auth startup failed')

        address = 'confirmed-' + suffix + '@example.test'
        changed = 'changed-' + suffix + '@example.test'
        credentials = {'email': address, 'password': password}
        def login(email=address, pwd=password):
            return request(base + '/token?grant_type=password', 'POST', {'email': email, 'password': pwd})
        def links(email, kind):
            for _ in range(60):
                _, listing, _ = request(inbox + '/api/v1/search?query=' + urllib.parse.quote('to:' + email))
                for item in listing.get('messages', []):
                    _, message, _ = request(inbox + '/api/v1/message/' + item['ID'])
                    for raw in re.findall(r'href=["\']([^"\']+)', message.get('HTML') or message.get('Text') or ''):
                        link = html.unescape(raw)
                        parsed = urllib.parse.urlparse(link)
                        if urllib.parse.parse_qs(parsed.query).get('type') == [kind]:
                            assert parsed.hostname == '127.0.0.1' and parsed.port == auth_port
                            return link
                time.sleep(.2)
            raise AssertionError('Expected isolated email link missing: ' + kind)
        code, created, _ = request(base + '/signup?redirect_to=' + urllib.parse.quote(callback, safe=''), 'POST', credentials)
        if code != 200:
            safe_message = str(created.get('msg') or created.get('message') or created.get('error_code') or 'unknown').replace(password, '[REDACTED]').replace(address, '[TEST_ADDRESS]')
            raise AssertionError(f'Isolated signup HTTP {code}: {safe_message}')
        assert code == 200 and not created.get('access_token') and not created.get('session'), 'Confirmation-required signup must not authenticate'
        user_id = created.get('id') or created['user']['id']
        checks['signup_requires_confirmation'] = True
        assert login()[0] in (400, 401), 'Unconfirmed login accepted'
        checks['unconfirmed_login_rejected'] = True
        link = links(address, 'signup')
        code, _, headers = request(link)
        assert code in (302, 303) and urllib.parse.urlparse(headers['Location']).scheme == 'com.revocred.app'
        assert login()[0] == 200, 'Confirmed login failed'
        checks['delivered_confirmation_link_enables_login'] = True
        code, _, headers = request(link)
        parsed = urllib.parse.urlparse(headers.get('Location', ''))
        assert code in (302, 303) and ('error' in parsed.fragment or 'error' in parsed.query), 'Confirmation link unexpectedly reusable'
        checks['confirmation_reuse_rejected'] = True
        code, duplicate, _ = request(base + '/signup', 'POST', {'email': address, 'password': secrets.token_urlsafe(24)})
        assert code == 200 and not duplicate.get('access_token') and not duplicate.get('session'), 'Duplicate signup leaked a session'
        assert login()[0] == 200, 'Duplicate signup changed existing password'
        checks['duplicate_signup_preserves_existing_account'] = True
        assert login(pwd='Wrong-Password-123!')[0] in (400, 401)
        checks['wrong_password_rejected'] = True
        _, session, _ = login()
        token = session['access_token']
        code, _, _ = request(base + '/user?redirect_to=' + urllib.parse.quote(callback, safe=''), 'PUT', {'email': changed}, token)
        assert code == 200, 'Email change request failed'
        code, current, _ = request(base + '/user', token=token)
        assert current['email'] == address, 'Email changed before confirmation'
        old_link, new_link = links(address, 'email_change'), links(changed, 'email_change')
        request(old_link)
        _, current, _ = request(base + '/user', token=token)
        assert current['email'] == address, 'Secure email change required only one inbox'
        request(new_link)
        assert login(email=changed)[0] == 200 and login()[0] in (400, 401), 'Confirmed email change did not update login'
        checks['both_inboxes_required_for_email_change'] = True
        _, session, _ = login(email=changed)
        code, refreshed, _ = request(base + '/token?grant_type=refresh_token', 'POST', {'refresh_token': session['refresh_token']})
        assert code == 200 and refreshed.get('access_token')
        checks['session_refresh'] = True
        assert request(base + '/logout?scope=global', 'POST', token=refreshed['access_token'])[0] in (200, 204)
        assert request(base + '/token?grant_type=refresh_token', 'POST', {'refresh_token': refreshed['refresh_token']})[0] in (400, 401)
        checks['logout_revokes_refresh_session'] = True
        assert request(base + '/admin/users/' + user_id, 'DELETE', token=jwt(secret))[0] in (200, 204)
        assert login(email=changed)[0] in (400, 401)
        checks['isolated_user_deleted_and_login_denied'] = True
        results['native_execution'] = 'not tested; delivered callback shape only'
        results['external_smtp'] = 'not tested; isolated Mailpit only'
    finally:
        for name in reversed(resources):
            subprocess.run(['docker', 'rm', '-f', name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(['docker', 'network', 'rm', network], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        results['isolated_resources_removed'] = all(subprocess.run(['docker', 'inspect', name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0 for name in resources)
        out = ROOT / '.local/auth-review/confirmation-smoke.json'
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(results, indent=2) + '\n')
    print(json.dumps(results, indent=2))


if __name__ == '__main__':
    main()
