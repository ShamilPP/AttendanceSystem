#!/usr/bin/env python3
"""Regenerates every app icon for both NexCrew apps, from code.

The mark is a fingerprint, matching `Icons.fingerprint` already used as the
in-app brand mark on the admin rail/login and the QR kiosk. Both apps share
one shape and differ only in gradient, so they read as a family while staying
distinguishable in a tab strip or app drawer:

    staff  bright indigo   #6366F1 -> #4338CA
    admin  deep navy-indigo #0F172A -> #3730A3

Run from the repo root (macOS: needs Google Chrome for rasterising and the
built-in `sips` for downsampling — no ImageMagick/Pillow required):

    python3 tools/generate_icons.py \\
        admin_panel/web \\
        mobile_app/web \\
        mobile_app/android/app/src/main/res \\
        mobile_app/ios/Runner/Assets.xcassets/AppIcon.appiconset

Writes 30 PNGs. Edit PALETTES / RIDGES below and re-run to restyle everything
at once; there are no binary source assets to keep in sync.

Caveat: output PNGs carry an alpha channel. That is fine for web and Android,
but the App Store rejects alpha in iOS icons — flatten before submitting.
"""
import math
import os
import subprocess
import sys

OUT = os.path.dirname(os.path.abspath(__file__))

# Brand gradients. Staff carries the primary indigo; admin is the deeper
# "back office" sibling so the two are obvious apart at favicon size.
PALETTES = {
    "staff": ("#6366F1", "#4338CA"),
    "admin": ("#0F172A", "#3730A3"),
}


def arc(rx, ry, a1, a2, cx=50.0, cy=50.0):
    """Elliptical arc path from angle a1 to a2 (deg, 0 = 12 o'clock, CW)."""
    def pt(a):
        r = math.radians(a)
        return cx + rx * math.sin(r), cy - ry * math.cos(r)

    x1, y1 = pt(a1)
    x2, y2 = pt(a2)
    large = 1 if abs(a2 - a1) > 180 else 0
    sweep = 1 if a2 > a1 else 0
    return (f'<path d="M {x1:.2f} {y1:.2f} A {rx:.2f} {ry:.2f} 0 '
            f'{large} {sweep} {x2:.2f} {y2:.2f}"/>')


# Concentric ridges, open at the bottom, with uneven spans so it reads as a
# fingerprint rather than a bullseye.
RIDGES = [
    (43, 45, -148, 148),
    (33, 36, -158, 122),
    (23, 27, -128, 158),
    (13, 18, -168, 112),
    (5, 9, -140, 140),
]

# Favicon-scale variant. Five ridges turn to mush below ~48px, so small sizes
# get three widely-spaced ridges and a heavier stroke — same silhouette, but
# it survives being 32 pixels wide.
RIDGES_SIMPLE = [
    (43, 45, -148, 148),
    (26, 29, -158, 132),
    (9, 13, -140, 140),
]


def glyph(stroke_w=7.0, simple=False):
    ridges = RIDGES_SIMPLE if simple else RIDGES
    paths = "\n      ".join(arc(*r) for r in ridges)
    return f'''<g fill="none" stroke="#FFFFFF" stroke-width="{stroke_w}"
       stroke-linecap="round">
      {paths}
    </g>'''


# variant -> (corner radius as a fraction of the tile, glyph scale)
#   std  - rounded tile, used for the web favicon / PWA / Android launcher
#   mask - Android/PWA "maskable": OS crops to a circle, so the art is full
#          bleed and the glyph stays inside the 80% safe zone
#   ios  - iOS applies its own squircle mask, so square with a fuller glyph
#   small - simplified glyph for favicons and tiny iOS slots
VARIANTS = {
    "std": (0.22, 0.68),
    "mask": (0.0, 0.56),
    "ios": (0.0, 0.64),
    "small": (0.22, 0.72),
}


def svg(palette, size=512, variant="std"):
    c1, c2 = PALETTES[palette]
    radius_f, scale = VARIANTS[variant]
    radius = size * radius_f
    inset = (1 - scale) / 2 * size
    stroke = {"std": 7.0, "mask": 7.5, "ios": 7.5, "small": 10.0}[variant]
    simple = variant == "small"
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}"
     viewBox="0 0 {size} {size}">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{c1}"/>
      <stop offset="1" stop-color="{c2}"/>
    </linearGradient>
  </defs>
  <rect width="{size}" height="{size}" rx="{radius:.1f}" fill="url(#g)"/>
  <svg x="{inset:.1f}" y="{inset:.1f}" width="{size * scale:.1f}"
       height="{size * scale:.1f}" viewBox="0 0 100 100">
    {glyph(stroke, simple)}
  </svg>
