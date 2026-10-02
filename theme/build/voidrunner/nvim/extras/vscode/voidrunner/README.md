# Voidrunner for VS Code

Near-black ground, pale accents; structure carried by lightness, hue only a whisper.

The VS Code port of [voidrunner.nvim](https://github.com/lanteignel93/voidrunner.nvim). Same palette, same roles: the
token colours follow the Neovim highlight groups (treesitter and LSP semantic tokens), and the
workbench uses the plugin's grounds — editor on `bg0`, panels on `bg1`, cursor line `bg2`,
selection `bg3`.

## Install

Either:

- **From the `.vsix`:** Extensions view → `···` menu → *Install from VSIX…* → pick
  `voidrunner-theme-1.0.0.vsix`. Or on the command line: `code --install-extension voidrunner-theme-1.0.0.vsix`.
- **From this folder:** copy the whole folder to `~/.vscode/extensions/voidrunner-theme`
  (Windows: `%USERPROFILE%\.vscode\extensions\voidrunner-theme`) and restart VS Code.

Then: *Preferences: Color Theme* (`Ctrl+K Ctrl+T`) → **Voidrunner**.

Semantic highlighting is on in the theme, so language servers (Pylance, clangd, rust-analyzer…)
colour parameters, members and read-only variables the way the Neovim LSP groups do.

## Build the `.vsix` yourself

```
npx @vscode/vsce package
```

## Generated

Rendered from the palette in the author's theme factory; issues go to
[lanteignel93/voidrunner.nvim](https://github.com/lanteignel93/voidrunner.nvim). MIT.
