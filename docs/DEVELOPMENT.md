# Development and build notes

## Source of truth

- [Repository](https://github.com/SimpleCaci/Brainless-Mini-Game-Jam-2026)
- [Released game and downloads](https://sim-ple.itch.io/maple-the-shepherd)
- [Brainless Mini-Game Jam](https://itch.io/jam/brainless-mini-game-jam)

The repository name is the jam name; the published game title is **Maple the Shepherd**.

## Editor configuration

`brainless-game-jam-2026/project.godot` declares Godot 4.5 and configures the compatibility renderer. Import that file rather than opening an exported executable to edit the game.

## Exports

The checked-in `export_presets.cfg` contains Web, Windows Desktop, macOS, Linux, and a temporary Web testing preset. Some output paths are machine-specific or blank. Review them in the editor before exporting; use a dedicated local build directory.

The official itch.io page currently lists Windows and Linux downloads. No macOS release or browser-playable release is claimed here solely because an export preset exists.

Keep historical exports separate from new builds. Do not overwrite a release while testing.

## Suggested verification before a new release

- Import the project with the intended Godot version.
- Run the main menu and confirm that a level starts.
- Check movement, sheep interactions, goals, win/lose screens, and audio.
- Export to the selected platform and test the exported build separately.
- Record the source commit, Godot version, export preset, and platform.
- Upload only the tested distribution files; exclude editor caches and credentials.

These checks are a maintenance checklist, not test results from this documentation update.

## Local snapshots

Downloaded source folders can predate the repository. Preserve local differences separately and compare them before copying files into this repository. Editor recovery files such as `*.tmp` and backup files may contain unfinished work; review them before removal.
