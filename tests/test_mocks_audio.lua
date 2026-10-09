-- tests/test_mocks_audio.lua
local audio = require( "testy.mocks.audio" )

local function test_newSource()
  audio.install()
  -- Используем существующий файл.
  local src = love.audio.newSource( "testy.lua", "static" )
  assert( src ~= nil )
  assert( type( src.play ) == "function" )
end

local function test_newSource_missing()
  audio.install()
  -- Мок должен кидать ошибку, если файла нет.
  local ok = pcall( love.audio.newSource, "no_such_file_xyz.ogg", "static" )
  assert( not ok )
end

local function test_play_spy()
  audio.install()
  audio.reset()
  local src = love.audio.newSource( "testy.lua", "static" )
  love.audio.play( src )
  assert( #audio.get_play_calls() == 1 )
end

return {}
