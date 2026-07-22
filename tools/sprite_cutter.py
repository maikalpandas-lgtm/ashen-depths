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


def erode_light_edge(im: Image.Image, light_thr: int, rounds: int) -> Image.Image:
    """Eat the washed anti-aliasing ramp off the silhouette.

    A JPG source blends the art into its background over 2-3px. Keying removes
    the background but leaves that ramp as opaque, WASHED pixels — a bright
    outline that despill's near-key test misses (it is already too far from the
    key colour to match). Since our art always has a thick ink outline, peeling
    LIGHT edge pixels is safe: erosion stops the moment it reaches the black
    line, so the silhouette keeps its shape.
    """
    if rounds <= 0:
        return im
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    total = 0
    for _ in range(rounds):
        kill: list[tuple[int, int]] = []
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a == 0 or min(r, g, b) <= light_thr:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < w and 0 <= ny < h) or px[nx, ny][3] == 0:
                        kill.append((x, y))
                        break
        if not kill:
            break
        for x, y in kill:
            px[x, y] = (0, 0, 0, 0)
        total += len(kill)
    if total:
        print(f"    eroded {total} washed edge px (light > {light_thr})")
    return im


def detect_key(im: Image.Image) -> tuple[int, int, int]:
    """Read the key colour off the image border instead of trusting the prompt.

    Generators do not honour "#FF00FF" exactly — the batch-1 art came back on
    (245, 21, 146), a distance of 116 from pure magenta. ffmpeg keyed nothing at
    that distance and the whole cut silently fell through to the flood, which
    cannot reach background enclosed by art.
    """
    im = im.convert("RGB")
    w, h = im.size
    px = im.load()
    counts: dict[tuple[int, int, int], int] = {}
    step = max(1, min(w, h) // 200)
    for x in range(0, w, step):
        for y in (0, h - 1):
            c = px[x, y]
            counts[c] = counts.get(c, 0) + 1
    for y in range(0, h, step):
        for x in (0, w - 1):
            c = px[x, y]
            counts[c] = counts.get(c, 0) + 1
    return max(counts.items(), key=lambda kv: kv[1])[0]


def kill_key_everywhere(im: Image.Image, key: tuple[int, int, int], tol: float) -> Image.Image:
    """Remove key-coloured pixels the border flood could not reach.

    Edge-flood is deliberately blind to background enclosed by art — the pocket
    between a blade and its slash arc, the inside of a cord loop — and those
    came through as solid pink blobs pasted into the sprite. A saturated key is
    safe to remove globally: no cave/ember palette contains neon magenta. Only
    runs for such keys; on a white or grey key this would eat the art.
    """
    if not (key[0] > 150 and key[2] > 100 and key[1] < 100):
        return im
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    killed = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if is_key(r, g, b, key, tol):
                px[x, y] = (0, 0, 0, 0)
                killed += 1
    if killed:
        print(f"    removed {killed} enclosed background px the flood could not reach")
    return im


def despill_tint(im: Image.Image, key: tuple[int, int, int], band: int) -> Image.Image:
    """Neutralise magenta bleed along the silhouette WITHOUT deleting pixels.

    The delete-based despill only works when the tinted pixel can be thrown
    away. On light art — the pale blue barrier hexes of card_block — the bleed
    sits on pixels we must keep, so deleting them would chew holes in the art.
    Here the magenta is pulled out of the colour instead: magenta spill shows up
    as red AND blue both sitting above green, which no teal/ember palette does.

    Only pixels within `band` of transparency are touched, so genuinely pink or
    purple art deeper inside the sprite is left alone.
    """
    if band <= 0 or not (key[0] > 150 and key[2] > 150 and key[1] < 100):
        return im  # magenta-style key only
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()

    # BFS outward from transparency to mark the edge band
    dist = [[-1] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                dist[y][x] = 0
                q.append((x, y))
    while q:
        x, y = q.popleft()
        if dist[y][x] >= band:
            continue
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and dist[ny][nx] < 0:
                dist[ny][nx] = dist[y][x] + 1
                q.append((nx, ny))

    fixed = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0 or dist[y][x] <= 0:
                continue
            spill = min(r, b) - g
            if spill <= 6:
                continue
            # Fade the correction out across the band so there is no hard line
            k = 1.0 - (dist[y][x] - 1) / float(max(band, 1))
            cut = int(spill * k)
            px[x, y] = (max(0, r - cut), g, max(0, b - cut), a)
            fixed += 1
    if fixed:
        print(f"    de-tinted {fixed} px of magenta bleed")
    return im


def restore_interior(
    im: Image.Image,
    key: tuple[int, int, int] | None = None,
    tol: float = 0.0,
) -> Image.Image:
    """Make an ffmpeg colorkey pass edge-safe.

    `colorkey` keys the WHOLE frame, so any key-coloured pixel INSIDE the
    silhouette is punched out too — on a white key that eats the cream core of
    a flame, highlights on steel, and so on. Here we flood the transparency
    from the border: holes that are not connected to the outside get their
    opacity back, so only real background is removed.

    Connectivity alone is not enough. Art frequently encloses a pocket of real
    background — the gap between a blade and its slash arc, the inside of a
    cord loop — and healing those pasted a solid magenta blob into the sprite.
    So a hole is only healed when its colour is NOT the key: cream inside a
    flame gets its opacity back, actual background does not.
    """
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()

    outside = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        q.append((x, 0))
        q.append((x, h - 1))
    for y in range(h):
        q.append((0, y))
        q.append((w - 1, y))

    while q:
        x, y = q.popleft()
        if not (0 <= x < w and 0 <= y < h) or outside[y][x]:
            continue
        if px[x, y][3] >= 128:
            continue
        outside[y][x] = True
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q.append((x + dx, y + dy))

    healed = 0
    kept = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a >= 128 or outside[y][x]:
                continue
            if key is not None and color_dist((r, g, b), key) <= tol:
                # An enclosed pocket of real background, not a hole in the art
                px[x, y] = (0, 0, 0, 0)
                kept += 1
                continue
            px[x, y] = (r, g, b, 255)
            healed += 1
    if healed:
        print(f"    restored {healed} interior px keyed out by ffmpeg")
    if kept:
        print(f"    left {kept} enclosed background px transparent")
    return im


def process_file(
    src: Path,
    dst: Path,
    key: tuple[int, int, int] | None,
    tol: float,
    pad: int,
    use_ffmpeg: bool,
    key_hex: str,
    ff_similarity: float,
    ff_blend: float,
    erode_light: int,
    light_thr: int,
    despill_band: int,
) -> None:
    if key is None:
        key = detect_key(Image.open(src))
        key_hex = "%02X%02X%02X" % key
        print(f"    key detected from border: #{key_hex}")

    if use_ffmpeg:
        tmp = dst.with_suffix(".fftmp.png")
        if cut_ffmpeg(src, tmp, key_hex, ff_similarity, ff_blend):
            im = Image.open(tmp).convert("RGBA")
            # colorkey is not edge-safe — put back anything it punched out of
            # the interior, then run the usual edge cleanup + crop
            im = restore_interior(im, key, tol)
            im = kill_key_everywhere(im, key, tol)
            im = despill_tint(im, key, despill_band)
            im = erode_light_edge(im, light_thr, erode_light)
            im = cut_edge_flood(im, key, tol, pad)
            im.save(dst)
            tmp.unlink(missing_ok=True)
            print(f"  ffmpeg+clean {src.name} -> {dst.name} {im.size}")
            return
        print(f"  ffmpeg failed, falling back to flood for {src.name}")

    out = cut_edge_flood(Image.open(src), key, tol, pad)
    out = kill_key_everywhere(out, key, tol)
    out = despill_tint(out, key, despill_band)
    out = erode_light_edge(out, light_thr, erode_light)
    out.save(dst)
    print(f"  flood {src.name} -> {dst.name} {out.size}")


def main() -> None:
    ap = argparse.ArgumentParser(description="Chromakey sprite cutter (edge flood)")
    ap.add_argument("src", help="Input file or directory")
    ap.add_argument("dst", help="Output file or directory")
    ap.add_argument("--color", default="auto",
                    help="Key color RRGGBB, or 'auto' to read it off the image border "
                         "(default). Generators rarely hit the requested hex exactly.")
    ap.add_argument("--tolerance", type=float, default=48.0, help="Color distance tolerance")
    ap.add_argument("--pad", type=int, default=4, help="Crop padding px")
    ap.add_argument(
        "--ffmpeg",
        action="store_true",
        help="Use ffmpeg colorkey as the alpha pass (interior holes are healed after)",
    )
    ap.add_argument("--ff-similarity", type=float, default=0.20,
                    help="ffmpeg colorkey similarity (lower = keys less)")
    ap.add_argument("--ff-blend", type=float, default=0.05,
                    help="ffmpeg colorkey blend (soft alpha ramp)")
    ap.add_argument("--erode-light", type=int, default=0,
                    help="Peel N rounds of washed (light) pixels off the silhouette. "
                         "Safe on art with a thick ink outline; fixes bright halos "
                         "left by anti-aliasing in JPG sources.")
    ap.add_argument("--light-threshold", type=int, default=120,
                    help="min(r,g,b) above which an edge pixel counts as washed")
    ap.add_argument("--despill-band", type=int, default=3,
                    help="Neutralise magenta bleed within N px of the silhouette "
                         "instead of deleting those pixels (magenta keys only)")
    args = ap.parse_args()

    auto_key = args.color.strip().lower() == "auto"
    key = None if auto_key else parse_color(args.color)
    key_hex = "" if auto_key else args.color.strip().lstrip("#").upper()
    src = Path(args.src)
    dst = Path(args.dst)

    if src.is_file():
        dst.parent.mkdir(parents=True, exist_ok=True)
        if dst.is_dir():
            dst = dst / (src.stem + ".png")
        process_file(src, dst, key, args.tolerance, args.pad, args.ffmpeg, key_hex,
                     args.ff_similarity, args.ff_blend, args.erode_light,
                     args.light_threshold, args.despill_band)
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
            f, dst / f"{f.stem}.png", key, args.tolerance, args.pad, args.ffmpeg,
            key_hex, args.ff_similarity, args.ff_blend, args.erode_light,
            args.light_threshold, args.despill_band
        )


if __name__ == "__main__":
    main()
