#!/usr/bin/env python3
"""Render original, issuer-inspired illustrations (not payment-card replicas).

Requires Pillow. No issuer artwork, cardholder details or account numbers are
used. The same local PNGs are used by Flutter and PDF export.
"""
from pathlib import Path
import ast
import math
import re

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1] / 'revocred_flutter'
OUT = ROOT / 'assets/images/cards'
W, H = 1200, 756
SCALE = 2


class ScaledDraw:
    """Keep design coordinates readable while rasterizing at 2400 x 1512."""
    def __init__(self, image):
        self.draw = ImageDraw.Draw(image)

    def __getattr__(self, name):
        method = getattr(self.draw, name)
        if name == 'textlength':
            return lambda *args, **kwargs: method(*args, **kwargs) / SCALE

        def scaled(coords, *args, **kwargs):
            def points(value):
                return type(value)(points(v) for v in value) if isinstance(value, (tuple, list)) else round(value * SCALE)
            for key in ('width', 'radius'):
                if key in kwargs:
                    kwargs[key] *= SCALE
            if name == 'line' and 'width' not in kwargs:
                kwargs['width'] = SCALE
            return method(points(coords), *args, **kwargs)
        return scaled


def font(size):
    return ImageFont.truetype(str(ROOT / 'assets/fonts/SpaceGrotesk-Bold.ttf'), size * SCALE)


def gradient(top, bottom):
    image = Image.new('RGB', (W * SCALE, H * SCALE))
    draw = ScaledDraw(image)
    for y in range(H):
        t = y / H
        shade = tuple(round(a * (1 - t) + b * t) for a, b in zip(top, bottom))
        draw.line((0, y, W, y), fill=shade, width=1)
    return image


