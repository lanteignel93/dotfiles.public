#!/usr/bin/env python3
"""render.py: palettes x templates -> build/<name>/

The palette files under palettes/ are the only place a colour is written by
hand. Everything under build/ is generated from them and committed, so every
box gets the rendered bundle by a plain git pull and nothing here needs to run
on a box without Python.

    render.py                 render every palette into build/
    render.py voidrunner      render one
    render.py --check         render to a temp dir and diff against build/ (exit 1 on drift)
    render.py --contrast      print the WCAG contrast table per palette (exit 1 below a floor)
    render.py --install       after rendering, copy the files that live in other trees:
                              Claude theme JSONs, bat themes, tuicr themes
    render.py --list          print the palette names

Template grammar, all of it:
    {{lime}}      -> #bdfe58        {{lime.hex}} -> bdfe58
    {{lime.sgr}}  -> 189;254;88     {{lime.rgb}} -> 189, 254, 88
    {{lime.r}} {{lime.g}} {{lime.b}} -> 189 254 88
    {{green}}     -> the role named by meta.ansi_green, same forms
    {{name}} {{title}} {{repo}} {{credit}} {{description}} {{variant}} {{uuid}}
    every [derived] key by name, same forms as a role
An unknown key is an error, never an empty string.

Stdlib only. Python >= 3.11 (tomllib).
"""
from __future__ import annotations

import argparse
import filecmp
import json
import math
import os
import re
import shutil
import sys
import tempfile
import uuid

try:
    import tomllib  # 3.11+
except ModuleNotFoundError:  # Ubuntu 22.04 ships 3.10; tomli is the same parser, pre-stdlib
    import tomli as tomllib
from pathlib import Path

HERE = Path(__file__).resolve().parent
PALETTES = HERE / "palettes"
TEMPLATES = HERE / "templates"
BUILD = HERE / "build"

ROLES = [
    # grounds
    "bg0", "bg1", "bg2", "bg3", "bg4", "lnr",
    # text
    "dim", "border", "fg2", "fg", "bright", "ident",
    # accents
    "lime", "limeDeep", "limeSoft", "cursor", "search", "func", "op",
    "mint", "mintVivid", "mintPale", "str", "lav", "sky", "type", "steel", "teal",
    "rose", "pink", "butter", "lspWarn", "peach", "red",
]
GROUNDS = ["bg1", "bg2", "bg3", "bg4", "lnr"]

# contrast class per role: (class, floor). Grounds are checked against bg0 for
# monotonic lightness instead of a floor; everything else is measured vs bg1.
CLASS = {"dim": ("comment", 2.2), "border": ("muted", 3.0), "limeDeep": ("muted", 3.0)}
TEXT_FLOOR = 4.5

DERIVED_ORDER = [
    "inactiveShimmer", "suggestion", "promptBorderShimmer", "permissionShimmer",
    "warningShimmer", "diffAdded", "diffRemoved", "diffAddedDimmed",
    "diffRemovedDimmed", "diffAddedWord", "diffRemovedWord",
    "memoryBackgroundColor", "pink_FOR_SUBAGENTS_ONLY",
]

# Files rendered into build/<name>/ that also ship inside the public nvim repo
# under extras/<app>/<name>.<ext>, for people who are not us.
EXTRAS = [
    ("kitty.conf", "kitty/{name}.conf"),
    ("alacritty.toml", "alacritty/{name}.toml"),
    ("tmux.conf", "tmux/{name}.conf"),
    ("syntax.tmTheme", "bat/{name}.tmTheme"),
    ("shell/fzf.zsh", "fzf/{name}.zsh"),
    ("shell/eza.zsh", "eza/{name}.zsh"),
    ("shell/zsh-syntax-highlighting.zsh", "zsh-syntax-highlighting/{name}.zsh"),
    ("lazygit.yml", "lazygit/{name}.yml"),
    ("tuicr.toml", "tuicr/{name}.toml"),
    ("claude.json", "claude-code/{name}.json"),
    ("ipython.py", "ipython/{name}.py"),
    ("polybar.ini", "polybar/{name}.ini"),
    ("awesome.lua", "awesome/{name}.lua"),
    ("gtk.css", "gtk-4.0/{name}.css"),
    ("obsidian/theme.css", "obsidian/{name}/theme.css"),
    ("obsidian/manifest.json", "obsidian/{name}/manifest.json"),
    ("firefox/manifest.json", "firefox/{name}/manifest.json"),
    ("slack.txt", "slack/{name}.txt"),
    ("spicetify/color.ini", "spicetify/{name}/color.ini"),
]

