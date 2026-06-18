# Example fkst package

This is the example fkst package named `example`, written by `fkst-hosted`'s
repo-setup endpoint to bootstrap this repository for fkst.

## Layout

```
.fkst/packages/example/
  departments/
    example/
      main.lua   <- the engine entry point for the `example` department
  README.md      <- this file
```

The engine entry point is `departments/example/main.lua`. Every fkst package
needs at least one `departments/<name>/main.lua`; `main.lua` returns a Lua
module table that the engine loads.

## Adding real departments

Add another `departments/<your-department>/main.lua` (and any supporting Lua
files alongside it). Keep each department self-contained.

## Using this package in a goal

Reference the package by its directory name (`example`) in a goal's
`package_names`. fkst resolves each name against this repo's
`.fkst/packages/<name>/` directory at session start.
