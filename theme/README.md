# theme/ — one palette, every surface

Two themes, one switch. `palettes/*.toml` is the only place a colour is written by hand; `render.py` turns each palette into every tool's config under `build/<name>/`, and `dye <name>` re-points `~/.config/theme/current` at one bundle and tells every live surface to reload.

```
palettes/voidrunner.toml     34 roles, derived overrides, contrast floors   <- the source
palettes/spacecowboy.toml
templates/                   one file per surface, {{role}} substitution only
templates/nvim/              the nvim plugin, rendered once per palette
render.py                    palettes x templates -> build/ ; --check, --contrast, --install
build/<name>/                COMMITTED render; every box gets it by git pull
dye                          the switch (linked to ~/.local/bin/dye by install.sh)
tests/test_theme.sh          determinism, contrast, byte-level regressions, role coverage
```

## Daily use

```
dye                 what this box wears, and which surfaces are wired
dye spacecowboy     flip everything; dye voidrunner flips back
dye doctor          drift: stray hex in tracked files, stale renders, unpublished repos
```

Surfaces that follow the link with no restart: nvim (every live instance), tmux, the zsh prompt and fzf/eza/bat/lazygit/tuicr colours (through `arm -a` or the next prompt), Claude Code (`/theme` in a running session), kitty (remote control on the desktop, OSC to the current window over ssh). On the desktop a flip also restarts awesome and restores the nitrogen wallpaper (skipped when the desktop is driven remotely), switches Obsidian live in every vault already wearing a dye theme, and re-applies the Spotify scheme through spicetify. Only Firefox's theme add-on and Slack's four colours stay manual; dye prints them.

## Changing a colour

1. Edit the role in `palettes/<name>.toml`.
2. `dye render` (renders, checks contrast, and `--install` copies the Claude, bat and tuicr files into their trees).
3. `bash theme/tests/test_theme.sh` (kept in the private repo, not exported). The voidrunner regressions compare against frozen copies of the files the factory replaced; a deliberate change updates the fixture in the same commit.
4. `dye publish --push` to send the nvim plugins to GitHub.

## Adding a surface

Write `templates/<app>.<ext>.tmpl` with `{{role}}` keys (`{{lime}}`, `{{lime.hex}}`, `{{lime.sgr}}`, `{{lime.rgb}}`, `{{name}}`, `{{title}}`), add a line to `EXTRAS` in `render.py` if other people should get it inside the nvim repos, point the app's config at `~/.config/theme/current/<file>`, and add a wiring check to `dye`'s `wired_report`.

## Adding a theme

Copy a palette file, change `[meta]` and the 34 roles, render. Contrast classes: text roles 4.5:1 against `bg1`, muted 3.0, comments 2.2, grounds monotonic against `bg0`. A `[floors]` entry waives a role with a reason and is printed as WAIVED. Create `~/src/<name>.nvim/main` with a README and LICENSE, then `dye publish <name>`.

## Not rendered

- **JupyterLab**: a palette theme needs a labextension build (`jupyter labextension` with a `@jupyterlab/apputils` theme plugin and an npm toolchain). Until that exists, set the built-in dark theme: Settings → Theme → JupyterLab Dark.
- **htop, bottom, neofetch**: built-in schemes only.

## Accepted deltas from the hand-kept Void files

nvim bracket `#e6e6e6` → `bright`; C++ scope noise `#a8a8a8` → `fg2`; nvim-notify background `#000000` → `bg0`; tmux inactive-tab text `#a1a1a1` → `fg2`, unused `#222222` dropped; p10k `darkred #FD2222` → `red`, and the prompt character now really is lime (it was a literal that never expanded). Everything else is byte-identical, and `tests/test_theme.sh` keeps it that way.
