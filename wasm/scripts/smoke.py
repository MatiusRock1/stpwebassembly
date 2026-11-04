"""Browser check of the packaged game: start it and look for working frames.

Opens the player in the installed Chrome (Playwright), presses Start and waits.
It passes when the engine reports no fatal or script error, frames keep coming and
the last capture of the game is not a flat colour (a flat 1280x720 PNG compresses
to a few KiB). Captures, the engine log and summary.json go to --out.

  python wasm/scripts/smoke.py [--url http://localhost:8093/index.html]
      [--args "--stp-minigames=hurdle"] [--wait 30] [--headed] [--out DIR]

Needs Playwright for Python and Chrome. It launches Chrome on the real GPU; without
one, WebGL falls back to software and the frame rate says nothing.
"""
import argparse
import json
import re
import sys
import time
from pathlib import Path
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from playwright.sync_api import sync_playwright

FLAT_FRAME_BYTES = 32 * 1024
FATAL = re.compile(r'SCRIPT ERROR|Parse Error|Failed to load script|RuntimeError|Aborted|GL_INVALID|WebGL: INVALID')


def with_args(url, engine_args):
    if not engine_args:
        return url
    parts = urlsplit(url)
    return urlunsplit(parts._replace(query=urlencode(parse_qsl(parts.query) + [('args', engine_args)])))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--url', default='http://localhost:8093/index.html')
    parser.add_argument('--args', default='', help='engine options passed with ?args=')
    parser.add_argument('--wait', type=int, default=30, help='seconds to run after the game starts')
    parser.add_argument('--headed', action='store_true')
    parser.add_argument('--out', type=Path, default=Path('smoke-evidence'))
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    console = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            channel='chrome', headless=not args.headed,
            args=['--enable-gpu', '--use-angle=d3d11', '--ignore-gpu-blocklist'])
        page = browser.new_page(viewport={'width': 1400, 'height': 1000})
        page.on('console', lambda message: console.append(f'[{message.type}] {message.text}'))
        page.on('pageerror', lambda error: console.append(f'[pageerror] {error.stack or error}'))
        page.add_init_script('''window.__frames = 0;
            (function tick() { window.__frames++; requestAnimationFrame(tick); })();''')
        page.goto(with_args(args.url, args.args))
        started = time.time()
        page.click('#start')
        state = {}
        while time.time() - started < 300:
            page.wait_for_timeout(500)
            state = page.evaluate('''() => ({status: document.querySelector('#status').textContent,
                loading: document.querySelector('#loading').hidden ? null
                    : document.querySelector('#loading-text').textContent,
                result: window.applicationResult})''')
            if state['loading'] is None or state['result']:
                break
        load_seconds = round(time.time() - started, 1)
        print(json.dumps({**state, 'seconds': load_seconds}), flush=True)
        frames_before = page.evaluate('window.__frames')
        page.wait_for_timeout(args.wait * 1000)
        frames = page.evaluate('window.__frames') - frames_before
        shot = args.out / 'last.png'
        page.locator('#canvas').screenshot(path=str(shot))
        (args.out / 'engine.log').write_text('\n'.join(page.evaluate('window.stpLog || []')), encoding='utf-8')
        (args.out / 'console.log').write_text('\n'.join(console), encoding='utf-8')
        browser.close()

    fatal = [line for line in console if FATAL.search(line)]
    checks = {
        'engine_running': state.get('loading') is None and not state.get('result'),
        'no_script_errors': not fatal,
        'frames_keep_coming': frames > args.wait * 10,
        'last_frame_not_flat': shot.stat().st_size > FLAT_FRAME_BYTES,
    }
    summary = {'checks': checks, 'load_seconds': load_seconds, 'fps': round(frames / args.wait, 1), 'errors': fatal[:20]}
    (args.out / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    print(json.dumps(summary, indent=2))
    sys.exit(0 if all(checks.values()) else 1)


if __name__ == '__main__':
    main()
