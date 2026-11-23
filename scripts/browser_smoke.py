#!/usr/bin/env python3
"""Real browser/account/recovery smoke test against local services only.

Install requirements-browser.txt and start `make local-preview` first.
Recovery emails are read from the local Supabase Mailpit container through
its published web API (port 54324). Creates and deletes only its own test account.
"""
import html
import json
import os
from pathlib import Path
import re
import shutil
import time
import urllib.parse
from playwright.sync_api import sync_playwright, expect
from local_e2e import ROOT, load_env, request


def resolve_chromium_executable() -> str | None:
    """Find a local Chromium/Chrome binary, or return None for Playwright default."""
    override = os.environ.get('CHROMIUM_PATH', '').strip()
    if override and Path(override).is_file():
        return override
    for name in ('chromium', 'chromium-browser', 'google-chrome', 'google-chrome-stable'):
        found = shutil.which(name)
        if found:
            return found
    snap = Path('/snap/bin/chromium')
    if snap.is_file():
        return str(snap)
    cache = Path.home() / '.cache' / 'ms-playwright'
    if cache.is_dir():
        candidates = sorted(
            cache.glob('chromium-*/chrome-linux*/chrome'),
            key=lambda p: p.as_posix(),
            reverse=True,
        )
        for candidate in candidates:
            if candidate.is_file():
                return str(candidate)
    return None


def launch_chromium(playwright, *, headless: bool = True):
    kwargs = {'headless': headless, 'args': ['--no-sandbox']}
    executable = resolve_chromium_executable()
    if executable:
        kwargs['executable_path'] = executable
    # Linux Unix domain sockets cap paths at 108 bytes; deep TMPDIR values
    # break Chromium's SingletonSocket unless TMPDIR is shortened.
    tmpdir = os.environ.get('TMPDIR', '')
    if len(tmpdir) > 40 and Path('/tmp').is_dir():
        kwargs['env'] = {**os.environ, 'TMPDIR': '/tmp'}
    return playwright.chromium.launch(**kwargs)


def enable_accessibility(page, timeout: int = 60000):
    page.wait_for_selector('flt-glass-pane', state='attached', timeout=timeout)
    # Wait briefly for Flutter to mount either its semantics placeholder or an
    # already-active semantics tree before clicking the placeholder.
    deadline = time.monotonic() + (timeout / 1000.0)
    while time.monotonic() < deadline:
        if page.locator('flt-semantics-host flt-semantics').count() > 0:
            return
        placeholder = page.locator('flt-semantics-placeholder')
        if placeholder.count() > 0:
            placeholder.first.evaluate('(element) => element.click()')
            page.wait_for_timeout(200)
            if page.locator('flt-semantics-host flt-semantics').count() > 0:
                return
        page.wait_for_timeout(100)


def fill_field(page, index, value):
    # Target the accessibility inputs Flutter keeps in sync; hidden
    # text-editing-host inputs also match generic `input` selectors.
    field = page.get_by_role('textbox').nth(index)
    field.scroll_into_view_if_needed()
    field.click()
    page.wait_for_timeout(150)
    field.fill(value)
    expect(field).to_have_value(value)
    page.wait_for_timeout(150)


def fill_labeled_field(page, label: str, value: str):
    """Fill a Flutter semantics text field by its accessible label."""
    field = page.get_by_role('textbox', name=label)
    field.first.scroll_into_view_if_needed()
    field.first.click()
    page.wait_for_timeout(150)
    field.first.fill(value)
    expect(field.first).to_have_value(value)
    page.wait_for_timeout(150)


def set_spending_sliders(page, amounts):
    """Set every slider through semantics and verify each snapped $50 step."""
    sliders = page.get_by_role('slider')
    expect(sliders.first).to_be_visible()
    assert sliders.count() == len(amounts), 'unexpected spending slider count'
    for index, amount in enumerate(amounts):
        assert amount >= 0 and amount % 50 == 0, \
            f'spending amount must be a non-negative $50 step: {amount}'
        # Flutter replaces a slider's semantics node after each increment. Re-
        # resolve and refocus it for every key so no step targets a detached node.
        for _ in range(105):
            slider = page.get_by_role('slider').nth(index)
            current = _slider_dollars(slider)
            if current <= 0:
                break
            slider.focus()
            slider.press('ArrowLeft')
            page.wait_for_timeout(90)
        for _ in range(105):
            slider = page.get_by_role('slider').nth(index)
            current = _slider_dollars(slider)
            if current >= amount:
                break
            slider.focus()
            slider.press('ArrowRight')
            page.wait_for_timeout(90)

        value = _slider_dollars(page.get_by_role('slider').nth(index))
        assert value == amount, \
            f'slider {index} stopped at ${value}, expected ${amount}'


