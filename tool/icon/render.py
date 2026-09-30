"""Renders tool/icon/icon.svg to PNG with Chromium (Playwright).

  python3 tool/icon/render.py out.png [full|fg|bg] [size]

full = the whole icon, fg = the character on transparency (Android adaptive
foreground, scaled into the safe zone), bg = only the background.
"""
import asyncio, pathlib, sys
from playwright.async_api import async_playwright

HERE = pathlib.Path(__file__).parent
import glob, os
# Use a preinstalled Chromium if there is one.
_found = sorted(glob.glob('/opt/pw-browsers/chromium-*/chrome-linux/chrome'))
CHROME = os.environ.get('CHROME') or (_found[-1] if _found else None)

async def main(out, mode='full', size=1024):
    svg = (HERE / 'icon.svg').read_text()
    if mode == 'fg':
        svg = svg.replace('<g id="bg">', '<g id="bg" display="none">')
        # Android keeps a circle of 66/108 of the canvas; fit the art inside.
        svg = svg.replace('<g id="fg"', '<g transform="translate(512 512) scale(0.74) translate(-512 -560)"><g id="fg"')
        svg = svg.replace('<g id="sparkles">', '</g><g transform="translate(512 512) scale(0.74) translate(-512 -560)"><g id="sparkles">')
        svg = svg.replace('</svg>', '</g></svg>')
    elif mode == 'bg':
        svg = svg.replace('<g id="fg"', '<g id="fg" display="none"')
        svg = svg.replace('<g id="sparkles">', '<g id="sparkles" display="none">')
    html = f'<html><body style="margin:0;background:transparent">{svg}</body></html>'
    async with async_playwright() as p:
        b = await p.chromium.launch(args=['--no-sandbox'], executable_path=CHROME)
        page = await b.new_page(viewport={'width': 1024, 'height': 1024},
                                device_scale_factor=size / 1024)
        await page.set_content(html)
        await page.locator('svg').screenshot(path=out, omit_background=True)
        await b.close()

if __name__ == '__main__':
    asyncio.run(main(sys.argv[1], *(sys.argv[2:3] or ['full']),
                     *([int(sys.argv[3])] if len(sys.argv) > 3 else [])))
