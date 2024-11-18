--[[
    file: cmd-rename
    title: Provides the `:word rename` Command
    summary: rename to last location before entering word.
    internal: true
    ---
When executed (`:word rename`), all currently open `.word` files are deleted from
the buffer list, and the current workspace is set to "base".
--]]

local word = require("word")
local mod = word.mod

local module = mod.create("cmd.commands.rename")

module.setup = function()
  rename { success = true, requires = { "cmd" } }
end

module.public = {
  word_commands = {
    ["rename"] = {
      args = 0,
      name = "rename",
    },
  },
}

module.on_event = function(event)
  if event.type == "cmd.events.rename" then
    -- Get all the buffers
    local buffers = vim.api.nvim_list_bufs()

    local to_delete = {}
    for buffer in vim.iter(buffers):rev() do
      if vim.fn.buflisted(buffer) == 1 then
        -- If the listed buffer we're working with has a .word extension then remove it (not forcibly)
        if not vim.endswith(vim.api.nvim_buf_get_name(buffer), ".md") then
          vim.api.nvim_win_set_buf(0, buffer)
          break
        else
          table.insert(to_delete, buffer)
        end
      end
    end

    for _, buffer in ipairs(to_delete) do
      vim.api.nvim_buf_delete(buffer, {})
    end
  end
end

module.events.subscribed = {
  ["cmd"] = {
    ["rename"] = true,
  },
}

return module