def _slider_dollars(slider):
    # Flutter exposes the human formatter through aria-valuetext; aria-valuenow
    # is an internal normalized accessibility value and is not the dollar amount.
    text = slider.get_attribute('aria-valuetext') or ''
    match = re.search(r'\$([\d,]+)', text)
    assert match, f'slider has no dollar-valued aria text: {text!r}'
    return int(match.group(1).replace(',', ''))


def latest_email(address: str, mailpit_url: str = 'http://127.0.0.1:54324', *, kind: str | None = None):
    """Poll a loopback Mailpit API for the latest message addressed to `address`."""
    parsed = urllib.parse.urlparse(mailpit_url)
    if parsed.hostname not in ('localhost', '127.0.0.1'):
        raise ValueError(f'Refusing non-loopback Mailpit URL: {mailpit_url}')
    base = mailpit_url.rstrip('/')
    for _ in range(40):
        _, result = request(
            base + '/api/v1/search?query=' + urllib.parse.quote('to:' + address)
        )
        messages = result.get('messages', [])
        for item in messages:
            _, message = request(base + '/api/v1/message/' + item['ID'])
            if kind is None:
                return message
            body = message.get('HTML') or message.get('Text') or ''
            if f'type={kind}' in html.unescape(body):
                return message
        time.sleep(.25)
    return None


def extract_verify_link(message: dict, *, expected_auth_host: str, expected_web_origin: str | None = None) -> str:
    """Extract and validate a Supabase /verify link from a Mailpit message."""
    html_body = message.get('HTML') or message.get('Text') or ''
    links = re.findall(r'href=["\']([^"\']+)', html_body)
    link = next((html.unescape(value) for value in links if '/auth/v1/verify' in value), None)
    if not link:
        raise AssertionError('No /auth/v1/verify link found in email message')
    parsed = urllib.parse.urlparse(link)
    if parsed.hostname not in ('localhost', '127.0.0.1', expected_auth_host):
        raise AssertionError(f'Unexpected external verify link host: {parsed.hostname}')
    if expected_web_origin is not None:
        redirect_to = urllib.parse.parse_qs(parsed.query).get('redirect_to', [''])[0]
        if redirect_to:
            r = urllib.parse.urlparse(redirect_to)
            actual_origin = f'{r.scheme}://{r.netloc}'
            expected = expected_web_origin.rstrip('/')
            if actual_origin != expected:
                raise AssertionError(
                    f'Auth callback origin mismatch: email redirects to {actual_origin!r} '
                    f'but browser is on {expected!r}'
                )
    return link


def assert_loopback_or_share(url: str, *, allow_share_tunnel: bool = False):
    parsed = urllib.parse.urlparse(url)
    host = parsed.hostname or ''
    if host in ('localhost', '127.0.0.1'):
        return
    if allow_share_tunnel and parsed.scheme == 'https' and host.endswith('.trycloudflare.com'):
        return
    raise SystemExit(f'Browser smoke refuses non-loopback service: {url}')


