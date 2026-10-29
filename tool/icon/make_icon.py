"""Generates the PackFoundry icon as SVG from exact geometry.

A steel gear with N equal teeth around a forge glow, and a big hammer laid
across it at exactly 45 degrees. Every shape comes from the parameters
below; colours and light are gradients only, no hatching.

Usage: python make_icon.py assets/icon.svg
The PNG and .ico are rendered from it by build_icon.ps1.
"""
import math
import sys
from pathlib import Path

SIZE = 512
C = SIZE / 2

# Gear: straight-flanked teeth between two exact circles.
TEETH = 12
R_TIP = 238
R_ROOT = 204
TIP_HALF = 6.5        # half width of a tooth at the tip, degrees
ROOT_HALF = 10.0      # half width of a tooth at the root, degrees
R_FACE = 168          # inner edge of the gear ring
BEVEL = 7             # inset of the lighter bevel outline

# Forge.
R_GLOW = 158          # thin bright ring
R_CORE = 150          # glowing disc

# Hammer, drawn upright about the centre, then rotated.
ANGLE = 45
HANDLE_W = 42
HANDLE_TOP = -120
HANDLE_END = 206
HEAD_W = 236
HEAD_H = 100
HEAD_CY = -158        # centre of the head along the handle
CHAMFER = 18          # cut corners of the head
NECK_W = 64
NECK_H = 30

# Sparks thrown off the forge, placed on a golden-angle spiral.
SPARKS = 0


def f(value):
    return f'{value:.2f}'.rstrip('0').rstrip('.')


def polar(radius, degrees, cx=C, cy=C):
    a = math.radians(degrees - 90)
    return cx + radius * math.cos(a), cy + radius * math.sin(a)


def gear_outline(tip, root, tip_half, root_half):
    step = 360 / TEETH
    d = []
    for i in range(TEETH):
        mid = i * step
        p0 = polar(root, mid - root_half)
        p1 = polar(tip, mid - tip_half)
        p2 = polar(tip, mid + tip_half)
        p3 = polar(root, mid + root_half)
        d.append(('M' if i == 0 else f'A{f(root)} {f(root)} 0 0 1 ') + f'{f(p0[0])} {f(p0[1])}')
        d.append(f'L{f(p1[0])} {f(p1[1])}')
        d.append(f'A{f(tip)} {f(tip)} 0 0 1 {f(p2[0])} {f(p2[1])}')
        d.append(f'L{f(p3[0])} {f(p3[1])}')
    first = polar(root, -root_half)
    d.append(f'A{f(root)} {f(root)} 0 0 1 {f(first[0])} {f(first[1])}Z')
    return ''.join(d)


def circle_path(r):
    return (
        f'M{f(C)} {f(C - r)}A{f(r)} {f(r)} 0 1 0 {f(C)} {f(C + r)}'
        f'A{f(r)} {f(r)} 0 1 0 {f(C)} {f(C - r)}Z'
    )


def head_polygon():
    """A block with chamfered corners, centred on (0, HEAD_CY)."""
    x, y = HEAD_W / 2, HEAD_H / 2
    k = CHAMFER
    pts = [
        (-x + k, -y), (x - k, -y), (x, -y + k), (x, y - k),
        (x - k, y), (-x + k, y), (-x, y - k), (-x, -y + k),
    ]
    return ' '.join(f'{f(px)},{f(HEAD_CY + py)}' for px, py in pts)


def sparks():
    golden = 137.50776
    out = []
    for i in range(SPARKS):
        t = (i + 1) / SPARKS
        r = 40 + 95 * math.sqrt(t)
        # Fan them out to the lower left, where the forge glows.
        angle = 200 + (i * golden) % 70
        x, y = polar(r, angle)
        size = 2.2 + 2.6 * (1 - t)
        out.append(
            f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(size)}" fill="#ffd27a" '
            f'opacity="{f(0.55 + 0.45 * (1 - t))}" filter="url(#sparkGlow)"/>'
        )
    return '\n    '.join(out)


