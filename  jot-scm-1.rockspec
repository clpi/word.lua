local MODREV, SPECREV = "scm", "-1"
rockspec_format = "3.0"
package = "jot.lua"
version = MODREV .. SPECREV

source = {
  url = "git://github.com/clpi/jot.lua",
  tag = "0.1.0-alpha",
}

description = {
  summary = "Extensibility of org, comfort of markdown, for everyone",
  package = "jot.lua",
  version = "0.1.0-alpha",
  detailed = [[
    Extensibility of org, comfort of markdown, for everyone
  ]],
  description = [[
    Extensibility of org, comfort of markdown, for everyone
  ]],
  homepage = "https://github.com/clpi/jot.lua",
  maintainer = "https://github.com/clpi",
  labels = {
    "wiki",
    "neovim",
    "note",
    "org",
    "markdown",
    "nvim",
    "plugin",
    "org-mode",
  },
  license = "MIT",
}

if MODREV == "scm" then
  source = {
    url = "git://github.com/clpi/jot.lua",
    tag = nil,
    branch = "master",
  }
end

dependencies = {
  "lua >= 5.1",
  "pathlib.nvim ~> 2.2",
}

test_dependencies = {
  "nvim-treesitter == 0.9.2",
}

-- test = {
--   type = "command",
--   command = "scripts/test.sh"
-- }
--
deploy = {
  wrap_bin_scripts = true,
}

build = {
  type = "builtin",
  build_pass = false,
  modules = {},
  install = {
    bin = {
      jotls = "scripts/bin/jotls",
      jot = "scripts/bin/jot",
    },
  },
  copy_directories = {
    "doc",
  },
}
--vim:ft=lua