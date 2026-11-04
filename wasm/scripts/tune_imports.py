"""Make the game fit a browser: lighter import settings and streamed music.

Everything the browser plays arrives over the network and sits in memory, while
the original assets target a desktop install. Run from the repository root after
Godot has written the .import files; running it again changes nothing.

  python wasm/scripts/tune_imports.py [--dry-run]

Rules, with the reason for each in docs/wasm/port.md:
  - GPU-compressed textures: at most TEXTURE_LIMIT pixels per side.
  - Large textures kept as lossless images: lossy WebP, same limit.
  - Long WAV files: QOA, which keeps the path and the scenes that use it.
  - Players of long sounds: stream them instead of the Web sample default, which
    decodes the whole sound into memory at the first play and blocks the page.
  - glTF models: the node naming of Godot 4.2, which the scenes were written for.
"""
import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEXTURE_LIMIT = 1024
LOSSLESS_LIMIT_BYTES = 256 * 1024
LONG_WAV_BYTES = 1024 * 1024
# About ten seconds of music; shorter sounds stay samples, as the engine prefers.
LONG_OGG_BYTES = 100 * 1024
PLAYBACK_TYPE_STREAM = 1
SKIP_DIRS = {'.git', '.godot', 'wasm', 'docs'}


def walk(pattern):
    for path in ROOT.rglob(pattern):
        if not SKIP_DIRS.intersection(path.relative_to(ROOT).parts):
            yield path


def set_param(text, name, value):
    pattern = re.compile(rf'^{re.escape(name)}=.*$', re.M)
    return pattern.sub(f'{name}={value}', text, count=1)


def tune_import(path):
    text = path.read_text(encoding='utf-8')
    source = path.with_suffix('')
    # Upstream has a few .import files left behind by deleted assets.
    if not source.is_file():
        return text
    if 'importer="texture"' in text:
        mode = re.search(r'^compress/mode=(\d+)', text, re.M)
        if mode and mode.group(1) == '2':
            return set_param(text, 'process/size_limit', TEXTURE_LIMIT)
        if mode and mode.group(1) == '0' and source.stat().st_size > LOSSLESS_LIMIT_BYTES:
            text = set_param(text, 'compress/mode', 1)
            return set_param(text, 'process/size_limit', TEXTURE_LIMIT)
    elif 'gltf/naming_version=0' in text:
        # Version 0 gives a node the name of its file a different name, so paths
        # like Scene/stage/Camera in the scenes no longer resolve.
        return set_param(text, 'gltf/naming_version', 1)
    elif 'importer="wav"' in text and source.stat().st_size > LONG_WAV_BYTES:
        # 2 is Quite OK Audio, about a fifth of the size with almost no decoding cost.
        return set_param(text, 'compress/mode', 2)
    return text


def is_long_sound(res_path):
    path = ROOT / res_path.removeprefix('res://')
    if not path.is_file():
        return False
    size = path.stat().st_size
    return (path.suffix == '.wav' and size > LONG_WAV_BYTES) or (path.suffix == '.ogg' and size > LONG_OGG_BYTES)


def tune_scene(path):
    text = path.read_text(encoding='utf-8')
    if 'type="AudioStreamPlayer' not in text:
        return text
    resources = dict(re.findall(r'\[ext_resource [^\]]*path="([^"]+)"[^\]]*id="([^"]+)"\]', text))
    by_id = {res_id: res_path for res_path, res_id in resources.items()}
    # Each node runs up to the next section header.
    def tune_node(match):
        node = match.group(0)
        stream = re.search(r'^stream = ExtResource\("([^"]+)"\)', node, re.M)
        if 'playback_type' in node or not stream or not is_long_sound(by_id.get(stream.group(1), '')):
            return node
        return node.replace(stream.group(0), f'{stream.group(0)}\nplayback_type = {PLAYBACK_TYPE_STREAM}', 1)
    return re.sub(r'^\[node [^\]]*type="AudioStreamPlayer(?:2D|3D)?"[^\]]*\]\n(?:(?!\[).*\n?)*', tune_node, text, flags=re.M)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    changed = {'import': 0, 'scene': 0}
    for kind, pattern, tune in (('import', '*.import', tune_import), ('scene', '*.tscn', tune_scene)):
        for path in walk(pattern):
            before = path.read_text(encoding='utf-8')
            after = tune(path)
            if after != before:
                changed[kind] += 1
                print(path.relative_to(ROOT).as_posix())
                if not args.dry_run:
                    path.write_text(after, encoding='utf-8', newline='\n')
    print(f"{'would change' if args.dry_run else 'changed'}: {changed['import']} import files, {changed['scene']} scenes")


if __name__ == '__main__':
    main()
