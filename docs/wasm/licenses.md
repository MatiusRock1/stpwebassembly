# Rights in the browser build

An inventory for anyone who distributes this build. It records what the files say, as checked on 2026-11-04 at `BASE_COMMIT.txt`. It is not legal advice.

## Components

| Component | Version | License | Holder | Obligations when distributing |
| --- | --- | --- | --- | --- |
| Game code | Upstream `dev`, `4812d746` | GPL-3.0-or-later, `licenses/LICENSE` | SuperTux Party contributors | Offer the corresponding source of the distributed build, keep the notices, mark the changes (`port.md`) |
| Web adaptations | This repository | GPL-3.0-or-later, as a derivative | Port author | Same |
| WebSocket client and server scripts | Godot demo projects, in `client/websocket/` and `server/websocket/` | MIT, in the file header | Godot contributors | Keep the header |
| Godot runtime | 4.7.2-stable official templates | MIT, plus third-party notices | Godot contributors | Keep the notice. The in-game credits print `Engine.get_license_text()` |
| Art | Listed per file in `licenses/LICENSE-ART.md` | CC0, CC BY 3.0 and 4.0, CC BY-SA 3.0 and 4.0, GPL 2.0 and 3.0, MIT | One author per entry | Attribution, share-alike where it applies, and source for the GPL files |
| Music and sounds | Listed per file in `licenses/LICENSE-MUSIC.md` | CC BY 3.0 and 4.0, CC0, OGA-BY 3.0 | One author per entry | Attribution |
| Fonts | `licenses/LICENSE-FONTS.md`, `assets/fonts/OFL` | SIL OFL 1.1 | Font authors | Keep the license with the fonts. Modified versions cannot keep a reserved font name |
| Shaders | `licenses/LICENSE-SHADER.md` | MIT, GPL-3.0-or-later | Named per file | Keep the notices |

No entry in these inventories carries a non-commercial or no-derivatives clause.

Attribution reaches the player: the Credits tab of the options menu renders those inventories at run time, which is why the export presets include `licenses/*.md`.

## How the port affects this

- **Source.** A GPL build needs its corresponding source available. This repository is that source, with the Godot version pinned by hash. It has to be public, and match the binary, before the build is distributed. The in-game credits link to it.
- **Changes to assets.** The import settings resize textures and re-encode audio (`port.md`, "Package size"). The inventories do not record this, and CC BY asks to indicate changes. `port.md` and this note are that indication.
- **Excluded assets** stay in the repository and out of the packages.

## Open questions for whoever publishes

The licenses above cover copyright in the files. They do not grant rights in names or mascots, and a file's license only speaks for its uploader. These deserve a decision before a public release. None of them is a conclusion that there is a problem.

| Item | In the build as | Question |
| --- | --- | --- |
| Beastie | Playable character, CC0 model and CC BY icons | Based on the BSD Daemon, whose copyright notice is held by Marshall Kirk McKusick and which has its own terms of use. A CC0 label on a fan model may not settle the character's rights |
| KDE and its dragons | The `KDEValley` board and its dragons, by an upstream contributor | "KDE" is a mark of KDE e.V., and the dragons evoke its mascots |
| GNU | NPC and `gnu_*` minigame types, `gnu_icon.png` from an OpenGameArt set | The GNU head has a license and use terms from the FSF |
| Godette and Godot | Playable character, CC BY 3.0, and two CC BY 4.0 icons | Godot's name and logo have a trademark policy |
| Tux and Nolok | Playable mascot, and `nolokicon.png` from SuperTuxKart under GPL 2.0 | Tux is broadly free to use. The name "Tux" and these derivatives are listed for completeness |
| "SuperTux Party" | Game name and title art, CC0 | No registered mark was found, but none was searched for formally. The site should present the port as unofficial |
| Linux | Text of the `kernel_compiling` minigame | Descriptive use of a mark |

The osu! case, in `.agents/skills/demos-games-catalog/references/release-and-withdrawal.md`, shows why this table exists: an unofficial label does not replace permission if a holder objects.

## Upstream's license check

`python check_license.py` (needs `tqdm`) finds a license for 504 of 505 files. The exception is `plugins/minigames/kernel_compiling/screen/progress.gdshader`, which `LICENSE-SHADER.md` does list as GPL-3.0-or-later, under a heading format the script does not read. `common/main_menu_bg.gdshader` has an entry in that file with no license text: treat it as a gap upstream should fill. Its 8 lines fall under the project's general GPL statement for code.

The script also warns about rules that match no files, left behind by moved assets. Those are harmless.
