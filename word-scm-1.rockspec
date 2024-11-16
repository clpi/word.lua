local MODREV, SPECREV = "scm", "-1"
rockspec_format = "3.0"
package = "word"
version = MODREV .. SPECREV

description = {
  summary = "Extensibility for everyone",
  labels = { "wiki", "plugin", "neovim", "notes", "markdown" },
  homepage = "https://github.com/clpi/word.lua",
  license = "MIT",
}

dependencies = {
  "lua == 5.1",
  "nvim-nio ~> 1.7",
  "plenary.nvim == 0.1.4",
  "nui.nvim == 0.3.0",
  "pathlib.nvim ~> 2.2",
}

source = {
  url = "http://github.com/clpi/word.lua/archive/v" .. MODREV .. ".zip",
}

if MODREV == "scm" then
  source = {
    url = "git://github.com/clpi/word.lua",
  }
end

test_dependencies = {
  "nlua",
  -- Placed here as we plan on removing nvim-treesitter as a dependency soon, but it's still required for various tests.
  "nvim-treesitter == 0.9.2",
}

build = {
  type = "builtin",
  copy_directories = {
    "queries",
    "doc",
  }
}
