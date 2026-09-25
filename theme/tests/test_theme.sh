#!/usr/bin/env bash
# test_theme.sh — the theme factory's checks.
#   1. render.py --check   : committed build/ matches a fresh render (determinism)
#   2. render.py --contrast: every role clears its class floor or is waived with a reason
#   3. regressions         : the voidrunner render equals the hand-kept Void files it replaced
#                            (fixtures frozen 2026-09-25 from kitty.conf, darkvoid.json,
#                            sckit.sh, .tmux.conf, .p10k.zsh)
#   4. coverage            : every role is used by at least one template
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T="$HERE/.."
PASS=0 FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s\n%s\n' "$1" "${2:-}"; }
check() { local n="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$n"; else bad "$n"; fi; }

echo "1. determinism"
out="$(python3 "$T/render.py" --check 2>&1)" && ok "build/ matches a fresh render" || bad "build/ drift" "$out"

echo "2. contrast"
out="$(python3 "$T/render.py" --contrast 2>&1)" && ok "all roles clear their floors (waivers printed by render.py)" || bad "contrast" "$out"

echo "3. regressions: voidrunner == the Void files it replaced"
B="$T/build/voidrunner"; F="$HERE/fixtures"

# kitty: every colour key in the old kitty.conf has the same value (case-insensitive)
kdiff="$(python3 - "$F/void-kitty.conf" "$B/kitty.conf" <<'PY'
import re, sys
def keys(p):
    d = {}
    for line in open(p, encoding="utf-8"):
        m = re.match(r"^\s*(background|foreground|cursor|cursor_text_color|color\d+)\s+(#[0-9a-fA-F]{6})", line)
        if m: d[m.group(1)] = m.group(2).lower()
    return d
old, new = keys(sys.argv[1]), keys(sys.argv[2])
bad = [f"{k}: old {v} new {new.get(k)}" for k, v in old.items() if new.get(k) != v]
print("; ".join(bad))
PY
)"
[[ -z "$kdiff" ]] && ok "kitty colours identical (${#kdiff} diffs)" || bad "kitty colours" "$kdiff"

# claude: byte-identical except the name
cdiff="$(diff <(sed 's/"name": "Darkvoid"/"name": "Voidrunner"/' "$F/void-darkvoid.json") "$B/claude.json" || true)"
[[ -z "$cdiff" ]] && ok "claude.json identical modulo name" || bad "claude.json" "$cdiff"

# sckit: the seven A_* lines are byte-identical
sdiff="$(diff <(sed -n '/^  A_LIME/,/^  A_ERR/p' "$F/void-sckit.txt") "$B/sckit.sh" || true)"
[[ -z "$sdiff" ]] && ok "sckit A_* lines identical" || bad "sckit" "$sdiff"

# tmux: each old darkvoid_* value equals the theme_* value it maps to (case-insensitive);
# subtle and type are accepted deltas (#222222 -> bg2, #a1a1a1 -> fg2) and not compared
tdiff="$(python3 - "$F/void-tmux.txt" "$B/tmux.conf" <<'PY'
import re, sys
def vals(p):
    return {m.group(1): m.group(2).lower() for m in
            (re.match(r"^(\w+)='(#[0-9a-fA-F]{6})'", l) for l in open(p, encoding="utf-8")) if m}
old, new = vals(sys.argv[1]), vals(sys.argv[2])
pairs = {"darkvoid_bg":"theme_bg","darkvoid_fg":"theme_fg","darkvoid_lime":"theme_lime","darkvoid_neon":"theme_neon",
         "darkvoid_sea_green":"theme_sea_green","darkvoid_lavender":"theme_lavender","darkvoid_red":"theme_red",
         "darkvoid_comment":"theme_comment","darkvoid_dark_gray":"theme_dark_gray"}
print("; ".join(f"{a}: {old[a]} != {b}: {new.get(b)}" for a, b in pairs.items() if old.get(a) != new.get(b)))
PY
)"
[[ -z "$tdiff" ]] && ok "tmux palette identical (subtle/type deltas accepted)" || bad "tmux" "$tdiff"

# p10k: the six values that map to roles
pdiff="$(python3 - "$F/void-p10k.txt" "$T/palettes/voidrunner.toml" <<'PY'
import re, sys, tomllib
old = {m.group(1): m.group(2).lower() for m in
       (re.search(r"local (darkvoid_\w+)='(#[0-9a-fA-F]{6})'", l) for l in open(sys.argv[1], encoding="utf-8")) if m}
roles = tomllib.load(open(sys.argv[2], "rb"))["roles"]
pairs = {"darkvoid_fg":"fg","darkvoid_lime":"lime","darkvoid_sea_green":"mint","darkvoid_lavender":"lav",
         "darkvoid_light_blue":"sky","darkvoid_red":"rose","darkvoid_comment":"dim"}
print("; ".join(f"{a}: {old[a]} != {b}: {roles[b]}" for a, b in pairs.items() if old.get(a) != roles[b].lower()))
PY
)"
[[ -z "$pdiff" ]] && ok "p10k values identical (darkred -> red is an accepted delta)" || bad "p10k" "$pdiff"

echo "4. coverage: every role is referenced by a template"
unused="$(python3 - "$T" <<'PY'
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])
text = "\n".join(p.read_text(encoding="utf-8") for p in (root/"templates").rglob("*") if p.is_file())
src = (root/"render.py").read_text(encoding="utf-8")
roles = re.search(r"ROLES = \[(.*?)\]", src, re.S).group(1)
roles = re.findall(r'"(\w+)"', roles)
used = set(re.findall(r"\{\{(\w+)(?:\.\w+)?\}\}", text))
print(" ".join(r for r in roles if r not in used))
PY
)"
[[ -z "$unused" ]] && ok "all roles used" || bad "unused roles" "$unused"

echo "5. build/ is tracked by git (a stock build/ ignore rule once hid it)"
n="$(cd "$T/.." && git ls-files theme/build 2>/dev/null | wc -l)"
(( n > 0 )) && ok "build/ tracked ($n files)" || bad "build/ is not tracked: check .gitignore for a build/ rule"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
