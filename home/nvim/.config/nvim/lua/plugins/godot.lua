-- godot: neovim serves the godot project it's in, for godot-nvim (lua/godot.lua), and gdscript-formatter
-- formats on save when it's installed; the pack's godot-server.nvim serves a pipe in .godot instead, so it's off
---@type LazySpec
return {
  { "Cretezy/godot-server.nvim", enabled = false },
  {
    "AstroNvim/astrocore",
    ---@type AstroCoreOpts
    opts = {
      autocmds = {
        godot = {
          {
            event = "VimEnter",
            desc = "Serve the Godot project for godot-nvim",
            callback = function() require("godot").serve() end,
          },
          {
            event = "BufWritePost",
            pattern = "*.gd",
            desc = "Format GDScript with gdscript-formatter",
            callback = function(args)
              if vim.fn.executable "gdscript-formatter" == 0 then return end
              local result = vim.system({ "gdscript-formatter", vim.api.nvim_buf_get_name(args.buf) }):wait()
              if result.code ~= 0 then
                vim.notify("gdscript-formatter: " .. (result.stderr or ""), vim.log.levels.WARN)
              end
              vim.cmd.checktime(args.buf)
            end,
          },
        },
      },
    },
  },
}
