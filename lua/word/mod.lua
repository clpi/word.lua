local uv = vim.loop or vim.uv
local lu = vim.lsp.util
local cb = require("word.util.callback")
local config = require("word.config").config
local log = require("word.util.log")
local utils = require("word.util")

_G.Mod = {}

--- @alias word.mod.public { version: string, [any]: any }

--- @class (exact) word.mod.resolver
--- @field ['lsp.completion']? lsp.completion
--- @field ['lsp.actions']? lsp.actions
--- @field ["ui.conceal"]? ui.conceal
--- @field ["ui.icon"]? ui.icon
--- @field workspace? workspace
--- @field ["ui.hl"]? ui.hl
--- @field ["ui.win"]? ui.win
--- @field note? note
--- @field link? link
--- @field cmd? cmd
--- @field code? code
--- @field todo? todo
--- @field ui? ui
--- @field ["ui.calendar"]? ui.calendar
--- @field ["ui.calendar.month"]? ui.calendar.month
--- @field ["ui.chat"]? ui.chat
--- @field ["ui.popup"]? ui.popup

--- Defines both a public and private configuration for a word init.
--- Public configurations may be tweaked by the user from the `word.setup()` function,  whereas private configurations are for internal use only.
--- @class (exact) word.mod.configuration
--- @field custom? table         Internal table that tracks the differences (changes) between the base `public` table and the new (altered) `public` table. It contains only the tables that the user has altered in their own configuration.
--- @field public private? table Internal configuration variables that may be tweaked by the developer.
--- @field public public? table  Configuration variables that may be tweaked by the user.

--- @class (exact) word.mod.events
--- @field defined? { [string]: word.event }              Lists all events defined by this init.
--- @field subscribed? { [string]: { [string]: boolean } } Lists the events that the init is subscribed to.

--- @alias word.mod.setup { success: boolean, requires?: string[], replaces?: string, replace_merge?: boolean, wants?: string[] }

--- Defines a init.
--- A init is an object that contains a set of hooks which are invoked by word whenever something in the
--- environment occurs. This can be an event, a simple act of the init being loaded or anything else.
--- @class (exact) word.mod
--- @field config? word.mod.configuration The configuration for the init.
--- @field events? word.mod.events Describes all information related to events for this init.
--- @field import? table<string, word.mod> Imported submod of the given init. Contrary to `required`, which only exposes the public API of a init, imported mod can be accessed in their entirety.
--- @field cmds? fun() Function that is invoked once the init is considered "stable", i.e. after all dependencies are loaded. Perform your main loading routine here.
--- @field opts? fun() Function that is invoked once the init is considered "stable", i.e. after all dependencies are loaded. Perform your main loading routine here.
--- @field maps? fun() Function that is invoked once the init is considered "stable", i.e. after all dependencies are loaded. Perform your main loading routine here.
--- @field load? fun() Function that is invoked once the init is considered "stable", i.e. after all dependencies are loaded. Perform your main loading routine here.
--- @field test? fun() Function that is invoked once the init is considered "stable", i.e. after all dependencies are loaded. Perform your main loading routine here.
--- @field bench? fun() Function that is invoked once the init is considered "stable", i.e. after all dependencies are loaded. Perform your main loading routine here.
--- @field name string The name of the init.
--- @field namespace string The name of the init.
--- @field post_load? fun() Function that is invoked after all mod are loaded. Useful if you want the word environment to be fully set up before performing some task.
--- @field path string The full path to the init (a more verbose version of `name`). Moday be used in lua's `require()` statements.
--- @field public private? table A convenience table to place all of your private variables that you don't want to expose.
--- @field public public? word.mod.public Every init can expose any set of information it sees fit through this field. All functions and variables declared in this table will be to any other init loaded.
--- @field required? word.mod.resolver Contains the public tables of all mod that were required via the `requires` array provided in the `setup()` function of this init.
--- @field setup? fun(): word.mod.setup? Function that is invoked before any other loading occurs. Should perform preliminary startup tasks.
--- @field replaced? boolean If `true`, this means the init is a replacement for a base init. This flag is set automatically whenever `setup().replaces` is set to a value.
--- @field on_event fun(event: word.event) A callback that is invoked any time an event the init has subscribed to has fired.
--- Returns a new word init, exposing all the necessary function and variables.
--- @param name string The name of the new init. Modake sure this is unique. The recommended naming convention is `category.mod_name` or `category.subcategory.mod_name`.
--- @return word.mod
_G.Mod.default_mod = function(name)
  return {
    setup = function()
      return {
        success = true,
        requires = {},
        replaces = nil,
        wants = {},
        replace_merge = false,
      }
    end,
    cmds = function() end,
    opts = function() end,
    maps = function()
      -- TODO: obviously inefficient
      Map.nmap(",wi", "<CMD>Word index<CR>")
      Map.nmap(",wp", "<CMD>Word note template<CR>")
      Map.nmap(",wc", "<CMD>Word note calendar<CR>")
      Map.nmap(",wn", "<CMD>Word note index<CR>")
      Map.nmap(",w.", "<CMD>Word note tomorrow<CR>")
      Map.nmap(",w,", "<CMD>Word note yesterday<CR>")
      Map.nmap(",wm", "<CMD>Word note month<CR>")
      Map.nmap(",wt", "<CMD>Word note today<CR>")
      Map.nmap(",wy", "<CMD>Word note year<CR>")
    end,
    load = function() end,
    on_event = function() end,
    post_load = function() end,
    name = "config",
    namespace = "word/" .. name,
    path = "mod.config",
    private = {},
    public = {
      version = require("word.config").config.version,
    },
    config = {
      private = {},
      public = {},
      custom = {},
    },
    events = {
      subscribed = { -- The events that the init is subscribed to
      },
      defined = {    -- The events that the init itself has defined
      },
    },
    required = {},
    import = {},
    test = function() end,
    bench = function() end,
  }
