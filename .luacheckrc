-- .luacheckrc
-- Luacheck configuration for the Flow library.
-- Run: luacheck flow/

-- Lua version
std = "lua51"

-- Maximum line length (0 = disabled)
max_line_length = false

-- Global symbols provided by the Defold runtime.
-- These are injected into every gui_script / script environment by the engine.
globals = {
  -- Defold core
  "gui",
  "msg",
  "hash",
  "vmath",
  "window",
  "sys",
  "go",
  -- Defold data types (used in annotations only; no runtime read/write)
  "url",
  "socket",
}

-- Read-only globals: modules that Defold injects but that library code must
-- not overwrite.
read_globals = {
  "print",
  "pairs",
  "ipairs",
  "type",
  "tostring",
  "tonumber",
  "math",
  "string",
  "table",
  "io",
  "os",
  "pcall",
  "xpcall",
  "error",
  "assert",
  "unpack",
  "select",
  "next",
  "rawget",
  "rawset",
  "rawequal",
  "setmetatable",
  "getmetatable",
  "require",
  "package",
  "collectgarbage",
  "load",
  "loadfile",
  "loadstring",
  "dofile",
  "coroutine",
  "_G",
  "_VERSION",
}

-- Per-file overrides ---------------------------------------------------------

files["tests/smoke.lua"] = {
  -- Tests define their own stubs for Defold globals.
  globals = { "vmath", "hash", "msg", "gui", "window", "sys" },
  -- W122: setting read-only field of global (package.path, package.preload) —
  --       intentional in test bootstrapping to configure the require path.
  -- W211: unused variable (screens require kept for module side-effects).
  -- W241: variable mutated but never accessed (gui_nodes write-only debug registry).
  ignore = { "122", "211", "241" },
}

files["tests/perf_probe.lua"] = {
  globals = { "vmath", "hash", "gui", "window", "sys" },
  -- W122: setting read-only field of global (package.path, package.preload) —
  --       intentional in test bootstrapping.
  ignore = { "122" },
}

files["sample/screens.lua"] = {
  -- Screens may use navigation as an upvalue captured at module scope.
  ignore = { "212" },
}

-- Ignore patterns common across generated/legacy code ------------------------

-- W111: setting an undefined global (suppressed for Defold builtins declared above)
-- W212: unused argument (common in Defold callbacks where self is unused)
ignore = { "212" }