# --- colour math (ported from the 2026-09-23 artifact; JS Math.round semantics) -----------

def hex2rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def _js_round(v: float) -> int:
    return int(math.floor(v + 0.5))


def rgb2hex(rgb) -> str:
    return "#" + "".join("%02x" % max(0, min(255, _js_round(v))) for v in rgb)


def mix(a: str, b: str, t: float) -> str:
    ra, rb = hex2rgb(a), hex2rgb(b)
    return rgb2hex(va + (vb - va) * t for va, vb in zip(ra, rb))


def lighten(h: str, t: float) -> str:
    return mix(h, "#ffffff", t)


def lum(h: str) -> float:
    def f(c: int) -> float:
        c /= 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = hex2rgb(h)
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def contrast(a: str, b: str) -> float:
    la, lb = lum(a), lum(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


# --- palettes -----------------------------------------------------------------------------

HEX_RE = re.compile(r"^#[0-9a-f]{6}$")


class Palette:
    def __init__(self, path: Path):
        with open(path, "rb") as fh:
            data = tomllib.load(fh)
        self.path = path
        self.meta = data.get("meta", {})
        for k in ("name", "title", "repo", "ansi_green"):
            if k not in self.meta:
                sys.exit(f"{path}: [meta] is missing '{k}'")
        self.name: str = self.meta["name"]
        roles = data.get("roles", {})
        missing = [r for r in ROLES if r not in roles]
        extra = [r for r in roles if r not in ROLES]
        if missing or extra:
            sys.exit(f"{path}: roles mismatch; missing={missing} extra={extra}")
        self.roles: dict[str, str] = {}
        for r in ROLES:
            v = str(roles[r]).lower()
            if not HEX_RE.match(v):
                sys.exit(f"{path}: role {r} is not #rrggbb: {roles[r]!r}")
            self.roles[r] = v
        if self.meta["ansi_green"] not in ROLES:
            sys.exit(f"{path}: ansi_green must name a role")
        self.derived_overrides = {k: str(v).lower() for k, v in data.get("derived", {}).items()}
        for k, v in self.derived_overrides.items():
            if k not in DERIVED_ORDER:
                sys.exit(f"{path}: unknown [derived] key {k}")
            if not HEX_RE.match(v):
                sys.exit(f"{path}: derived {k} is not #rrggbb: {v!r}")
        self.floors = data.get("floors", {})
        self.derived = self._derive()

    def _derive(self) -> dict[str, str]:
        p = self.roles
        d = {
            "inactiveShimmer": lighten(p["dim"], .12),
            "suggestion": lighten(p["dim"], .12),
            "promptBorderShimmer": lighten(p["dim"], .12),
            "permissionShimmer": lighten(p["sky"], .35),
            "warningShimmer": lighten(p["butter"], .45),
            "diffAdded": mix(p["bg1"], p["mintPale"], .18),
            "diffRemoved": mix(p["bg1"], p["pink"], .18),
            "diffAddedDimmed": mix(p["bg1"], p["mintPale"], .10),
            "diffRemovedDimmed": mix(p["bg1"], p["pink"], .10),
            "diffAddedWord": mix(p["bg1"], p["mintPale"], .32),
            "diffRemovedWord": mix(p["bg1"], p["pink"], .32),
            "memoryBackgroundColor": mix(p["bg3"], p["lav"], .10),
            "pink_FOR_SUBAGENTS_ONLY": mix(p["pink"], p["lav"], .45),
        }
        d.update(self.derived_overrides)
        return d

    # the {{key}} namespace
    def context(self) -> dict[str, str]:
        ctx: dict[str, str] = {}

        def put(key: str, h: str) -> None:
            r, g, b = hex2rgb(h)
            ctx[key] = h
            ctx[key + ".hex"] = h[1:]
            ctx[key + ".sgr"] = f"{r};{g};{b}"
            ctx[key + ".rgb"] = f"{r}, {g}, {b}"
            ctx[key + ".r"], ctx[key + ".g"], ctx[key + ".b"] = str(r), str(g), str(b)

        for k, v in self.roles.items():
            put(k, v)
        for k, v in self.derived.items():
            put(k, v)
        put("green", self.roles[self.meta["ansi_green"]])
        for k in ("name", "title", "repo", "credit", "description", "variant"):
            ctx[k] = str(self.meta.get(k, ""))
        ctx["uuid"] = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{self.name}.theme.lanteignel93"))
        return ctx

    def claude_json(self) -> str:
        p, d = self.roles, self.derived
        o = {
            "name": self.meta["title"],
            "base": "dark",
            "overrides": {
                "claude": p["lime"], "claudeShimmer": p["mint"],
                "text": p["fg"], "inverseText": p["bg1"],
                "inactive": p["dim"], "inactiveShimmer": d["inactiveShimmer"],
                "subtle": p["dim"], "suggestion": d["suggestion"],
                "permission": p["sky"], "permissionShimmer": d["permissionShimmer"],
                "remember": p["lav"],
                "success": p["mint"], "error": p["rose"],
                "warning": p["butter"], "warningShimmer": d["warningShimmer"],
                "merged": p["lav"],
                "promptBorder": p["dim"], "promptBorderShimmer": d["promptBorderShimmer"],
                "planMode": p["teal"], "autoAccept": p["butter"],
                "bashBorder": p["limeDeep"], "ide": p["steel"],
                "fastMode": p["mintVivid"], "fastModeShimmer": p["mintPale"],
                "diffAdded": d["diffAdded"], "diffRemoved": d["diffRemoved"],
                "diffAddedDimmed": d["diffAddedDimmed"], "diffRemovedDimmed": d["diffRemovedDimmed"],
                "diffAddedWord": d["diffAddedWord"], "diffRemovedWord": d["diffRemovedWord"],
                "userMessageBackground": p["bg3"], "userMessageBackgroundHover": p["bg4"],
                "messageActionsBackground": p["bg2"], "bashMessageBackgroundColor": p["bg2"],
                "memoryBackgroundColor": d["memoryBackgroundColor"],
                "selectionBg": p["bg3"],
                "rate_limit_fill": p["lime"], "rate_limit_empty": p["lnr"],
                "briefLabelYou": p["sky"], "briefLabelClaude": p["lime"],
                "red_FOR_SUBAGENTS_ONLY": p["pink"], "blue_FOR_SUBAGENTS_ONLY": p["sky"],
                "green_FOR_SUBAGENTS_ONLY": p["mint"], "yellow_FOR_SUBAGENTS_ONLY": p["butter"],
                "purple_FOR_SUBAGENTS_ONLY": p["lav"], "orange_FOR_SUBAGENTS_ONLY": p["peach"],
                "pink_FOR_SUBAGENTS_ONLY": d["pink_FOR_SUBAGENTS_ONLY"],
                "cyan_FOR_SUBAGENTS_ONLY": p["teal"],
            },
        }
        return json.dumps(o, indent=2) + "\n"


def load_palettes(names: list[str] | None) -> list[Palette]:
    paths = sorted(PALETTES.glob("*.toml"))
    pals = [Palette(p) for p in paths]
    if names:
        by = {p.name: p for p in pals}
        unknown = [n for n in names if n not in by]
        if unknown:
            sys.exit(f"unknown palette(s): {unknown}; have {sorted(by)}")
        pals = [by[n] for n in names]
    return pals


# --- rendering ----------------------------------------------------------------------------

KEY_RE = re.compile(r"\{\{([A-Za-z0-9_]+(?:\.[a-z]+)?)\}\}")


PARTIAL_RE = re.compile(r"^\{\{>\s*([A-Za-z0-9_./-]+)\s*\}\}[ \t]*$", re.M)


def expand_partials(text: str, where: str, depth: int = 0) -> str:
    """{{> shell/fzf.zsh}} on its own line pulls in templates/shell/fzf.zsh.tmpl."""
    if depth > 8:
        sys.exit(f"{where}: partials nested too deep")

    def rep(m: re.Match) -> str:
        rel = m.group(1)
        src = TEMPLATES / (rel + ".tmpl")
        if not src.exists():
            src = TEMPLATES / rel
        if not src.exists():
            sys.exit(f"{where}: partial not found: {rel}")
        return expand_partials(src.read_text(encoding="utf-8").rstrip("\n"), rel, depth + 1)

    return PARTIAL_RE.sub(rep, text)


def substitute(text: str, ctx: dict[str, str], where: str) -> str:
    text = expand_partials(text, where)
    missing: set[str] = set()

    def rep(m: re.Match) -> str:
        k = m.group(1)
        if k not in ctx:
            missing.add(k)
            return m.group(0)
        return ctx[k]

    out = KEY_RE.sub(rep, text)
    if missing:
        sys.exit(f"{where}: unknown template key(s): {sorted(missing)}")
    return out


def render_one(pal: Palette, out_root: Path) -> Path:
    ctx = pal.context()
    out = out_root / pal.name
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    for src in sorted(TEMPLATES.rglob("*")):
        if src.is_dir():
            continue
        rel = str(src.relative_to(TEMPLATES))
        rel = substitute(rel, ctx, f"path {rel}")
        if rel.endswith(".tmpl"):
            rel = rel[: -len(".tmpl")]
        dst = out / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        text = src.read_text(encoding="utf-8")
        dst.write_text(substitute(text, ctx, rel), encoding="utf-8")
        if os.access(src, os.X_OK):
            dst.chmod(0o755)
    (out / "name").write_text(pal.name + "\n", encoding="utf-8")
    (out / "claude.json").write_text(pal.claude_json(), encoding="utf-8")
    extras = out / "nvim" / "extras"
    for bundle_rel, extra_rel in EXTRAS:
        srcf = out / bundle_rel
        if not srcf.exists():
            continue
        dstf = extras / extra_rel.format(name=pal.name)
        dstf.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(srcf, dstf)
    return out


def render_all(pals: list[Palette], out_root: Path) -> None:
    for pal in pals:
        render_one(pal, out_root)


def check(pals: list[Palette]) -> int:
    with tempfile.TemporaryDirectory(prefix="theme-render-") as tmp:
        tmp_root = Path(tmp)
        render_all(pals, tmp_root)
        bad = 0
        for pal in pals:
            want, have = tmp_root / pal.name, BUILD / pal.name
            if not have.exists():
                print(f"DRIFT {pal.name}: build/{pal.name} missing")
                bad += 1
                continue
            diffs = _dir_diff(want, have)
            for d in diffs:
                print(f"DRIFT {pal.name}: {d}")
            bad += len(diffs)
        if bad:
            print(f"{bad} difference(s): run render.py and commit build/")
            return 1
    print("build/ is current")
    return 0


def _dir_diff(a: Path, b: Path) -> list[str]:
    out: list[str] = []

    def walk(dc: filecmp.dircmp, prefix: str) -> None:
        for n in dc.left_only:
            out.append(f"{prefix}{n}: only in render")
        for n in dc.right_only:
            out.append(f"{prefix}{n}: only in build")
        for n in dc.diff_files:
            out.append(f"{prefix}{n}: differs")
        for n, sub in dc.subdirs.items():
            walk(sub, f"{prefix}{n}/")

    walk(filecmp.dircmp(a, b), "")
    return out


# --- contrast -----------------------------------------------------------------------------

def contrast_report(pals: list[Palette]) -> int:
    fail = 0
    for pal in pals:
        p = pal.roles
        print(f"\n{pal.name}: contrast vs bg1 {p['bg1']} (grounds vs bg0 {p['bg0']})")
        # grounds: lightness must step up monotonically from bg0
        prev = lum(p["bg0"])
        for g in GROUNDS:
            l = lum(p[g])
            ratio = contrast(p[g], p["bg0"])
            ok = l > prev
            print(f"  {g:<10} {p[g]}  {ratio:5.2f}  ground {'ok' if ok else 'NOT LIGHTER THAN PREVIOUS'}")
            if not ok:
                fail += 1
            prev = l
        for r in ROLES:
            if r in GROUNDS or r == "bg0":
                continue
            cls, floor = CLASS.get(r, ("text", TEXT_FLOOR))
            ratio = contrast(p[r], p["bg1"])
            waived = pal.floors.get(r)
            if ratio >= floor:
                status = "ok"
            elif waived and ratio >= float(waived.get("ratio", 0)):
                status = f"WAIVED {waived.get('why', '')}"
            else:
                status = "FAIL"
                fail += 1
            print(f"  {r:<10} {p[r]}  {ratio:5.2f}  {cls} >= {floor}  {status}")
    if fail:
        print(f"\n{fail} role(s) below floor")
        return 1
    print("\ncontrast ok")
    return 0


# --- install: files that live in other trees --------------------------------------------

def install(pals: list[Palette]) -> None:
    home = Path.home()
    claude_dir = Path(os.environ.get("THEME_CLAUDE_DIR", home / "dotclaude" / ".claude" / "themes"))
    bat_dir = HERE.parent / "bat" / "themes"
    tuicr_dir = HERE.parent / "tuicr" / "themes"
    for d in (claude_dir, bat_dir, tuicr_dir):
        d.mkdir(parents=True, exist_ok=True)
    for pal in pals:
        b = BUILD / pal.name
        pairs = [
            (b / "claude.json", claude_dir / f"{pal.name}.json"),
            (b / "syntax.tmTheme", bat_dir / f"{pal.name}.tmTheme"),
            (b / "syntax.tmTheme", tuicr_dir / f"{pal.name}-syntax.tmTheme"),
            (b / "tuicr.toml", tuicr_dir / f"{pal.name}.toml"),
        ]
        for src, dst in pairs:
            shutil.copyfile(src, dst)
            print(f"installed {dst}")


# --- main ---------------------------------------------------------------------------------

def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("names", nargs="*", help="palette names (default: all)")
    ap.add_argument("--check", action="store_true", help="diff a fresh render against build/")
    ap.add_argument("--contrast", action="store_true", help="print the contrast table")
    ap.add_argument("--install", action="store_true", help="also copy into dotclaude/bat/tuicr")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--out", type=Path, default=BUILD, help="output root (default build/)")
    a = ap.parse_args(argv)
    pals = load_palettes(a.names or None)
    if a.list:
        print("\n".join(p.name for p in pals))
        return 0
    if a.check:
        return check(pals)
    if a.contrast:
        return contrast_report(pals)
    render_all(pals, a.out)
    for pal in pals:
        n = sum(1 for _ in (a.out / pal.name).rglob("*") if _.is_file())
        print(f"rendered {pal.name}: {n} files -> {a.out / pal.name}")
    if a.install:
        install(pals)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