end
-- local cmd = require("word.cmd")

--- @param name string The name of the new init. Modake sure this is unique. The recommended naming convention is `category.mod_name` or `category.subcategory.mod_name`.
--- @param imports? string[] A list of imports to attach to the init. Import data is requestable via `init.required`. Use paths relative to the current init.
--- @return word.mod
function _G.Mod.create(name, imports)
  ---@type word.mod
  local new_mod = Mod.default_mod(name)
  if imports then
    for _, imp in ipairs(imports) do
      local fullpath = table.concat({ name, imp }, ".")
      if not Mod.load_mod(fullpath) then
        log.error(
          "Unable to load import '"
          .. fullpath
          .. "'! An error  (see traceback below):"
        )
        assert(false)
      end
      new_mod.import[fullpath] = Mod.loaded_mod[fullpath]
    end
  end

  if name then
    new_mod.name = name
    new_mod.path = "mod." .. name
    new_mod.namespace = "word/" .. name
    vim.api.nvim_create_namespace(new_mod.namespace)
  end
  return new_mod
end

--- Constructs a metainit from a list of submod. Modetamod are mod that can autoload batches of mod at once.
--- @param name string The name of the new metainit. Modake sure this is unique. The recommended naming convention is `category.mod_name` or `category.subcategory.mod_name`.
--- @param ... string A list of init names to load.
--- @return word.mod
_G.Mod.create_meta = function(name, ...)
  ---@type word.mod
  local m = Mod.create(name)

  m.config.public.enable = { ... }

  m.setup = function()
    return { success = true }
  end
  if m.cmds then
    m.cmds()
  end
  if m.opts then
    m.opts()
  end
  if m.maps then
    m.maps()
  end

  m.load = function()
    m.config.public.enable = (function()
      if not m.config.public.disable then
        return m.config.public.enable
      end

      local ret = {}

      for _, mname in ipairs(m.config.public.enable) do
        if not vim.tbl_contains(m.config.public.disable, mname) then
          table.insert(ret, mname)
        end
      end

      return ret
    end)()

    for _, mname in ipairs(m.config.public.enable) do
      Mod.load_mod(mname)
    end
  end
  return m
end

-- TODO: What goes below this line until the next notice used to belong to mod
-- We need to find a way to make these functions easier to maintain

--- Tracks the amount of currently loaded mod.
Mod.loaded_mod_count = 0

--- The table of currently loaded mod
--- @type { [string]: word.mod }
Mod.loaded_mod = {}

