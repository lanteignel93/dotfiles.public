# Read by every zsh, before .zshrc, including non-interactive shells.
# Environment variables only — interactive config stays in .zshrc.

# CMake >=3.17 honors this env var: every configure emits
# compile_commands.json so clangd gets real flags in every checkout.
export CMAKE_EXPORT_COMPILE_COMMANDS=ON

# Every terminal we reach these boxes from is truecolor (kitty), but COLORTERM
# is emitted by the emulator and dropped by the ssh hop, leaving it empty on the
# servers. Restore it if absent so tools that sniff COLORTERM (non-tmux shells,
# nvim, delta, ...) get the right answer. ${VAR:-default} keeps a real value the
# ssh session did forward.
export COLORTERM=${COLORTERM:-truecolor}

# rustup: puts ~/.cargo/bin on PATH (non-interactive shells need it too)
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
