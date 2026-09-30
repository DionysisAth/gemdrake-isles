#!/usr/bin/env python3
"""Builds the store graphics and a 15-second 9:16 promo video.

1. Record frames from the game:
     SHOTS=build/promo flutter test test_shots/promo_test.dart
2. Compose:
     python3 tool/promo/make_promo.py build/promo build/store
   (needs Pillow and imageio-ffmpeg: pip install pillow imageio-ffmpeg)

Writes to the output folder:
  promo_15s.mp4           1080x1920, 30 fps, H.264 + AAC (TikTok / Reels / Shorts)
  screenshot_1..6.png     1080x1920 Play Store phone screenshots
  feature_graphic.png     1024x500 Play Store feature graphic
  icon_512.png            512x512 Play Store icon
"""

import math
import pathlib
import shutil
import subprocess
import sys

import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
FONT = str(ROOT / "assets/fonts/Fredoka-700.ttf")
FONT_MED = str(ROOT / "assets/fonts/Fredoka-600.ttf")
W, H, FPS = 1080, 1920, 30
TOTAL = 15 * FPS
FADE = 6  # crossfade frames between scenes

INK = (48, 30, 79)
TOP, BOTTOM = (124, 92, 255), (255, 126, 182)


def font(size, medium=False):
    return ImageFont.truetype(FONT_MED if medium else FONT, size)


def gradient(w, h, top=TOP, bottom=BOTTOM):
    g = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        g.putpixel((0, y), tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))
    img = g.resize((w, h))
    # Soft light spots
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    for x, y, r in [(0.15, 0.12, 0.35), (0.9, 0.55, 0.3), (0.3, 0.9, 0.28)]:
        d.ellipse(
            [w * x - w * r, h * y - w * r, w * x + w * r, h * y + w * r],
            fill=(255, 255, 255, 38),
        )
    glow = glow.filter(ImageFilter.GaussianBlur(w * 0.08))
    return Image.alpha_composite(img.convert("RGBA"), glow)


def caption(img, text, y, size=92, fill=(255, 255, 255), stroke=INK):
    d = ImageDraw.Draw(img)
    f = font(size)
    lines = text.split("\n")
    for i, line in enumerate(lines):
        box = d.textbbox((0, 0), line, font=f, stroke_width=9)
        x = (img.width - (box[2] - box[0])) / 2
        d.text(
            (x, y + i * size * 1.1),
            line,
            font=f,
            fill=fill,
            stroke_width=9,
            stroke_fill=stroke,
        )


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, img.width - 1, img.height - 1], radius, fill=255
    )
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


_bg_cache = {}


def phone_frame(app, text, scale=1.0):
    """App screenshot in a white phone bezel on the gradient, with a caption."""
    bg = _bg_cache.get("bg")
    if bg is None:
        bg = _bg_cache["bg"] = gradient(W, H)
    canvas = bg.copy()
    ph = int(1420 * scale)
    pw = int(ph * app.width / app.height)
    shot = rounded(app.resize((pw, ph), Image.LANCZOS), 44)
    bezel = Image.new("RGBA", (pw + 28, ph + 28), (0, 0, 0, 0))
    ImageDraw.Draw(bezel).rounded_rectangle(
        [0, 0, pw + 27, ph + 27], 58, fill=(255, 255, 255, 255)
    )
    bezel.alpha_composite(shot, (14, 14))
    x = (W - bezel.width) // 2
    y = 440 + (1420 - ph) // 2
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x + 10, y + 24, x + bezel.width + 10, y + bezel.height + 24],
        58,
        fill=(40, 20, 70, 110),
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(22)))
    canvas.alpha_composite(bezel, (x, y))
    caption(canvas, text, 150 if "\n" in text else 215)
    return canvas.convert("RGB")


def full_bleed(frame, text):
    img = frame.convert("RGBA").resize((W, H))
    caption(img, text, 230)
    return img.convert("RGB")


