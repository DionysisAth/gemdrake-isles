#!/usr/bin/env python3
"""Builds advertising pictures and a landscape trailer for YouTube / Play.

1. Record frames from the game:
     SHOTS=build/promo flutter test test_shots/promo_test.dart
2. Make the store graphics first (they're reused):
     python3 tool/promo/make_promo.py build/promo build/store
3. Compose (needs Pillow, numpy and imageio-ffmpeg):
     python3 tool/promo/make_ads.py build/promo build/store build/ads

Writes to the output folder:
  gemdrake_isles_trailer_1080p.mp4   1920x1080, 30 fps, H.264 + AAC
  pictures/in_game/       the game's own screens, no text
  pictures/story_9x16/    1080x1920 (Stories, Reels, TikTok, Play screenshots)
  pictures/square_1x1/    1080x1080 (Instagram / Facebook feed)
  pictures/landscape_16x9/ 1920x1080 (YouTube, Facebook, X, web)
  pictures/feature_graphic.png, pictures/icon_512.png
"""

import math
import pathlib
import shutil
import subprocess
import sys

import imageio_ffmpeg
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from make_promo import INK, ROOT, font, frames, gradient, rounded  # noqa: E402

FPS = 30
FADE = 8
LW, LH = 1920, 1080
ICON = ROOT / "tool/icon/icon-1024.png"


def ease(t):
    t = max(0.0, min(1.0, t))
    return 1 - (1 - t) ** 3


