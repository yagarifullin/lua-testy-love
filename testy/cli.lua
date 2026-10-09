-- Единый парсер аргументов и сборщик файлов.
local M = {}

local function file_exists( path )
  local f = io.open( path, "r" )
  if f then f:close() return true end
  return false
end

local function is_dir( path )
  local f = io.open( path .. "/.", "r" )
  if f then f:close() return true end
  return false
end

-- Рекурсивный сбор *.lua файлов из директории.
local function collect_recursive( dir, acc )
  acc = acc or {}
  dir = dir:gsub( "/+$", "" )   -- ← убираем trailing slashes
  local p = io.popen( "ls -1 '" .. dir .. "' 2>/dev/null" )
  if not p then return acc end
  for line in p:lines() do
    local full = dir .. "/" .. line
    if is_dir( full ) then
      collect_recursive( full, acc )
    elseif line:match( "%.lua$" ) then
      acc[ #acc+1 ] = full
    end
  end
  p:close()
  return acc
end

function M.parse( args )
  local opts = {
    files = {},
    recursive = false,
    tap = false,
    verbose = false,
    help = false,
    mock_love = false,
    no_extra = false,
    test_mode = false,
    window = false,
    screenshot = false,
    tolerance = 0.01,
  }
  local i = 1
  while args[ i ] do
    local a = args[ i ]
    if a == "-r" then opts.recursive = true
    elseif a == "-t" then opts.tap = true
    elseif a == "-v" then opts.verbose = true
    elseif a == "-h" or a == "--help" then opts.help = true
    elseif a == "--mock-love" then opts.mock_love = true
    elseif a == "--no-extra" then opts.no_extra = true
    elseif a == "--test" then opts.test_mode = true
    elseif a == "--window" then opts.window = true
    elseif a == "--screenshot" then opts.screenshot = true
    elseif a == "--tolerance" then
      i = i + 1
      opts.tolerance = tonumber( args[ i ] ) or 0.01
    else
      opts.files[ #opts.files+1 ] = a
    end
    i = i + 1
  end
  -- Рекурсивный сбор.
  if opts.recursive then
    local expanded = {}
    for _, f in ipairs( opts.files ) do
      if is_dir( f ) then
        collect_recursive( f, expanded )
      else
        expanded[ #expanded+1 ] = f
      end
    end
    opts.files = expanded
  end
  return opts
end

function M.help_text()
  return [[
Usage: testy.lua [flags] <files>...
Flags:
  -r              recursive: also scan required modules
  -t              TAP output
  -v              verbose
  -h, --help      this message
  --mock-love     install LOVE mocks (standalone mode)
  --no-extra      do not auto-load testy.extra
LOVE mode (passed after `love . --test`):
  --window        run with visible window
  --screenshot    capture screenshots for comparison
  --tolerance N   pixel tolerance (default 0.01)
]]
end

return M