</svg>
'''


CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


MASTER = 1024


def render_master(palette, variant, png_path):
    """Rasterise one master at 1024px via headless Chrome.

    Chrome's --screenshot crops rather than scales when the window is smaller
    than the SVG, so every size is downsampled from a master instead of being
    rendered directly — which also gives far better antialiasing at 20-48px
    than rasterising the vector at that size would.
    """
    tmp = os.path.join(OUT, f"_tmp_{palette}_{variant}.svg")
    with open(tmp, "w") as f:
        f.write(svg(palette, size=MASTER, variant=variant))
    subprocess.run(
        [CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
         "--force-device-scale-factor=1",
         "--default-background-color=00000000",
         f"--screenshot={png_path}", f"--window-size={MASTER},{MASTER}",
         f"file://{tmp}"],
        check=True, capture_output=True,
    )
    os.remove(tmp)


def downsample(master_png, out_png, px):
    if px == MASTER:
        subprocess.run(["cp", master_png, out_png], check=True)
        return
    subprocess.run(
        ["sips", "--resampleHeightWidth", str(px), str(px),
         master_png, "--out", out_png],
        check=True, capture_output=True,
    )


def main():
    admin_web, staff_web = sys.argv[1], sys.argv[2]

    masters = {}
    for palette in ("admin", "staff"):
        for variant in ("std", "mask", "ios", "small"):
            path = os.path.join(OUT, f"_master_{palette}_{variant}.png")
            render_master(palette, variant, path)
            masters[(palette, variant)] = path

    targets = []  # (palette, variant, path, px)
    for palette, web_dir in (("admin", admin_web), ("staff", staff_web)):
        icons = os.path.join(web_dir, "icons")
        os.makedirs(icons, exist_ok=True)
        targets += [
            (palette, "small", os.path.join(web_dir, "favicon.png"), 32),
            (palette, "std", os.path.join(icons, "Icon-192.png"), 192),
            (palette, "std", os.path.join(icons, "Icon-512.png"), 512),
            (palette, "mask", os.path.join(icons, "Icon-maskable-192.png"), 192),
            (palette, "mask", os.path.join(icons, "Icon-maskable-512.png"), 512),
        ]

    # Android launcher densities + iOS app icons: staff app only (admin is
    # web-only, it has no android/ or ios/ folder).
    if len(sys.argv) > 3:
        android_res = sys.argv[3]
        for density, px in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
                            ("xxhdpi", 144), ("xxxhdpi", 192)):
            d = os.path.join(android_res, f"mipmap-{density}")
            os.makedirs(d, exist_ok=True)
            targets.append(
                ("staff", "std", os.path.join(d, "ic_launcher.png"), px))

    if len(sys.argv) > 4:
        ios_dir = sys.argv[4]
        ios = [
            ("Icon-App-20x20@1x.png", 20), ("Icon-App-20x20@2x.png", 40),
            ("Icon-App-20x20@3x.png", 60), ("Icon-App-29x29@1x.png", 29),
            ("Icon-App-29x29@2x.png", 58), ("Icon-App-29x29@3x.png", 87),
            ("Icon-App-40x40@1x.png", 40), ("Icon-App-40x40@2x.png", 80),
            ("Icon-App-40x40@3x.png", 120), ("Icon-App-60x60@2x.png", 120),
            ("Icon-App-60x60@3x.png", 180), ("Icon-App-76x76@1x.png", 76),
            ("Icon-App-76x76@2x.png", 152),
            ("Icon-App-83.5x83.5@2x.png", 167),
            ("Icon-App-1024x1024@1x.png", 1024),
        ]
        for name, px in ios:
            # Settings/Spotlight slots are tiny; give them the simple glyph.
            variant = "small" if px <= 60 else "ios"
            targets.append(("staff", variant, os.path.join(ios_dir, name), px))

    for palette, variant, path, px in targets:
        downsample(masters[(palette, variant)], path, px)
        print(f"  {px:>4}px  {path}")

    for path in masters.values():
        os.remove(path)
    print(f"\n{len(targets)} icons written.")


if __name__ == "__main__":
    main()
