# dotfiles

My Linux desktop: awesome WM and polybar, kitty and alacritty, tmux, zsh, and a Neovim setup built for C++ and Python, all in one dark theme.

![Desktop: tmux with Neovim splits on a C++ order book project](pictures/desktop.png)

## What's here

| Path | What it is |
|---|---|
| `nvim/` | Neovim on lazy.nvim: LSP, blink.cmp, treesitter, telescope, conform, DAP, gitsigns, snacks, and a stack of colorschemes switchable with themery |
| `.tmux.conf`, `.tmux/scripts/tmux-sysstat` | tmux with vim-style navigation shared with Neovim, session persistence, and a non-blocking CPU and memory status script |
| `awesome/` | awesome WM: `rc.lua`, a Gruvbox theme, autostart and a screenshot helper |
| `polybar/` | The bar: workspaces, window title, CPU, memory, network, date and MPD |
| `kitty/`, `alacritty/` | Terminals, including `dark_void.toml`, my alacritty port of darkvoid |
| `.zshrc`, `.zshenv`, `.p10k.zsh` | zsh on oh-my-zsh with powerlevel10k, fzf-tab, autosuggestions and syntax highlighting |
| `tuicr/` | tuicr config with darkvoid themes |
| `lazygit/`, `bottom/`, `htop/`, `neofetch/`, `gtk-4.0/` | Smaller tool configs |
| `gitignore_global` | Global git ignore |

## The theme

Most of this is dressed in [darkvoid](https://github.com/aliqyan-21/darkvoid.nvim). `nvim/colors/darkvoid.lua` layers my tweaks on top of the plugin, and I carried the palette over to alacritty, tuicr and the rest.

## Using it

These are my configs, not a framework, so take whatever is useful. Most directories drop straight into `~/.config/` (`nvim/` becomes `~/.config/nvim`), and the zsh and tmux files go in your home directory.

A few things are installed separately:

- **zsh:** [oh-my-zsh](https://ohmyz.sh/), [powerlevel10k](https://github.com/romkatv/powerlevel10k), [fzf-tab](https://github.com/Aloxaf/fzf-tab), [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) and [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- **tmux plugins** through [tpm](https://github.com/tmux-plugins/tpm): vim-tmux-navigator, tmux-resurrect and tmux-continuum
- **awesome:** the [collision](https://github.com/Elv13/collision) module, cloned into `~/.config/awesome/collision`
- **polybar:** the icons need the Material Icons font

## Credits

- [darkvoid.nvim](https://github.com/aliqyan-21/darkvoid.nvim) by aliqyan-21
- [awesome-wm-gruvbox-theme](https://github.com/lnus/awesome-wm-gruvbox-theme) by lnus, the base of `awesome/themes/gruvbox`
- [polybar-gruvbox-theme](https://github.com/emgyrz/polybar-gruvbox-theme) by emgyrz, the base of `polybar/`

This repo is generated from my private dotfiles, so machine-specific pieces are left out.
