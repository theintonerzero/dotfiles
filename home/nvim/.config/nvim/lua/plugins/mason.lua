-- the language servers claude's lsp plugins run that the packs don't install; on a server, only the
-- tools that need no toolchain
---@type LazySpec
return {
  "WhoIsSethDaniel/mason-tool-installer.nvim",
  opts = function(_, opts)
    local on_server, machine = pcall(require, "machine")
    if on_server and type(machine) == "table" and machine.server == true then
      -- a server has no node, python, go or rust to install a tool with, so of what the packs ask for
      -- it gets the ones mason has as a ready-made program for linux (selene on intel only)
      local standalone = { "lua-language-server", "stylua", "selene", "shellcheck", "shfmt", "taplo", "marksman" }
      opts.ensure_installed = vim.tbl_filter(
        function(tool) return vim.tbl_contains(standalone, tool) end,
        opts.ensure_installed or {}
      )
    else
      opts.ensure_installed = require("astrocore").list_insert_unique(opts.ensure_installed, {
        "pyright",
        "typescript-language-server",
        "kotlin-lsp",
      })
    end
    -- mason has only an intel netcoredbg for a mac, which an apple silicon one can't run; c#'s debugger
    -- there is the netcoredbg command the vscodium step makes (lua/plugins/csharp.lua)
    if vim.fn.has "mac" == 1 and vim.uv.os_uname().machine == "arm64" then
      opts.ensure_installed = vim.tbl_filter(function(tool) return tool ~= "netcoredbg" end, opts.ensure_installed)
    end
    -- with no screen, as dot install runs it, the tools are installed by MasonToolsInstallSync alone: the
    -- pass this plugin makes by itself at startup would start the same installs first, and the command
    -- never hears that an install it didn't start has finished, so it would wait for good
    if #vim.api.nvim_list_uis() == 0 then opts.run_on_start = false end
  end,
}
