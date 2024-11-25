local E = Mod.create("data.export")

E.setup = function()
  return {
    success = true,
    requires = {
      "integration.treesitter",
      'cmd',
      'workspace',
    }
  }
end

E.config.public = {
}

E.load = function()
  Mod.await('cmd', function(cmd)
    cmd.add_commands_from_table({
      export = {
        subcommands = {
          file = {
            args = 0,
            name = 'data.export.update'
          },
          workspace = {
            name = 'data.export.insert',
            args = 0,
          },
        },
        name = 'export'
      }
    })
  end)
end

E.config.public = {

}

E.private = {

}

E.public = {

}

E.on_event = function(e)

end

E.events.subscribed = {
  cmd = {
    ["data.export.insert"] = true,
    ["data.export.update"] = true,
  }
}



return E
