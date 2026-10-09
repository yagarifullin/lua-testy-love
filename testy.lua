#!/usr/bin/env lua

-- Testy: оригинал + патч (SKIP, mock-love, CLI).
-- Публичное API сохранено. Формат вывода сохранён, добавлен SKIP.

local prefix = "test_"
local pass_char, fail_char, skip_char = ".", "X", "S"
local max_line = 72
local gap = " "
local fh = io.stderr

local files, chunks, do_recursive, do_tap = {}, {}, false, false
local tests, test_functions = {}, {}
local n_tests, n_passed, n_errors, n_skipped = 0, 0, 0, 0
local cursor_pos = 0
local locals = {}
local thischunk = debug.getinfo( 1, "f" ).func
local assert = assert
local extra_ok, extra = pcall( require, "testy.extra" )
if not extra_ok then extra = {} end

-- Патч: SKIP-статус, TAP SKIP, mock-love, no-extra, verbose, help.
local do_mock_love, do_no_extra, do_verbose, do_help = false, false, false, false

-- Стек SKIP-причин по test-функциям (на случай вложенных вызовов).
local skip_reasons = {}

local function evaluate_test_assertion( finfo, cinfo, ok, ... )
  n_tests = n_tests + 1
  if do_tap then
    fh:write( ok and "" or "not ", "ok ", n_tests )
    local src, line = finfo.source, cinfo.currentline
    fh:write( " ", src, ":", line )
    if type( (...) ) == "string" and
       ((...):match( "^#[\t ]*[Tt][Oo][Dd][Oo]" ) or
        (...):match( "^#[\t ]*[Ss][Kk][Ii][Pp]" )) then
      fh:write( " ", (...) )
    end
    if not ok then
      local msg = (...) ~= nil and tostring( (...) )
                               or "test assertion failed!"
      fh:write( "\n# Failed test (", src, " at line ", line, ": '",
                msg:gsub( "\n", "\n#\t" ), "')" )
    end
    fh:write( "\n" )
  else
    fh:write( ok and pass_char or fail_char )
    cursor_pos = (cursor_pos + 1) % max_line
    if cursor_pos == 0 then fh:write( "\n" ) end
  end
  fh:flush()
  if ok then
    n_passed = n_passed + 1
    return ok, ...
  else
    local fail = {
      no = n_tests,
      line = cinfo.currentline,
      reason = (...) ~= nil and tostring( (...) ) or nil
    }
    finfo[ #finfo+1 ] = fail
  end
end

local function _G_assert( ok, ... )
  local info = debug.getinfo( 2, "fl" )
  local finfo = test_functions[ info.func or false ]
  if finfo then
    return evaluate_test_assertion( finfo, info, ok, ... )
  else
    return assert( ok, ... )
  end
end

local function _G_testy_assert( ok, ... )
  local info, i, finfo = debug.getinfo( 2, "fl" ), 3
  while info do
    if info.func == thischunk then break end
    finfo = test_functions[ info.func or false ]
    if finfo then break end
    info, i = debug.getinfo( i, "fl" ), i+1
  end
  if finfo then
    return evaluate_test_assertion( finfo, info, ok, ... )
  else
    error( "call to 'testy_assert' function outside of tests", 2 )
  end
end

-- Патч: функция SKIP. Используется в тестах для явного пропуска.
function _G.testy_skip( reason )
  error( "SKIP:" .. (reason or "no reason"), 2 )
end

-- Патч: тест требует LÖVE, если в шапке есть `-- testy:requires love`.
local function has_requires_love( fname )
  local f = io.open( fname, "r" )
  if not f then return false end
  local head = f:read( "*l" ) or ""
  local second = f:read( "*l" ) or ""
  f:close()
  for _, line in ipairs{ head, second } do
    if line:match( "^%-%-%s*testy:requires%s+love" ) then return true end
  end
  return false
end

local function main_chunk( lvl )
  lvl = lvl+1
  local info, i = debug.getinfo( lvl, "Sf" ), lvl+2
  if not info or info.what ~= "main" or info.func == thischunk then
    return false
  end
  if not do_recursive then
    info = debug.getinfo( lvl+1, "Sf" )
    while info and info.func ~= thischunk do
      if info.what == "main" then return false end
      info, i = debug.getinfo( i, "Sf" ), i+1
    end
  end
  return true
end

local function line_ret_hook( event, no )
  if event ~= "tail_return" and main_chunk( 2 ) then
    local info = debug.getinfo( 2, "Sf" )
    if event == "line" then
      local locs = {}
      local i, name, value = 2, debug.getlocal( 2, 1 )
      while name do
        if #name >= #prefix and
           type( value ) == "function" and
           name:sub( 1, #prefix ) == prefix then
          locs[ #locs+1 ] = {
            caption = name:sub( #prefix+1 ):gsub( "_+", function( u )
              return #u == 1 and " " or u:sub( 2 )
            end ),
            name = name,
            func = value,
            source = info.short_src,
          }
        end
        i, name, value = i+1, debug.getlocal( 2, i )
      end
      locals[ info.func ] = locs
    else
      for _,tdata in ipairs( locals[ info.func ] or {} ) do
        tests[ #tests+1 ] = tdata
        test_functions[ tdata.func ] = tdata
      end
    end
  end
end

local function loadfile_with_extra_return( fname )
  local f, msg = io.open( fname, "rb" )
  if not f then return nil, msg end
  local s = f:read( "*a" )
  if not s then return nil, "input/ouput error" end
  s = s:gsub( "^#[^\n]*", "") .. "\nreturn\n"
  local c, msg = (loadstring or load)( s, "@"..fname )
  if c then return c else return loadfile( fname ) end
end

local searchpath = package.searchpath
if not searchpath then
  local delim = package.config:match( "^(.-)\n" ):gsub( "%%", "%%%%" )
  function searchpath( name, path )
    local pname = name:gsub( "%.", delim ):gsub( "%%", "%%%%" )
    local msg = {}
    for subpath in path:gmatch( "[^;]+" ) do
      local fpath = subpath:gsub( "%?", pname )
      local f = io.open( fpath, "r" )
      if f then f:close() return fpath end
      msg[ #msg+1 ] = "\n\tno file '"..fpath.."'"
    end
    return nil, table.concat( msg )
  end
end

local function lua_searcher( modname )
  assert( type( modname ) == "string" )
  local fn, msg = searchpath( modname, package.path )
  if not fn then return msg end
  local mod, msg = loadfile_with_extra_return( fn )
  if not mod then
    error( "error loading module '"..modname.."' from file '"..fn..
           "':\n\t"..msg, 0 )
  end
  return mod, fn
end

-- Патч: используем testy/cli.lua для рекурсивного сбора файлов.
-- Если cli.lua недоступен — fallback на оригинальный парсинг.
local cli_ok, cli = pcall( require, "testy.cli" )
if cli_ok and cli and cli.parse then
  local opts = cli.parse( _G.arg )
  do_recursive = opts.recursive
  do_tap       = opts.tap
  do_mock_love = opts.mock_love
  do_no_extra  = opts.no_extra
  do_verbose   = opts.verbose
  do_help      = opts.help
  for _, f in ipairs( opts.files ) do
    files[ #files+1 ] = f
  end
  -- Очищаем arg, как в оригинале.
  for i = #_G.arg, 1, -1 do
    _G.arg[ i ] = nil
  end
else
  -- Fallback: оригинальный парсинг.
  for i,a in ipairs( _G.arg ) do
    if a == "-r" then
      do_recursive = true
    elseif a == "-t" then
      do_tap = true
      fh = io.stdout
    elseif a == "--mock-love" then
      do_mock_love = true
    elseif a == "--no-extra" then
      do_no_extra = true
    elseif a == "-v" then
      do_verbose = true
    elseif a == "-h" or a == "--help" then
      do_help = true
    else
      files[ #files+1 ] = a
    end
    _G.arg[ i ] = nil
  end
end

if do_help then
  io.stdout:write([[
Usage: testy.lua [flags] <files>...
Flags:
  -r              recursive: also scan required modules
  -t              TAP output
  -v              verbose
  -h, --help      this message
  --mock-love     install LOVE mocks (standalone mode)
  --no-extra      do not auto-load testy.extra
]])
  os.exit( 0, true )
end

if do_no_extra then extra = {} end

if do_mock_love then
  local ok, mock_init = pcall( require, "testy.mocks.init" )
  if ok and mock_init and mock_init.install then
    mock_init.install()
  end
end

-- Загрузка файлов.
for i,f in ipairs( files ) do
  chunks[ i ] = assert( loadfile_with_extra_return( f ) )
end

if do_recursive then
  local searchers = package.searchers or package.loaders
  local off = 0
  if package.loaded[ "luarocks.loader" ] then off = 1 end
  searchers[ 2+off ] = lua_searcher
end

-- Определяем, какие файлы требуют LÖVE (по метке в шапке).
local files_require_love = {}
for i, f in ipairs( files ) do
  files_require_love[ f ] = has_requires_love( f )
end

-- Запуск чанков.
for i,c in ipairs( chunks ) do
  _G.arg[ 0 ] = files[ i ]
  _G.assert = _G_assert
  debug.sethook( line_ret_hook, "lr" )
  c( "module.test", files[ i ] )
  debug.sethook()
end

-- Запуск тестов.
for _,t in ipairs( tests ) do
  if do_tap then
    fh:write( "# ", t.caption, " ('", t.source, "')\n" )
  else
    local headerlen = #t.caption + #t.source + #gap + 5
    fh:write( t.caption, " ('", t.source, "')" )
    if headerlen >= max_line then
      fh:write( "\n" )
    else
      fh:write( gap )
      cursor_pos = headerlen
    end
  end
  fh:flush()

  -- Патч: если файл требует LÖVE, а мы в standalone без моков — SKIP.
  local src_file = t.source:gsub( "^@", "" )
  local requires_love = files_require_love[ src_file ]
                     or files_require_love[ t.source ]

  if requires_love and not do_mock_love then
    n_skipped = n_skipped + 1
    if do_tap then
      fh:write( "ok ", n_tests+1, " # SKIP requires LOVE\n" )
      n_tests = n_tests + 1
    else
      fh:write( "SKIP (requires LOVE)\n" )
    end
    fh:flush()
    cursor_pos = 0
  else
    _G.assert = _G_assert
    _G.testy_assert = _G_testy_assert
    for k,v in pairs( extra ) do _G[ k ] = v end

    -- Оборачиваем вызов для перехвата SKIP-ошибок.
    local ok, msg = xpcall( function()
      -- Обёртка для перехвата SKIP
      local co_ok, co_msg = pcall( t.func )
      if not co_ok and type(co_msg) == "string"
         and co_msg:match("^SKIP:") then
        error( co_msg, 0 )
      elseif not co_ok then
        error( co_msg, 0 )
      end
    end, debug.traceback )

    if cursor_pos ~= 0 then
      fh:write( "\n" )
      cursor_pos = 0
    end

    if not ok and type(msg) == "string" and msg:match( "SKIP:" ) then
      -- Это SKIP.
      n_skipped = n_skipped + 1
      local reason = msg:match( "SKIP:([^\n]*)" ) or "no reason"
      if do_tap then
        fh:write( "ok ", n_tests+1, " # SKIP ", reason, "\n" )
        n_tests = n_tests + 1
      else
        fh:write( "SKIP (", reason, ")\n" )
      end
    elseif not ok then
      n_errors = n_errors + 1
      if do_tap then
        fh:write( "# [ERROR] test function '", t.name, "' died:\n# ",
                  msg:gsub( "\n", "\n# " ), "\n" )
      else
        fh:write( "[ERROR] test function '", t.name, "' died:\n ",
                  msg:gsub( "\n", "\n " ), "\n" )
      end
    else
      if not do_tap then
        for _,f in ipairs( t ) do
          fh:write( "[FAIL] ", t.source, ":", f.line,
                    ": in function '", t.name, "'\n" )
          if f.reason then
            fh:write( "\t", f.reason:gsub( "\n\t?", "\n\t" ), "\n" )
          end
        end
      end
    end
    fh:flush()
  end
end

if do_tap then
  fh:write( "1..", n_tests+n_errors, "\n" )
else
  fh:write( n_tests, " tests (", n_passed, " ok, ", n_tests-n_passed,
            " failed, ", n_errors, " errors, ", n_skipped, " skipped)\n" )
end
fh:flush()

if not do_tap and n_tests ~= n_passed or n_errors > 0 then
  os.exit( 1, true )
end