--- Loads and enables a init
--- Loads a specified init. If the init subscribes to any events then they will be activated too.
--- @param m word.mod The actual init to load.
--- @return boolean # Whether the init successfully loaded.
function Mod.load_mod_from_table(m)
  log.info("Loading init with name" .. m.name)

  -- If our init is already loaded don't try loading it again
  if Mod.loaded_mod[m.name] then
    log.trace("mod" .. m.name .. "already loaded. Omitting...")
    return true
  end

  -- Invoke the setup function. This function returns whether or not the loading of the init was successful and some metadata.
  ---@type word.mod.setup
  local mod_load = m.setup and m.setup()
      or {
        success = true,
        replaces = {},
        replace_merge = false,
        requires = {},
        wants = {},
      }

  -- We do not expect init.setup() to ever return nil, that's why this check is in place
  if not mod_load then
    log.error(
      "init"
      .. m.name
      .. "does not handle init loading correctly; init.setup() returned nil. Omitting..."
    )
    return false
  end

  -- A part of the table returned by init.setup() tells us whether or not the init initialization was successful
  if mod_load.success == false then
    log.trace("mod" .. m.name .. "did not load properly.")
    return false
  end

  --[[
      --    This small snippet of code creates a copy of an already loaded init with the same name.
      --    If the init wants to replace an already loaded init then we need to create a deepcopy of that old init
      --    in order to stop it from getting overwritten.
      --]]
  ---@type word.mod
  local mod_to_replace

  -- If the return value of init.setup() tells us to hotswap with another init then cache the init we want to replace with
  if mod_load.replaces and mod_load.replaces ~= "" then
    mod_to_replace = vim.deepcopy(Mod.loaded_mod[mod_load.replaces])
  end

  -- Add the init into the list of loaded mod
  -- The reason we do this here is so other mod don't recursively require each other in the dependency loading loop below
  Mod.loaded_mod[m.name] = m

  -- If the init "wants" any other mod then verify they are loaded
  if mod_load.wants and not vim.tbl_isempty(mod_load.wants) then
    log.info(
      "mod" .. m.name .. "wants certain mod. Ensuring they are loaded..."
    )

    -- Loop through each dependency and ensure it's loaded
    for _, req_mod in ipairs(mod_load.wants) do
      log.trace("Verifying" .. req_mod)

      -- This would've always returned false had we not added the current init to the loaded init list earlier above
      if not Mod.is_mod_loaded(req_mod) then
        if config.user.mods[req_mod] then
          log.trace(
            "Wanted init"
            .. req_mod
            .. "isn't loaded but can be as it's defined in the user's config. Loading..."
          )

          if not Mod.load_mod(req_mod) then
            require("word.util.log").error(
              "Unable to load wanted init for"
              .. m.name
              .. "- the init didn't load successfully"
            )

            -- Modake sure to clean up after ourselves if the init failed to load
            Mod.loaded_mod[m.name] = nil
            return false
          end
        else
          log.error(
            ("Unable to load init %s, wanted dependency %s was not satisfied. Be sure to load the init and its appropriate config too!")
            :format(
              m.name,
              req_mod
            )
          )

          -- Modake sure to clean up after ourselves if the init failed to load
          Mod.loaded_mod[m.name] = nil
          return false
        end
      end

      -- Create a reference to the dependency's public table
      m.required[req_mod] = Mod.loaded_mod[req_mod].public
    end
  end

  -- If any dependencies have been defined, handle them
  if mod_load.requires and vim.tbl_count(mod_load.requires) > 0 then
    log.info(
      "mod" .. m.name .. "has dependencies. Loading dependencies first..."
    )

    -- Loop through each dependency and load it one by one
    for _, req_mod in pairs(mod_load.requires) do
      log.trace("Loading submod" .. req_mod)

      -- This would've always returned false had we not added the current init to the loaded init list earlier above
      if not Mod.is_mod_loaded(req_mod) then
        if not Mod.load_mod(req_mod) then
          log.error(
            ("Unable to load init %s, required dependency %s did not load successfully"):format(
              m.name,
              req_mod
            )
          )

          -- Modake sure to clean up after ourselves if the init failed to load
          Mod.loaded_mod[m.name] = nil
          return false
        end
      else
        log.trace("mod" .. req_mod .. "already loaded, skipping...")
      end

      -- Create a reference to the dependency's public table
      m.required[req_mod] = Mod.loaded_mod[req_mod].public
    end
  end

  -- After loading all our dependencies, see if we need to hotswap another init with ourselves
  if mod_to_replace then
    -- Modake sure the names of both mod match
    m.name = mod_to_replace.name

    -- Whenever a init gets hotswapped, a special flag is set inside the init in order to signalize that it has been hotswapped before
    -- If this flag has already been set before, then throw an error - there is no way for us to know which hotswapped init should take priority.
    if mod_to_replace.replaced then
      log.error(
        ("Unable to replace init %s - init replacement clashing detected. This error triggers when a init tries to be replaced more than two times - word doesn't know which replacement to prioritize.")
        :format(
          mod_to_replace.name
        )
      )

      -- Modake sure to clean up after ourselves if the init failed to load
      Mod.loaded_mod[m.name] = nil

      return false
    end

    -- If the replace_merge flag is set to true in the setup() return value then recursively merge the data from the
    -- previous init into our new one. This allows for practically seamless hotswapping, as it allows you to retain the data
    -- of the previous init.
    if mod_load.replace_merge then
      m = utils.extend(m, {
        private = mod_to_replace.private,
        config = mod_to_replace.config,
        public = mod_to_replace.public,
        events = mod_to_replace.events,
      })
    end

    -- Set the special init.replaced flag to let everyone know we've been hotswapped before
    m.replaced = true
  end

  log.info("Successfully loaded init", m.name)

  -- Keep track of the number of loaded mod
  Mod.loaded_mod_count = Mod.loaded_mod_count + 1

  if m.cmds then
    m.cmds()
  end
  if m.opts then
    m.opts()
  end
  if m.maps then
    m.maps()
  end
  if m.load then
    m.load()
  end

  -- local msg = ("%fms"):format((vim.loop.hrtime() - start) / 1e6)
  -- vim.notify(msg .. " " .. init.name)

  Mod.broadcast_event({
    type = "mod_loaded",
    split_type = { "mod_loaded" },
    filename = "",
    filehead = "",
    cursor_position = { 0, 0 },
    referrer = "",
    line_content = "",
    content = m,
    payload = m,
    topic = "mod_loaded",
    broadcast = true,
    buffer = vim.api.nvim_get_current_buf(),
    window = vim.api.nvim_get_current_win(),
    mode = vim.fn.mode(),
  })

  return true
