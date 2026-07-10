from reportlab.lib.pagesizes import LETTER
from reportlab.lib.units import inch
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfgen import canvas
from reportlab.lib import colors

output_path = '/workspace/revocred-mobile/Revocred_31_Day_Launch_Plan_Free_First.pdf'

c = canvas.Canvas(output_path, pagesize=LETTER)
width, height = LETTER
margin = 0.75 * inch
max_width = width - 2 * margin


def draw_wrapped_text(text, x, y, font_name='Helvetica', font_size=11, leading=14):
    c.setFont(font_name, font_size)
    words = text.split(' ')
    line = ''
    lines = []

    for word in words:
        candidate = (line + ' ' + word).strip()
        if pdfmetrics.stringWidth(candidate, font_name, font_size) <= max_width:
            line = candidate
        else:
            if line:
                lines.append(line)
            line = word
    if line:
        lines.append(line)

    for l in lines:
        if y < margin:
            c.showPage()
            y = height - margin
            c.setFont(font_name, font_size)
        c.drawString(x, y, l)
        y -= leading

    return y


y = height - margin

# Title
c.setFillColor(colors.HexColor('#0f274b'))
c.setFont('Helvetica-Bold', 20)
c.drawString(margin, y, 'Revocred 31-Day Launch Plan (Free-First Monetization)')
y -= 26

c.setFillColor(colors.black)
c.setFont('Helvetica', 11)
y = draw_wrapped_text('Goal: Launch Revocred on the Apple App Store in 31 days with a free-first model to maximize adoption and collect proof of demand before turning on subscriptions.', margin, y)
y -= 10

sections = [
    ('Executive Summary', [
        'Yes, a 31-day launch is realistic if we remove Apple account blockers quickly and execute in focused work blocks.',
        'Initial launch is free. Revenue optimization is phase 2 once real user behavior data is collected.',
        'Critical external dependency: active Apple Developer account + App Store Connect access.'
    ]),
    ('Launch Strategy: Free First, Monetize After', [
        'Phase 1 (Launch): Keep core features open to all users to maximize installs and engagement.',
        'Phase 2 (Validation): Measure retention, REVO usage, and qualitative feedback.',
        'Phase 3 (Monetization): Turn on subscriptions with Apple IAP once premium value is proven.'
    ]),
    ('31-Day Timeline', [
        'Days 1–3: Apple distribution unblock (Developer account, App Store Connect, TestFlight readiness).',
        'Days 4–10: Product readiness (free launch instrumentation, event analytics, crash monitoring, feature flags).',
        'Days 11–16: Reliability and compliance (legal pages, privacy details, export compliance, support channel).',
        'Days 17–21: QA and polish on iPhone (critical path testing, bug fixes, performance polish).',
        'Days 22–25: App Store assets (screenshots, listing copy, keywords, metadata, policy links).',
        'Day 26: Submit build to App Store review.',
        'Days 27–31: Review buffer for fixes/resubmission if needed.'
    ]),
    ('Must-Have Tooling for a Real Business', [
        'App + Backend: Expo/React Native, Supabase, OpenAI (already in place).',
        'Distribution: EAS Build + App Store Connect + TestFlight.',
        'Analytics: PostHog or Mixpanel (funnel + retention).',
        'Monitoring: Sentry (crashes/errors).',
        'Payments (later): Apple IAP (and optional Stripe for web channel later).',
        'Operations: support inbox (Crisp/Intercom), legal docs, domain + marketing page.'
    ]),
    ('Launch Readiness Checklist (Minimum)', [
        'Apple account active and app record configured in App Store Connect.',
        'At least one successful TestFlight build installed on real iPhone.',
        'Core user journey tested end-to-end (signup/login -> Home -> REVO -> Profile).',
        'Crash-free baseline established in TestFlight testers.',
        'Privacy Policy + Terms accessible from app and store listing.',
        'App Store assets finalized and submission metadata complete.'
    ]),
    ('Post-Launch KPI Targets (First 2 Weeks)', [
        'Activation: % of new users who ask REVO at least once.',
        'Engagement: average REVO prompts per active user.',
        'Retention: D1 and D7 return rates.',
        'Reliability: crash-free sessions and API success rate.',
        'Monetization readiness: identify top premium candidate features from usage patterns.'
    ]),
    ('Immediate Next Actions', [
        '1) Resolve Apple Developer account creation issue (highest-priority blocker).',
        '2) Complete first iOS TestFlight build path.',
        '3) Add analytics events and crash monitoring before submission.',
        '4) Finalize legal and App Store metadata package.'
    ]),
]

for title, bullets in sections:
    if y < 130:
        c.showPage()
        y = height - margin

    c.setFillColor(colors.HexColor('#143a6e'))
    c.setFont('Helvetica-Bold', 14)
    c.drawString(margin, y, title)
    y -= 18

    c.setFillColor(colors.black)
    for bullet in bullets:
        y = draw_wrapped_text(f'- {bullet}', margin + 8, y, font_name='Helvetica', font_size=11, leading=14)
    y -= 8

# Footer
if y < 60:
    c.showPage()
    y = height - margin

c.setFillColor(colors.HexColor('#5a5a5a'))
c.setFont('Helvetica-Oblique', 9)
c.drawString(margin, 0.5 * inch, 'Prepared for Revocred launch planning. Free-first strategy version.')

c.save()
print(output_path)
