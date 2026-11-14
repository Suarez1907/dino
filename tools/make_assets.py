#!/usr/bin/env python3
"""Draw the app icon, adaptive icon, and boot splash. No third-party art."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
GODOT = ROOT / "godot"
FONT = GODOT / "assets" / "fonts" / "Nunito-Bold.ttf"


def rounded(size, radius, color):
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=color)
    return image


def dino_face(draw, cx, cy, scale, fill, ink):
    draw.ellipse((cx - 34 * scale, cy - 28 * scale, cx + 34 * scale, cy + 30 * scale), fill=fill)
    draw.ellipse((cx - 18 * scale, cy - 6 * scale, cx - 6 * scale, cy + 8 * scale), fill=ink)
    draw.ellipse((cx + 6 * scale, cy - 6 * scale, cx + 18 * scale, cy + 8 * scale), fill=ink)
    draw.ellipse((cx - 14 * scale, cy - 4 * scale, cx - 10 * scale, cy), fill=(255, 255, 255, 255))
    draw.ellipse((cx + 10 * scale, cy - 4 * scale, cx + 14 * scale, cy), fill=(255, 255, 255, 255))
    draw.arc((cx - 16 * scale, cy + 6 * scale, cx + 16 * scale, cy + 24 * scale), 20, 160, fill=ink, width=max(2, int(3 * scale)))
    draw.polygon(
        [
            (cx - 28 * scale, cy - 10 * scale),
            (cx - 18 * scale, cy - 36 * scale),
            (cx - 8 * scale, cy - 8 * scale),
        ],
        fill=(243, 234, 212, 255),
    )
    draw.polygon(
        [
            (cx + 10 * scale, cy - 12 * scale),
            (cx + 24 * scale, cy - 40 * scale),
            (cx + 30 * scale, cy - 8 * scale),
        ],
        fill=(243, 234, 212, 255),
    )


def icon(size, bg, face):
    image = rounded(size, int(size * 0.22), bg)
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle(
        (int(size * 0.08), int(size * 0.08), int(size * 0.92), int(size * 0.92)),
        radius=int(size * 0.18),
        fill=(135, 192, 106, 255),
    )
    dino_face(draw, size * 0.5, size * 0.56, size / 128.0, face, (36, 48, 68, 255))
    # little bone
    draw.line(
        (size * 0.72, size * 0.78, size * 0.88, size * 0.68),
        fill=(246, 234, 210, 255),
        width=max(3, size // 28),
    )
    return image


def splash():
    image = Image.new("RGBA", (1280, 720), (252, 214, 140, 255))
    draw = ImageDraw.Draw(image)
    for i, color in enumerate([(230, 176, 96), (196, 132, 73), (232, 196, 138)]):
        draw.ellipse((80 + i * 30, 430, 520 + i * 80, 820), fill=color + (255,))
    draw.ellipse((760, 460, 1260, 860), fill=(214, 156, 92, 255))
    # sky band
    draw.rectangle((0, 0, 1280, 360), fill=(143, 206, 232, 255))
    draw.ellipse((860, 40, 1040, 220), fill=(255, 214, 120, 255))
    dino = Image.new("RGBA", (420, 360), (0, 0, 0, 0))
    d = ImageDraw.Draw(dino)
    dino_face(d, 210, 190, 4.2, (244, 227, 188, 255), (36, 48, 68, 255))
    image.alpha_composite(dino, (430, 210))
    font = ImageFont.truetype(str(FONT), 92) if FONT.exists() else ImageFont.load_default()
    small = ImageFont.truetype(str(FONT), 36) if FONT.exists() else font
    draw.text((80, 70), "Dino Kazı", font=font, fill=(36, 48, 68, 255))
    draw.text((84, 180), "Kayıp kemikleri bul.", font=small, fill=(36, 48, 68, 230))
    return image


def branding():
    image = Image.new("RGBA", (720, 160), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(str(FONT), 72) if FONT.exists() else ImageFont.load_default()
    draw.text((20, 36), "Dino Kazı", font=font, fill=(36, 48, 68, 255))
    return image


def main():
    icon_dir = GODOT / "assets" / "icon"
    icon_dir.mkdir(parents=True, exist_ok=True)
    icon(512, (246, 193, 91, 255), (244, 227, 188, 255)).save(GODOT / "icon.png")
    icon(192, (246, 193, 91, 255), (244, 227, 188, 255)).save(icon_dir / "icon_192.png")
    icon(432, (0, 0, 0, 0), (244, 227, 188, 255)).save(icon_dir / "adaptive_fg.png")
    rounded(432, 96, (246, 193, 91, 255)).save(icon_dir / "adaptive_bg.png")
    splash().save(GODOT / "assets" / "splash.png")
    branding().save(GODOT / "assets" / "splash_branding.png")
    print("assets ok")


if __name__ == "__main__":
    main()