end

--- Unlike `load_mod_from_table()`, which loads a init from memory, `load_mod()` tries to find the corresponding init file on disk and loads it into memory.
--- If the init cannot not be found, attempt to load it off of github (unimplemented). This function also applies user-defined config and keys to the mod themselves.
--- This is the recommended way of loading mod - `load_mod_from_table()` should only really be used by word itself.
--- @param mod_name string A path to a init on disk. A path seperator in word is '.', not '/'.
--- @param cfg table? A config that reflects the structure of `word.config.user.setup["init.name"].config`.
--- @return boolean # Whether the init was successfully loaded.
function _G.Mod.load_mod(mod_name, cfg)
  -- Don't bother loading the init from disk if it's already loaded
  if _G.Mod.is_mod_loaded(mod_name) then
    return true
  end

  -- Attempt to require the init, does not throw an error if the init doesn't exist
  local modl = require("word.mod." .. mod_name)

  -- If the init is nil for some reason return false
  if not modl then
    log.error(
      "Unable to load init"
      .. mod_name
      .. "- loaded file returned nil. Be sure to return the table created by mod.create() at the end of your init.lua file!"
    )
    return false
  end

  -- If the value of `init` is strictly true then it means the required file returned nothing
  -- We obviously can't do anything meaningful with that!
  if modl == true then
    log.error(
      "An error has occurred when loading"
      .. mod_name
      ..
      "- loaded file didn't return anything meaningful. Be sure to return the table created by mod.create() at the end of your init.lua file!"
    )
    return false
  end

  -- Load the user-defined config
  if cfg and not vim.tbl_isempty(cfg) then
    modl.config.custom = cfg
    modl.config.public = utils.extend(modl.config.public, cfg)
  else
    modl.config.custom = config.mods[mod_name]
    modl.config.public =
        utils.extend(modl.config.public, modl.config.custom or {})
  end

  -- Pass execution onto load_mod_from_table() and let it handle the rest
  return Mod.load_mod_from_table(modl)
