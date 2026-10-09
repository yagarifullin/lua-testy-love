-- -- testy:requires love

local M = {}

function M.screen_size()
  return love.graphics.getWidth(), love.graphics.getHeight()
end

function M.new_image( path )
  return love.graphics.newImage( path )
end

function M.play_sound( path )
  local src = love.audio.newSource( path, "static" )
  love.audio.play( src )
  return src
end

local function test_screen_size()
  local w, h = M.screen_size()
  assert( type( w ) == "number" )
  assert( type( h ) == "number" )
  assert( w > 0 and h > 0 )
end

local function test_new_image_missing()
  -- Работает в обоих режимах: файла нет → ошибка.
  local ok = pcall( M.new_image, "no_such_file_xyz.png" )
  assert( not ok )
end

local function test_play_sound_missing()
  -- Работает в обоих режимах: файла нет → ошибка.
  local ok = pcall( M.play_sound, "no_such_sound_xyz.ogg" )
  assert( not ok )
end

return M
