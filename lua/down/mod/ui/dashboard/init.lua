local D = require("down.mod").create("ui.dashboard")

D.setup = function()
  return {
    loaded = true,
    requires = {},
  }
end

---@class down.ui.dashboard.Config
D.config = {}

---@class down.ui.dashboard.Data
D.data = {}

return D
