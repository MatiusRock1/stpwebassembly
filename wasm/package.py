"""Assemble the web directory from the export and the browser player.

  python wasm/package.py <work>     (<work>/godot is the output of wasm/build.sh)

Copies what the page loads into <work>/web and writes stp.manifest.json: the name,
size and content hash of each file, which the player needs for the download
progress and to cache files by content. The packages get their hash in the file
name, so a new build cannot be mixed up with a cached one.
"""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
ENGINE_FILES = ['stp.js', 'stp.wasm', 'stp.audio.worklet.js', 'stp.audio.position.worklet.js']
PLAYER_FILES = ['index.html', 'application.mjs']
PACKS = {'desktop': 'stp.desktop.pck', 'mobile': 'stp.mobile.pck'}


def content_hash(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            digest.update(block)
    return digest.hexdigest()[:16]


def copy_if_changed(source, target):
    if target.is_file() and target.stat().st_size == source.stat().st_size and content_hash(target) == content_hash(source):
        return
    shutil.copyfile(source, target)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('work', type=Path, help='work directory of wasm/build.sh')
    parser.add_argument('--debug', action='store_true',
                        help='package <work>/godot-debug (DEBUG=1 build) into <work>/web-debug')
    args = parser.parse_args()
    suffix = '-debug' if args.debug else ''
    export, web = args.work / f'godot{suffix}', args.work / f'web{suffix}'
    web.mkdir(parents=True, exist_ok=True)

    for name in ENGINE_FILES:
        copy_if_changed(export / name, web / name)
    for name in PLAYER_FILES:
        shutil.copyfile(REPO / 'wasm' / 'browser' / name, web / name)

    packs, keep = {}, set()
    for device, source_name in PACKS.items():
        source = export / source_name
        digest = content_hash(source)
        # .bin because Cloudflare caches that extension by default; Godot reads a
        # package by its contents, whatever its name.
        name = f'stp-{device}-{digest}.bin'
        copy_if_changed(source, web / name)
        keep.add(name)
        packs[device] = {'name': name, 'size': source.stat().st_size, 'hash': digest, 'pack': True}
    for old in [*web.glob('stp.*.pck'), *web.glob('stp-*.bin')]:
        if old.name not in keep:
            old.unlink()

    wasm = web / 'stp.wasm'
    files = {'wasm': {'name': 'stp.wasm', 'size': wasm.stat().st_size, 'hash': content_hash(wasm)}, **packs}
    version = hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest()[:16]
    manifest = {'version': version, 'files': files, 'packs': packs}
    (web / 'stp.manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')

    for device, pack in packs.items():
        print(f"{device}: {pack['name']} {pack['size'] / 1048576:.0f} MiB")
    print(f"wasm: {files['wasm']['size'] / 1048576:.0f} MiB")
    print(f'web directory: {web}')


if __name__ == '__main__':
    main()
