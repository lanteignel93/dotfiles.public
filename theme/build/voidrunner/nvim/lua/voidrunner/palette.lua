-- voidrunner palette: generated from palettes/voidrunner.toml. Do not edit here;
-- edit the palette and re-render. Roles, not colours, are the API.
return {
  -- grounds
  bg0 = "#0d0d0d",      -- terminal ground; the editor ground while transparent
  bg1 = "#1c1c1c",      -- panel, Pmenu, statusline, floats
  bg2 = "#262626",      -- cursor line, message backgrounds
  bg3 = "#303030",      -- visual, selection
  bg4 = "#3c3c3c",      -- end of buffer, hover
  lnr = "#404040",      -- line numbers, indent guides
  -- text
  dim = "#585858",      -- comments, structure
  border = "#585858",
  fg2 = "#9e9e9e",      -- secondary text, punctuation, scope noise
  fg = "#c0c0c0",
  bright = "#f1f1f1",
  ident = "#f1f1f1",
  -- accents
  lime = "#bdfe58",        -- hero: keywords, titles, your work
  limeDeep = "#4b8902", -- preprocessor
  limeSoft = "#bedc74", -- hints
  cursor = "#bdfe58",
  search = "#5eeeaf",
  func = "#5eeeaf",
  op = "#5eeeaf",
  mint = "#5eeeaf",        -- arrival: success, command
  mintVivid = "#1bfd9c", -- selection in menus
  mintPale = "#baffc9",   -- git added
  str = "#e5ccff",
  lav = "#e5ccff",          -- elsewhere: visual, remote
  sky = "#99ccff",          -- types, booleans, insert
  steel = "#7fa1c3",      -- info, terminal
  teal = "#b2d8d8",        -- constants, numbers
  rose = "#dea6a0",        -- errors, replace
  pink = "#ffb3ba",        -- git removed
  butter = "#ffffba",    -- warnings, git changed
  lspWarn = "#ffffba",
  peach = "#ffd9ba",      -- orange
  red = "#fa1100",          -- ANSI red
  -- derived (diff backgrounds and tints)
  diffAdded = "#223b2b",
  diffRemoved = "#3b2427",
  diffAddedDimmed = "#1a2b20",
  diffRemovedDimmed = "#2b1c1e",
  diffAddedWord = "#35573c",
  diffRemovedWord = "#57383c",
  memory = "#302a3a",
  -- ANSI green (the hero when it is green, else the palette's calmer green)
  green = "#bdfe58",
  none = "NONE",
  terminal = {
    "#1c1c1c", "#fa1100", "#bdfe58", "#ffffba", "#5eeeaf", "#e5ccff", "#7fa1c3", "#ffffff",
    "#585858", "#fa1100", "#bdfe58", "#ffffba", "#5eeeaf", "#e5ccff", "#7fa1c3", "#ffffff",
  },
}