def main():
    config = load_env(ROOT / '.env.local')
    api, auth = config['REVOCRED_API_URL'], config['SUPABASE_URL']
    for value in (api, auth):
        assert_loopback_or_share(value)
    public = {'apikey': config['SUPABASE_ANON_KEY']}
    # Explicit share overrides still target the local preview through its
    # existing tunnels. Never infer public endpoints from production settings.
    api = os.environ.get('REVOCRED_SHARE_API', api).rstrip('/')
    auth = os.environ.get('REVOCRED_SHARE_SUPABASE', auth).rstrip('/')
    web = os.environ.get('REVOCRED_SHARE_WEB', 'http://127.0.0.1:8083').rstrip('/')
    for value in (api, auth, web):
        assert_loopback_or_share(value, allow_share_tunnel=True)
    mailpit = os.environ.get('REVOCRED_MAILPIT_URL', 'http://127.0.0.1:54324').rstrip('/')
    email = f'browser-{time.time_ns()}@example.test'
    original_password = 'Local-Browser-Test-49381!'
    password = original_password
    _, signup = request(auth + '/auth/v1/signup', 'POST', {'email': email, 'password': password}, public)
    deleted = False
    try:
        with sync_playwright() as playwright:
            browser = launch_chromium(playwright, headless=True)
            context = browser.new_context(viewport={'width': 1280, 'height': 900}, accept_downloads=True)
            page = context.new_page()
            errors = []
            page.on('pageerror', lambda error: errors.append(str(error)))
            page.goto(web + '/')
            enable_accessibility(page)
            page.get_by_role('button', name='I already have an account').click()
            # Let the animated form swap finish so Flutter attaches its
            # input channel before values are injected.
            expect(page.get_by_role('button', name='Sign in', exact=True)).to_be_visible()
            page.wait_for_timeout(400)
            fill_field(page, 0, email)
            fill_field(page, 1, 'Incorrect-Password-123!')
            page.get_by_role('button', name='Sign in', exact=True).click()
            expect(page.get_by_text('Invalid login credentials', exact=False)).to_be_visible(timeout=30000)
            expect(page).to_have_url(re.compile(r'.*#/welcome$'))
            fill_field(page, 1, password)
            page.get_by_role('button', name='Sign in', exact=True).click()
            # A confirmed account with no saved questionnaire is sent to
            # onboarding rather than an empty home screen.
            expect(page).to_have_url(re.compile(r'.*#/questionnaire$'), timeout=30000)
            page.goto(web + '/#/account')
            enable_accessibility(page)
            page.get_by_role('button', name='Export my data').click()
            expect(page.get_by_text('Your account data (JSON)', exact=True)).to_be_visible(timeout=30000)
            download_btn = page.get_by_role('button', name='Download JSON', exact=True)
            if download_btn.count() > 0:
                with page.expect_download(timeout=15000) as dl_info:
                    download_btn.click()
                dl_path = dl_info.value.path()
                exported = json.loads(Path(dl_path).read_text(encoding='utf-8'))
                assert isinstance(exported, dict) and exported, 'Downloaded JSON export was empty'
            page.get_by_role('button', name='Close', exact=True).click()
            page.goto(web + '/#/profile')
            enable_accessibility(page)
            page.get_by_role('button', name='Log out', exact=True).click()
            expect(page).to_have_url(re.compile(r'.*#/welcome$'))
            page.get_by_role('button', name='Forgot password / confirm email').click()
            fill_field(page, 0, email)
            page.get_by_role('button', name='Send password reset').click()
            message = latest_email(email, mailpit_url=mailpit, kind='recovery')
            if not message:
                raise AssertionError('Recovery email did not arrive in local Mailpit')
            link = extract_verify_link(
                message,
                expected_auth_host=urllib.parse.urlparse(auth).hostname or '127.0.0.1',
                expected_web_origin=web,
            )
            page.goto(link)
            enable_accessibility(page)
            expect(page.get_by_text('Set a new password', exact=True)).to_be_visible(timeout=30000)
            expect(page.get_by_role('button', name='Update password', exact=True)).to_be_visible()
            page.wait_for_timeout(400)
            password = 'Local-Reset-Test-729415!'
            fill_field(page, 0, password)
            page.get_by_role('button', name='Update password', exact=True).click()
            expect(page).to_have_url(re.compile(r'.*#/home$'), timeout=30000)
            page.reload()
            enable_accessibility(page)
            expect(page).to_have_url(re.compile(r'.*#/home$'))
            page.goto(web + '/#/account')
            enable_accessibility(page)
            expect(page.get_by_role('button', name='Delete my account', exact=True)).to_be_visible()
            page.wait_for_timeout(400)
            # Target Current password explicitly (textbox 2 after Email and New password).
            current_pw = page.get_by_role('textbox', name='Current password')
            if current_pw.count() > 0:
                fill_labeled_field(page, 'Current password', password)
            else:
                fill_field(page, page.get_by_role('textbox').count() - 1, password)
            page.get_by_role('button', name='Delete my account', exact=True).click()
            page.get_by_role('button', name='Delete account', exact=True).click()
            expect(page).to_have_url(re.compile(r'.*#/welcome$'), timeout=30000)
            deleted = True
            mobile = browser.new_page(viewport={'width': 390, 'height': 844}, is_mobile=True, has_touch=True)
            mobile.on('pageerror', lambda error: errors.append(str(error)))
            mobile.goto(web + '/')
            enable_accessibility(mobile)
            mobile.get_by_role('button', name='Privacy and terms', exact=True).click()
            expect(mobile.get_by_text('Privacy & Terms', exact=True)).to_be_visible(timeout=30000)
            browser.close()
            if errors:
                raise AssertionError('Browser runtime errors: ' + '; '.join(errors))
        print('Browser smoke passed: real sign-in, export/download, sign-out, emailed PKCE recovery, password update, reload, deletion and mobile legal navigation.')
    finally:
        if not deleted:
            token = None
            for candidate in (password, original_password):
                try:
                    _, login = request(auth + '/auth/v1/token?grant_type=password', 'POST', {'email': email, 'password': candidate}, public)
                    token = login.get('access_token')
                    break
                except OSError:
                    continue
            if token:
                request(api + '/v1/account', 'DELETE', headers={'Authorization': 'Bearer ' + token})


if __name__ == '__main__':
    main()