end

--- Has the same principle of operation as load_mod_from_table(), except it then sets up the parent init's "required" table, allowing the parent to access the child as if it were a dependency.
--- @param init word.mod A valid table as returned by mod.create()
--- @param parent_mod string|word.mod If a string, then the parent is searched for in the loaded mod. If a table, then the init is treated as a valid init as returned by mod.create()
function _G.Mod.load_mod_as_dependency_from_table(init, parent_mod)
  if Mod.load_mod_from_table(init) then
    if type(parent_mod) == "string" then
      Mod.loaded_mod[parent_mod].required[init.name] = init.public
    elseif type(parent_mod) == "table" then
      parent_mod.required[init.name] = init.public
    end
  end
end

--- Normally loads a init, but then sets up the parent init's "required" table, allowing the parent init to access the child as if it were a dependency.
--- @param mod_name string A path to a init on disk. A path seperator in word is '.', not '/'
--- @param parent_mod string The name of the parent init. This is the init which the dependency will be attached to.
--- @param cfg? table A config that reflects the structure of word.config.user.setup["init.name"].config
function _G.Mod.load_mod_as_dependency(mod_name, parent_mod, cfg)
  if Mod.load_mod(mod_name, cfg) and Mod.is_mod_loaded(parent_mod) then
    Mod.loaded_mod[parent_mod].required[mod_name] = Mod.get_mod_config(mod_name)
  end
end

--- Retrieves the public API exposed by the init.
--- @generic T
--- @param mod_name `T` The name of the init to retrieve.
--- @return T?
function _G.Mod.get_mod(mod_name)
  if not Mod.is_mod_loaded(mod_name) then
    log.trace(
      "Attempt to get init with name",
      mod_name,
      "failed - init is not loaded."
    )
    return
  end

  return Mod.loaded_mod[mod_name].public
end

--- Returns the init.config.public table if the init is loaded
--- @param mod_name string The name of the init to retrieve (init must be loaded)
--- @return table?
function _G.Mod.get_mod_config(mod_name)
  if not Mod.is_mod_loaded(mod_name) then
    log.trace(
      "Attempt to get init config with name",
      mod_name,
      "failed - init is not loaded."
    )
    return
  end

  return Mod.loaded_mod[mod_name].config.public
end

--- Returns true if init with name mod_name is loaded, false otherwise
--- @param mod_name string The name of an arbitrary init
--- @return boolean
function _G.Mod.is_mod_loaded(mod_name)
  return Mod.loaded_mod[mod_name] ~= nil
end

--- Reads the init's public table and looks for a version variable, then converts it from a string into a table, like so: `{ major = <number>, minor = <number>, patch = <number> }`.
--- @param mod_name string The name of a valid, loaded init.
--- @return table? parsed_version
function _G.Mod.get_mod_version(mod_name)
  -- If the init isn't loaded then don't bother retrieving its version
  if not Mod.is_mod_loaded(mod_name) then
    log.trace(
      "Attempt to get init version with name",
      mod_name,
      "failed - init is not loaded."
    )
    return
  end

  -- Grab the version of the init
  local version = Mod.get_mod(mod_name).version

  -- If it can't be found then error out
  if not version then
    log.trace(
      "Attempt to get init version with name",
      mod_name,
      "failed - version variable not present."
    )
    return
  end

  return utils.parse_version_string(version)
end

--- Executes `callback` once `init` is a valid and loaded init, else the callback gets instantly executed.
--- @param mod_name string The name of the init to listen for.
--- @param callback fun(mod_public_table: word.mod.public) The callback to execute.
function _G.Mod.await(mod_name, callback)
  if Mod.is_mod_loaded(mod_name) then
    callback(assert(Mod.get_mod(mod_name)))
    return
  end

  cb.on_event("mod_loaded", function(_, init)
    callback(init.public)
  end, function(event)
    return event.content.name == mod_name
  end)
