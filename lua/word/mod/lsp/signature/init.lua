local M = Mod.create("lsp.signature")

---@class lsp.signature
M.public = {
  ---@param param lsp.SignatureHelpParams
  ---@param callback fun(sh: lsp.SignatureHelp)
  ---@param notify_reply_callback fun():nil
  ---@return nil
  handle = function(param, callback, notify_reply_callback)
    ---@type lsp.SignatureHelp
    local sh = {
      signatures = {
        {
          label = "test",
          documentation = {
            value = "test",
            kind = "markdown",
          },
          parameters = {
            {
              label = "test",
              documentation = {
                value = "test",
                kind = "markdown",
              },
            },
          },
        },
      },
      activeSignature = 1,
      activeParameter = 1,
    }
    callback(sh)
    notify_reply_callback()
  end,


  ---@type lsp.SignatureHelpOptions
  opts = {
    workDoneProgress = true,
    retriggerCharacters = { "(", "," },
    triggerCharacters = { "(", "," },
  },
  ---@type lsp.SignatureHelpClientCapabilities
  capabilities = {
    dynamicRegistration = true,
    contextSupport = true,
    signatureInformation = {
      activeParameterSupport = true,
      documentationFormat = { "markdown", "plaintext" },
      noActiveParameterSupport = true,
      parameterInformation = {
        labelOffsetSupport = true,
      },
    },
  },
}

return M
