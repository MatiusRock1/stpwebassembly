#!/usr/bin/env python3
import re
import os
import sys
import glob
import shlex
import shutil
import subprocess
import pathlib
from tqdm import tqdm

DIR_MARKDOWN = "## "
FILE_MARKDOWN = "### "

BLACKLIST = []

LICENSE_FILE = [
    "licenses/LICENSE-ART.md",
    "licenses/LICENSE-MUSIC.md",
    "licenses/LICENSE-SHADER.md",
    "licenses/LICENSE-FONTS.md",
]
FILE_EXTENSIONS = [
    "*.png",
    "*.jpg",
    "*.jpeg",
    "*.escn",
    "*.dae",
    "*.obj",
    "*.hdr",
    "*.ttf",
    "*.blend",
    "*.wav",
    "*.mp3",
    "*.ogg",
    "*.gdshader",
    "*.otf",
    "*.glb",
    "*.gltf",
    "*.svg",
    "*.xcf"
]


def file_matches(shellpath, x):
    shellpath = shellpath.replace("\\_", "_").replace("\\*", "*").replace("\\\\", "\\")
    # force absolute path match, otherwise it's just a suffix match
    return pathlib.PurePosixPath("/" + x).match("/" + shellpath)


files = set()
for extension in FILE_EXTENSIONS:
    files |= set(glob.glob("**/%s" % extension, recursive=True))
num_files = len(files)

print("Checking %d files" % num_files)
LICENSE_FILESIZE = sum([os.stat(x).st_size for x in LICENSE_FILE])

unmatched_dirs = []
unmatched_files = []

with tqdm(total=LICENSE_FILESIZE, unit="B") as pbar:
    for x in LICENSE_FILE:
        with open(x, "r") as f:
            current_dir = ""
            for line in f:
                if line.startswith(DIR_MARKDOWN):
                    current_dir = line[len(DIR_MARKDOWN) :].strip()
                    files = [s for s in files if not file_matches(current_dir, s)]
                elif line.startswith(FILE_MARKDOWN):
                    current_files = map(
                        str.strip, line[len(FILE_MARKDOWN) :].split("|")
                    )

                    for name in current_files:
                        path = os.path.normpath(("%s/%s" % (current_dir, name)))
                        matched = [s for s in files if file_matches(path, s)]
                        files = [s for s in files if not file_matches(path, s)]
                        if not matched:
                            unmatched_files.append(path)
                pbar.update(len(line))

blacklist_regex = re.compile("|".join(BLACKLIST))
print("\x1B[32mLicense found for %d files\x1B[0m" % (num_files - len(files)))

for dirname in unmatched_dirs:
    print("\x1B[33mWarning: Rule matches no directory: %s\x1B[0m" % dirname)
for filename in unmatched_files:
    print("\x1B[33mWarning: Rule matches no files: %s\x1B[0m" % filename)

for f in files:
    if not (BLACKLIST and p.match(f)):
        print("\x1B[31mNo license found for: %s\x1B[0m" % f)

# Return an exit code of 0, if there are no missing licenses
sys.exit(len(files) > 0)
