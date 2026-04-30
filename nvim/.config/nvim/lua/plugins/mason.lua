---@type LazySpec
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = {
      ensure_installed = {
        -- lua
        "lua-language-server",
        "stylua",

        -- web / typescript
        "vtsls",
        "prettier",
        "eslint_d",
        "js-debug-adapter",
        "tree-sitter-cli",

        -- python
        "basedpyright",
        "ruff",

        -- go
        "gopls",
        "gofumpt",
        "delve", -- go debugger

        -- rust
        "rust-analyzer",

        -- dotnet
        "csharp-language-server",
        "netcoredbg", -- dotnet debugger

        -- shell / bash
        "bash-language-server",
        "shfmt",
        "shellcheck",

        -- misc
        "json-lsp",
        "yaml-language-server",
        "taplo", -- toml
        "marksman", -- markdown
      },
    },
  },
}
