"""Erzeugt die kleinen TGA-Texturen in media/ (abgerundete Fenster, Schein, Symbolmaske).

Aufruf:  python tools/make_textures.py
Alle Texturen sind weiß mit Alpha und werden im Spiel per Vertex-Farbe eingefärbt.
Kantenlängen sind Zweierpotenzen. Die Teile werden im Addon als 9-Slice benutzt.
"""
import math
import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "media")


def rrect_sdf(px, py, cx, cy, hw, hh, r):
    """Abstand zu einem abgerundeten Rechteck (negativ innen)."""
    qx = abs(px - cx) - (hw - r)
    qy = abs(py - cy) - (hh - r)
    return math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - r


def clamp(v):
    return max(0.0, min(1.0, v))


def write_tga(name, size, alpha_fn):
    data = bytearray()
    for y in range(size):
        for x in range(size):
            a = int(round(clamp(alpha_fn(x + 0.5, y + 0.5)) * 255))
            data += bytes((255, 255, 255, a))   # BGRA, weiß
    header = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    size & 255, size >> 8, size & 255, size >> 8, 32, 0x28])
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(header + bytes(data))


def fill(size, radius):
    c, h = size / 2, size / 2 - 0.5
    return lambda x, y: 0.5 - rrect_sdf(x, y, c, c, h, h, radius)


def ring(size, radius, thick):
    c, h = size / 2, size / 2 - 0.5
    def fn(x, y):
        d = rrect_sdf(x, y, c, c, h, h, radius)
        return clamp(0.5 - d) * clamp(d + thick + 0.5)
    return fn


def glow(size, margin, radius, power=2.2, peak=0.85):
    """Innen durchsichtig, außen weich auslaufend (liegt über dem Fenster)."""
    c, h = size / 2, size / 2 - margin
    def fn(x, y):
        d = rrect_sdf(x, y, c, c, h, h, radius)
        if d <= 0:
            return 0.0
        return peak * clamp(1 - d / margin) ** power
    return fn


write_tga("fill64.tga", 64, fill(64, 14))
write_tga("ring64.tga", 64, ring(64, 14, 2.0))
write_tga("mask64.tga", 64, fill(64, 14))
write_tga("glow128.tga", 128, glow(128, 32, 14))
write_tga("glowicon64.tga", 64, glow(64, 16, 14))
print("Texturen geschrieben nach", os.path.normpath(OUT))
