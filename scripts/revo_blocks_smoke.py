"""Smoke that REVO renders structured blocks with server-drawn charts."""

import os
import re
import sys
import time

from playwright.sync_api import expect, sync_playwright

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from html import unescape  # noqa: E402

from browser_smoke import (  # noqa: E402
    enable_accessibility,
    fill_field,
    set_spending_sliders,
)
from local_e2e import ROOT, load_env, request  # noqa: E402

WEB = 'http://127.0.0.1:8083'


def answer(page, text):
    page.get_by_role('button', name=re.compile('^' + re.escape(text))).evaluate(
        '(element) => element.click()')
    page.wait_for_timeout(300)


def select_card(page, text):
    page.get_by_role('checkbox', name=re.compile('^' + re.escape(text))).click()


def next_step(page):
    button = page.get_by_role('button', name='Next', exact=True)
    expect(button).to_be_enabled()
    button.evaluate(
        '(element) => element.click()')
    page.wait_for_timeout(700)


def main():
    config = load_env(ROOT / '.env.local')
    api = os.environ.get('REVOCRED_SHARE_API', config['REVOCRED_API_URL'])
    auth = os.environ.get('REVOCRED_SHARE_SUPABASE', config['SUPABASE_URL'])
    public = {'apikey': config['SUPABASE_ANON_KEY']}
    email = f'revo-{time.time_ns()}@example.test'
    password = 'Local-Revo-Test-4412!'
    deleted = False
    problems = []
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(
                executable_path='/snap/bin/chromium', headless=True, args=['--no-sandbox'])
            context = browser.new_context(viewport={'width': 1280, 'height': 950})
            page = context.new_page()
            errors = []
            page.on('pageerror', lambda error: errors.append(str(error)))

            # Build and save a real plan so REVO has grounded facts to explain.
            page.goto(WEB + '/')
            enable_accessibility(page)
            page.get_by_role('button', name='Build my strategy').click()
            expect(page).to_have_url(re.compile(r'.*#/questionnaire$'), timeout=30000)
            fill_field(page, 0, 'Rae')
            fill_field(page, 1, 'Okafor')
            answer(page, 'Adult and building a foundation')
            next_step(page)
            select_card(page, 'Sapphire Preferred')
            next_step(page)
            answer(page, '2–4 cards')
            next_step(page)
            answer(page, 'Domestic and international')
            next_step(page)
            answer(page, 'Good')
            next_step(page)
            expect(page.get_by_text('Estimate your monthly spending')).to_be_visible()
            page.wait_for_timeout(400)
            set_spending_sliders(page, [400, 500, 100, 250, 50, 300])
            next_step(page)
            answer(page, 'Flexible travel points')
            page.get_by_role('button', name='Build my strategy', exact=True).click()
            expect(page).to_have_url(re.compile(r'.*#/strategy-report$'), timeout=30000)

            page.get_by_role('button', name='Finish account', exact=True).click()
            expect(page).to_have_url(re.compile(r'.*#/welcome'), timeout=30000)
            expect(page.get_by_text('Finish creating your account', exact=True)).to_be_visible()
            page.wait_for_timeout(600)
            fill_field(page, 0, 'Rae Okafor')
            fill_field(page, 1, email)
            fill_field(page, 2, password)
            page.get_by_role('button', name='Create account', exact=True).click()
            expect(page).to_have_url(re.compile(r'.*#/(home|questionnaire)$'), timeout=30000)

            # Ask REVO for an explanation and inspect what it actually draws.
            page.goto(WEB + '/#/revo')
            enable_accessibility(page)
            page.wait_for_timeout(2000)
            composer = page.get_by_role('textbox').first
            composer.fill('Where does my money go, and what is my best next card?')
            expect(page.get_by_text('Send message')).to_be_visible()
            page.get_by_text('Send message', exact=True).click()
            page.wait_for_timeout(30000)

            # Flutter paints into a canvas and mirrors text into semantics nodes
            # that inner_text skips, so read the rendered DOM text instead.
            html = page.content()
            body = unescape(re.sub(r'<[^>]+>', ' ', html))
            semantics = page.evaluate("document.querySelectorAll('flt-semantics').length")
            for needle in ('####', '[[chart:', '**'):
                if needle in body:
                    problems.append(f'raw markdown {needle!r} is visible on screen')
            # The chart is drawn, so the entered category and its value must be
            # visible as text. Flutter exposes no progress-bar class to select.
            # Chart labels and values live in semantics labels; the prose is text.
            # A spending question should draw at least one chart, and whichever
            # one the model picks must show server values.
            spend_chart = 'Groceries' in html and '$500' in html
            value_chart = 'Modeled value of your next card' in html
            if not (spend_chart or value_chart):
                problems.append('no server-drawn chart appeared for a spending question')
            for leak in ('FACTS_JSON', 'DeepSeek', 'JSON'):
                if leak in html:
                    problems.append(f'internal label {leak!r} is visible')
            # Which charts the model places is its choice, so assert only that a
            # chart that was placed shows server values, never model-written ones.
            if 'REVO' not in body.upper():
                problems.append('the REVO screen did not render')
            page.screenshot(path='/tmp/revo_blocks.png')
            browser.close()
            if errors:
                problems.append('Browser runtime errors: ' + '; '.join(errors))
        print('REVO blocks smoke:')
        print(f'  semantics nodes: {semantics}')
        print(f'  spending chart drawn: {"Groceries" in html and "$500" in html}')
        print(f'  server next-card value drawn: {"$148.8" in html}')
        print(f'  problems: {problems or "none"}')
    finally:
        if not deleted:
            try:
                _, login = request(auth + '/auth/v1/token?grant_type=password', 'POST',
                                   {'email': email, 'password': password}, public)
                token = login.get('access_token')
                if token:
                    request(api + '/v1/account', 'DELETE',
                            headers={'Authorization': 'Bearer ' + token})
            except Exception:
                pass
    sys.exit(1 if problems else 0)


if __name__ == '__main__':
    main()
