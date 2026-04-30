---@type LazySpec
return {
  "AstroNvim/astroui",
  ---@type AstroUIOpts
  dependencies = {
    {
      "ellisonleao/gruvbox.nvim",
      priority = 1000,
      config = function()
        require("gruvbox").setup {
          transparent_mode = true,
          contrast = "", -- "hard", "soft" or ""
          italic = {
            strings = true,
            emphasis = true,
            comments = true,
            operators = false,
            folds = true,
          },
        }
      end,
    },
  },
  opts = {
    -- change colorscheme
    colorscheme = "gruvbox",
    highlights = {
      init = {},
      astrodark = {},
    },
    icons = {
      LSPLoading1 = "⠋",
      LSPLoading2 = "⠙",
      LSPLoading3 = "⠹",
      LSPLoading4 = "⠸",
      LSPLoading5 = "⠼",
      LSPLoading6 = "⠴",
      LSPLoading7 = "⠦",
      LSPLoading8 = "⠧",
      LSPLoading9 = "⠇",
      LSPLoading10 = "⠏",
    },
  },
}
