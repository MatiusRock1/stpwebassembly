"""Write the assets nothing uses into the exclude filter of the export presets.

  python wasm/scripts/update_exclusions.py <file with the output of unused_assets.gd>

Upstream ships them in its desktop downloads; a browser would download them for
nothing. They stay in the repository. Generate the input in the toolchain image,
on the imported project (docs/wasm/toolchain.md has the command).
"""
import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PRESETS = ROOT / 'export_presets.cfg'
BASE_FILTER = ['addons/*', 'screenshot.png']
WEB_PRESETS = ['Web', 'Web Mobile', 'Web Server']


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('unused', type=Path)
    args = parser.parse_args()
    unused = sorted(line[len('UNUSED res://'):].strip()
                    for line in args.unused.read_text(encoding='utf-8').splitlines()
                    if line.startswith('UNUSED res://'))
    value = ','.join(BASE_FILTER + unused)
    text = PRESETS.read_text(encoding='utf-8')
    for preset in WEB_PRESETS:
        pattern = re.compile(rf'(name="{re.escape(preset)}"\n(?:.*\n)*?exclude_filter=")[^"]*(")')
        text, count = pattern.subn(lambda match: match.group(1) + value + match.group(2), text, count=1)
        if count != 1:
            raise SystemExit(f'preset not found: {preset}')
    PRESETS.write_text(text, encoding='utf-8', newline='\n')
    print(f'{len(unused)} assets excluded from {len(WEB_PRESETS)} presets')


if __name__ == '__main__':
    main()
