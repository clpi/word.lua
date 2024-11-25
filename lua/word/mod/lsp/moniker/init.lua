local M = Mod.create("lsp.moniker")

---@class lsp.moniker
M.public = {

  ---@type lsp.MonikerClientCapabilities
  capabilities = {
    dynamicRegistration = true

  },
  ---@type lsp.MonikerOptions
  opts = {
    workDoneProgress = true,


  },

  ---@param param lsp.MonikerParams
  ---@param callback fun(lsp.Moniker):nil
  ---@param notify_reply_callback fun(lsp.Moniker):nil
  ---@return nil
  handle = function(param, callback, notify_reply_callback)
    ---@type lsp.Moniker
    local h = {
      contents = {
        value = "Hello, World!",
        kind = "markdown",
      },
      range = {
        start = {
          line = 0,
          character = 0,
        },
        ["end"] = {
          line = 0,
          character = 0,
        },
      },
    }
    callback(h)
    notify_reply_callback(h)
  end,
}

return M
