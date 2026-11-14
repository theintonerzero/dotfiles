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
    -- with no screen, as dot install runs it, the tools are installed by MasonToolsInstallSync alone: the
    -- pass this plugin makes by itself at startup would start the same installs first, and the command
    -- never hears that an install it didn't start has finished, so it would wait for good
    if #vim.api.nvim_list_uis() == 0 then opts.run_on_start = false end
  end,
}
