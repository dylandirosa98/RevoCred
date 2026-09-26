#!/usr/bin/env python3
"""Real browser/account/recovery smoke test against local services only.

Install requirements-browser.txt and start `make local-preview` first.
Recovery emails are read from the local Supabase Mailpit container through
its published web API (port 54324). Creates and deletes only its own test account.
"""
import html
import os
import re
import time
import urllib.parse
from playwright.sync_api import sync_playwright, expect
from local_e2e import ROOT, load_env, request


def enable_accessibility(page):
    page.wait_for_selector('flt-glass-pane', state='attached', timeout=60000)
    placeholder = page.locator('flt-semantics-placeholder')
    if placeholder.count():
        placeholder.evaluate('(element) => element.click()')


def fill_field(page, index, value):
    # Target the accessibility inputs Flutter keeps in sync; hidden
    # text-editing-host inputs also match generic `input` selectors.
    page.get_by_role('textbox').nth(index).fill(value)


def latest_email(address: str):
    for _ in range(40):
        _, result = request(
            'http://127.0.0.1:54324/api/v1/search?query=' +
            urllib.parse.quote('to:' + address))
        messages = result.get('messages', [])
        if messages:
            _, message = request(
                'http://127.0.0.1:54324/api/v1/message/' + messages[0]['ID'])
            return message
        time.sleep(.25)
    return None


def main():
    config = load_env(ROOT / '.env.local')
    api, auth = config['REVOCRED_API_URL'], config['SUPABASE_URL']
    for value in (api, auth):
        if urllib.parse.urlparse(value).hostname not in ('localhost', '127.0.0.1'):
            raise SystemExit('Browser smoke refuses non-loopback services.')
    public = {'apikey': config['SUPABASE_ANON_KEY']}
    email = f'browser-{time.time_ns()}@example.test'
    original_password = 'Local-Browser-Test-49381!'
    password = original_password
    _, signup = request(auth + '/auth/v1/signup', 'POST', {'email':email, 'password':password}, public)
    deleted = False
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(executable_path=os.environ.get('CHROMIUM_PATH', '/snap/bin/chromium'), headless=True, args=['--no-sandbox'])
            context = browser.new_context(viewport={'width':1280,'height':900})
            page = context.new_page()
            errors = []
            page.on('pageerror', lambda error: errors.append(str(error)))
            page.goto('http://127.0.0.1:8083/')
            enable_accessibility(page)
            page.get_by_role('button', name='I already have an account').click()
            # Let the animated form swap finish so Flutter attaches its
            # input channel before values are injected.
            expect(page.get_by_role('button', name='Sign in', exact=True)).to_be_visible()
            page.wait_for_timeout(400)
            fill_field(page, 0, email)
            fill_field(page, 1, password)
            page.get_by_role('button', name='Sign in', exact=True).click()
            # A confirmed account with no saved questionnaire is sent to
            # onboarding rather than an empty home screen.
            expect(page).to_have_url(re.compile(r'.*#/questionnaire$'), timeout=30000)
            page.goto('http://127.0.0.1:8083/#/account')
            enable_accessibility(page)
            page.get_by_role('button', name='Export my data').click()
            expect(page.get_by_text('Your account data (JSON)', exact=True)).to_be_visible()
            page.get_by_role('button', name='Close', exact=True).click()
            page.goto('http://127.0.0.1:8083/#/profile')
            enable_accessibility(page)
            page.get_by_role('button', name='Log out', exact=True).click()
            expect(page).to_have_url(re.compile(r'.*#/welcome$'))
            page.get_by_role('button', name='Forgot password / confirm email').click()
            fill_field(page, 0, email)
            page.get_by_role('button', name='Send password reset').click()
            message = latest_email(email)
            if not message:
                raise AssertionError('Recovery email did not arrive in local Mailpit')
            html_body = message.get('HTML') or message.get('Text') or ''
            links = re.findall(r'href=["\']([^"\']+)', html_body)
            link = next(html.unescape(value) for value in links if '/auth/v1/verify' in value)
            if urllib.parse.urlparse(link).hostname not in ('localhost', '127.0.0.1'):
                raise AssertionError('Unexpected external recovery link')
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
            page.goto('http://127.0.0.1:8083/#/account')
            enable_accessibility(page)
            expect(page.get_by_role('button', name='Delete my account', exact=True)).to_be_visible()
            page.wait_for_timeout(400)
            fill_field(page, 1, password)
            page.get_by_role('button', name='Delete my account', exact=True).click()
            page.get_by_role('button', name='Delete account', exact=True).click()
            expect(page).to_have_url(re.compile(r'.*#/welcome$'), timeout=30000)
            deleted = True
            mobile = browser.new_page(viewport={'width':390,'height':844})
            mobile.goto('http://127.0.0.1:8083/')
            enable_accessibility(mobile)
            mobile.get_by_role('button', name='Privacy and terms', exact=True).click()
            expect(mobile.get_by_text('RevoCred local / pre-release notice', exact=True)).to_be_visible()
            browser.close()
            if errors:
                raise AssertionError('Browser runtime errors: ' + '; '.join(errors))
        print('Browser smoke passed: real sign-in, export, sign-out, emailed PKCE recovery, password update, reload, deletion and mobile legal navigation.')
    finally:
        if not deleted:
            token = None
            for candidate in (password, original_password):
                try:
                    _, login = request(auth + '/auth/v1/token?grant_type=password', 'POST', {'email':email,'password':candidate}, public)
                    token = login.get('access_token')
                    break
                except OSError:
                    continue
            if token:
                request(api + '/v1/account', 'DELETE', headers={'Authorization':'Bearer '+token})


if __name__ == '__main__':
    main()
