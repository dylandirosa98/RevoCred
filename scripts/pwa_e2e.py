#!/usr/bin/env python3
"""Comprehensive end-to-end Playwright QA suite for the RevoCred Flutter PWA.

Covers:
  1. Guest -> questionnaire -> personal preview strategy report -> sign up ->
     email confirmation / login -> plan carry-over.
  2. Wallet management on web: search OpenCard index, add card with custom
     terms, add card skipping terms, remove card, verify wallet score updates.
  3. PDF download & Web Share fallback (`strategy_report_delivery_web.dart`):
     real non-empty `%PDF-` blob downloads without runtime errors.
  4. REVO chat on web: consent sheet (Cancel / Basic / Agree), basic reply
     rendering, external HTTPS link opening in a new tab, chat clear.
  5. Account lifecycle on web: password recovery via emailed PKCE link
     (`/?recovery=true`), session persistence across full reload, JSON export
     download, and password-reauthenticated account deletion.
  6. Mobile PWA (390x844), tablet (768x1024), dark mode (`prefers-color-scheme:
     dark`), large text, bottom nav bounds, modal sheet ergonomics, and clean
     back/URL navigation.

Modes:
  --mode local          Run against local Supabase + Mailpit + Go API + local
                        Flutter web build (`.env.local`, loopback-only).
  --mode self-contained Spin up a faithful loopback GoTrue PKCE + Mailpit +
                        RevoCred API harness and compile/serve the real-mode
                        release Flutter web build on 127.0.0.1. Requires no
                        Docker daemon and never touches production.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import http.server
import json
import os
from pathlib import Path
import re
import secrets
import socket
import socketserver
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import uuid

from playwright.sync_api import expect, sync_playwright

from browser_smoke import (
    assert_loopback_or_share,
    enable_accessibility,
    extract_verify_link,
    fill_field,
    fill_labeled_field,
    latest_email,
    launch_chromium,
    set_spending_sliders,
)
from local_e2e import ROOT, load_env, request


def free_port() -> int:
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


def make_jwt(user_id: str, email: str) -> str:
    def b64(data: dict) -> str:
        raw = json.dumps(data, separators=(',', ':')).encode('utf-8')
        return base64.urlsafe_b64encode(raw).decode('ascii').rstrip('=')

    now = int(time.time())
    header = b64({'alg': 'HS256', 'typ': 'JWT'})
    payload = b64({
        'aud': 'authenticated',
        'role': 'authenticated',
        'sub': user_id,
        'email': email,
        'iat': now,
        'exp': now + 3600,
    })
    sig = b64({'sig': secrets.token_hex(8)})
    return f'{header}.{payload}.{sig}'


def _catalog_fixture() -> list[dict]:
    return [
        {
            'id': '20000000-0000-4000-8000-000000000001',
            'issuer': 'Chase',
            'network': 'Visa',
            'name': 'Sapphire Preferred',
            'annual_fee_cents': 9500,
            'best_use': 'Travel portal and transfer partners',
            'reward_rates': {'dining': 3, 'travel': 2, 'streaming': 3, 'other': 1},
            'benefits': ['Primary rental car insurance', '$50 annual hotel credit'],
            'transferable_points': True,
            'minimum_credit_tier': 'good',
            'rewards_type': 'travel',
        },
        {
            'id': '20000000-0000-4000-8000-000000000002',
            'issuer': 'Chase',
            'network': 'Visa',
            'name': 'Freedom Unlimited',
            'annual_fee_cents': 0,
            'best_use': 'Everyday catch-all in the Chase ecosystem',
            'reward_rates': {'dining': 3, 'drugstores': 3, 'other': 1.5},
            'benefits': ['No annual fee', 'Purchase protection'],
            'transferable_points': True,
            'minimum_credit_tier': 'good',
            'rewards_type': 'hybrid',
        },
        {
            'id': '20000000-0000-4000-8000-000000000003',
            'issuer': 'Chase',
            'network': 'Mastercard',
            'name': 'Freedom Flex',
            'annual_fee_cents': 0,
            'best_use': 'Rotating categories and dining',
            'reward_rates': {'dining': 3, 'drugstores': 3, 'other': 1},
            'benefits': ['Cell phone protection', 'No annual fee'],
            'transferable_points': True,
            'minimum_credit_tier': 'good',
            'rewards_type': 'hybrid',
        },
        {
            'id': '20000000-0000-4000-8000-000000000004',
            'issuer': 'American Express',
            'network': 'Amex',
            'name': 'Blue Cash Everyday',
            'annual_fee_cents': 0,
            'best_use': 'U.S. supermarkets and online retail',
            'reward_rates': {'groceries': 3, 'gas': 3, 'other': 1},
            'benefits': ['No annual fee'],
            'transferable_points': False,
            'minimum_credit_tier': 'good',
            'rewards_type': 'cash_back',
        },
        {
            'id': '20000000-0000-4000-8000-000000000005',
            'issuer': 'Capital One',
            'network': 'Visa',
            'name': 'Venture X',
            'annual_fee_cents': 39500,
            'best_use': 'Premium travel catch-all and portal spend',
            'reward_rates': {'travel': 2, 'other': 2},
            'benefits': ['$300 annual travel credit', 'Airport lounge access'],
            'transferable_points': True,
            'minimum_credit_tier': 'excellent',
            'rewards_type': 'travel',
        },
        {
            'id': '20000000-0000-4000-8000-000000000006',
            'issuer': 'Capital One',
            'network': 'Mastercard',
            'name': 'SavorOne',
            'annual_fee_cents': 0,
            'best_use': 'Dining, groceries, and entertainment',
            'reward_rates': {'dining': 3, 'groceries': 3, 'streaming': 3, 'other': 1},
            'benefits': ['No annual fee', 'No foreign transaction fees'],
            'transferable_points': False,
            'minimum_credit_tier': 'good',
            'rewards_type': 'cash_back',
        },
    ]


def _index_fixture() -> list[dict]:
    return [
        {
            'id': 'ref-discover-it-miles',
            'issuer': 'Discover',
            'name': 'Discover it Miles',
            'network': 'Discover',
            'rewards_type': 'travel',
            'annual_fee_cents': 0,
            'reward_rates': {'other': 1.5},
            'terms_status': 'verified',
            'source_url': 'https://www.discover.com/credit-cards/travel/',
            'source_captured_on': '2026-10-01',
        },
        {
            'id': 'ref-citi-custom-cash',
            'issuer': 'Citi',
            'name': 'Citi Custom Cash',
            'network': 'Mastercard',
            'rewards_type': 'cash_back',
            'annual_fee_cents': 0,
            'reward_rates': {'groceries': 5, 'other': 1},
            'terms_status': 'verified',
            'source_url': 'https://www.citi.com/credit-cards/citi-custom-cash-credit-card',
            'source_captured_on': '2026-10-01',
        },
        {
            'id': 'ref-discover-student-chrome',
            'issuer': 'Discover',
            'name': 'Discover it Chrome',
            'network': 'Discover',
            'rewards_type': 'cash_back',
            'annual_fee_cents': 0,
            'reward_rates': {},
            'terms_status': 'partial',
            'source_url': '',
            'source_captured_on': '',
        },
    ]


class LocalHarnessState:
    """In-memory state for self-contained GoTrue + Mailpit + RevoCred API."""

    DISCLOSURE_VERSION = hashlib.sha256(b'revocred-pwa-e2e-disclosure-v1').hexdigest()

    def __init__(self, auth_base: str, api_base: str, *, require_confirmation: bool = True):
        self.lock = threading.Lock()
        self.auth_base = auth_base.rstrip('/')
        self.api_base = api_base.rstrip('/')
        self.require_confirmation = require_confirmation
        self.catalog = _catalog_fixture()
        self.index = _index_fixture()
        self.users: dict[str, dict] = {}
        self.users_by_email: dict[str, str] = {}
        self.tokens: dict[str, str] = {}
        self.refresh_tokens: dict[str, str] = {}
        self.verify_tokens: dict[str, dict] = {}
        self.pkce_codes: dict[str, dict] = {}
        self.emails: list[dict] = []
        self.offers = [
            {
                'id': '30000000-0000-4000-8000-000000000002',
                'card_id': '20000000-0000-4000-8000-000000000002',
                'is_affiliate': False,
                'ends_at': '2099-12-31T23:59:59Z',
            },
            {
                'id': '30000000-0000-4000-8000-000000000003',
                'card_id': '20000000-0000-4000-8000-000000000003',
                'is_affiliate': False,
                'ends_at': '2099-12-31T23:59:59Z',
            },
        ]

    def _wallet_score(self, wallet: list[dict]) -> int:
        scored = [w['card'] for w in wallet if not w['card'].get('terms_unknown')]
        if not scored:
            return 18
        score = 22
        max_dining = max((float(c.get('reward_rates', {}).get('dining', 1)) for c in scored), default=1.0)
        max_groceries = max((float(c.get('reward_rates', {}).get('groceries', 1)) for c in scored), default=1.0)
        max_travel = max((float(c.get('reward_rates', {}).get('travel', 1)) for c in scored), default=1.0)
        max_other = max((float(c.get('reward_rates', {}).get('other', 1)) for c in scored), default=1.0)
        score += min(18, int(max_dining * 5))
        score += min(18, int(max_groceries * 4))
        score += min(15, int(max_travel * 5))
        score += min(15, int(max_other * 7))
        if any(c.get('transferable_points') for c in scored):
            score += 10
        return min(98, score)

    def _build_playbook(self, wallet: list[dict], strategy_code: str = 'S04') -> dict:
        owned_names = {w['card']['name']: w['card']['id'] for w in wallet}
        plan_cards = [
            ('Freedom Unlimited', 'Everyday catch-all in the Chase ecosystem', '20000000-0000-4000-8000-000000000002'),
            ('Freedom Flex', 'Rotating categories and dining', '20000000-0000-4000-8000-000000000003'),
            ('Sapphire Preferred', 'Travel portal and transfer partners', '20000000-0000-4000-8000-000000000001'),
        ]
        steps = []
        next_card = ''
        for name, use, cid in plan_cards:
            if name in owned_names:
                steps.append({
                    'name': name,
                    'use': use,
                    'status': 'have',
                    'covered_by': name,
                    'card_id': cid,
                })
            elif not next_card:
                next_card = name
                steps.append({
                    'name': name,
                    'use': use,
                    'status': 'next',
                    'card_id': cid,
                    'timing': 'Consider now, after checks',
                    'timing_note': 'Verify eligibility and budget first.',
                })
            else:
                steps.append({
                    'name': name,
                    'use': use,
                    'status': 'later',
                    'card_id': cid,
                    'timing': 'Wait 3-6 months',
                    'timing_note': 'Re-evaluate after your previous application.',
                })
        return {
            'code': strategy_code,
            'title': 'Flexible travel foundation',
            'ecosystem': 'Chase',
            'next_card': next_card,
            'steps': steps,
            'unused_cards': [],
            'alternatives': [],
        }

    def _build_purchase_guide(self, wallet: list[dict]) -> dict:
        categories = []
        for cid, label in (('dining', 'Dining'), ('groceries', 'Groceries'), ('travel', 'Travel'), ('gas', 'Gas'), ('other', 'General purchases')):
            options = []
            for item in wallet:
                card = item['card']
                if card.get('terms_unknown'):
                    continue
                rate = float(card.get('reward_rates', {}).get(cid, card.get('reward_rates', {}).get('other', 1)))
                options.append({
                    'card_id': card['id'],
                    'card_name': card['name'],
                    'rate': rate,
                    'cash_equivalent_rate': rate,
                    'earn_label': f'{rate:g}x on {label.lower()}',
                    'reason': f'{card["name"]} earns {rate:g}x in this category.',
                    'conditions': [],
                    'source': 'Issuer terms',
                    'last_verified': '2026-10-01',
                })
            options.sort(key=lambda o: o['rate'], reverse=True)
            categories.append({
                'id': cid,
                'label': label,
                'options': options,
                'fallback_options': [],
                'conditional': [],
                'unknown': [],
                'unknown_card_ids': [],
                'assumptions': 'Educational estimate valuing points at 1 cent.',
                'tied': len(options) > 1 and options[0]['rate'] == options[1]['rate'],
            })
        return {
            'settings': {'travel_mode': 'general', 'caps_available': True},
            'travel_modes': [
                {'id': 'general', 'label': 'General travel'},
                {'id': 'portal', 'label': 'Issuer travel portal'},
            ],
            'categories': categories,
        }

    def build_plan_payload(self, answers: dict, wallet: list[dict], profile_name: str, email: str) -> dict:
        playbook = self._build_playbook(wallet, 'S04')
        next_card_name = playbook['next_card'] or 'Freedom Unlimited'
        next_card = next((c for c in self.catalog if c['name'] == next_card_name), self.catalog[1])
        score = self._wallet_score(wallet)
        yearly = max(120, score * 8)
        return {
            'profile': {
                'display_name': profile_name,
                'credit_card_strategy': 'S04',
                'goal': 'Flexible travel points',
                'top_spend_categories': 'Dining, Groceries, Other',
                'next_application_target': next_card['name'],
                'email': email,
            },
            'wallet': wallet,
            'catalog': self.catalog,
            'playbook': playbook,
            'latest_questionnaire': answers,
            'latest_recommendations': {
                'run_id': str(uuid.uuid4()),
                'strategy_code': 'S04',
                'engine_version': 'v1-e2e',
                'dataset_version': '2026-11',
                'items': [
                    {
                        'card_id': next_card['id'],
                        'card_name': next_card['name'],
                        'ongoing_annual_estimate_cents': yearly * 100,
                        'first_year_estimate_cents': yearly * 100,
                        'reasons': ['Fills the next open slot in your S04 strategy.'],
                    }
                ],
            },
            'wallet_metrics': {
                'score': score,
                'yearly_value': yearly,
                'ongoing_value': {
                    'rewards_cents': (yearly + 95) * 100,
                    'credits_cents': 0,
                    'anniversary_cents': 0,
                    'fees_cents': 9500 if any(w['card']['annual_fee_cents'] > 0 for w in wallet) else 0,
                    'total_cents': yearly * 100,
                    'model_version': 'ongoing-v1',
                    'benefits': [],
                    'assumptions': ['Points valued at 1 cent each.'],
                },
            },
            'quick_prompts': [
                'What card should I use for groceries?',
                'Explain my next card move',
            ],
            'chat_mode': 'external_ai',
            'purchase_guide': self._build_purchase_guide(wallet),
        }

    def issue_session(self, user: dict) -> dict:
        access = make_jwt(user['id'], user['email'])
        refresh = 'ref-' + secrets.token_urlsafe(24)
        self.tokens[access] = user['id']
        self.refresh_tokens[refresh] = user['id']
        return {
            'access_token': access,
            'refresh_token': refresh,
            'token_type': 'bearer',
            'expires_in': 3600,
            'expires_at': int(time.time()) + 3600,
            'user': {
                'id': user['id'],
                'aud': 'authenticated',
                'role': 'authenticated',
                'email': user['email'],
                'created_at': user['created_at'],
                'email_confirmed_at': user['confirmed_at'],
                'app_metadata': {'provider': 'email'},
                'user_metadata': user['user_metadata'],
            },
        }

    def add_email(self, to_email: str, subject: str, link: str) -> None:
        msg_id = str(uuid.uuid4())
        self.emails.insert(0, {
            'ID': msg_id,
            'To': [{'Address': to_email}],
            'Subject': subject,
            'HTML': f'<p>{subject}</p><p><a href="{link}">Confirm link</a></p>',
            'Text': f'{subject}: {link}',
        })


class _HarnessServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def start_self_contained_harness(
    web_dir: Path,
    *,
    require_confirmation: bool = True,
    auth_port: int = 0,
    api_port: int = 0,
    web_port: int = 0,
):
    """Start loopback GoTrue+Mailpit, RevoCred API, and static web servers."""
    auth_port = auth_port or free_port()
    api_port = api_port or free_port()
    web_port = web_port or free_port()
    auth_base = f'http://127.0.0.1:{auth_port}'
    api_base = f'http://127.0.0.1:{api_port}'
    web_base = f'http://127.0.0.1:{web_port}'
    state = LocalHarnessState(auth_base, api_base, require_confirmation=require_confirmation)

    class CombinedHandler(http.server.BaseHTTPRequestHandler):
        protocol_version = 'HTTP/1.1'

        def log_message(self, format, *args):
            return

        def _send_json(self, code: int, payload, extra_headers: dict[str, str] | None = None):
            body = b'' if payload is None else json.dumps(payload).encode('utf-8')
            self.send_response(code)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Access-Control-Allow-Headers', '*')
            self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
            if payload is not None:
                self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            for k, v in (extra_headers or {}).items():
                self.send_header(k, v)
            self.end_headers()
            if body:
                self.wfile.write(body)

        def _send_redirect(self, location: str):
            self.send_response(302)
            self.send_header('Location', location)
            self.send_header('Content-Length', '0')
            self.end_headers()

        def _read_json(self) -> dict:
            length = int(self.headers.get('Content-Length', '0') or '0')
            if length <= 0:
                return {}
            raw = self.rfile.read(length)
            return json.loads(raw.decode('utf-8')) if raw else {}

        def _bearer_user(self) -> dict | None:
            auth_header = self.headers.get('Authorization', '')
            if not auth_header.startswith('Bearer '):
                return None
            token = auth_header[7:].strip()
            with state.lock:
                uid = state.tokens.get(token)
                return state.users.get(uid) if uid else None

        def do_OPTIONS(self):
            self._send_json(204, None)

        def do_GET(self):
            parsed = urllib.parse.urlparse(self.path)
            path = parsed.path
            query = urllib.parse.parse_qs(parsed.query)

            # Mailpit-compatible endpoints
            if path == '/api/v1/search':
                q = query.get('query', [''])[0]
                target = q[3:].lower() if q.startswith('to:') else q.lower()
                with state.lock:
                    matched = [
                        {'ID': m['ID'], 'Subject': m['Subject'], 'To': m['To']}
                        for m in state.emails
                        if any(target in t['Address'].lower() for t in m['To'])
                    ]
                self._send_json(200, {'messages': matched})
                return
            if path.startswith('/api/v1/message/'):
                mid = path.split('/')[-1]
                with state.lock:
                    msg = next((m for m in state.emails if m['ID'] == mid), None)
                if not msg:
                    self._send_json(404, {'error': 'not found'})
                    return
                self._send_json(200, msg)
                return

            # GoTrue endpoints
            if path == '/auth/v1/user':
                user = self._bearer_user()
                if not user:
                    self._send_json(401, {'msg': 'Invalid token'})
                    return
                self._send_json(200, {
                    'id': user['id'],
                    'aud': 'authenticated',
                    'role': 'authenticated',
                    'email': user['email'],
                    'created_at': user['created_at'],
                    'email_confirmed_at': user['confirmed_at'],
                    'app_metadata': {'provider': 'email'},
                    'user_metadata': user['user_metadata'],
                })
                return
            if path == '/auth/v1/verify':
                tok = query.get('token', [''])[0]
                kind = query.get('type', [''])[0]
                redirect_to = query.get('redirect_to', [web_base + '/'])[0]
                with state.lock:
                    record = state.verify_tokens.pop(tok, None)
                    if not record or record['type'] != kind:
                        self._send_redirect(redirect_to + '#error=access_denied')
                        return
                    user = state.users.get(record['user_id'])
                    if not user:
                        self._send_redirect(redirect_to + '#error=access_denied')
                        return
                    if kind == 'signup':
                        user['confirmed'] = True
                        user['confirmed_at'] = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
                    code_challenge = record.get('code_challenge', '')
                    if code_challenge:
                        auth_code = 'pkce-' + secrets.token_urlsafe(18)
                        state.pkce_codes[auth_code] = {
                            'user_id': user['id'],
                            'code_challenge': code_challenge,
                            'type': kind,
                        }
                        sep = '&' if '?' in redirect_to else '?'
                        self._send_redirect(f'{redirect_to}{sep}code={urllib.parse.quote(auth_code)}')
                        return
                    session = state.issue_session(user)
                    frag = urllib.parse.urlencode({
                        'access_token': session['access_token'],
                        'refresh_token': session['refresh_token'],
                        'expires_in': '3600',
                        'token_type': 'bearer',
                        'type': kind,
                    })
                    self._send_redirect(f'{redirect_to}#{frag}')
                return

            # RevoCred API GET endpoints
            if path in ('/healthz', '/readyz'):
                self._send_json(200, {'status': 'ok'})
                return
            if path == '/v1/public/cards':
                self._send_json(200, {'data': state.catalog})
                return
            if path == '/v1/public/card-index':
                q = query.get('q', [''])[0].strip().lower()
                results = [
                    c for c in state.index
                    if not q or q in c['name'].lower() or q in c['issuer'].lower()
                ]
                self._send_json(200, {'data': results})
                return
            if path == '/v1/public/chat-disclosure':
                self._send_json(200, {
                    'data': {
                        'external': True,
                        'version': state.DISCLOSURE_VERSION,
                        'recipient': 'Local QA AI Service',
                        'model': 'qa-explainer-v1',
                        'data_use': 'Your wallet cards, spending summary, and question are shared only to explain your deterministic plan.',
                        'data_use_points': [
                            'Wallet card names and spending estimates are sent to answer your question.',
                            'Deterministic rankings and scores remain server-owned.',
                        ],
                        'search_provider': 'Public card terms lookup',
                    }
                })
                return
            if path == '/v1/offers':
                self._send_json(200, {'data': state.offers})
                return
            if path == '/v1/bootstrap':
                user = self._bearer_user()
                if not user:
                    self._send_json(401, {'error': {'message': 'unauthorized'}})
                    return
                with state.lock:
                    if user['questionnaire'] is None:
                        payload = {
                            'profile': {
                                'display_name': user['display_name'],
                                'credit_card_strategy': '',
                                'goal': '',
                                'top_spend_categories': '',
                                'next_application_target': '',
                                'email': user['email'],
                            },
                            'wallet': user['wallet'],
                            'catalog': state.catalog,
                            'wallet_metrics': {'score': state._wallet_score(user['wallet']), 'yearly_value': 0},
                            'quick_prompts': ['What card should I use for groceries?'],
                            'chat_mode': 'external_ai',
                            'purchase_guide': state._build_purchase_guide(user['wallet']),
                        }
                    else:
                        payload = state.build_plan_payload(
                            user['questionnaire'],
                            user['wallet'],
                            user['display_name'],
                            user['email'],
                        )
                self._send_json(200, {'data': payload})
                return
            if path == '/v1/chat/messages':
                user = self._bearer_user()
                if not user:
                    self._send_json(401, {'error': {'message': 'unauthorized'}})
                    return
                with state.lock:
                    self._send_json(200, {'data': list(user['messages'])})
                return
            if path == '/v1/chat/consent':
                user = self._bearer_user()
                if not user:
                    self._send_json(401, {'error': {'message': 'unauthorized'}})
                    return
                with state.lock:
                    self._send_json(200, {'data': user['chat_consent']})
                return
            if path == '/v1/ai-plan':
                user = self._bearer_user()
                if not user:
                    self._send_json(401, {'error': {'message': 'unauthorized'}})
                    return
                self._send_json(200, {
                    'data': {
                        'plan': 'free',
                        'used': 0,
                        'limit': 3,
                        'ai_available': True,
                        'purchases_enabled': False,
                    }
                })
                return
            if path == '/v1/purchase-guide':
                user = self._bearer_user()
                if not user:
                    self._send_json(401, {'error': {'message': 'unauthorized'}})
                    return
                with state.lock:
                    self._send_json(200, {'data': state._build_purchase_guide(user['wallet'])})
                return
            if path == '/v1/account/export':
                user = self._bearer_user()
                if not user:
                    self._send_json(401, {'error': {'message': 'unauthorized'}})
                    return
                with state.lock:
                    self._send_json(200, {
                        'data': {
                            'email': user['email'],
                            'display_name': user['display_name'],
                            'records': {
                                'wallet': user['wallet'],
                                'questionnaire': user['questionnaire'],
                                'chat_messages': user['messages'],
                                'recommendation_runs': [{'strategy_code': 'S04'}] if user['questionnaire'] else [],
                            },
                        }
                    })
                return
            self._send_json(404, {'error': {'message': f'unknown GET {path}'}})

        def do_POST(self):
            parsed = urllib.parse.urlparse(self.path)
            path = parsed.path
            query = urllib.parse.parse_qs(parsed.query)
            body = self._read_json()

            # GoTrue POST endpoints
            if path == '/auth/v1/signup':
                email = str(body.get('email', '')).strip().lower()
                password = str(body.get('password', ''))
                metadata = body.get('data') or {}
                redirect_to = query.get('redirect_to', [web_base + '/'])[0]
                code_challenge = str(body.get('code_challenge', '') or '')
                with state.lock:
                    if email in state.users_by_email:
                        self._send_json(422, {'msg': 'User already registered', 'error_code': 'user_already_exists'})
                        return
                    uid = str(uuid.uuid4())
                    now = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
                    confirmed = not state.require_confirmation
                    user = {
                        'id': uid,
                        'email': email,
                        'password': password,
                        'display_name': str(metadata.get('display_name') or '').strip(),
                        'user_metadata': dict(metadata),
                        'created_at': now,
                        'confirmed': confirmed,
                        'confirmed_at': now if confirmed else None,
                        'wallet': [],
                        'questionnaire': None,
                        'messages': [],
                        'chat_consent': {'granted': False, 'version': ''},
                    }
                    state.users[uid] = user
                    state.users_by_email[email] = uid
                    if confirmed:
                        self._send_json(200, state.issue_session(user))
                    else:
                        tok = secrets.token_urlsafe(24)
                        state.verify_tokens[tok] = {
                            'user_id': uid,
                            'type': 'signup',
                            'code_challenge': code_challenge,
                        }
                        verify_url = (
                            f'{state.auth_base}/auth/v1/verify?'
                            + urllib.parse.urlencode({
                                'token': tok,
                                'type': 'signup',
                                'redirect_to': redirect_to,
                            })
                        )
                        state.add_email(email, 'Confirm your RevoCred account', verify_url)
                        self._send_json(200, {
                            'id': uid,
                            'aud': 'authenticated',
                            'role': 'authenticated',
                            'email': email,
                            'created_at': now,
                            'app_metadata': {'provider': 'email'},
                            'user_metadata': user['user_metadata'],
                            'identities': [{
                                'id': uid,
                                'user_id': uid,
                                'identity_id': uid,
                                'provider': 'email',
                                'identity_data': {'email': email},
                                'created_at': now,
                                'updated_at': now,
                            }],
                        })
                return

            if path == '/auth/v1/token':
                grant = query.get('grant_type', [''])[0]
                with state.lock:
                    if grant == 'password':
                        email = str(body.get('email', '')).strip().lower()
                        password = str(body.get('password', ''))
                        uid = state.users_by_email.get(email)
                        user = state.users.get(uid) if uid else None
                        if not user or user['password'] != password:
                            self._send_json(400, {'error': 'invalid_grant', 'error_description': 'Invalid login credentials', 'msg': 'Invalid login credentials'})
                            return
                        if not user['confirmed']:
                            self._send_json(400, {'error': 'email_not_confirmed', 'msg': 'Email not confirmed'})
                            return
                        self._send_json(200, state.issue_session(user))
                        return
                    if grant == 'pkce':
                        auth_code = str(body.get('auth_code', ''))
                        verifier = str(body.get('code_verifier', ''))
                        rec = state.pkce_codes.pop(auth_code, None)
                        if not rec:
                            self._send_json(400, {'error': 'invalid_grant', 'msg': 'Invalid PKCE code'})
                            return
                        digest = base64.urlsafe_b64encode(
                            hashlib.sha256(verifier.encode('ascii')).digest()
                        ).decode('ascii').rstrip('=')
                        if digest != rec['code_challenge']:
                            self._send_json(400, {'error': 'invalid_grant', 'msg': 'PKCE verifier mismatch'})
                            return
                        user = state.users.get(rec['user_id'])
                        if not user:
                            self._send_json(400, {'error': 'invalid_grant', 'msg': 'User missing'})
                            return
                        self._send_json(200, state.issue_session(user))
                        return
                    if grant == 'refresh_token':
                        ref = str(body.get('refresh_token', ''))
                        uid = state.refresh_tokens.get(ref)
                        user = state.users.get(uid) if uid else None
                        if not user:
                            self._send_json(400, {'error': 'invalid_grant', 'msg': 'Invalid refresh token'})
                            return
                        self._send_json(200, state.issue_session(user))
                        return
                self._send_json(400, {'msg': f'unsupported grant {grant}'})
                return

            if path == '/auth/v1/recover':
                email = str(body.get('email', '')).strip().lower()
                redirect_to = query.get('redirect_to', [web_base + '/?recovery=true'])[0]
                code_challenge = str(body.get('code_challenge', '') or '')
                with state.lock:
                    uid = state.users_by_email.get(email)
                    if uid:
                        tok = secrets.token_urlsafe(24)
                        state.verify_tokens[tok] = {
                            'user_id': uid,
                            'type': 'recovery',
                            'code_challenge': code_challenge,
                        }
                        verify_url = (
                            f'{state.auth_base}/auth/v1/verify?'
                            + urllib.parse.urlencode({
                                'token': tok,
                                'type': 'recovery',
                                'redirect_to': redirect_to,
                            })
                        )
                        state.add_email(email, 'Reset your RevoCred password', verify_url)
                self._send_json(200, {})
                return

            if path == '/auth/v1/logout':
                auth_header = self.headers.get('Authorization', '')
                if auth_header.startswith('Bearer '):
                    with state.lock:
                        state.tokens.pop(auth_header[7:].strip(), None)
                self._send_json(204, None)
                return

            # RevoCred API POST endpoints
            if path == '/v1/public/plan':
                existing_ids = set(body.get('existing_card_ids') or [])
                wallet = [
                    {'id': f'preview-{c["id"]}', 'status': 'active', 'card': c}
                    for c in state.catalog
                    if c['id'] in existing_ids
                ]
                name = str(body.get('display_name') or '').strip()
                payload = state.build_plan_payload(body, wallet, name, '')
                self._send_json(200, {'data': payload})
                return

            if path == '/v1/onboarding':
                user = self._bearer_user()
                if not user:
                    self._send_json(401, {'error': {'message': 'unauthorized'}})
                    return
                with state.lock:
                    user['questionnaire'] = body
                    if str(body.get('display_name') or '').strip():
                        user['display_name'] = str(body['display_name']).strip()
                    existing_ids = set(body.get('existing_card_ids') or [])
                    held_card_ids = {w['card']['id'] for w in user['wallet']}
                    for c in state.catalog:
                        if c['id'] in existing_ids and c['id'] not in held_card_ids:
                            user['wallet'].append({
                                'id': str(uuid.uuid4()),
                                'status': 'active',
                                'card': c,
                            })
                    plan = state.build_plan_payload(body, user['wallet'], user['display_name'], user['email'])
                self._send_json(201, {'data': plan['latest_recommendations']})
                return

            if path == '/v1/wallet':
                user = self._bearer_user()
                if not user:
                    self._send_json(401, {'error': {'message': 'unauthorized'}})
                    return
                card_id = body.get('catalog_card_id')
                card = next((c for c in state.catalog if c['id'] == card_id), None)
                if not card:
                    self._send_json(404, {'error': {'message': 'card not found'}})
                    return
                with state.lock:
                    entry = {'id': str(uuid.uuid4()), 'status': 'active', 'card': card}
                    user['wallet'].append(entry)
                self._send_json(201, {'data': entry})
                return

            if path == '/v1/wallet/custom':
                user = self._bearer_user()
                if not user:
                    self._send_json(401, {'error': {'message': 'unauthorized'}})
                    return
                card = {
                    'id': str(uuid.uuid4()),
                    'issuer': str(body.get('issuer', 'Custom')),
                    'network': str(body.get('network', 'Other')),
                    'name': str(body.get('name', 'Custom Card')),
                    'annual_fee_cents': int(body.get('annual_fee_cents') or 0),
                    'best_use': str(body.get('best_use') or 'Custom card'),
                    'reward_rates': body.get('reward_rates') or {'other': 1},
                    'benefits': body.get('benefits') or [],
                    'transferable_points': bool(body.get('transferable_points')),
                    'terms_unknown': bool(body.get('terms_unknown')),
                    'rewards_type': 'cash_back',
                }
                with state.lock:
                    entry = {'id': str(uuid.uuid4()), 'status': 'active', 'card': card}
                    user['wallet'].append(entry)
                self._send_json(201, {'data': entry})
                return

            if path == '/v1/chat/messages':
                user = self._bearer_user()
                if not user:
                    self._send_json(401, {'error': {'message': 'unauthorized'}})
                    return
                prompt = str(body.get('content', '')).strip()
                consent_ver = body.get('ai_consent_version')
                use_ai = consent_ver == state.DISCLOSURE_VERSION
                now = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
                user_msg = {
                    'id': str(uuid.uuid4()),
                    'role': 'user',
                    'content': prompt,
                    'created_at': now,
                }
                if use_ai:
                    reply_text = (
                        'AI guidance for your S04 plan: pair your Chase cards for dining and everyday spend. '
                        'Review issuer terms at [Chase terms](https://www.chase.com/personal/credit-cards).'
                    )
                    mode = 'ai'
                else:
                    reply_text = (
                        'Basic plan summary: your current strategy is S04. '
                        'Confirm current card terms at [Official issuer guide](https://www.chase.com/personal/credit-cards).'
                    )
                    mode = 'basic'
                assistant_msg = {
                    'id': str(uuid.uuid4()),
                    'role': 'assistant',
                    'mode': mode,
                    'content': reply_text,
                    'blocks': [
                        {'type': 'paragraph', 'text': reply_text},
                    ],
                    'created_at': now,
                }
                with state.lock:
                    user['messages'].extend([user_msg, assistant_msg])
                self._send_json(201, {'data': [user_msg, assistant_msg]})
                return

            if path == '/v1/client-errors':
                self._send_json(204, None)
                return

            self._send_json(404, {'error': {'message': f'unknown POST {path}'}})

        def do_PUT(self):
            parsed = urllib.parse.urlparse(self.path)
            path = parsed.path
            body = self._read_json()

            if path == '/auth/v1/user':
                user = self._bearer_user()
                if not user:
                    self._send_json(401, {'msg': 'Invalid token'})
                    return
                with state.lock:
                    if body.get('password'):
                        user['password'] = str(body['password'])
                    if isinstance(body.get('data'), dict):
                        for k, v in body['data'].items():
                            if v is None:
                                user['user_metadata'].pop(k, None)
                            else:
                                user['user_metadata'][k] = v
                self._send_json(200, {
                    'id': user['id'],
                    'aud': 'authenticated',
                    'role': 'authenticated',
                    'email': user['email'],
                    'created_at': user['created_at'],
                    'email_confirmed_at': user['confirmed_at'],
                    'app_metadata': {'provider': 'email'},
                    'user_metadata': user['user_metadata'],
                })
                return

            if path == '/v1/profile/display-name':
                user = self._bearer_user()
                if not user:
                    self._send_json(401, {'error': {'message': 'unauthorized'}})
                    return
                with state.lock:
                    user['display_name'] = str(body.get('display_name', '')).strip()
                self._send_json(200, {'data': {'display_name': user['display_name']}})
                return

            if path == '/v1/chat/consent':
                user = self._bearer_user()
                if not user:
                    self._send_json(401, {'error': {'message': 'unauthorized'}})
                    return
                ver = str(body.get('version', ''))
                with state.lock:
                    user['chat_consent'] = {'granted': True, 'version': ver}
                self._send_json(200, {'data': user['chat_consent']})
                return

            self._send_json(404, {'error': {'message': f'unknown PUT {path}'}})

        def do_DELETE(self):
            parsed = urllib.parse.urlparse(self.path)
            path = parsed.path
            body = self._read_json()
            user = self._bearer_user()
            if not user:
                self._send_json(401, {'error': {'message': 'unauthorized'}})
                return
            if path == '/v1/wallet':
                wid = body.get('wallet_card_id')
                with state.lock:
                    user['wallet'] = [w for w in user['wallet'] if w['id'] != wid]
                self._send_json(204, None)
                return
            if path == '/v1/chat/messages':
                with state.lock:
                    user['messages'].clear()
                self._send_json(204, None)
                return
            if path == '/v1/chat/consent':
                with state.lock:
                    user['chat_consent'] = {'granted': False, 'version': ''}
                self._send_json(204, None)
                return
            if path == '/v1/account':
                with state.lock:
                    uid = user['id']
                    state.users.pop(uid, None)
                    state.users_by_email.pop(user['email'], None)
                    for tok in [t for t, u in state.tokens.items() if u == uid]:
                        state.tokens.pop(tok, None)
                    for ref in [r for r, u in state.refresh_tokens.items() if u == uid]:
                        state.refresh_tokens.pop(ref, None)
                self._send_json(204, None)
                return
            self._send_json(404, {'error': {'message': f'unknown DELETE {path}'}})

    class StaticHandler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(web_dir), **kwargs)

        def log_message(self, format, *args):
            return

    auth_server = _HarnessServer(('127.0.0.1', auth_port), CombinedHandler)
    api_server = _HarnessServer(('127.0.0.1', api_port), CombinedHandler)
    web_server = _HarnessServer(('127.0.0.1', web_port), StaticHandler)
    threads = [
        threading.Thread(target=srv.serve_forever, daemon=True)
        for srv in (auth_server, api_server, web_server)
    ]
    for t in threads:
        t.start()

    def stop():
        for srv in (web_server, api_server, auth_server):
            srv.shutdown()
            srv.server_close()

    return {
        'auth': auth_base,
        'api': api_base,
        'web': web_base,
        'mailpit': auth_base,
        'anon_key': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiJ9.qa-local',
        'state': state,
        'stop': stop,
    }


def build_web_release(api_url: str, supabase_url: str, anon_key: str, *, redirect_url: str = '') -> Path:
    flutter = os.environ.get('FLUTTER', str(Path.home() / '.local/share/flutter/bin/flutter'))
    cmd = [
        flutter,
        'build',
        'web',
        '--release',
        '--no-web-resources-cdn',
        '--dart-define=REVOCRED_USE_MOCKS=false',
        f'--dart-define=REVOCRED_API_URL={api_url}',
        f'--dart-define=SUPABASE_URL={supabase_url}',
        f'--dart-define=SUPABASE_ANON_KEY={anon_key}',
    ]
    if redirect_url:
        cmd.append(f'--dart-define=REVOCRED_AUTH_REDIRECT_URL={redirect_url}')
    subprocess.run(cmd, cwd=ROOT / 'revocred_flutter', check=True)
    return ROOT / 'revocred_flutter' / 'build' / 'web'


def click_choice(page, text: str):
    page.get_by_role('button', name=re.compile('^' + re.escape(text))).evaluate('(el) => el.click()')
    page.wait_for_timeout(250)


def click_next(page):
    button = page.get_by_role('button', name='Next', exact=True)
    expect(button).to_be_enabled(timeout=15000)
    button.evaluate('(el) => el.click()')
    page.wait_for_timeout(500)


def check_no_overflow_errors(console_errors: list[str], page_errors: list[str], label: str):
    overflows = [m for m in console_errors if 'RenderFlex overflowed' in m or 'overflowed by' in m]
    assert not overflows, f'{label}: Flutter layout overflow errors: {overflows}'
    assert not page_errors, f'{label}: Browser runtime errors: {page_errors}'


def assert_bottom_nav_within_viewport(page, viewport_width: int, viewport_height: int):
    tabs = page.get_by_role('tab')
    count = tabs.count()
    assert count == 5, f'Expected 5 bottom nav tabs, found {count}'
    for i in range(count):
        box = tabs.nth(i).bounding_box()
        assert box is not None, f'Bottom nav tab {i} has no bounding box'
        assert box['x'] >= -1 and box['x'] + box['width'] <= viewport_width + 1, (
            f'Bottom nav tab {i} clipped horizontally: {box} in width {viewport_width}'
        )
        assert box['y'] + box['height'] <= viewport_height + 2, (
            f'Bottom nav tab {i} clipped vertically: {box} in height {viewport_height}'
        )
        assert box['height'] >= 44, f'Bottom nav tab {i} tap height too small: {box["height"]}'


def run_e2e_suite(*, web: str, api: str, auth: str, mailpit: str, anon_key: str) -> dict:
    public = {'apikey': anon_key}
    email = f'pwa-e2e-{time.time_ns()}@example.test'
    original_password = 'Local-PWA-E2E-Password-4921!'
    password = original_password
    deleted = False
    results: dict[str, object] = {'passed': False, 'checks': {}}

    try:
        with sync_playwright() as p:
            browser = launch_chromium(p, headless=True)
            context = browser.new_context(
                viewport={'width': 390, 'height': 844},
                is_mobile=True,
                has_touch=True,
                accept_downloads=True,
            )
            page = context.new_page()
            page_errors: list[str] = []
            console_errors: list[str] = []
            page.on('pageerror', lambda err: page_errors.append(str(err)))
            page.on(
                'console',
                lambda msg: console_errors.append(msg.text) if msg.type == 'error' else None,
            )

            # -----------------------------------------------------------------
            # 1. Guest -> Questionnaire -> Personal Preview -> Sign Up ->
            #    Email Confirmation / Login -> Plan Carry-Over
            # -----------------------------------------------------------------
            page.goto(web + '/')
            enable_accessibility(page)
            page.get_by_role('button', name='Build my strategy').click()
            expect(page).to_have_url(re.compile(r'.*#/questionnaire$'), timeout=30000)
            expect(page.get_by_text('What adult life stage fits best?')).to_be_visible()

            fill_field(page, 0, 'Dana')
            fill_field(page, 1, 'Okafor')
            click_choice(page, 'Adult and building a foundation')
            click_next(page)

            expect(page.get_by_text('Which cards do you already have?')).to_be_visible()
            page.get_by_role('checkbox', name=re.compile('^Sapphire Preferred')).first.click()
            click_next(page)

            click_choice(page, '2–4 cards')
            click_choice(page, 'Up to $300')
            click_next(page)

            click_choice(page, 'Domestic and international')
            click_next(page)

            click_choice(page, 'Good')
            click_next(page)

            expect(page.get_by_text('Estimate your monthly spending')).to_be_visible()
            page.wait_for_timeout(300)
            set_spending_sliders(page, [400, 500, 100, 250, 50, 300])
            click_next(page)

            expect(page.get_by_text('What is your primary rewards goal?')).to_be_visible()
            click_choice(page, 'Flexible travel points')
            page.get_by_role('button', name='Build my strategy', exact=True).click()

            expect(page).to_have_url(re.compile(r'.*#/strategy-report$'), timeout=30000)
            expect(page.get_by_text('YOUR WALLET SCORE')).to_be_visible(timeout=20000)
            preview_text = page.inner_text('body')
            assert 'Sapphire Preferred' in preview_text, 'Owned card missing from guest preview'

            # -----------------------------------------------------------------
            # 3a. PDF Download & Web Share fallback on Strategy Report
            # -----------------------------------------------------------------
            download_btn = page.get_by_role('button', name='Download PDF', exact=True)
            download_btn.scroll_into_view_if_needed()
            with page.expect_download(timeout=30000) as pdf_dl:
                download_btn.click()
            pdf_bytes = Path(pdf_dl.value.path()).read_bytes()
            assert pdf_dl.value.suggested_filename.endswith('.pdf'), pdf_dl.value.suggested_filename
            assert pdf_bytes.startswith(b'%PDF-') and len(pdf_bytes) > 1000, 'Invalid PDF download'

            share_btn = page.get_by_role('button', name='Share', exact=True)
            share_btn.scroll_into_view_if_needed()
            with page.expect_download(timeout=30000) as share_dl:
                share_btn.click()
            share_bytes = Path(share_dl.value.path()).read_bytes()
            assert share_bytes.startswith(b'%PDF-') and len(share_bytes) > 1000, 'Invalid Web Share PDF fallback'
            results['checks']['pdf_download_and_share_fallback'] = {
                'filename': pdf_dl.value.suggested_filename,
                'download_bytes': len(pdf_bytes),
                'share_fallback_bytes': len(share_bytes),
            }

            # Sign up from strategy report
            page.get_by_role('button', name='Finish account', exact=True).click()
            expect(page).to_have_url(re.compile(r'.*#/welcome'), timeout=30000)
            expect(page.get_by_text('Finish creating your account', exact=True)).to_be_visible()
            page.wait_for_timeout(450)
            fill_field(page, 0, 'Dana Okafor')
            fill_field(page, 1, email)
            fill_field(page, 2, password)
            page.get_by_role('button', name='Create account', exact=True).click()

            # Support both confirmation-required and auto-confirm auth configs.
            page.wait_for_timeout(1200)
            if '#/welcome' in page.url:
                expect(page.get_by_text('Check your email', exact=False)).to_be_visible(timeout=20000)
                confirm_msg = latest_email(email, mailpit_url=mailpit, kind='signup')
                assert confirm_msg, 'Confirmation email did not arrive in Mailpit'
                confirm_link = extract_verify_link(
                    confirm_msg,
                    expected_auth_host=urllib.parse.urlparse(auth).hostname or '127.0.0.1',
                    expected_web_origin=web,
                )
                page.goto(confirm_link)
                enable_accessibility(page)
                page.wait_for_timeout(800)
                if '#/welcome' in page.url:
                    # If confirmation did not auto-authenticate, sign in now.
                    if page.get_by_role('button', name='I already have an account').count() > 0:
                        page.get_by_role('button', name='I already have an account').click()
                        page.wait_for_timeout(350)
                    fill_field(page, 0, email)
                    fill_field(page, 1, password)
                    page.get_by_role('button', name='Sign in', exact=True).click()

            expect(page).to_have_url(re.compile(r'.*#/home$'), timeout=30000)
            expect(page.get_by_text('Hello, Dana', exact=False)).to_be_visible(timeout=30000)
            assert_bottom_nav_within_viewport(page, 390, 844)
            results['checks']['guest_onboarding_signup_carryover'] = True

            # Capture initial wallet score via API
            _, session = request(
                auth + '/auth/v1/token?grant_type=password',
                'POST',
                {'email': email, 'password': password},
                public,
            )
            auth_headers = {'Authorization': 'Bearer ' + session['access_token']}
            _, boot0 = request(api + '/v1/bootstrap', headers=auth_headers)
            score_initial = boot0['data']['wallet_metrics']['score']
            assert any(w['card']['name'] == 'Sapphire Preferred' for w in boot0['data']['wallet']), (
                'Owned card did not carry over after signup'
            )

            # -----------------------------------------------------------------
            # 2. Wallet management on web: OpenCard search, add with custom
            #    terms, add skipping terms, remove card, verify score updates
            # -----------------------------------------------------------------
            page.get_by_role('tab', name='Cards', exact=True).click()
            expect(page).to_have_url(re.compile(r'.*#/cards$'), timeout=20000)
            expect(page.get_by_text('Sapphire Preferred', exact=False).first).to_be_visible(timeout=20000)
            page.get_by_role('button', name='Add a card to wallet', exact=True).first.click()
            search = page.get_by_role('textbox').first
            expect(search).to_be_focused(timeout=10000)
            search.fill('Citi Custom')
            citi_row = page.get_by_role('group', name=re.compile(r'^Citi Custom Cash'))
            expect(citi_row).to_be_visible(timeout=20000)
            citi_row.get_by_role('button', name='Add', exact=True).click()

            # Card terms sheet opens -> customize fee & groceries rate -> save
            expect(page.get_by_text('Terms for Citi Custom Cash', exact=False)).to_be_visible(timeout=15000)
            page.wait_for_timeout(300)
            fill_labeled_field(page, 'Annual fee in dollars', '0')
            fill_labeled_field(page, 'groceries', '5')
            use_terms = page.get_by_role('button', name='Use these terms', exact=True)
            use_terms.scroll_into_view_if_needed()
            use_terms.click()
            expect(page.get_by_text('2 ACTIVE', exact=False)).to_be_visible(timeout=20000)

            _, boot_after_terms = request(api + '/v1/bootstrap', headers=auth_headers)
            score_after_terms = boot_after_terms['data']['wallet_metrics']['score']
            assert score_after_terms > score_initial, (
                f'Expected score to increase after adding 5x groceries card: {score_initial} -> {score_after_terms}'
            )

            # Add second OpenCard index card skipping terms
            add_btn = page.get_by_role('button', name='Add a card to wallet', exact=True).first
            for _ in range(8):
                box = add_btn.bounding_box()
                if box and 10 <= box['y'] and box['y'] + box['height'] <= 760:
                    break
                page.mouse.move(195, 400)
                delta = -260 if (box and box['y'] < 10) else 260
                page.mouse.wheel(0, delta)
                page.wait_for_timeout(150)
            add_btn.click()
            search = page.get_by_role('textbox').first
            expect(search).to_be_focused(timeout=10000)
            search.fill('Discover it Chrome')
            discover_row = page.get_by_role('group', name=re.compile(r'^Discover it Chrome'))
            expect(discover_row).to_be_visible(timeout=20000)
            discover_row.get_by_role('button', name='Add', exact=True).click()
            expect(page.get_by_text('Terms for Discover it Chrome', exact=False)).to_be_visible(timeout=15000)
            skip_btn = page.get_by_role('button', name='Skip - do not use this card in my score', exact=True)
            skip_btn.scroll_into_view_if_needed()
            skip_btn.click()
            expect(page.get_by_text('3 ACTIVE', exact=False)).to_be_visible(timeout=20000)

            _, boot_after_skip = request(api + '/v1/bootstrap', headers=auth_headers)
            assert boot_after_skip['data']['wallet_metrics']['score'] == score_after_terms, (
                'Card added with skipped terms should not alter wallet score'
            )

            # Remove a card and verify count + score update.
            # Tap the exposed bottom strip of the stacked card (just like a real
            # finger tap on mobile, since the preferred card overlaps the center).
            citi_stack = page.get_by_role('button', name=re.compile(r'^Citi Custom Cash\.'))
            citi_stack.scroll_into_view_if_needed()
            citi_box = citi_stack.bounding_box()
            assert citi_box is not None
            citi_stack.click(position={'x': min(80, citi_box['width'] / 2), 'y': citi_box['height'] - 18})
            page.wait_for_timeout(300)
            remove_btn = page.get_by_role('button', name='Remove from wallet', exact=True)
            remove_btn.scroll_into_view_if_needed()
            remove_btn.click()
            expect(page.get_by_text('Remove card?', exact=False)).to_be_visible(timeout=10000)
            page.get_by_role('button', name='Remove', exact=True).click()
            expect(page.get_by_text('2 ACTIVE', exact=False)).to_be_visible(timeout=20000)

            _, boot_after_remove = request(api + '/v1/bootstrap', headers=auth_headers)
            score_after_remove = boot_after_remove['data']['wallet_metrics']['score']
            assert score_after_remove == score_initial, (
                f'Expected score to revert after removing Citi Custom Cash: {score_after_remove} vs {score_initial}'
            )
            results['checks']['wallet_management_and_score'] = {
                'score_initial': score_initial,
                'score_after_custom_terms': score_after_terms,
                'score_after_skip': boot_after_skip['data']['wallet_metrics']['score'],
                'score_after_remove': score_after_remove,
            }

            # -----------------------------------------------------------------
            # 4. REVO chat on web: consent sheet (Cancel / Basic / Agree),
            #    basic reply rendering, link opening, chat clear
            # -----------------------------------------------------------------
            page.get_by_role('tab', name=re.compile(r'^(Ask REVO|REVO)$')).click()
            expect(page).to_have_url(re.compile(r'.*#/revo$'), timeout=20000)
            expect(page.get_by_text('Meet your wallet guide', exact=False)).to_be_visible(timeout=20000)
            page.wait_for_timeout(300)

            def type_revo(text: str):
                composer = page.locator('textarea').last
                composer.scroll_into_view_if_needed()
                composer.click()
                page.wait_for_timeout(350)
                composer.fill(text)
                page.wait_for_timeout(300)
                expect(page.locator('textarea').last).to_have_value(text, timeout=10000)

            send_btn = page.get_by_role('button', name=re.compile(r'^Send message'))

            # Cancel consent -> prompt retained, nothing sent
            type_revo('Compare my cards')
            send_btn.click()
            expect(page.get_by_text('Let REVO use AI?', exact=False)).to_be_visible(timeout=15000)
            page.get_by_role('button', name='Cancel', exact=True).click()
            expect(page.get_by_text('Let REVO use AI?', exact=False)).to_have_count(0)
            expect(page.locator('textarea').last).to_have_value('Compare my cards')

            # Basic answer -> renders basic label + opens HTTPS link in new tab
            send_btn.click()
            expect(page.get_by_text('Let REVO use AI?', exact=False)).to_be_visible(timeout=15000)
            page.get_by_role('button', name='Basic answer instead', exact=True).click()
            expect(
                page.get_by_role('group', name=re.compile(r'Basic answer \(no AI\)'))
            ).to_be_visible(timeout=30000)
            # Intercept external navigation so popup opens cleanly without hitting public internet
            context.route('https://www.chase.com/**', lambda route: route.fulfill(status=200, body='ok'))
            with page.expect_popup(timeout=15000) as popup_info:
                page.get_by_text('Official issuer guide', exact=True).click()
            popup = popup_info.value
            assert 'chase.com' in popup.url, f'Unexpected popup URL: {popup.url}'
            popup.close()
            # Ensure main PWA tab stayed on /#/revo
            expect(page).to_have_url(re.compile(r'.*#/revo$'))

            # Agree to AI -> renders AI answer without basic label
            type_revo('Explain my S04 roadmap')
            send_btn.click()
            expect(page.get_by_text('Let REVO use AI?', exact=False)).to_be_visible(timeout=15000)
            page.get_by_role('button', name='Agree and continue', exact=True).click()
            expect(
                page.get_by_role('group', name=re.compile(r'AI guidance for your S04 plan'))
            ).to_be_visible(timeout=30000)

            # Clear chat -> returns to empty state
            page.get_by_role('button', name='Clear', exact=True).click()
            expect(page.get_by_text('Clear conversation?', exact=False)).to_be_visible(timeout=10000)
            page.get_by_role('button', name='Clear conversation', exact=True).click()
            expect(page.get_by_text('Meet your wallet guide', exact=False)).to_be_visible(timeout=20000)
            results['checks']['revo_chat_consent_links_clear'] = True

            # -----------------------------------------------------------------
            # 6. Responsive viewports: Mobile dark (390x844), Tablet dark
            #    (768x1024), deep-link reload back button & URL navigation
            # -----------------------------------------------------------------
            page.emulate_media(color_scheme='dark')
            for route in ('/home', '/cards', '/strategy', '/revo', '/profile', '/strategy-report', '/explore-rewards', '/legal'):
                page.goto(web + '/#' + route)
                enable_accessibility(page)
                page.wait_for_timeout(250)
                if route in ('/home', '/cards', '/strategy', '/revo', '/profile'):
                    assert_bottom_nav_within_viewport(page, 390, 844)
                if route in ('/explore-rewards', '/legal'):
                    expect(page.get_by_role('button', name=re.compile(r'^Back'))).to_be_visible(timeout=10000)
            check_no_overflow_errors(console_errors, page_errors, 'mobile-390-dark')

            # Tablet dark (768x1024)
            page.set_viewport_size({'width': 768, 'height': 1024})
            for route in ('/home', '/cards', '/strategy', '/revo', '/profile', '/strategy-report'):
                page.goto(web + '/#' + route)
                enable_accessibility(page)
                page.wait_for_timeout(200)
                if route in ('/home', '/cards', '/strategy', '/revo', '/profile'):
                    assert_bottom_nav_within_viewport(page, 768, 1024)
            check_no_overflow_errors(console_errors, page_errors, 'tablet-768-dark')
            page.set_viewport_size({'width': 390, 'height': 844})
            page.emulate_media(color_scheme='light')
            results['checks']['mobile_tablet_dark_responsive'] = True

            # -----------------------------------------------------------------
            # 5. Account lifecycle: logout -> emailed PKCE recovery ->
            #    password update -> full reload session persistence ->
            #    JSON export download -> password-reauthenticated deletion
            # -----------------------------------------------------------------
            page.goto(web + '/#/profile')
            enable_accessibility(page)
            logout_btn = page.get_by_role('button', name='Log out', exact=True)
            logout_btn.scroll_into_view_if_needed()
            logout_btn.click()
            expect(page).to_have_url(re.compile(r'.*#/welcome$'), timeout=30000)

            page.get_by_role('button', name='Forgot password / confirm email').click()
            expect(page.get_by_role('heading', name='Account recovery')).to_be_visible(timeout=20000)
            fill_field(page, 0, email)
            page.get_by_role('button', name='Send password reset').click()
            recovery_msg = latest_email(email, mailpit_url=mailpit, kind='recovery')
            assert recovery_msg, 'Recovery email did not arrive in Mailpit'
            recovery_link = extract_verify_link(
                recovery_msg,
                expected_auth_host=urllib.parse.urlparse(auth).hostname or '127.0.0.1',
                expected_web_origin=web,
            )
            page.goto(recovery_link)
            enable_accessibility(page)
            expect(page.get_by_text('Set a new password', exact=False)).to_be_visible(timeout=30000)
            password = 'Local-PWA-Reset-Password-7712!'
            fill_field(page, 0, password)
            page.get_by_role('button', name='Update password', exact=True).click()
            expect(page).to_have_url(re.compile(r'.*#/home$'), timeout=30000)

            # Full browser reload preserves authenticated session
            page.reload()
            enable_accessibility(page)
            expect(page).to_have_url(re.compile(r'.*#/home$'), timeout=30000)
            expect(page.get_by_text('Hello, Dana', exact=False)).to_be_visible(timeout=30000)

            # Direct reload on /#/account exposes Back button + Export JSON download + Deletion
            page.goto(web + '/#/account')
            enable_accessibility(page)
            expect(page.get_by_role('button', name=re.compile(r'^Back'))).to_be_visible(timeout=15000)
            export_btn = page.get_by_role('button', name='Export my data', exact=True)
            export_btn.scroll_into_view_if_needed()
            export_btn.click()
            expect(page.get_by_text('Your account data (JSON)', exact=False)).to_be_visible(timeout=20000)
            with page.expect_download(timeout=15000) as json_dl:
                page.get_by_role('button', name='Download JSON', exact=True).click()
            exported_text = Path(json_dl.value.path()).read_text(encoding='utf-8')
            exported_json = json.loads(exported_text)
            assert json_dl.value.suggested_filename.endswith('.json')
            assert exported_json['data']['email'] == email
            page.get_by_role('button', name='Close', exact=True).click()

            fill_labeled_field(page, 'Current password', password)
            del_btn = page.get_by_role('button', name='Delete my account', exact=True)
            del_btn.scroll_into_view_if_needed()
            del_btn.click()
            expect(page.get_by_text('Permanently delete your account?', exact=False)).to_be_visible(timeout=10000)
            page.get_by_role('button', name='Delete account', exact=True).click()
            expect(page).to_have_url(re.compile(r'.*#/welcome$'), timeout=30000)
            deleted = True

            # Verify deleted account login is rejected
            try:
                request(
                    auth + '/auth/v1/token?grant_type=password',
                    'POST',
                    {'email': email, 'password': password},
                    public,
                )
            except urllib.error.HTTPError as err:
                assert err.code in (400, 401), f'Unexpected post-delete login status {err.code}'
            else:
                raise AssertionError('Deleted account could still log in')

            check_no_overflow_errors(console_errors, page_errors, 'account-lifecycle')
            results['checks']['account_recovery_reload_export_delete'] = {
                'json_export_filename': json_dl.value.suggested_filename,
                'json_export_bytes': len(exported_text.encode('utf-8')),
            }
            context.close()
            browser.close()

        results['passed'] = True
        return results
    finally:
        if not deleted:
            token = None
            for candidate in (password, original_password):
                try:
                    _, login = request(
                        auth + '/auth/v1/token?grant_type=password',
                        'POST',
                        {'email': email, 'password': candidate},
                        public,
                    )
                    token = login.get('access_token')
                    break
                except OSError:
                    continue
            if token:
                try:
                    request(api + '/v1/account', 'DELETE', headers={'Authorization': 'Bearer ' + token})
                except OSError:
                    pass


def main(argv: list[str] | None = None):
    parser = argparse.ArgumentParser(description='RevoCred PWA end-to-end Playwright QA suite')
    parser.add_argument(
        '--mode',
        choices=('local', 'self-contained'),
        default='local',
        help='Run against local Supabase/API (`local`) or an in-process loopback harness (`self-contained`).',
    )
    parser.add_argument(
        '--web-dir',
        default='',
        help='Existing compiled Flutter web build directory (for --mode self-contained with --skip-build).',
    )
    parser.add_argument(
        '--skip-build',
        action='store_true',
        help='Skip `flutter build web --release` in self-contained mode (requires existing build matching ports).',
    )
    parser.add_argument('--auth-port', type=int, default=0, help='Optional fixed auth port in self-contained mode.')
    parser.add_argument('--api-port', type=int, default=0, help='Optional fixed API port in self-contained mode.')
    parser.add_argument('--web-port', type=int, default=0, help='Optional fixed web port in self-contained mode.')
    args = parser.parse_args(argv)

    if args.mode == 'local':
        config = load_env(ROOT / '.env.local')
        api = os.environ.get('REVOCRED_SHARE_API', config['REVOCRED_API_URL']).rstrip('/')
        auth = os.environ.get('REVOCRED_SHARE_SUPABASE', config['SUPABASE_URL']).rstrip('/')
        web = os.environ.get('REVOCRED_SHARE_WEB', 'http://127.0.0.1:8083').rstrip('/')
        mailpit = os.environ.get('REVOCRED_MAILPIT_URL', 'http://127.0.0.1:54324').rstrip('/')
        for value in (api, auth, web):
            assert_loopback_or_share(value, allow_share_tunnel=True)
        assert_loopback_or_share(mailpit)
        results = run_e2e_suite(
            web=web,
            api=api,
            auth=auth,
            mailpit=mailpit,
            anon_key=config['SUPABASE_ANON_KEY'],
        )
        print('PWA E2E (local) PASSED:\n' + json.dumps(results, indent=2))
        return

    web_dir = Path(args.web_dir) if args.web_dir else (ROOT / 'revocred_flutter' / 'build' / 'web')
    harness = start_self_contained_harness(
        web_dir,
        require_confirmation=True,
        auth_port=args.auth_port,
        api_port=args.api_port,
        web_port=args.web_port,
    )
    try:
        if not args.skip_build:
            # Deliberately bake a DIFFERENT redirect URL at build time to prove
            # resolveAuthRedirectUrl uses the active browser origin on web!
            build_web_release(
                harness['api'],
                harness['auth'],
                harness['anon_key'],
                redirect_url='https://mismatched-origin.example.test/',
            )
        results = run_e2e_suite(
            web=harness['web'],
            api=harness['api'],
            auth=harness['auth'],
            mailpit=harness['mailpit'],
            anon_key=harness['anon_key'],
        )
        print('PWA E2E (self-contained) PASSED:\n' + json.dumps(results, indent=2))
    finally:
        harness['stop']()


if __name__ == '__main__':
    main()