end

--- @alias Mode
--- | "n"
--- | "no"
--- | "nov"
--- | "noV"
--- | "noCTRL-V"
--- | "CTRL-V"
--- | "niI"
--- | "niR"
--- | "niV"
--- | "nt"
--- | "Terminal"
--- | "ntT"
--- | "v"
--- | "vs"
--- | "V"
--- | "Vs"
--- | "CTRL-V"
--- | "CTRL-Vs"
--- | "s"
--- | "S"
--- | "CTRL-S"
--- | "i"
--- | "ic"
--- | "ix"
--- | "R"
--- | "Rc"
--- | "Rx"
--- | "Rv"
--- | "Rvc"
--- | "Rvx"
--- | "c"
--- | "cr"
--- | "cv"
--- | "cvr"
--- | "r"
--- | "rm"
--- | "r?"
--- | "!"
--- | "t"

--- @class (exact) word.event
--- @field type string The type of the event. Exists in the format of `category.name`.
--- @field split_type string[] The event type, just split on every `.` character, e.g. `{ "category", "name" }`.
--- @field content? table|any The content of the event. The data found here is specific to each individual event. Can be thought of as the payload.
--- @field referrer string The name of the init that triggered the event.
--- @field broadcast boolean Whether the event was broadcast to all mod. `true` is so, `false` if the event was specifically sent to a single recipient.
--- @field cursor_position { [1]: number, [2]: number } The position of the cursor at the moment of broadcasting the event.
--- @field filename string The name of the file that the user was in at the moment of broadcasting the event.
--- @field filehead string The directory the user was in at the moment of broadcasting the event.
--- @field line_content string The content of the line the user was editing at the moment of broadcasting the event.
--- @field buffer number The buffer ID of the buffer the user was in at the moment of broadcasting the event.
--- @field window number The window ID of the window the user was in at the moment of broadcasting the event.
--- @field mode Mode The mode Neovim was in at the moment of broadcasting the event.

-- TODO: What goes below this line until the next notice used to belong to mod
-- We need to find a way to make these functions easier to maintain

--[[
  --    word EVENT FILE
  --    This file is responsible for dealing with event handling and broadcasting.
  --    All mod that subscribe to an event will receive it once it is triggered.
  --]]

--- The working of this function is best illustrated with an example:
--        If type == 'some_plugin.events.my_event', this function will return { 'some_plugin', 'my_event' }
--- @param type string The full path of a init event
--- @return string[]?
function _G.Mod.split_event_type(type)
  local start_str, end_str = type:find("%.events%.")

  local split_event_type = { type:sub(0, start_str - 1), type:sub(end_str + 1) }

  if #split_event_type ~= 2 then
    log.warn("Invalid type name:", type)
    return
  end

  return split_event_type
end

--- Returns an event template defined in `init.events.defined`.
--- @param init word.mod A reference to the init invoking the function
--- @param type string A full path to a valid event type (e.g. `init.events.some_event`)
--- @return word.event?
function _G.Mod.get_event_template(init, type)
  -- You can't get the event template of a type if the type isn't loaded
  if not Mod.is_mod_loaded(init.name) then
    log.info("Unable to get event of type", type, "with init", init.name)
    return
  end

  -- Split the event type into two
  local split_type = Mod.split_event_type(type)

  if not split_type then
    log.warn(
      "Unable to get event template for event",
      type,
      "and init",
      init.name
    )
    return
  end

  log.trace("Returning", split_type[2], "for init", split_type[1])

  -- Return the defined event from the specific init
  return Mod.loaded_mod[init.name].events.defined[split_type[2]]
end

--- Creates a deep copy of the `mod.base_event` event and returns it with a custom type and referrer.
--- @param init word.mod A reference to the init invoking the function.
--- @param name string A relative path to a valid event template.
--- @return word.event
function Mod.define_event(init, name)
  -- Create a copy of the base event and override the values with ones specified by the user

  ---@type word.event
  local new_event = {
    payload = nil,
    topic = "base_event",
    type = "base_event",
    split_type = {},
    content = nil,
    referrer = "config",
    broadcast = true,
    cursor_position = {},
    filename = "",
    filehead = "",
    line_content = "",
    buffer = 0,
    window = 0,
    mode = "",
  }

  if name then
    new_event.type = init.name .. ".events." .. name
  end

  new_event.referrer = init.name

  return new_event
