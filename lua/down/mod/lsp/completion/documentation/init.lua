local D = require("down.mod").create("lsp.completion.documentation")

D.setup = function()
  return {
    loaded = true,
  }
end

---@class lsp.completion.documentation.Data
D.data = {
}

return D
