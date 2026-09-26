#!/usr/bin/env python3
"""Real browser test of guest onboarding, plan saving and account deletion.

Runs only against loopback local services. Creates and deletes only its own
throwaway account. Requires `make local-preview` and requirements-browser.txt.
"""
import re
import time

from playwright.sync_api import sync_playwright, expect

from browser_smoke import enable_accessibility, fill_field
from local_e2e import ROOT, load_env, request

WEB = 'http://127.0.0.1:8083'


def answer(page, text):
    # Flutter exposes each choice as a semantics button whose label is the
    # option text repeated once, so match the leading label only.
    page.get_by_role('button', name=re.compile('^' + re.escape(text))).click()


def select_card(page, text):
    page.get_by_role('checkbox', name=re.compile('^' + re.escape(text))).click()


def next_step(page):
    page.get_by_role('button', name='Next', exact=True).click()
    page.wait_for_timeout(250)


def main():
    config = load_env(ROOT / '.env.local')
    api, auth = config['REVOCRED_API_URL'], config['SUPABASE_URL']
    public = {'apikey': config['SUPABASE_ANON_KEY']}
    email = f'onboard-{time.time_ns()}@example.test'
    password = 'Local-Onboard-Test-8871!'
    deleted = False
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(
                executable_path='/snap/bin/chromium', headless=True, args=['--no-sandbox'])
            context = browser.new_context(viewport={'width': 1280, 'height': 950})
            page = context.new_page()
            errors = []
            page.on('pageerror', lambda error: errors.append(str(error)))

            # 1. A first-time visitor is offered the questionnaire before an account.
            page.goto(WEB + '/')
            enable_accessibility(page)
            page.get_by_role('button', name='Build my strategy').click()
            expect(page).to_have_url(re.compile(r'.*#/questionnaire$'), timeout=30000)
            expect(page.get_by_text('What adult life stage fits best?')).to_be_visible()

            # 2. Nothing is pre-answered: Next stays disabled until each choice is made.
            next_button = page.get_by_role('button', name='Next', exact=True)
            assert next_button.is_disabled(), 'Next was enabled before any answer'
            answer(page, 'Adult and building a foundation')
            expect(next_button).to_be_enabled()

            next_step(page)
            expect(page.get_by_text('Which cards do you already have?')).to_be_visible()
            select_card(page, 'Sapphire Preferred')
            expect(page.get_by_role('checkbox', name=re.compile('^Sapphire Preferred')).first).to_be_checked()
            next_step(page)
            answer(page, r'Up to $100 per card')
            next_step(page)
            answer(page, 'Domestic and international')
            next_step(page)
            answer(page, 'Good')
            next_step(page)
            expect(page.get_by_text('Estimate your monthly spending')).to_be_visible()
            page.wait_for_timeout(400)
            for field, amount in (('dining', '400'), ('groceries', '500'),
                                  ('gas', '120'), ('travel', '250'),
                                  ('streaming', '30'), ('other', '300')):
                fill_field(page, ['dining', 'groceries', 'gas', 'travel',
                                  'streaming', 'other'].index(field), amount)
            next_step(page)
            expect(page.get_by_text('What is your primary rewards goal?')).to_be_visible()
            answer(page, 'Flexible travel points')
            page.get_by_role('button', name='Build my strategy', exact=True).click()

            # 3. A personal plan is shown without an account, and it is not demo data.
            expect(page).to_have_url(re.compile(r'.*#/strategy-report$'), timeout=30000)
            expect(page.get_by_text('Your personal strategy preview')).to_be_visible()
            report = page.inner_text('body')
            assert re.search(r'S0[1-9] STRATEGY', report), 'strategy code missing from preview'
            next_move = re.search(r'Recommended next: (.+)', report)
            assert next_move, 'preview does not name a recommended next move'
            recommended = next_move.group(1).strip()
            assert recommended != 'Sapphire Preferred', \
                f'preview recommended an owned card: {recommended}'
            roadmap = report.split('APPLICATION ROADMAP')[1].split('RECOMMENDED NEXT MOVE')[0]
            for line in roadmap.splitlines():
                if 'Sapphire Preferred' in line:
                    assert 'Already in wallet' in roadmap, \
                        'an owned card was presented as a roadmap step to apply for'
            assert 'Official issuer link' in report, 'official-link disclosure missing'
            assert 'commission' not in report.lower().split('current wallet annual value')[0].split('official issuer link')[0], \
                'an affiliate disclosure appeared without a partner link'

            # 4. Saving requires an account, and the draft survives the round trip.
            page.get_by_role('button', name='Create an account to save my plan').click()
            expect(page).to_have_url(re.compile(r'.*#/welcome'), timeout=30000)
            expect(page.get_by_text('Build your strategy', exact=True)).to_be_visible()
            # Let the animated form swap finish so Flutter attaches its input
            # channel before values are injected.
            page.wait_for_timeout(600)
            fill_field(page, 0, email)
            fill_field(page, 1, password)
            expect(page.get_by_role('textbox').nth(0)).to_have_value(email)
            page.get_by_role('button', name='Create account', exact=True).click()

            # 5. The plan is saved: same strategy, and the owned card is in the wallet.
            expect(page).to_have_url(re.compile(r'.*#/(home|questionnaire)$'), timeout=30000)
            page.goto(WEB + '/#/strategy-report')
            enable_accessibility(page)
            expect(page.get_by_text(re.compile(r'S0[1-9] STRATEGY'))).to_be_visible(timeout=30000)
            saved_report = page.inner_text('body')
            assert 'Your personal strategy preview' not in saved_report, \
                'the saved plan still claims to be a guest preview'
            assert 'Create an account to save my plan' not in saved_report, \
                'a saved plan still asks for an account'
            assert recommended in saved_report, \
                f'saved plan lost the next move: {recommended}'
            assert re.search(r'Recommended next: ' + re.escape(recommended), saved_report), \
                'saved plan does not restate the same recommended move'
            page.goto(WEB + '/#/strategy')
            enable_accessibility(page)
            expect(page.get_by_text('YOUR RECOMMENDED STRATEGY')).to_be_visible(timeout=30000)
            page.goto(WEB + '/#/cards')
            enable_accessibility(page)
            expect(page.get_by_text('Sapphire Preferred').first).to_be_visible(timeout=30000)

            # 6. The plan does not leak back into the demo profile after sign-out.
            page.goto(WEB + '/#/profile')
            enable_accessibility(page)
            page.get_by_role('button', name='Log out', exact=True).click()
            expect(page).to_have_url(re.compile(r'.*#/welcome$'), timeout=30000)
            page.goto(WEB + '/#/questionnaire')
            enable_accessibility(page)
            expect(page.get_by_text('What adult life stage fits best?')).to_be_visible(timeout=30000)
            assert not page.get_by_text('Sapphire Preferred').is_visible(), \
                'signed-out visitor still sees the saved wallet'

            page.goto(WEB + '/#/account-recovery')
            enable_accessibility(page)
            page.wait_for_timeout(300)
            browser.close()
            if errors:
                raise AssertionError('Browser runtime errors: ' + '; '.join(errors))
        print('Onboarding smoke passed: guest preview before sign-up, no pre-answered '
              'questions, owned card saved and not recommended, plan restored, and '
              'signed-out visitors see no private data. Recommended next move was '
              f'{recommended!r}.')
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


if __name__ == '__main__':
    main()