end

--- Returns a copy of the event template provided by a init.
--- @param init word.mod A reference to the init invoking the function
--- @param type string A full path to a valid .vent type (e.g. `init.events.some_event`)
--- @param content table|any? The content of the event, can be anything from a string to a table to whatever you please.
--- @param ev? table The original event data.
--- @return word.event? # New event.
function Mod.create_event(init, type, content, ev)
  -- Get the init that contains the event
  local mod_name = Mod.split_event_type(type)[1]

  -- Retrieve the template from init.events.defined
  local event_template =
      Mod.get_event_template(Mod.loaded_mod[mod_name] or { name = "" }, type)

  if not event_template then
    log.warn("Unable to create event of type", type, ". Returning nil...")
    return
  end

  -- Modake a deep copy here - we don't want to override the actual base table!
  local new_event = vim.deepcopy(event_template)

  new_event.type = type
  new_event.content = content
  new_event.referrer = init.name

  -- Override all the important values
  new_event.split_type = assert(Mod.split_event_type(type))
  new_event.filename = vim.fn.expand("%:t") --[[@as string]]
  new_event.filehead = vim.fn.expand("%:p:h") --[[@as string]]

  local bufid = ev and ev.buf or vim.api.nvim_get_current_buf()
  local winid = assert(vim.fn.bufwinid(bufid))

  if winid == -1 then
    winid = vim.api.nvim_get_current_win()
  end

  new_event.cursor_position = vim.api.nvim_win_get_cursor(winid)

  local row_1b = new_event.cursor_position[1]
  new_event.line_content =
      vim.api.nvim_buf_get_lines(bufid, row_1b - 1, row_1b, true)[1]
  new_event.referrer = init.name
  new_event.broadcast = true
  new_event.buffer = bufid
  new_event.window = winid
  new_event.mode = vim.api.nvim_get_mode().mode

  return new_event
end

--- Sends an event to all subscribed mod. The event contains the filename, filehead, cursor position and line content as a bonus.
--- @param event word.event An event, usually created by `mod.create_event()`.
--- @param callback function? A callback to be invoked after all events have been asynchronously broadcast
function _G.Mod.broadcast_event(event, callback)
  -- Broadcast the event to all mod
  if not event.split_type then
    log.error(
      "Unable to broadcast event of type",
      event.type,
      "- invalid event name"
    )
    return
  end

  -- Let the callback handler know of the event
  -- log.info(event.content.name .. event.type)
  cb.handle(event)

  -- Loop through all the mod
  for _, current_init in pairs(Mod.loaded_mod) do
    -- If the current init has any subscribed events and if it has a subscription bound to the event's init name then
    if
        current_init.events.subscribed
        and current_init.events.subscribed[event.split_type[1]]
    then
      -- Check whether we are subscribed to the event type
      local evt =
          current_init.events.subscribed[event.split_type[1]][event.split_type[2]]

      if evt ~= nil and evt == true then
        -- Run the on_event() for that init
        current_init.on_event(event)
      end
    end
  end
  -- TODO: deprecate
  if callback then
    callback()
  end
end

--- Instead of broadcasting to all loaded mod, `send_event()` only sends to one init.
--- @param recipient string The name of a loaded init that will be the recipient of the event.
--- @param event word.event An event, usually created by `mod.create_event()`.
function _G.Mod.send_event(recipient, event)
  -- If the recipient is not loaded then there's no reason to send an event to it
  if not Mod.is_mod_loaded(recipient) then
    log.warn(
      "Unable to send event to init" .. recipient .. "- the init is not loaded."
    )
    return
  end
  event.broadcast = false
  cb.handle(event)
  local modl = Mod.loaded_mod[recipient]
  if modl.events.subscribed and mod.events.subscribed[event.split_type[1]] then
    local evt = modl.events.subscribed[event.split_type[1]][event.split_type[2]]
    if evt ~= nil and evt == true then
      modl.on_event(event)
    end
  end
end

return Mod