def text_block(img, lines, x, y, size, fill="white", stroke=INK, sw=8, align="left", alpha=1.0):
    """Draws [lines] from (x, y); x is the left edge, or the centre if centred."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    f = font(size)
    for i, line in enumerate(lines):
        w = d.textbbox((0, 0), line, font=f, stroke_width=sw)[2]
        lx = x - w / 2 if align == "center" else x
        d.text((lx, y + i * size * 1.12), line, font=f, fill=fill, stroke_width=sw, stroke_fill=stroke)
    if alpha < 1:
        layer.putalpha(layer.getchannel("A").point(lambda v: int(v * alpha)))
    img.alpha_composite(layer)


def phone(app, height):
    """App screenshot in a white phone bezel, with its drop shadow."""
    ph = height
    pw = int(ph * app.width / app.height)
    shot = rounded(app.convert("RGB").resize((pw, ph), Image.LANCZOS), int(ph * 0.03))
    pad = max(10, int(ph * 0.01))
    bezel = Image.new("RGBA", (pw + 2 * pad, ph + 2 * pad), (0, 0, 0, 0))
    ImageDraw.Draw(bezel).rounded_rectangle(
        [0, 0, bezel.width - 1, bezel.height - 1], int(ph * 0.04), fill="white"
    )
    bezel.alpha_composite(shot, (pad, pad))
    m = 40
    out = Image.new("RGBA", (bezel.width + 2 * m, bezel.height + 2 * m), (0, 0, 0, 0))
    ImageDraw.Draw(out).rounded_rectangle(
        [m + 8, m + 20, m + bezel.width + 8, m + bezel.height + 20],
        int(ph * 0.04),
        fill=(40, 20, 70, 110),
    )
    out = out.filter(ImageFilter.GaussianBlur(18))
    out.alpha_composite(bezel, (m, m))
    return out


def sky_fill(frame, w, h):
    """The island frame's sky (a top-to-bottom gradient), widened to w x h.

    Each row's colour is the median of the frame's outer columns, which are
    sky apart from the odd floating rock.
    """
    a = np.asarray(frame.convert("RGB").resize((frame.width * h // frame.height, h)), dtype=np.float32)
    edge = max(4, a.shape[1] // 12)
    rows = np.median(np.concatenate([a[:, :edge], a[:, -edge:]], axis=1), axis=1)
    # The island reaches the frame's edges in its middle rows: blend the sky
    # colour from above it to the colour below it there instead.
    top, bottom = int(h * 0.30), int(h * 0.90)
    f = np.linspace(0, 1, bottom - top)[:, None]
    rows[top:bottom] = rows[top] * (1 - f) + rows[bottom] * f
    # Smooth out any rock that sits at the edge.
    k = 61
    pad = np.pad(rows, ((k // 2, k // 2), (0, 0)), mode="edge")
    rows = np.stack([np.convolve(pad[:, c], np.ones(k) / k, mode="valid") for c in range(3)], axis=1)
    sky = np.repeat(rows[:, None, :], w, axis=1).clip(0, 255).astype(np.uint8)
    return Image.fromarray(sky, "RGB").convert("RGBA")


def island_card(frame, w, h, cx):
    """The portrait island frame on a canvas of w x h, centred on x=cx, with
    its left and right edges fading into a blurred fill."""
    canvas = sky_fill(frame, w, h)
    fw = int(frame.width * h / frame.height)
    pic = frame.convert("RGBA").resize((fw, h), Image.LANCZOS)
    fade = Image.new("L", (fw, h), 255)
    d = ImageDraw.Draw(fade)
    edge = int(fw * 0.18)
    for x in range(edge):
        v = int(255 * ease(x / edge))
        d.line([(x, 0), (x, h)], fill=v)
        d.line([(fw - 1 - x, 0), (fw - 1 - x, h)], fill=v)
    pic.putalpha(fade)
    canvas.alpha_composite(pic, (int(cx - fw / 2), 0))
    return canvas


def logo(img, x, y, size=84, alpha=1.0):
    icon = rounded(Image.open(ICON).convert("RGB").resize((size, size), Image.LANCZOS), size // 5)
    if alpha < 1:
        icon.putalpha(icon.getchannel("A").point(lambda v: int(v * alpha)))
    img.alpha_composite(icon, (x, y))
    text_block(img, ["Gemdrake Isles"], x + size + 22, y + size * 0.16, int(size * 0.6), sw=6, alpha=alpha)


_bg = {}


def bg(w, h):
    if (w, h) not in _bg:
        _bg[(w, h)] = gradient(w, h)
    return _bg[(w, h)].copy()


# ---------------------------------------------------------------- pictures


def landscape_app(app, lines, t=1.0, sub=None):
    img = bg(LW, LH)
    p = phone(app, 960)
    a = ease(t * 2)
    img.alpha_composite(p, (LW - p.width - 120, int((LH - p.height) / 2 + (1 - a) * 40)))
    logo(img, 110, 90, alpha=a)
    y = 360 - (len(lines) - 2) * 50
    text_block(img, lines, 110, y + (1 - a) * 30, 104, alpha=a)
    if sub:
        text_block(img, [sub], 116, y + len(lines) * 116 + 30, 46, stroke=(90, 50, 140), sw=5, alpha=a)
    return img.convert("RGB")


def landscape_island(frame, lines, t=1.0, sub=None):
    img = island_card(frame, LW, LH, LW * 0.68)
    a = ease(t * 2)
    logo(img, 110, 90, alpha=a)
    y = 360 - (len(lines) - 2) * 50
    text_block(img, lines, 110, y + (1 - a) * 30, 104, alpha=a)
    if sub:
        text_block(img, [sub], 116, y + len(lines) * 116 + 30, 46, stroke=(90, 50, 140), sw=5, alpha=a)
    return img.convert("RGB")


def square_app(app, lines):
    img = bg(1080, 1080)
    text_block(img, lines, 540, 50, 78, align="center")
    p = phone(app, 1080 - 120 - len(lines) * 88)
    img.alpha_composite(p, ((1080 - p.width) // 2, 1080 - p.height + 30))
    return img.convert("RGB")


def square_island(frame, lines):
    img = island_card(frame, 1080, 1080, 540)
    text_block(img, lines, 540, 50, 78, align="center")
    return img.convert("RGB")


SHOTS = [
    ("board", "app", ["Merge gems, plants", "& dragon eggs"], "Drag two alike together to make something better"),
    ("hatch", "app", ["Hatch adorable", "dragons"], "Earth, Water, Fire, Crystal and Shadow"),
    ("island", "app", ["Restore magical", "floating islands"], "Rebuild bridges, towers, gardens and more"),
    ("festival", "app", ["Weekly festivals"], "Exclusive dragons and rewards every week"),
    ("book", "app", ["Collect every", "dragon"], "Fill your Dragon Book"),
    ("world_volcano", "island", ["5 worlds to bring", "back to life"], "Meadow, Volcano, Lagoon, Crystal, Shadow"),
    ("world_lagoon", "island", ["Sunny Lagoon"], "Palm trees, waterfalls and sea dragons"),
    ("world_crystal", "island", ["Crystal Peaks"], "Sparkling towers in the clouds"),
    ("world_shadow", "island", ["Shadow Isle"], "Lanterns, mystery and rare dragons"),
]


def pictures(src, store, out):
    pics = out / "pictures"
    shutil.rmtree(pics, ignore_errors=True)
    for sub in ["in_game", "story_9x16", "square_1x1", "landscape_16x9"]:
        (pics / sub).mkdir(parents=True)
    st = src / "stills"
    for f in sorted(st.glob("*.png")):
        shutil.copy(f, pics / "in_game" / f.name)
    for f in sorted(store.glob("screenshot_*.png")):
        shutil.copy(f, pics / "story_9x16" / f.name.replace("screenshot", "story"))
    for name in ["feature_graphic.png", "icon_512.png"]:
        shutil.copy(store / name, pics / name)
    for i, (name, kind, lines, sub) in enumerate(SHOTS, 1):
        img = Image.open(st / f"{name}.png")
        tag = f"{i:02d}_{name}.png"
        if kind == "app":
            landscape_app(img, lines, sub=sub).save(pics / "landscape_16x9" / tag)
            square_app(img, lines).save(pics / "square_1x1" / tag)
        else:
            landscape_island(img, lines, sub=sub).save(pics / "landscape_16x9" / tag)
            square_island(img, lines).save(pics / "square_1x1" / tag)
    # A wide banner (YouTube / Facebook cover).
    banner = island_card(Image.open(st / "world_lagoon.png"), 2560, 1440, 1880)
    icon = rounded(Image.open(ICON).convert("RGB").resize((300, 300), Image.LANCZOS), 60)
    banner.alpha_composite(icon, (300, 470))
    text_block(banner, ["Gemdrake", "Isles"], 650, 470, 150, sw=10)
    text_block(banner, ["Merge. Hatch. Restore."], 660, 820, 70, stroke=(90, 50, 140), sw=6)
    banner.convert("RGB").save(pics / "banner_2560x1440.png")
    return pics


# ---------------------------------------------------------------- trailer


def intro(n):
    for i in range(n):
        img = bg(LW, LH)
        t = i / FPS
        pop = ease(t / 0.6)
        size = int(360 * (0.55 + 0.45 * pop) * (1 + 0.015 * math.sin(t * 4)))
        icon = rounded(Image.open(ICON).convert("RGB").resize((size, size), Image.LANCZOS), size // 5)
        img.alpha_composite(icon, ((LW - size) // 2, 170 + (360 - size) // 2))
        a = ease((t - 0.35) / 0.5)
        text_block(img, ["Gemdrake Isles"], LW / 2, 600 + (1 - a) * 30, 130, align="center", sw=10, alpha=a)
        b = ease((t - 0.8) / 0.5)
        text_block(img, ["Merge. Hatch. Restore."], LW / 2, 780, 64, align="center",
                   stroke=(90, 50, 140), sw=6, alpha=b)
        yield img.convert("RGB")


def scene(paths, kind, lines, sub, n=None):
    paths = list(paths)
    n = n or len(paths)
    for i in range(n):
        f = Image.open(paths[min(i, len(paths) - 1)])
        t = i / 20
        yield (landscape_app if kind == "app" else landscape_island)(f, lines, t, sub)


def still(path, kind, lines, sub, n):
    """A still with a slow zoom, so it doesn't look frozen."""
    base = Image.open(path).convert("RGB")
    for i in range(n):
        z = 1 + 0.06 * i / n
        w, h = base.size
        cw, ch = int(w / z), int(h / z)
        f = base.crop(((w - cw) // 2, (h - ch) // 3, (w - cw) // 2 + cw, (h - ch) // 3 + ch)).resize((w, h))
        yield (landscape_app if kind == "app" else landscape_island)(f, lines, i / 20, sub)


def end_card(n):
    for i in range(n):
        img = bg(LW, LH)
        t = i / FPS
        pop = ease(t / 0.5)
        size = int(330 * (0.6 + 0.4 * pop) * (1 + 0.015 * math.sin(t * 4)))
        icon = rounded(Image.open(ICON).convert("RGB").resize((size, size), Image.LANCZOS), size // 5)
        img.alpha_composite(icon, ((LW - size) // 2, 120 + (330 - size) // 2))
        text_block(img, ["Gemdrake Isles"], LW / 2, 500, 120, align="center", sw=10)
        text_block(img, ["Merge. Hatch. Restore."], LW / 2, 660, 58, align="center", stroke=(90, 50, 140), sw=6)
        a = ease((t - 0.4) / 0.4)
        d = ImageDraw.Draw(img)
        f = font(58)
        label = "Free on Google Play"
        box = d.textbbox((0, 0), label, font=f)
        pw, ph = box[2] - box[0] + 120, 124
        px, py = (LW - pw) // 2, 800 + int((1 - a) * 30)
        pill = Image.new("RGBA", img.size, (0, 0, 0, 0))
        pd = ImageDraw.Draw(pill)
        pd.rounded_rectangle([px, py + 10, px + pw, py + ph + 10], 62, fill=(46, 154, 79))
        pd.rounded_rectangle([px, py, px + pw, py + ph], 62, fill=(76, 191, 107))
        pd.text((px + 60, py + 26), label, font=f, fill="white")
        pill.putalpha(pill.getchannel("A").point(lambda v: int(v * a)))
        img.alpha_composite(pill)
        yield img.convert("RGB")


def trailer(src, out):
    st = src / "stills"
    scenes = [
        ("intro", intro(75)),
        ("board", scene(frames(src / "s1_board"), "app", ["Merge to make", "magic"],
                        "Match gems, plants and eggs")),
        ("hatch", scene(frames(src / "s2_hatch"), "app", ["Hatch adorable", "dragons"],
                        "Common, rare, epic and legendary")),
        ("restore", scene(frames(src / "s3_restore"), "island", ["Restore floating", "islands"],
                          "Watch every island come back to life")),
        ("worlds", scene(frames(src / "s4_worlds"), "island", ["Explore 5", "magical worlds"],
                         "Meadow, Volcano, Lagoon, Crystal, Shadow")),
        ("island", still(st / "island.png", "app", ["Earn coins while", "you're away"],
                         "Your dragons keep collecting treasure", 100)),
        ("festival", still(st / "festival.png", "app", ["Weekly festivals"],
                           "Exclusive dragons and rewards", 100)),
        ("book", still(st / "book.png", "app", ["Collect them all"],
                       "35 dragons in the Dragon Book", 100)),
        ("end", end_card(110)),
    ]
    starts, total = {}, 0
    ff = imageio_ffmpeg.get_ffmpeg_exe()
    raw = out / "_video.mp4"
    enc = subprocess.Popen(
        [ff, "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
         "-s", f"{LW}x{LH}", "-r", str(FPS), "-i", "-",
         "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p", str(raw)],
        stdin=subprocess.PIPE,
    )
    # The last FADE frames of each scene are held back and blended into the
    # first FADE frames of the next one.
    pending = []
    for name, gen in scenes:
        tail, pending = pending, []
        starts[name] = total
        for k, fr in enumerate(gen):
            if k < len(tail):
                fr = Image.blend(tail[k], fr, (k + 1) / (len(tail) + 1))
            pending.append(fr)
            if len(pending) > FADE:
                enc.stdin.write(pending.pop(0).tobytes())
                total += 1
    for fr in pending:
        enc.stdin.write(fr.tobytes())
        total += 1
    enc.stdin.close()
    enc.wait()
    seconds = total / FPS

    audio = ROOT / "assets/audio"
    at = lambda scene, frame: (starts[scene] + frame) / FPS  # noqa: E731
    sfx = [
        ("pop.wav", at("intro", 4)),
        ("merge_6.wav", at("board", 9)),
        ("merge_4.wav", at("board", 48)),
        ("merge_3.wav", at("board", 75)),
        ("hatch.wav", at("hatch", 2)),
        ("restore.wav", at("restore", 8)),
        ("restore.wav", at("restore", 38)),
        ("restore.wav", at("restore", 68)),
        ("coin.wav", at("island", 10)),
        ("bonus.wav", at("festival", 10)),
        ("chirp.wav", at("book", 10)),
        ("levelup.wav", at("end", 12)),
    ]
    inputs = ["-i", str(raw), "-i", str(audio / "music_meadow.wav"), "-i", str(audio / "music_lagoon.wav")]
    filters = [
        "[1:a]aresample=44100[m1]",
        "[2:a]aresample=44100[m2]",
        f"[m1][m2]acrossfade=d=2,volume=0.5,atrim=0:{seconds:.2f},"
        f"afade=t=out:st={seconds - 1.5:.2f}:d=1.5[m]",
    ]
    mix = ["[m]"]
    for n, (name, t) in enumerate(sfx):
        inputs += ["-i", str(audio / name)]
        ms = int(t * 1000)
        filters.append(f"[{n + 3}:a]aresample=44100,adelay={ms}|{ms},volume=0.85[s{n}]")
        mix.append(f"[s{n}]")
    filters.append("".join(mix) + f"amix=inputs={len(mix)}:normalize=0,atrim=0:{seconds:.2f}[a]")
    subprocess.run(
        [ff, "-y", "-loglevel", "error"] + inputs
        + ["-filter_complex", ";".join(filters), "-map", "0:v", "-map", "[a]",
           "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-ar", "44100", "-ac", "2",
           "-movflags", "+faststart", str(out / "gemdrake_isles_trailer_1080p.mp4")],
        check=True,
    )
    raw.unlink()
    return seconds


def main():
    src = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "build/promo")
    store = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else "build/store")
    out = pathlib.Path(sys.argv[3] if len(sys.argv) > 3 else "build/ads")
    out.mkdir(parents=True, exist_ok=True)
    pictures(src, store, out)
    seconds = trailer(src, out)
    print(f"Done: {out} (trailer {seconds:.1f} s)")


if __name__ == "__main__":
    main()
