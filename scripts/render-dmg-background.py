#!/usr/bin/env python3
"""Draw the Shotli disk-image window. Points are 800×560; the file is @2x."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "macos" / "dmg"
REGULAR = "/usr/share/fonts/truetype/macos/Inter-Regular.ttf"
BOLD = "/usr/share/fonts/truetype/macos/Inter-Bold.ttf"

WIDTH = 800
HEIGHT = 560


def render(scale: int) -> Image.Image:
    image = Image.new("RGBA", (WIDTH * scale, HEIGHT * scale), (244, 245, 247, 255))
    draw = ImageDraw.Draw(image)
    bold = ImageFont.truetype(BOLD, 34 * scale)
    regular = ImageFont.truetype(REGULAR, 15 * scale)
    footer = ImageFont.truetype(REGULAR, 13 * scale)
    icon = Image.open(ROOT / "desktop" / "icon.png").convert("RGBA").resize((28 * scale, 28 * scale), Image.Resampling.LANCZOS)

    title = "Install Shotli"
    title_width = draw.textlength(title, font=bold)
    mark = 28 * scale
    gap = 10 * scale
    row = mark + gap + title_width
    origin = (WIDTH * scale - row) / 2
    image.alpha_composite(icon, (int(origin), int(42 * scale)))
    draw.text((origin + mark + gap, 56 * scale), title, font=bold, fill=(29, 29, 31, 255), anchor="lm")
    draw.text(
        (WIDTH * scale / 2, 96 * scale),
        "Drag Shotli into Applications. Screenshots stay on this Mac.",
        font=regular,
        fill=(110, 110, 115, 255),
        anchor="ma",
    )

    wells = [(60, 148, 340, 448), (460, 148, 740, 448)]
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    for box in wells:
        scaled = [value * scale for value in box]
        scaled[1] += 10 * scale
        scaled[3] += 10 * scale
        shadow_draw.rounded_rectangle(scaled, radius=32 * scale, fill=(20, 20, 20, 28))
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18 * scale)))

    draw = ImageDraw.Draw(image)
    for box in wells:
        scaled = [value * scale for value in box]
        draw.rounded_rectangle(scaled, radius=32 * scale, fill=(255, 255, 255, 255))
        draw.rounded_rectangle(scaled, radius=32 * scale, outline=(0, 0, 0, 18), width=max(1, scale))

    draw_arrow(draw, scale)
    draw.text(
        (WIDTH * scale / 2, 508 * scale),
        "First launch: Control-click Shotli, choose Open, then choose Open again.",
        font=footer,
        fill=(142, 142, 147, 255),
        anchor="ma",
    )
    flat = Image.new("RGB", image.size, (244, 245, 247))
    flat.paste(image, mask=image.getchannel("A"))
    return flat


def draw_arrow(draw: ImageDraw.ImageDraw, scale: int) -> None:
    color = (52, 120, 246, 255)
    cy = 298 * scale
    x0 = 364 * scale
    x1 = 436 * scale
    thickness = 8 * scale
    draw.rounded_rectangle(
        [x0, cy - thickness / 2, x1 - 18 * scale, cy + thickness / 2],
        radius=thickness / 2,
        fill=color,
    )
    head = 18 * scale
    draw.polygon(
        [(x1 - 24 * scale, cy - head), (x1, cy), (x1 - 24 * scale, cy + head)],
        fill=color,
    )


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    retina = render(2)
    retina.save(OUT / "background@2x.png", dpi=(144, 144))
    one = render(1)
    one.save(OUT / "background.png", dpi=(72, 72))


if __name__ == "__main__":
    main()
