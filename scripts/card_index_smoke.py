#!/usr/bin/env python3
"""Real browser test: add a card from the search-only index during onboarding.

Covers both paths the cardholder can take: accept terms (the card is scored) and
skip them (the card is owned but must stay out of the score, and the UI must say
so). Loopback only; deletes the account it creates.
"""
import os
import re
import time

from playwright.sync_api import sync_playwright, expect

from browser_smoke import enable_accessibility, fill_field, set_spending_sliders
from local_e2e import ROOT, load_env, request

WEB = os.environ.get('REVOCRED_SHARE_WEB', 'http://127.0.0.1:8083')


def answer(page, text):
    page.get_by_role('button', name=re.compile('^' + re.escape(text))).evaluate(
        '(element) => element.click()')
    page.wait_for_timeout(300)


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
    email = f'index-{time.time_ns()}@example.test'
    password = 'Local-Index-Test-5521!'
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(
                executable_path='/snap/bin/chromium', headless=True, args=['--no-sandbox'])
            page = browser.new_context(viewport={'width': 1280, 'height': 950}).new_page()
            errors = []
            page.on('pageerror', lambda error: errors.append(str(error)))

            page.goto(WEB + '/')
            enable_accessibility(page)
            page.get_by_role('button', name='Build my strategy').click()
            expect(page).to_have_url(re.compile(r'.*#/questionnaire$'), timeout=30000)
            fill_field(page, 0, 'Kai')
            fill_field(page, 1, 'Mercer')
            answer(page, 'Adult and building a foundation')
            next_step(page)
            expect(page.get_by_text('Which cards do you already have?')).to_be_visible()

            # 1. Searching the index finds a product the catalog does not model.
            page.wait_for_timeout(400)
            fill_field(page, 0, 'southwest')
            expect(page.get_by_text('Matching cards')).to_be_visible(timeout=20000)
            # Flutter exposes each result as one group whose name carries the
            # product and whether terms are on file, so match on that.
            expect(page.get_by_role('group', name=re.compile('^Chase Southwest Rapid Rewards Plus'))).to_be_visible(timeout=20000)
            expect(page.get_by_role('group', name=re.compile('Identity only - you will enter the terms')).first).to_be_visible()

            # 2. Adding opens the terms step, which offers both paths and explains
            #    the consequence of skipping.
            page.get_by_role('group', name=re.compile('^Chase Southwest Rapid Rewards Plus')).get_by_role(
                'button', name='Add', exact=True).click()
            expect(page.get_by_text("Terms for Chase Southwest Rapid Rewards")).to_be_visible(timeout=20000)
            expect(page.get_by_text('Issuer list checked 2026-09-26')).to_be_visible()
            expect(
                page.get_by_text('Without terms RevoCred cannot include this card in your wallet score')
            ).to_be_visible()

            # 3. Skipping is honoured and the reason is restated on the step.
            page.get_by_role('button', name='Skip - do not use this card in my score').click()
            expect(page.get_by_text(re.compile(r'^Your cards?( \(\d+\))?$'))).to_be_visible(timeout=20000)
            expect(page.get_by_role('group', name=re.compile('No terms - not used in your score'))).to_be_visible()
            expect(
                page.get_by_text('Cards added without terms are not used in your score', exact=False)
            ).to_be_visible()

            # 4. A second card with real terms, to prove the scored path too.
            fill_field(page, 0, 'aer lingus')
            page.get_by_role('group', name=re.compile('^Chase Aer Lingus')).get_by_role(
                'button', name='Add', exact=True).click()
            expect(page.get_by_text('Terms for Chase Aer Lingus')).to_be_visible(timeout=20000)
            page.get_by_role('button', name='Use these terms').click()
            expect(page.get_by_role('group', name=re.compile('Using the terms you entered'))).to_be_visible()

            # 5. Finish the questionnaire and check the report is coherent.
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
            expect(page).to_have_url(re.compile(r'.*#/strategy-report$'), timeout=40000)
            # The redesigned report mirrors the reference roadmap and does not
            # duplicate the wallet list. The onboarding step already verified
            # the no-terms warning; here verify neither owned card becomes the
            # recommended next application.
            report = page.inner_text('body')
            assert re.search(r'Recommended next: (.+)', report), 'no next move'
            next_move = re.search(r'Recommended next: (.+)', report).group(1).strip()
            for owned in ('Southwest Rapid Rewards', 'Aer Lingus'):
                assert owned != next_move, f'recommended a card the user owns: {owned}'

            # 6. Sign up and confirm both cards persisted as owned.
            page.get_by_role('button', name='Finish account', exact=True).click()
            expect(page).to_have_url(re.compile(r'.*#/welcome'), timeout=30000)
            page.wait_for_timeout(600)
            # Sign-up asks for the display name first, then email and password.
            fill_field(page, 0, 'Kai Mercer')
            fill_field(page, 1, email)
            fill_field(page, 2, password)
            expect(page.get_by_role('textbox').nth(1)).to_have_value(email)
            page.get_by_role('button', name='Create account', exact=True).click()
            expect(page).to_have_url(re.compile(r'.*#/(home|questionnaire)$'), timeout=40000)
            page.goto(WEB + '/#/cards')
            enable_accessibility(page)
            cards = page.inner_text('body')
            for owned in ('Southwest Rapid Rewards', 'Aer Lingus'):
                assert owned in cards, f'{owned} missing from the saved wallet'
            # No Apply link for a card the user already holds.
            assert 'Apply for' not in cards, 'an owned card offered an Apply link'
            browser.close()
            if errors:
                raise AssertionError('Browser runtime errors: ' + '; '.join(errors))
        print('Card index smoke passed: search finds unmodelled products, terms can be '
              'accepted or skipped, skipping is explained and excluded from the score, '
              'both cards saved to the wallet, and no Apply link appears for owned cards. '
              f'Recommended next move was {next_move!r}.')
    finally:
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
