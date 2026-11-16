-- c#'s debugger on an apple silicon mac: mason has only an intel netcoredbg for a mac, which one without
-- rosetta can't run, so mason installs none there (lua/plugins/mason.lua) and the debugger is the
-- netcoredbg command the vscodium step makes, a copy of the arm64 one the c# extension brings
-- (shared/vscodium.sh). everywhere else mason's own is set up by mason-nvim-dap, as the pack has it
if not (vim.fn.has "mac" == 1 and vim.uv.os_uname().machine == "arm64") then return {} end

---@type LazySpec
return {
  {
    "mfussenegger/nvim-dap",
    opts = function()
      local dap = require "dap"
      local command = vim.fs.joinpath(vim.env.HOME, ".local/bin/netcoredbg")
      -- looked for as a session starts, so a debugger installed since neovim opened is found
      dap.adapters.coreclr = function(callback)
        if vim.fn.executable(command) == 0 then
          vim.notify("No " .. command .. " to debug C# with: run dot install", vim.log.levels.WARN)
          return
        end
        callback { type = "executable", command = command, args = { "--interpreter=vscode" } }
      end
      -- the ways to launch are mason-nvim-dap's own, which it sets up only for a debugger mason installed
      local configurations = require("mason-nvim-dap.mappings.configurations").coreclr
      for _, filetype in ipairs { "cs", "fsharp" } do
        if not dap.configurations[filetype] then dap.configurations[filetype] = vim.deepcopy(configurations) end
      end
    end,
  },
}
