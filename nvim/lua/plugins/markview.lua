-- For `plugins/markview.lua` users.
return {
  "OXY2DEV/markview.nvim",
  lazy = false,

  -- For blink.cmp's completion
  -- source
  dependencies = {
    "saghen/blink.cmp"
  },

  -- LaTeX belongs to snacks (typeset images, notebooks only: see
  -- plugins/jupyter.lua). markview's own LaTeX renderer switches on as soon as
  -- the `latex` treesitter parser exists, and would draw the same $...$ a
  -- second time on top. Off here keeps every other markdown file exactly as it
  -- was before the parser was added.
  opts = {
    latex = { enable = false },
  },
};
