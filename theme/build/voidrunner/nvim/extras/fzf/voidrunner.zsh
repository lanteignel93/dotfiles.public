# fzf (voidrunner): transparent ground, panel selection, the hero for the pointer
# separator and scrollbar colours arrived in fzf 0.35: an older fzf (Ubuntu 22.04 ships
# 0.29) rejects the whole --color option, and every picker then dies with "invalid color
# specification". So they are added only when the fzf on PATH knows them.
() {
  local c="bg:-1,bg+:#303030,fg:#c0c0c0,fg+:#f1f1f1,hl:#5eeeaf,hl+:#1bfd9c,info:#99ccff,prompt:#bdfe58,pointer:#bdfe58,marker:#bdfe58,spinner:#bdfe58,header:#585858,border:#585858,gutter:-1,query:#f1f1f1"
  local v=${$(FZF_DEFAULT_OPTS= command fzf --version 2>/dev/null)%% *}
  [[ -n $v ]] && (( ${v%%.*} > 0 || ${${v#*.}%%.*} >= 35 )) && c+=",separator:#585858,scrollbar:#585858"
  export FZF_DEFAULT_OPTS="--color=$c"
}