def render(key, issuer, title, top, bottom, motif, network='VISA', light=False):
    image = gradient(top, bottom).convert('RGBA')
    layer = Image.new('RGBA', (W * SCALE, H * SCALE))
    d = ScaledDraw(layer)
    if motif == 'cash':
        for y in range(414, H):
            t = (y - 414) / (H - 414)
            d.line((0, y, W, y), fill=(4, round(155 - 75 * t), round(124 - 55 * t), 255))
        d.rectangle((0, 400, W, 432), fill=(60, 226, 197, 210))
        for r in range(105, 385, 32):
            d.arc((790-r, 360-r, 790+r, 360+r), 190, 350, fill=(60, 231, 242, 100), width=12)
    elif motif == 'flex':
        for x in range(-400, W + 500, 95):
            d.polygon([(x, 0), (x+155, 0), (x+560, H), (x+455, H)], fill=(110, 248, 255, 17))
        d.polygon([(760, 0), (1200, 0), (1200, 756), (1030, 756)], fill=(4, 55, 133, 25))
    elif motif == 'sapphire':
        for pts in [[(310, H), (790, 0), (665, H)], [(540, H), (1130, 0), (915, 455), (W, 120)], [(145, H), (640, 95), (525, 375), (970, 0)]]:
            d.line(pts, fill=(75, 201, 250, 200), width=4)
        d.polygon([(500, H), (W, 135), (890, H)], fill=(1, 125, 213, 50))
        d.polygon([(0, 0), (440, 0), (0, 665)], fill=(19, 71, 148, 70))
    elif motif == 'contour':
        for i in range(17):
            pts = []
            for y in range(-50, H + 100, 8):
                x = 400 + i * 39 + 110 * math.sin(y / 153 + i * .11)
                pts.append((x, y))
            d.line(pts, fill=(8, 12, 19, 170), width=5)
            d.line([(x+5, y) for x, y in pts], fill=(210, 218, 224, 45), width=2)
    elif motif == 'metal':
        for i in range(34):
            x = 550 + i * 23
            d.arc((x-360, -90, x+360, 810), 85, 280, fill=(255, 255, 255, 40), width=2)
        for y in range(0, H, 5):
            d.line((0, y, W, y), fill=(255, 255, 255, 13), width=1)
        d.rounded_rectangle((740, 135, 1000, 570), radius=125, outline=(255,255,255,95), width=6)
        d.rounded_rectangle((768, 167, 972, 538), radius=105, outline=(255,255,255,80), width=3)
    elif motif == 'venture':
        d.polygon([(180, H), (890, 0), (W, 0), (505, H)], fill=(104, 119, 151, 28))
        d.arc((560, 285, 1420, 820), 183, 265, fill=(212, 79, 91, 220), width=7)
        for i in range(8):
            d.line((740+i*27, 0, 140+i*27, H), fill=(199,213,244,18), width=2)
    elif motif == 'orbit':
        for i in range(10):
            d.arc((400+i*26, -180+i*18, 1490-i*12, 900-i*18), 70, 300, fill=(232,171,95,70), width=3)
    else:
        for i in range(14):
            d.line((-220+i*100, H, 350+i*100, 0), fill=(255,255,255,22), width=3)
    image = Image.alpha_composite(image, layer)
    d = ScaledDraw(image)
    fg = (35, 39, 43) if light else (246, 249, 255)
    muted = (75, 80, 85) if light else (205, 218, 234)
    issuer_size = 100
    while d.textlength(issuer, font=font(issuer_size)) > 1060:
        issuer_size -= 2
    d.text((65, 40), issuer, font=font(issuer_size), fill=fg)
    # Larger product lettering is readable on Retina phones. Long names wrap
    # instead of being shrunk to a blurry, single-line micro-label.
    title_size = 68
    while True:
        lines = ['']
        for word in title.upper().split():
            candidate = f'{lines[-1]} {word}'.strip()
            if lines[-1] and d.textlength(candidate, font=font(title_size)) > 1060:
                lines.append(word)
            else:
                lines[-1] = candidate
        if len(lines) <= 2 or title_size <= 40:
            break
        title_size -= 2
    for i, line in enumerate(lines):
        d.text((67, 166 + i * (title_size + 3)), line, font=font(title_size), fill=fg)
    # Original engraved chip and contactless motif, never a working card number.
    chip = (69, 315, 207, 416)
    d.rounded_rectangle(chip, radius=18, fill=(208,205,186), outline=(239,236,218), width=3)
    for x in [112, 163]:
        d.line((x, 318, x, 414), fill=(126,132,126), width=3)
    for y in [348, 382]:
        d.line((72, y, 204, y), fill=(126,132,126), width=3)
    d.rounded_rectangle((114, 340, 160, 391), radius=8, fill=(214,212,194), outline=(129,134,126), width=3)
    for r in [20, 33, 46]:
        d.arc((214-r, 364-r, 214+r, 364+r), -55, 55, fill=fg, width=5)
    d.text((65, 641), 'REWARDS STRATEGY', font=font(21), fill=muted)
    d.text((65, 681), 'STYLIZED ILLUSTRATION', font=font(14), fill=muted)
    if network == 'Mastercard':
        d.ellipse((987, 594, 1100, 707), fill=(222,94,62) if not light else (141,145,149))
        d.ellipse((1050, 594, 1163, 707), fill=(236,176,69) if not light else (186,189,191))
    else:
        network_size = 49
        while d.textlength(network, font=font(network_size)) > 185:
            network_size -= 1
        d.text((W-235, 619), network, font=font(network_size), fill=fg)
        d.text((W-224, 678), 'REWARDS', font=font(15), fill=muted)
    mask = Image.new('L', (W * SCALE,H * SCALE))
    ScaledDraw(mask).rounded_rectangle((0,0,W-1,H-1), radius=48, fill=255)
    image.putalpha(mask)
    OUT.mkdir(parents=True, exist_ok=True)
    image.save(OUT / f'{key}.png', optimize=True)


