local util = require("telescope._extensions.word.util")

return function(opts)
  opts = opts or {}

  local current_workspace = util.get_current_workspace()

  if not current_workspace then
    return
  end

  require("telescope.builtin").grep_string({
    search = "^\\s*(\\*+|\\|{1,2}|\\${1,2})\\s+",
    use_regex = true,
    search_dirs = { tostring(current_workspace) },
    prompt_title = "Find in Norg files",
  })
end
