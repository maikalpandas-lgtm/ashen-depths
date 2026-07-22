#!/usr/bin/env python3
"""
Chromakey sprite cutter for AI assets (magenta / custom key color).

- Flood-fill from image edges only (won't punch holes if key color appears inside)
- Removes color fringe (despill-ish) along the silhouette
- Crops to opaque bounds + pad
- Optional ffmpeg path for pure key colors (see --ffmpeg)

Usage:
  python3 tools/sprite_cutter.py assets/textures/raw assets/textures \\
      --color FF00FF --tolerance 48 --pad 4

  # single file:
  python3 tools/sprite_cutter.py raw/hand.png out/hand.png --color FF00FF
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from collections import deque
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Need Pillow: pip install pillow", file=sys.stderr)
    sys.exit(1)


def parse_color(s: str) -> tuple[int, int, int]:
    s = s.strip().lstrip("#")
    if len(s) != 6:
        raise ValueError(f"color must be RRGGBB, got {s}")
    return int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16)


def color_dist(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2) ** 0.5


def is_key(r: int, g: int, b: int, key: tuple[int, int, int], tol: float) -> bool:
    if color_dist((r, g, b), key) <= tol:
        return True
    # Near-magenta / pink fallback (AI rarely hits exact #FF00FF)
    if key[0] > 200 and key[2] > 150 and key[1] < 80:
        if r > 180 and b > 100 and g < 140 and r + b > g * 2.0:
            return True
    return False


def cut_edge_flood(
    im: Image.Image,
    key: tuple[int, int, int],
    tol: float,
    pad: int,
) -> Image.Image:
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()

    vis = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        q.append((x, 0))
        q.append((x, h - 1))
    for y in range(h):
        q.append((0, y))
        q.append((w - 1, y))

    while q:
        x, y = q.popleft()
        if not (0 <= x < w and 0 <= y < h) or vis[y][x]:
            continue
        r, g, b, _a = px[x, y]
        if not is_key(r, g, b, key, tol):
            continue
        vis[y][x] = True
        px[x, y] = (0, 0, 0, 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q.append((x + dx, y + dy))

    # Fringe / despill: key-tinted pixels adjacent to transparency
    for _ in range(3):
        kill: list[tuple[int, int]] = []
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue
                # near-key halo (works for ANY key colour), plus the old
                # magenta/pink spill heuristic.
                #
                # The magenta test requires g < 150, so on a WHITE key it never
                # fired and the anti-aliased white ramp survived as a bright
                # outline. The generic distance test below is what catches it.
                spill = (
                    color_dist((r, g, b), key) <= tol * 1.9
                    or is_key(r, g, b, key, tol * 1.15)
                    or (r > 160 and b > 90 and g < 150 and r + b > g * 1.8)
                )
                if not spill:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] == 0:
                        kill.append((x, y))
                        break
        for x, y in kill:
            px[x, y] = (0, 0, 0, 0)

    # Solid alpha on subject
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if a < 40:
                px[x, y] = (0, 0, 0, 0)
            else:
                px[x, y] = (r, g, b, 255)

    bb = im.getbbox()
    if not bb:
        return im
    x0, y0, x1, y1 = bb
    x0 = max(0, x0 - pad)
    y0 = max(0, y0 - pad)
    x1 = min(w, x1 + pad)
    y1 = min(h, y1 + pad)
    return im.crop((x0, y0, x1, y1))


def cut_ffmpeg(src: Path, dst: Path, key_hex: str, similarity: float, blend: float) -> bool:
    if not shutil.which("ffmpeg"):
        return False
    # colorkey everywhere (not edge-safe) — only for pure key colors
    vf = f"colorkey=0x{key_hex}:{similarity}:{blend},format=rgba"
    cmd = [
        "ffmpeg", "-y", "-i", str(src),
        "-vf", vf,
        "-frames:v", "1",
        str(dst),
    ]
    r = subprocess.run(cmd, capture_output=True)
    return r.returncode == 0 and dst.exists()


def process_file(
    src: Path,
    dst: Path,
    key: tuple[int, int, int],
    tol: float,
    pad: int,
    use_ffmpeg: bool,
    key_hex: str,
) -> None:
    if use_ffmpeg:
        tmp = dst.with_suffix(".fftmp.png")
        if cut_ffmpeg(src, tmp, key_hex, 0.35, 0.12):
            im = Image.open(tmp).convert("RGBA")
            # still run edge cleanup + crop
            im = cut_edge_flood(im, key, tol, pad)
            im.save(dst)
            tmp.unlink(missing_ok=True)
            print(f"  ffmpeg+clean {src.name} -> {dst.name} {im.size}")
            return
        print(f"  ffmpeg failed, falling back to flood for {src.name}")

    im = Image.open(src)
    out = cut_edge_flood(im, key, tol, pad)
    out.save(dst)
    print(f"  flood {src.name} -> {dst.name} {out.size}")


def main() -> None:
    ap = argparse.ArgumentParser(description="Chromakey sprite cutter (edge flood)")
    ap.add_argument("src", help="Input file or directory")
    ap.add_argument("dst", help="Output file or directory")
    ap.add_argument("--color", default="FF00FF", help="Key color RRGGBB (default magenta)")
    ap.add_argument("--tolerance", type=float, default=48.0, help="Color distance tolerance")
    ap.add_argument("--pad", type=int, default=4, help="Crop padding px")
    ap.add_argument(
        "--ffmpeg",
        action="store_true",
        help="Try ffmpeg colorkey first (not edge-safe; pure key only)",
    )
    args = ap.parse_args()

    key = parse_color(args.color)
    key_hex = args.color.strip().lstrip("#").upper()
    src = Path(args.src)
    dst = Path(args.dst)

    if src.is_file():
        dst.parent.mkdir(parents=True, exist_ok=True)
        if dst.is_dir():
            dst = dst / (src.stem + ".png")
        process_file(src, dst, key, args.tolerance, args.pad, args.ffmpeg, key_hex)
        return

    if not src.is_dir():
        print(f"Not found: {src}", file=sys.stderr)
        sys.exit(1)

    dst.mkdir(parents=True, exist_ok=True)
    exts = {".png", ".jpg", ".jpeg", ".webp"}
    files = sorted(p for p in src.iterdir() if p.suffix.lower() in exts)
    if not files:
        print(f"No images in {src}")
        return
    for f in files:
        process_file(
            f, dst / f"{f.stem}.png", key, args.tolerance, args.pad, args.ffmpeg, key_hex
        )


if __name__ == "__main__":
    main()
