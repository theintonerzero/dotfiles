-- the language servers claude's lsp plugins run that the packs don't install
---@type LazySpec
return {
  "WhoIsSethDaniel/mason-tool-installer.nvim",
  opts = function(_, opts)
    opts.ensure_installed = require("astrocore").list_insert_unique(opts.ensure_installed, {
      "pyright",
      "typescript-language-server",
      "kotlin-lsp",
    })
  end,
}