def end_card(i, n):
    img = gradient(W, H)
    t = i / max(1, n - 1)
    pop = 1 - (1 - min(1, t * 3)) ** 3  # ease-out pop-in
    icon = Image.open(ROOT / "tool/icon/icon-1024.png").convert("RGBA")
    size = int(440 * (0.6 + 0.4 * pop) * (1 + 0.02 * math.sin(i / 4)))
    icon = rounded(icon.resize((size, size), Image.LANCZOS), size // 5)
    img.alpha_composite(icon, ((W - size) // 2, 520 + (440 - size) // 2))
    caption(img, "Gemdrake Isles", 1040, size=118)
    caption(img, "Merge. Hatch. Restore.", 1200, size=64, stroke=(90, 50, 140))
    # "Free on Google Play" pill
    d = ImageDraw.Draw(img)
    f = font(58)
    label = "Free on Google Play"
    box = d.textbbox((0, 0), label, font=f)
    pw, ph = box[2] - box[0] + 110, 128
    px, py = (W - pw) // 2, 1360
    d.rounded_rectangle([px, py + 10, px + pw, py + ph + 10], 64, fill=(46, 154, 79))
    d.rounded_rectangle([px, py, px + pw, py + ph], 64, fill=(76, 191, 107))
    d.text((px + 55, py + 26), label, font=f, fill="white")
    return img.convert("RGB")


def frames(folder):
    return sorted(pathlib.Path(folder).glob("f_*.png"))


def build_video(src, out):
    scenes = [
        ("board", [phone_frame(Image.open(f), "Merge to make magic") for f in frames(src / "s1_board")]),
        ("hatch", [phone_frame(Image.open(f), "Hatch adorable\ndragons") for f in frames(src / "s2_hatch")[:72]]),
        ("restore", [full_bleed(Image.open(f), "Restore floating\nislands") for f in frames(src / "s3_restore")]),
        ("worlds", [full_bleed(Image.open(f), "Explore 5 magical\nworlds") for f in frames(src / "s4_worlds")]),
    ]
    used = sum(len(s) for _, s in scenes) - FADE * len(scenes)
    end_n = TOTAL - used
    scenes.append(("end", [end_card(i, end_n) for i in range(end_n)]))

    tmp = out / "_frames"
    shutil.rmtree(tmp, ignore_errors=True)
    tmp.mkdir(parents=True)
    starts = {}
    seq = []
    for name, fr in scenes:
        starts[name] = max(0, len(seq) - FADE) if seq else 0
        if seq:
            # Crossfade the last FADE frames with the first FADE of this scene.
            for k in range(FADE):
                a = seq[len(seq) - FADE + k]
                seq[len(seq) - FADE + k] = Image.blend(a, fr[k], (k + 1) / (FADE + 1))
            fr = fr[FADE:]
        seq.extend(fr)
    seq = seq[:TOTAL]
    while len(seq) < TOTAL:
        seq.append(seq[-1])
    for i, im in enumerate(seq):
        im.save(tmp / f"v_{i:04d}.png")

    # Music + sound effects at the moments they happen.
    audio = ROOT / "assets/audio"
    s = lambda frame: frame / FPS
    sfx = [
        ("merge_6.wav", s(starts["board"] + 9)),
        ("merge_4.wav", s(starts["board"] + 48)),
        ("merge_3.wav", s(starts["board"] + 75)),
        ("hatch.wav", s(starts["hatch"] + 2)),
        ("restore.wav", s(starts["restore"] + 8)),
        ("restore.wav", s(starts["restore"] + 38)),
        ("restore.wav", s(starts["restore"] + 68)),
        ("levelup.wav", s(starts["end"] + 2)),
    ]
    inputs = ["-i", str(audio / "music_meadow.wav")]
    filters = ["[1:a]volume=0.55,afade=t=out:st=13.8:d=1.2[m]"]
    mix = ["[m]"]
    for n, (name, t) in enumerate(sfx):
        inputs += ["-i", str(audio / name)]
        ms = int(t * 1000)
        filters.append(f"[{n + 2}:a]adelay={ms}|{ms},volume=0.9[s{n}]")
        mix.append(f"[s{n}]")
    filters.append(
        "".join(mix) + f"amix=inputs={len(mix)}:normalize=0,atrim=0:15[a]"
    )
    ff = imageio_ffmpeg.get_ffmpeg_exe()
    subprocess.run(
        [ff, "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", str(tmp / "v_%04d.png")]
        + inputs
        + [
            "-filter_complex", ";".join(filters),
            "-map", "0:v", "-map", "[a]",
            "-c:v", "libx264", "-preset", "slow", "-crf", "18",
            "-pix_fmt", "yuv420p", "-r", str(FPS),
            "-c:a", "aac", "-b:a", "160k", "-ar", "44100", "-ac", "2",
            "-t", "15", "-movflags", "+faststart",
            str(out / "promo_15s.mp4"),
        ],
        check=True,
    )
    shutil.rmtree(tmp)


def build_stills(src, out):
    st = src / "stills"
    shots = [
        (st / "board.png", "Merge gems, plants\n& dragon eggs", "phone"),
        (st / "island.png", "Restore magical\nfloating islands", "phone"),
        (st / "hatch.png", "Hatch & grow\nadorable dragons", "phone"),
        (st / "world_volcano.png", "5 worlds to bring\nback to life", "full"),
        (st / "festival.png", "Weekly festivals &\nexclusive dragons", "phone"),
        (st / "book.png", "Collect every dragon\nin the Dragon Book", "phone"),
    ]
    for i, (path, text, kind) in enumerate(shots, 1):
        img = Image.open(path)
        res = phone_frame(img, text) if kind == "phone" else full_bleed(img, text)
        res.save(out / f"screenshot_{i}.png")

    # Feature graphic: sky gradient, island on the right, title on the left.
    fg = gradient(1024, 500, (120, 200, 255), (220, 200, 255))
    world = Image.open(st / "world_lagoon.png").convert("RGBA")
    crop = world.crop((0, 320, 1080, 1720)).resize((520, 674), Image.LANCZOS)
    # Fade the picture's left edge into the background.
    fade = Image.new("L", crop.size, 255)
    for x in range(140):
        ImageDraw.Draw(fade).line([(x, 0), (x, crop.height)], fill=int(255 * x / 140))
    crop.putalpha(fade)
    fg.alpha_composite(crop, (500, -110))
    d = ImageDraw.Draw(fg)
    for text, y, size in [("Gemdrake", 110, 104), ("Isles", 215, 104)]:
        d.text((52, y), text, font=font(size), fill="white", stroke_width=8, stroke_fill=INK)
    d.text((56, 350), "Merge. Hatch. Restore.", font=font(42), fill=INK)
    fg.convert("RGB").save(out / "feature_graphic.png")

    Image.open(ROOT / "tool/icon/icon-1024.png").convert("RGB").resize(
        (512, 512), Image.LANCZOS
    ).save(out / "icon_512.png")


def main():
    src = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "build/promo")
    out = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else "build/store")
    out.mkdir(parents=True, exist_ok=True)
    build_stills(src, out)
    build_video(src, out)
    print(f"Done: {out}")


if __name__ == "__main__":
    main()
