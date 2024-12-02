---@meta
---
--- @alias jot.mod.pub { version: string, [any]: any }

--- @class (exact) jot.mod.resolver
--- @field ['lsp.completion']? lsp.completion
--- @field ['lsp.actions']? lsp.actions
--- @field ['lsp.command']? lsp.command
--- @field ['lsp.hint']? lsp.hint
--- @field ['lsp.hover']? lsp.hover
--- @field ['lsp.lens']? lsp.lens
--- @field lsp? jot.lsp
--- @field ['lsp.semantic']? lsp.semantic
--- @field ["ui.conceal"]? ui.conceal
--- @field ["ui.icon"]? ui.icon
--- @field workspace? workspace
--- @field ["ui.hl"]? ui.hl
--- @field ["ui.win"]? ui.win
--- @field note? note
--- @field log? log
--- @field link? link
--- @field cmd? cmd
--- @field code? code
--- @field todo? todo
--- @field ui? ui
--- @field template? template
--- @field ["code.snippet"]? code.snippet
--- @field ["code.run"]? code.run
--- @field ["ui.calendar"]? ui.calendar
--- @field ["ui.calendar.month"]? ui.calendar.month
--- @field ["ui.chat"]? ui.chat
--- @field ["ui.popup"]? ui.popup

--- Defines both a public and private config for a jot init.
--- Public configs may be tweaked by the user from the `jot.setup()` function,  whereas private configs are for internal use only.
--- @class (exact) jot.mod.config
--- @field enable
--- @field public public? table  config variables that may be tweaked by the user.

--- @class (exact) jot.mod.events
--- @field defined? { [string]: jot.event }              Lists all events defined by this init.
--- @field subscribed? { [string]: { [string]: boolean } } Lists the events that the init is subscribed to.

--- @alias jot.mod.setup { loaded: boolean, requires?: string[], replaces?: string, replace_merge?: boolean, wants?: string[] }

--- Defines a init.
--- A init is an object that contains a set of hooks which are invoked by jot whenever something in the
--- environment occurs. This can be an event, a simple act of the init being loaded or anything else.
--- @class (exact) jot.mod
--- @field config? jot.mod.config The config for the init.
--- @field events? jot.mod.events Describes all information related to events for this init.
--- @field import? table<string, jot.mod> Imported submod of the given init. Contrary to `required`, which only exposes the public API of a init, imported mod can be accessed in their entirety.
--- @field cmds? fun() Function that adds all the commands for the init.
--- @field opts? fun() Function that adds all the options for the init.
--- @field maps? fun() Function that adds all the mappings for the init.
--- @field load? fun() Function that is invoked once the init is considered "stable", i.e. after all dependencies are loaded. Perform your main loading routine here.
--- @field test? fun() Function that is invoked when the init is being tested.
--- @field bench? fun() Function that is invoked when the init is being benchmarked.
--- @field name string The name of the init.
--- @field namespace string The name of the init.
--- @field post_load? fun() Function that is invoked after all mod are loaded. Useful if you want the jot environment to be fully set up before performing some task.
--- @field path string The full path to the init (a more verbose version of `name`). Moday be used in lua's `require()` statements.
--- @field public private? table A convenience table to place all of your private variables that you don't want to expose.
--- @field public public? jot.mod.public Every init can expose any set of information it sees fit through this field. All functions and variables declared in this table will be to any other init loaded.
--- @field required? jot.mod.resolver Contains the public tables of all mod that were required via the `requires` array provided in the `setup()` function of this init.
--- @field setup? fun(): jot.mod.setup? Function that is invoked before any other loading occurs. Should perform preliminary startup tasks.
--- @field replaced? boolean If `true`, this means the init is a replacement for a base init. This flag is set automatically whenever `setup().replaces` is set to a value.
--- @field on_event fun(event: jot.event) A callback that is invoked any time an event the init has subscribed to has fired.
--- Returns a new jot init, exposing all the necessary function and variables.
--- @param name string The name of the new init. Modake sure this is unique. The recommended naming convention is `category.mod_name` or `category.subcategory.mod_name`.
--- @return jot.mod
---
---
--- @alias OperatingSystem
--- | "windows"
--- | "wsl"
--- | "wsl2"
--- | "mac"
--- | "linux"
--- | "bsd"
--- @alias jot.config.init { config?: table }

--- @class (exact) jot.config.ft
--- @field md boolean
--- @field mdx boolean
--- @field markdown boolean

--- @class (exact) jot.config.user
--- @field hook? fun(manual: boolean, arguments?: string)    A user-defined function that is invoked whenever jot starts up. May be used to e.g. set custom keybindings.
--- @field lazy? boolean                             Whether to defer loading the jot base until after the user has entered a `.jot` file.
--- @field logger? jot.log.config                   A config table for the logger.

--- @class (exact) jot.config
--- @field args table<string, string>                   A list of arguments provided to the `:jotStart` function in the form of `key=value` pairs. Only applicable when `user_config.lazy_loading` is `true`.
--- @field manual boolean?                                   Used if jot was manually loaded via `:jotStart`. Only applicable when `user_config.lazy_loading` is `true`.
--- @field mods table<string, jot.config.init> Acts as a copy of the user's config that may be modified at runtime.
--- @field os OperatingSystem                           The operating system that jot is currently running under.
--- @field pathsep "\\"|"/"                                  The operating system that jot is currently running under.
--- @field loaded boolean                                   Set to `true` when jot is fully initialized.
--- @field data string
--- @field user jot.config.user              Stores the config provided by the user.
--- @field version string                                    The version of jot that is currently active. Automatically updated by CI on every release.

--- Stores the config for the entirety of jot.
--- This includes not only the user config (passed to `setup()`), but also internal
--- variables that describe something specific about the user's hardware.
--- @see jot.setup
---
---
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

--- @class (exact) jot.event
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
