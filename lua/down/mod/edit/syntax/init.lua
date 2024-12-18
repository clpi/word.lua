local down = require("down")
local mod, utils = down.mod, down.utils

local M = mod.create("edit.syntax")

local function schedule(func)
  vim.schedule(function()
    if
        M.data.disable_deferred_updates
        or (
          (
            M.data.debounce_counters[vim.api.nvim_win_get_cursor(0)[1] + 1]
            or 0
          ) >= M.config.performance.max_debounce
        )
    then
      return
    end

    func()
  end)
end

M.setup = function()
  return {
    loaded = true,
    requires = {
      "tool.treesitter",
    },
  }
end

---@class down.edit.syntax.Data
M.data = {
  largest_change_start = -1,
  largest_change_end = -1,

  last_change = {
    active = false,
    line = 0,
  },

  -- we need to track the buffers in use
  last_buffer = "",

  disable_deferred_updates = false,
  debounce_counters = {},

  code_block_table = {
    --[[
           table is setup like so
            {
               buf_name_1 = {loaded_regex = {regex_name = {type = "type", range = {start_row1 = end_row1}}}}
               buf_name_2 = {loaded_regex = {regex_name = {type = "type", range = {start_row1 = end_row1}}}}
            }
        --]]
  },

  available_languages = {},

  -- fills M.data.ooaded_code_blocks with the list of active code blocks in the buffer
  -- stores globally apparently
  check_code_block_type = function(buf, reload, from, to)
    -- parse the current buffer, and clear out the buffer's loaded code blocks if needed
    local current_buf = vim.api.nvim_buf_get_name(buf)

    -- load nil table with empty values
    if M.data.code_block_table[current_buf] == nil then
      M.data.code_block_table[current_buf] = { loaded_regex = {} }
    end

    -- recreate table for buffer on buffer change
    -- reason for existence:
    --[[
            user deletes a bunch of code blocks from file, and said code blocks
            were the only regex blocks of that language. on a full buffer refresh
            like reentering the buffer, this will get cleared to recreate what languages
            are loaded. then another function will handle unloading syntax files on next load
        --]]
    for key in pairs(M.data.code_block_table) do
      if current_buf == key and reload == true then
        for k, _ in
        pairs(M.data.code_block_table[current_buf].loaded_regex)
        do
          M.data.remove_syntax(
            string.format("textGroup%s", string.upper(k)),
            string.format("textSnip%s", string.upper(k))
          )
          M.data.code_block_table[current_buf].loaded_regex[k] = nil
        end
      end
    end

    -- If the tree is valid then attempt to perform the query
    local tree = M.required["tool.treesitter"].get_document_root(buf)

    if tree then
      -- get the language node used by the code block
      local code_lang = utils.ts_parse_query(
        "markdown",
        [[(
                    (ranged_verbatim_tag (tag_name) @_tagname (tag_parameters) @language)
                    (#any-of? @_tagname "code" "embed")
                )]]
      )

      -- check for each code block capture in the root with a language paramater
      -- to build a table of all the languages for a given buffer
      local compare_table = {} -- a table to compare to what was loaded
      for id, node in
      code_lang:iter_captures(tree:root(), buf, from or 0, to or -1)
      do
        if id == 2 then -- id 2 here refers to the "language" tag
          -- find the end node of a block so we can grab the row
          local end_node = node:next_named_sibling():next_sibling()
          -- get the start and ends of the current capture
          local start_row = node:range() + 1
          local end_row

          -- don't try to parse a nil value
          if end_node == nil then
            end_row = start_row + 1
          else
            end_row = end_node:range() + 1
          end

          local regex_lang = vim.treesitter.get_node_text(node, buf)

          -- make sure that the language is actually valid
          local type_func = function()
            return M.data.available_languages[regex_lang].type
          end
          local ok, type = pcall(type_func)

          if not ok then
            type = "null" -- null type will never get parsed like treesitter languages
          end

          -- add language to table
          -- if type is empty it means this language has never been found
          if
              M.data.code_block_table[current_buf].loaded_regex[regex_lang]
              == nil
          then
            M.data.code_block_table[current_buf].loaded_regex[regex_lang] =
            {
              type = type,
              range = {},
              cluster = "",
            }
          end
          -- else just do what we need to do
          M.data.code_block_table[current_buf].loaded_regex[regex_lang].range[start_row] =
              end_row
          table.insert(compare_table, regex_lang)
        end
      end

      -- compare loaded languages to see if the file actually has the code blocks
      if from == nil then
        for lang in
        pairs(M.data.code_block_table[current_buf].loaded_regex)
        do
          local found_lang = false
          for _, matched in pairs(compare_table) do
            if matched == lang then
              found_lang = true
              break
            end
          end
          -- if no lang was matched, means we didn't find a language in our parse
          -- remove the syntax include and region
          if found_lang == false then
            -- delete loaded lang from the table
            M.data.code_block_table[current_buf].loaded_regex[lang] = nil
            M.data.remove_syntax(
              string.format("textGroup%s", string.upper(lang)),
              string.format("textSnip%s", string.upper(lang))
            )
          end
        end
      end
    end
  end,

  -- load syntax files for regex code blocks
  trigger_highlight_regex_code_block = function(
      buf,
      remove,
      ignore_buf,
      from,
      to
  )
    -- scheduling this function seems to break parsing properly
    -- schedule(function()
    local current_buf = vim.api.nvim_buf_get_name(buf)
    -- only parse from the loaded_code_blocks M, not from the file directly
    if M.data.code_block_table[current_buf] == nil then
      return
    end
    local lang_table = M.data.code_block_table[current_buf].loaded_regex
    for lang_name, curr_table in pairs(lang_table) do
      if curr_table.type == "syntax" then
        -- NOTE: the regex fallback code was originally mostly adapted from Vimwiki
        -- In its current form it has been intensely expanded upon
        local group = string.format("textGroup%s", string.upper(lang_name))
        local snip = string.format("textSnip%s", string.upper(lang_name))
        local start_marker = string.format("@code %s", lang_name)
        local end_marker = "@end"
        local has_syntax = string.format("syntax list @%s", group)

        -- sync groups when needed
        if
            ignore_buf == false
            and vim.api.nvim_buf_get_name(buf) == M.data.last_buffer
        then
          M.data.sync_regex_code_blocks(buf, lang_name, from, to)
        end

        -- try removing syntax before doing anything
        -- fixes hi link groups from not loading on certain updates
        if remove == true then
          M.data.remove_syntax(group, snip)
        end

        --- @type boolean, string|{ output: string }
        local ok, result =
            pcall(vim.api.nvim_exec2, has_syntax, { output = true })

        result = result.output or result

        local count = select(2, result:gsub("\n", "\n")) -- get length of result from syn list
        local empty_result = 0
        -- look to see if the textGroup is actually empty
        -- clusters don't delete when they're clear
        for line in result:gmatch("([^\n]*)\n?") do
          empty_result = string.match(line, "textGroup%w+%s+cluster=NONE")
          if empty_result == nil then
            empty_result = 0
          else
            empty_result = #empty_result
            break
          end
        end

        -- see if the syntax files even exist before we try to call them
        -- if syn list was an error, or if it was an empty result
        if
            ok == false
            or (
              ok == true
              and (
                (string.sub(result, 1, 1) == ("N" or "V") and count == 0)
                or (empty_result > 0)
              )
            )
        then
          -- absorb all syntax stuff
          -- potentially needs to be expanded upon as bad values come in
          local is_keydown = vim.bo[buf].iskeydown
          local current_syntax = ""
          local foldmethod = vim.o.foldmethod
          local foldexpr = vim.o.foldexpr
          local foldtext = vim.o.foldtext
          local foldnestmax = vim.o.foldnestmax
          local foldcolumn = vim.o.foldcolumn
          local foldenable = vim.o.foldenable
          local foldminlines = vim.o.foldminlines
          if vim.b.current_syntax ~= "" or vim.b.current_syntax ~= nil then
            current_syntax = lang_name
            vim.b.current_syntax = nil ---@diagnostic disable-line
          end

          -- include the cluster that will put inside the region
          -- source using the available languages
          for syntax, table in pairs(M.data.available_languages) do
            if table.type == "syntax" then
              if lang_name == syntax then
                if empty_result == 0 then
                  -- get the file name for the syntax file
                  --- @type string|string[]
                  local file = vim.api.nvim_get_runtime_file(
                    string.format("syntax/%s.vim", syntax),
                    false
                  )
                  if file == nil then
                    file = vim.api.nvim_get_runtime_file(
                      string.format("after/syntax/%s.vim", syntax),
                      false
                    )
                  end

                  file = file[1]

                  local command =
                      string.format("syntax include @%s %s", group, file)
                  vim.cmd(command)

                  -- make sure that group has things when needed
                  local regex = group .. "%s+cluster=(.+)"
                  --- @type boolean, string|{ output: string }
                  local _, found_cluster = pcall(
                    vim.api.nvim_exec2,
                    string.format("syntax list @%s", group),
                    { output = true }
                  )

                  found_cluster = found_cluster.output or found_cluster

                  local actual_cluster
                  for match in found_cluster:gmatch(regex) do
                    actual_cluster = match
                  end
                  if actual_cluster ~= nil then
                    M.data.code_block_table[current_buf].loaded_regex[lang_name].cluster =
                        actual_cluster
                  end
                elseif
                    M.data.code_block_table[current_buf].loaded_regex[lang_name].cluster
                    ~= nil
                then
                  local command = string.format(
                    "silent! syntax cluster %s add=%s",
                    group,
                    M.data.code_block_table[current_buf].loaded_regex[lang_name].cluster
                  )
                  vim.cmd(command)
                end
              end
            end
          end

          -- reset some values after including
          vim.bo[buf].iskeydown = is_keydown
          vim.b.current_syntax = current_syntax or "" ---@diagnostic disable-line

          has_syntax = string.format("syntax list %s", snip)
          --- @type boolean, string|{ output: string }
          _, result = pcall(vim.api.nvim_exec2, has_syntax, { output = true })
          result = result.output or result
          count = select(2, result:gsub("\n", "\n")) -- get length of result from syn list

          --[[
                        if we see "-" it means there potentially is already a region for this lang
                        we must have only 1 line, more lines means there is a region already
                        see :h syn-list for the format
                    --]]
          if count == 0 or (string.sub(result, 1, 1) == "-" and count == 0) then
            -- set highlight groups
            local regex_fallback_hl = string.format(
              [[
                                syntax region %s
                                \ matchgroup=Snip
                                \ start="%s" end="%s"
                                \ contains=@%s
                                \ keepend
                            ]],
              snip,
              start_marker,
              end_marker,
              group
            )
            vim.cmd(string.format("%s", regex_fallback_hl))
            -- sync everything
            M.data.sync_regex_code_blocks(buf, lang_name, from, to)
          end

          vim.o.foldmethod = foldmethod
          vim.o.foldexpr = foldexpr
          vim.o.foldtext = foldtext
          vim.o.foldnestmax = foldnestmax
          vim.o.foldcolumn = foldcolumn
          vim.o.foldenable = foldenable
          vim.o.foldminlines = foldminlines
        end

        vim.b.current_syntax = "" ---@diagnostic disable-line
        M.data.last_buffer = vim.api.nvim_buf_get_name(buf)
      end
    end
    -- end)
  end,

  -- remove loaded syntax include and snip region
  remove_syntax = function(group, snip)
    -- these clears are silent. errors do not matter
    -- errors are assumed to come from the functions that call this
    local group_remove = string.format("silent! syntax clear @%s", group)
    vim.cmd(group_remove)

    local snip_remove = string.format("silent! syntax clear %s", snip)
    vim.cmd(snip_remove)
  end,

  -- sync regex code blocks
  sync_regex_code_blocks = function(buf, regex, from, to)
    local current_buf = vim.api.nvim_buf_get_name(buf)
    -- only parse from the loaded_code_blocks M, not from the file directly
    if M.data.code_block_table[current_buf] == nil then
      return
    end
    local lang_table = M.data.code_block_table[current_buf].loaded_regex
    for lang_name, curr_table in pairs(lang_table) do
      -- if we got passed a regex, then we need to only parse the right one
      if regex ~= nil then
        if regex ~= lang_name then
          goto continue
        end
      end
      if curr_table.type == "syntax" then
        -- sync from code block

        -- for incremental syncing
        if from ~= nil then
          local found_lang = false
          for start_row, end_row in pairs(curr_table.range) do
            -- see if the text changes we made included a regex code block
            if start_row <= from and end_row >= to then
              found_lang = true
            end
          end

          -- didn't find match from this range of the current language, skip parsing
          if found_lang == false then
            goto continue
          end
        end

        local snip = string.format("textSnip%s", string.upper(lang_name))
        local start_marker = string.format("@code %s", lang_name)
        -- local end_marker = "@end"
        local regex_fallback_hl = string.format(
          [[
                        syntax sync match %s
                        \ grouphere %s
                        \ "%s"
                    ]],
          snip,
          snip,
          start_marker
        )
        vim.cmd(string.format("silent! %s", regex_fallback_hl))

        -- NOTE: this is kept as a just in case
        -- sync back from end block
        -- regex_fallback_hl = string.format(
        --     [[
        --         syntax sync match %s
        --         \ groupthere %s
        --         \ "%s"
        --     ]],
        --     snip,
        --     snip,
        --     end_marker
        -- )
        -- TODO check groupthere, a slower process
        -- vim.cmd(string.format("silent! %s", regex_fallback_hl))
        -- vim.cmd("syntax sync maxlines=100")
      end
      ::continue::
    end
  end,
}

---@class down.edit.syntax.Config
M.config = {
  -- Performance options for highlighting.
  --
  -- These options exhibit the same behaviour as the [`concealer`](@concealer)'s.
  performance = {
    -- How many lines each "chunk" of a file should take up.
    --
    -- When the size of the buffer is greater than this value,
    -- the buffer is then broken up into equal chunks and operations
    -- are done individually on those chunks.
    increment = 1250,

    -- How long the syntax M should wait before starting to conceal
    -- the buffer.
    timeout = 0,

    -- How long the syntax M should wait before starting to conceal
    -- a new chunk.
    interval = 500,

    -- The maximum amount of recalculations that take place at a single time.
    -- More operations than this count will be dropped.
    --
    -- Especially useful when e.g. holding down `x` in a buffer, forcing
    -- hundreds of recalculations at a time.
    max_debounce = 5,
  },
}

M.load = function()
  M.data.available_languages = utils.get_language_list(false)
end

M.on = function(event)
  M.data.debounce_counters[event.cursor_position[1] + 1] = M.data.debounce_counters
      [event.cursor_position[1] + 1]
      or 0

  local function should_debounce()
    return M.data.debounce_counters[event.cursor_position[1] + 1]
        >= M.config.performance.max_debounce
  end

  if
      event.type == "autocommands.events.bufenter" and event.content.markdown
  then
    local buf = event.buffer

    local line_count = vim.api.nvim_buf_line_count(buf)

    if line_count < M.config.performance.increment then
      M.data.check_code_block_type(buf, false)
      M.data.trigger_highlight_regex_code_block(buf, false, false)
    else
      local block_current =
          math.floor(event.cursor_position[1] / M.config.performance.increment)

      local function trigger_syntax_for_block(block)
        local line_begin = block == 0 and 0
            or block * M.config.performance.increment - 1
        local line_end = math.min(
          block * M.config.performance.increment
          + M.config.performance.increment
          - 1,
          line_count
        )

        M.data.check_code_block_type(buf, false, line_begin, line_end)
        M.data.trigger_highlight_regex_code_block(
          buf,
          false,
          false,
          line_begin,
          line_end
        )
      end

      trigger_syntax_for_block(block_current)

      local block_bottom, block_top = block_current - 1, block_current + 1

      local timer = vim.loop.new_timer()

      timer:start(
        M.config.performance.timeout,
        M.config.performance.interval,
        vim.schedule_wrap(function()
          local block_bottom_valid = block_bottom == 0
              or (block_bottom * M.config.performance.increment - 1 >= 0)
          local block_top_valid = block_top * M.config.performance.increment - 1
              < line_count

          if
              not vim.api.nvim_buf_is_loaded(buf)
              or (not block_bottom_valid and not block_top_valid)
          then
            timer:stop()
            return
          end

          if block_bottom_valid then
            trigger_syntax_for_block(block_bottom)
            block_bottom = block_bottom - 1
          end

          if block_top_valid then
            trigger_syntax_for_block(block_top)
            block_top = block_top + 1
          end
        end)
      )
    end

    vim.api.nvim_buf_attach(buf, false, {
      on_lines = function(_, cur_buf, _, start, _end)
        if buf ~= cur_buf then
          return true
        end

        if should_debounce() then
          return
        end

        M.data.last_change.active = true

        local mode = vim.api.nvim_get_mode().mode

        if mode ~= "i" then
          M.data.debounce_counters[event.cursor_position[1] + 1] = M.data.debounce_counters
              [event.cursor_position[1] + 1]
              + 1

          schedule(function()
            local new_line_count = vim.api.nvim_buf_line_count(buf)

            -- Sometimes occurs with one-line undos
            if start == _end then
              _end = _end + 1
            end

            if new_line_count > line_count then
              _end = _end + (new_line_count - line_count - 1)
            end

            line_count = new_line_count

            vim.schedule(function()
              M.data.debounce_counters[event.cursor_position[1] + 1] = M.data.debounce_counters
                  [event.cursor_position[1] + 1]
                  - 1
            end)
          end)
        else
          if M.data.largest_change_start == -1 then
            M.data.largest_change_start = start
          end

          if M.data.largest_change_end == -1 then
            M.data.largest_change_end = _end
          end

          M.data.largest_change_start = start
              < M.data.largest_change_start
              and start
              or M.data.largest_change_start
          M.data.largest_change_end = _end
              > M.data.largest_change_end
              and _end
              or M.data.largest_change_end
        end
      end,
    })
  elseif event.type == "autocommands.events.insertleave" then
    if should_debounce() then
      return
    end

    schedule(function()
      if
          not M.data.last_change.active
          or M.data.largest_change_end == -1
      then
        M.data.check_code_block_type(
          event.buffer,
          false
        -- M.data.last_change.line,
        -- M.data.last_change.line + 1
        )
        M.data.trigger_highlight_regex_code_block(
          event.buffer,
          false,
          true,
          M.data.last_change.line,
          M.data.last_change.line + 1
        )
      else
        M.data.check_code_block_type(
          event.buffer,
          false,
          M.data.last_change.line,
          M.data.last_change.line + 1
        )
        M.data.trigger_highlight_regex_code_block(
          event.buffer,
          false,
          true,
          M.data.largest_change_start,
          M.data.largest_change_end
        )
      end

      M.data.largest_change_start, M.data.largest_change_end =
          -1, -1
    end)
  elseif event.type == "autocommands.events.vimleavepre" then
    M.data.disable_deferred_updates = true
  elseif event.type == "autocommands.events.colorscheme" then
    M.data.trigger_highlight_regex_code_block(event.buffer, true, false)
  end
end

M.subscribed = {
  autocommands = {
    bufenter = true,
    colorscheme = true,
    insertleave = true,
    vimleavepre = true,
  },
}

return M