def svg():
    hw = HANDLE_W / 2
    neck_y = HEAD_CY + HEAD_H / 2 - 6
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {SIZE} {SIZE}" width="{SIZE}" height="{SIZE}">
  <!-- PackFoundry icon, generated: {TEETH}-tooth gear (tip r={R_TIP}, root r={R_ROOT}),
       forge core r={R_CORE}, hammer at {ANGLE} degrees. -->
  <defs>
    <linearGradient id="steelGear" x1="0.2" y1="0" x2="0.8" y2="1">
      <stop offset="0" stop-color="#7d838d"/>
      <stop offset="0.45" stop-color="#474b53"/>
      <stop offset="1" stop-color="#1e2024"/>
    </linearGradient>
    <linearGradient id="bevel" x1="0.2" y1="0" x2="0.8" y2="1">
      <stop offset="0" stop-color="#ffffff" stop-opacity="0.45"/>
      <stop offset="0.5" stop-color="#ffffff" stop-opacity="0.06"/>
      <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
    </linearGradient>
    <radialGradient id="forge" cx="0.4" cy="0.62" r="0.62">
      <stop offset="0" stop-color="#ffb04a"/>
      <stop offset="0.28" stop-color="#e5600f"/>
      <stop offset="0.62" stop-color="#6a2108"/>
      <stop offset="1" stop-color="#1c0c06"/>
    </radialGradient>
    <radialGradient id="rim" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0.86" stop-color="#ff8a1f" stop-opacity="0"/>
      <stop offset="0.95" stop-color="#ffb347" stop-opacity="0.9"/>
      <stop offset="1" stop-color="#ff6a00" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="faceShadow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0.88" stop-color="#000" stop-opacity="0"/>
      <stop offset="1" stop-color="#000" stop-opacity="0.55"/>
    </radialGradient>
    <linearGradient id="headTop" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#f4f6f9"/>
      <stop offset="0.38" stop-color="#c3c8cf"/>
      <stop offset="0.62" stop-color="#8c929b"/>
      <stop offset="1" stop-color="#4c5058"/>
    </linearGradient>
    <linearGradient id="headSides" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#000" stop-opacity="0.35"/>
      <stop offset="0.12" stop-color="#000" stop-opacity="0"/>
      <stop offset="0.88" stop-color="#000" stop-opacity="0"/>
      <stop offset="1" stop-color="#000" stop-opacity="0.35"/>
    </linearGradient>
    <linearGradient id="handle" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#2a1a12"/>
      <stop offset="0.4" stop-color="#7a4a2c"/>
      <stop offset="0.6" stop-color="#5c3721"/>
      <stop offset="1" stop-color="#1f130d"/>
    </linearGradient>
    <linearGradient id="neck" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#3a3d44"/>
      <stop offset="0.45" stop-color="#9aa0a8"/>
      <stop offset="1" stop-color="#2e3136"/>
    </linearGradient>
    <linearGradient id="emberEdge" x1="0" y1="1" x2="0" y2="0">
      <stop offset="0" stop-color="#ff8a1f" stop-opacity="0.95"/>
      <stop offset="0.5" stop-color="#ff8a1f" stop-opacity="0"/>
    </linearGradient>
    <clipPath id="core"><circle cx="{f(C)}" cy="{f(C)}" r="{R_CORE}"/></clipPath>
    <filter id="softGlow" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="7"/>
    </filter>
    <filter id="sparkGlow" x="-200%" y="-200%" width="500%" height="500%">
      <feGaussianBlur stdDeviation="1.4" result="b"/>
      <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
    <filter id="drop" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="0" dy="10" stdDeviation="9" flood-color="#000" flood-opacity="0.6"/>
    </filter>
  </defs>

  <!-- Gear -->
  <path d="{gear_outline(R_TIP, R_ROOT, TIP_HALF, ROOT_HALF)}{circle_path(R_FACE)}"
        fill="url(#steelGear)" fill-rule="evenodd" stroke="#1d1f23" stroke-width="5"
        stroke-linejoin="round"/>
  <path d="{gear_outline(R_TIP - BEVEL, R_ROOT - BEVEL, TIP_HALF - 0.6, ROOT_HALF - 0.4)}{circle_path(R_FACE + BEVEL)}"
        fill="none" stroke="url(#bevel)" stroke-width="3" fill-rule="evenodd"
        stroke-linejoin="round"/>

  <!-- Forge -->
  <circle cx="{f(C)}" cy="{f(C)}" r="{R_FACE}" fill="#120a06"/>
  <circle cx="{f(C)}" cy="{f(C)}" r="{R_CORE}" fill="url(#forge)"/>
  <circle cx="{f(C)}" cy="{f(C)}" r="{R_CORE}" fill="url(#faceShadow)"/>
  <circle cx="{f(C)}" cy="{f(C)}" r="{R_GLOW + 12}" fill="url(#rim)" filter="url(#softGlow)"/>
  <circle cx="{f(C)}" cy="{f(C)}" r="{R_GLOW}" fill="none" stroke="#ffc266" stroke-width="3.5"/>

  <!-- Hammer -->
  <g transform="translate({f(C)} {f(C)}) rotate({ANGLE})" filter="url(#drop)">
    <rect x="{f(-hw)}" y="{f(HANDLE_TOP)}" width="{f(HANDLE_W)}" height="{f(HANDLE_END - HANDLE_TOP)}"
          rx="{f(hw)}" fill="url(#handle)" stroke="#120b07" stroke-width="4"/>
    <rect x="{f(-hw)}" y="{f(HANDLE_TOP)}" width="{f(HANDLE_W)}" height="{f(HANDLE_END - HANDLE_TOP)}"
          rx="{f(hw)}" fill="url(#emberEdge)" opacity="0.35"/>
    <rect x="{f(-NECK_W / 2)}" y="{f(neck_y)}" width="{f(NECK_W)}" height="{f(NECK_H)}"
          rx="6" fill="url(#neck)" stroke="#16181b" stroke-width="4"/>
    <polygon points="{head_polygon()}" fill="url(#headTop)" stroke="#16181b"
             stroke-width="5" stroke-linejoin="round"/>
    <polygon points="{head_polygon()}" fill="url(#headSides)"/>
    <polygon points="{head_polygon()}" fill="url(#emberEdge)" opacity="0.45"/>
  </g>
</svg>
'''


if __name__ == '__main__':
    out = Path(sys.argv[1])
    out.write_text(svg(), encoding='utf-8')
    print(out)
