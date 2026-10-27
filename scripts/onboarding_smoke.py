#!/usr/bin/env python3
"""Real browser test of guest onboarding, plan saving and account deletion.

Runs only against loopback local services. Creates and deletes only its own
throwaway account. Requires `make local-preview` and requirements-browser.txt.
"""
import os
import re
import time

from playwright.sync_api import sync_playwright, expect

from browser_smoke import enable_accessibility, fill_field, set_spending_sliders
from local_e2e import ROOT, load_env, request

# A shared tunnel run overrides all three so the same assertions cover the
# public origin, not just loopback.
WEB = os.environ.get('REVOCRED_SHARE_WEB', 'http://127.0.0.1:8083')


def answer(page, text):
    # Flutter exposes each choice as a semantics button whose label is the
    # option text repeated once, so match the leading label only.
    page.get_by_role('button', name=re.compile('^' + re.escape(text))).evaluate(
        '(element) => element.click()')
    page.wait_for_timeout(300)


def select_card(page, text):
    page.get_by_role('checkbox', name=re.compile('^' + re.escape(text))).click()


def next_step(page):
    # Flutter can leave a slider semantics node over the fixed footer while a
    # thumb is focused, so activate the already-enabled footer button directly.
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
            fill_field(page, 0, 'Dana')
            fill_field(page, 1, 'Okafor')
            answer(page, 'Adult and building a foundation')
            expect(next_button).to_be_enabled()

            next_step(page)
            expect(page.get_by_text('Which cards do you already have?')).to_be_visible()
            fill_field(page, 0, 'amex')
            expect(page.get_by_role('group', name=re.compile('^American Express Blue Cash Everyday'))).to_be_visible(timeout=20000)
            fill_field(page, 0, '')
            select_card(page, 'Sapphire Preferred')
            expect(page.get_by_role('checkbox', name=re.compile('^Sapphire Preferred')).first).to_be_checked()
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
            expect(page.get_by_text('What is your primary rewards goal?')).to_be_visible()
            answer(page, 'Flexible travel points')
            page.get_by_role('button', name='Build my strategy', exact=True).click()

            # 3. A personal plan is shown without an account, and it is not demo data.
            expect(page).to_have_url(re.compile(r'.*#/strategy-report$'), timeout=30000)
            expect(page.get_by_text('Your personal strategy preview')).to_have_count(0)
            expect(page.get_by_role('button', name='Create an account to save my plan')).to_have_count(0)
            report = page.inner_text('body')
            assert re.search(r'S0[1-9] STRATEGY', report), 'strategy code missing from preview'
            next_move = re.search(r'Consider next: ([^\n—]+)', report)
            assert next_move, 'preview does not name a recommended next move'
            recommended = next_move.group(1).strip()
            assert recommended != 'Sapphire Preferred', \
                f'preview recommended an owned card: {recommended}'
            # The Apply button attaches after the async offers request, so wait
            # for the disclosure rather than assuming it rendered immediately.
            expect(page.get_by_text(re.compile('Official issuer link'))).to_be_visible(timeout=30000)
            report = page.inner_text('body')
            # An owned card can be outside the selected playbook, so its name in
            # the profile summary does not imply it has a roadmap column.
            assert '1 cards currently in your wallet' in report, \
                'the preview lost the selected owned card'
            assert 'Official issuer link' in report, 'official-link disclosure missing'
            assert 'commission' not in report.lower().split('current wallet annual value')[0].split('official issuer link')[0], \
                'an affiliate disclosure appeared without a partner link'

            # 4. Saving requires an account, and the draft survives the round trip.
            assert page.get_by_role('button', name='Back to settings', exact=True).count() == 0
            page.get_by_role('button', name='Finish account', exact=True).click()
            expect(page).to_have_url(re.compile(r'.*#/welcome'), timeout=30000)
            page.get_by_role('button', name='Back', exact=True).click()
            expect(page).to_have_url(re.compile(r'.*#/strategy-report$'), timeout=30000)
            expect(page.get_by_text('YOUR WALLET SCORE')).to_be_visible()
            page.get_by_role('button', name='Finish account', exact=True).click()
            expect(page).to_have_url(re.compile(r'.*#/welcome'), timeout=30000)
            page.go_back()
            expect(page).to_have_url(re.compile(r'.*#/strategy-report$'), timeout=30000)
            expect(page.get_by_text('YOUR WALLET SCORE')).to_be_visible()
            page.get_by_role('button', name='Finish account', exact=True).click()
            expect(page.get_by_text('Finish creating your account', exact=True)).to_be_visible()
            # Let the animated form swap finish so Flutter attaches its input
            # channel before values are injected.
            page.wait_for_timeout(600)
            # Sign-up asks for a name before anything else.
            # Sign-up asks for the display name first, then email and password.
            fill_field(page, 0, 'Dana Okafor')
            fill_field(page, 1, email)
            fill_field(page, 2, password)
            preference = page.get_by_role('checkbox', name=re.compile('Email me RevoCred updates'))
            expect(preference).not_to_be_checked()
            preference.evaluate('(element) => element.click()')
            expect(preference).to_be_checked()
            expect(page.get_by_role('textbox').nth(1)).to_have_value(email)
            page.get_by_role('button', name='Create account', exact=True).click()

            # 5. The plan is saved: same strategy, and the owned card is in the wallet.
            expect(page).to_have_url(re.compile(r'.*#/(home|questionnaire)$'), timeout=30000)
            _, signed_in = request(auth + '/auth/v1/token?grant_type=password', 'POST', {'email': email, 'password': password}, public)
            assert signed_in['user']['user_metadata']['email_notifications_opt_in'] is True, 'notification consent was not persisted'
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
            assert re.search(r'Consider next: ' + re.escape(recommended), saved_report), \
                'saved plan does not restate the same recommended move'
            page.goto(WEB + '/#/strategy')
            enable_accessibility(page)
            expect(page.get_by_text("Dana’s Personalized Credit Card Strategy")).to_be_visible(timeout=30000)
            page.goto(WEB + '/#/cards')
            enable_accessibility(page)
            expect(page.get_by_text('Sapphire Preferred').first).to_be_visible(timeout=30000)

            # 5b. The name asked for at sign-up is the name the app greets.
            page.goto(WEB + '/#/home')
            enable_accessibility(page)
            expect(page.get_by_text('Hello, Dana', exact=False)).to_be_visible(timeout=30000)
            assert 'Alex' not in page.inner_text('body'), 'a placeholder name is still shown'

            # 6. The plan does not leak back into the demo profile after sign-out.
            page.goto(WEB + '/#/profile')
            enable_accessibility(page)
            page.get_by_role('button', name='Log out', exact=True).click()
            expect(page).to_have_url(re.compile(r'.*#/welcome$'), timeout=30000)
            for path in ('home', 'cards', 'strategy', 'revo', 'profile', 'account', 'strategy-report'):
                page.goto(WEB + '/#/' + path)
                enable_accessibility(page)
                expect(page).to_have_url(re.compile(r'.*#/welcome$'), timeout=30000)
                assert 'Dana' not in page.inner_text('body'), 'private name visible after logout'
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