def main():
    render('double-cash', 'citi', 'Double Cash', (10,58,119), (6,117,161), 'cash', 'Mastercard')
    render('freedom-flex', 'CHASE', 'freedom flex', (0,170,220), (5,102,166), 'flex', 'Mastercard')
    render('freedom-unlimited', 'CHASE', 'freedom unlimited', (31,102,188), (8,43,99), 'flex')
    render('freedom-rise', 'CHASE', 'freedom rise', (24,138,201), (4,57,121), 'flex')
    render('sapphire-preferred', 'CHASE', 'Sapphire Preferred', (10,26,62), (4,10,25), 'sapphire')
    render('sapphire-reserve', 'CHASE', 'Sapphire Reserve', (38,47,65), (10,15,26), 'sapphire')
    render('strata', 'citi', 'Strata', (138,144,149), (56,59,64), 'contour', 'Mastercard')
    render('strata-premier', 'citi', 'Strata Premier', (123,128,132), (44,47,51), 'contour', 'Mastercard')
    render('strata-elite', 'citi', 'Strata Elite', (65,70,77), (19,23,30), 'contour', 'Mastercard')
    render('amex-gold', 'AMERICAN EXPRESS', 'Gold', (235,203,132), (169,123,57), 'metal', 'AMEX', True)
    render('amex-platinum', 'AMERICAN EXPRESS', 'Platinum', (224,229,230), (140,149,157), 'metal', 'AMEX', True)
    render('venture-x', 'Capital One', 'Venture X', (35,46,63), (12,18,32), 'venture')
    render('savor', 'Capital One', 'Savor', (188,112,69), (97,48,27), 'orbit', 'Mastercard')
    render('quicksilver', 'Capital One', 'Quicksilver', (213,222,231), (128,143,160), 'metal', 'Mastercard', True)
    render('discover', 'DISCOVER', 'Cash Back', (50,56,66), (17,21,30), 'orbit', 'DISCOVER')
    render('bilt', 'BILT', 'Rewards', (48,49,55), (15,16,21), 'contour', 'Mastercard')
    render('generic', 'REWARDS', 'Your card', (36,73,111), (16,28,52), 'sapphire')
    for issuer, names in catalog().items():
        for name in names:
            top, bottom, motif, network, light = recipe(issuer, name)
            render(f'{identity(issuer)}-{identity(name)}', issuer, name, top, bottom, motif, network, light)


def identity(value):
    return re.sub(r'[^a-z0-9]', '', value.lower().replace('+', 'plus'))


def catalog():
    source = (ROOT / 'lib/core/logic/card_art_catalog.dart').read_text()
    return {issuer: ast.literal_eval('[' + names + ']')
            for issuer, names in re.findall(r"'([^']+)':\s*\[(.*?)\]", source, re.S)}


def recipe(issuer, name):
    """Original colour/motif interpretations; not official issuer artwork."""
    n = identity(name)
    if issuer == 'American Express':
        if 'bluecash' in n:
            return (108,181,221) if 'everyday' in n else (29,57,106), (34,83,150) if 'everyday' in n else (8,23,54), 'metal', 'AMEX', False
        if 'delta' in n:
            if 'reserve' in n:
                return (88,65,115), (28,21,44), 'venture', 'AMEX', False
            if 'platinum' in n:
                return (199,208,217), (121,137,157), 'venture', 'AMEX', True
            if 'gold' in n:
                return (211,182,123), (140,108,47), 'venture', 'AMEX', True
            return (46,93,164), (14,39,89), 'venture', 'AMEX', False
        if 'hilton' in n:
            return (36,66,91) if 'aspire' in n else (77,122,169), (13,27,43), 'contour', 'AMEX', False
        if 'marriott' in n:
            return (72,68,77) if 'brilliant' in n else (181,149,112), (26,23,32) if 'brilliant' in n else (97,70,47), 'metal', 'AMEX', 'brilliant' not in n
        if 'gold' in n:
            return (235,203,132), (169,123,57), 'metal', 'AMEX', True
        return (224,229,230), (140,149,157), 'metal', 'AMEX', True
    if issuer == 'Chase':
        if 'sapphire' in n:
            return (10,26,62) if 'preferred' in n else (38,47,65), (4,10,25), 'sapphire', 'VISA', False
        if 'freedomflex' in n:
            return (0,170,220), (5,102,166), 'flex', 'Mastercard', False
        if 'freedom' in n:
            return (31,102,188), (8,43,99), 'flex', 'VISA', False
        if 'united' in n:
            return (40,75,137), (9,21,46), 'venture', 'VISA', False
        if 'southwest' in n:
            return (52,81,166), (19,37,102), 'orbit', 'VISA', False
        if 'marriott' in n:
            return (112,102,101), (41,36,42), 'contour', 'VISA', False
        if 'ihg' in n:
            return (48,83,83), (10,29,30), 'metal', 'Mastercard', False
        if 'disney' in n:
            return (125,32,48), (44,13,37), 'orbit', 'VISA', False
        if 'amazon' in n or 'prime' in n:
            return (76,82,91), (16,22,31), 'metal', 'VISA', False
        if 'slate' in n:
            return (182,199,213), (93,115,137), 'flex', 'VISA', True
        if 'instacart' in n:
            return (53,146,89), (13,66,34), 'orbit', 'Mastercard', False
        if 'doordash' in n:
            return (206,54,54), (117,17,34), 'flex', 'Mastercard', False
        if 'aircanada' in n:
            return (95,52,64), (26,25,34), 'venture', 'Mastercard', False
        if 'aerlingus' in n:
            return (16,132,115), (8,50,53), 'venture', 'VISA', False
        return (41,64,118), (9,23,58), 'venture', 'VISA', False
    if issuer == 'Capital One':
        if 'savor' in n:
            return (188,112,69), (97,48,27), 'orbit', 'Mastercard', False
        if 'quicksilver' in n or 'platinum' in n:
            return (213,222,231), (128,143,160), 'metal', 'Mastercard', True
        if 'venture' in n:
            return (35,46,63) if 'venturex' in n else (40,72,112), (12,18,32), 'venture', 'VISA', False
        if 'tmobile' in n:
            return (198,0,114), (77,9,58), 'flex', 'VISA', False
        if 'rei' in n or 'cabela' in n:
            return (74,112,69), (25,55,35), 'contour', 'Mastercard', False
        if 'basspro' in n:
            return (194,164,70), (94,83,27), 'orbit', 'Mastercard', True
        if 'bjs' in n:
            return (161,34,55), (58,13,27), 'flex', 'Mastercard', False
        return (127,125,91), (52,49,40), 'metal', 'VISA', False
    if issuer == 'Citi':
        if 'doublecash' in n:
            return (10,58,119), (6,117,161), 'cash', 'Mastercard', False
        if 'strata' in n:
            return (65,70,77) if 'elite' in n else (123,128,132), (44,47,51), 'contour', 'Mastercard', False
        if 'costco' in n:
            return (219,221,224), (132,141,152), 'metal', 'VISA', True
        if 'homedepot' in n:
            return (240,129,28), (151,62,9), 'flex', 'STORE', False
        if 'bestbuy' in n:
            return (24,68,131), (4,24,69), 'flex', 'STORE', False
        if 'macys' in n:
            return (195,47,58), (89,17,32), 'orbit', 'STORE', False
        if 'aadvantage' in n:
            return (172,186,202), (64,83,108), 'venture', 'Mastercard', False
        return (22,101,166), (5,38,87), 'sapphire', 'Mastercard', False
    if issuer == 'Discover':
        if 'miles' in n:
            return (83,179,205), (13,72,104), 'flex', 'DISCOVER', False
        if 'chrome' in n:
            return (195,204,211), (89,106,120), 'metal', 'DISCOVER', True
        return (50,56,66), (17,21,30), 'orbit', 'DISCOVER', False
    if issuer == 'Wells Fargo':
        if 'activecash' in n:
            return (48,102,164), (15,37,92), 'flex', 'VISA', False
        if 'autograph' in n:
            return (164,42,65), (52,24,63), 'sapphire', 'VISA', False
        if 'reflect' in n:
            return (229,232,224), (159,165,166), 'metal', 'VISA', True
        return (39,75,103), (7,26,46), 'contour', 'Mastercard', False
    if issuer == 'U.S. Bank':
        if 'altitudego' in n:
            return (187,39,52), (84,11,35), 'flex', 'VISA', False
        if 'smartly' in n or 'shield' in n:
            return (177,188,194), (85,102,116), 'metal', 'VISA', True
        return (24,85,139), (9,29,56), 'sapphire', 'VISA', False
    if issuer == 'Bank of America':
        return (50,70,78) if 'summit' in n else (167,191,194), (14,30,41) if 'summit' in n else (83,112,125), 'venture', 'VISA', 'summit' not in n
    return (48,49,55), (15,16,21), 'contour', 'Mastercard', False


if __name__ == '__main__':
    main()
