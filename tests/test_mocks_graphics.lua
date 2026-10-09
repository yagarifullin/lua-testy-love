local graphics = require( "testy.mocks.graphics" )
local window = require( "testy.mocks.window" )

local function test_getWidth_reflects_window()
  window.install()
  graphics.install()
  window.reset()
  love.window.setMode( 640, 480 )
  assert( love.graphics.getWidth() == 640 )
  assert( love.graphics.getHeight() == 480 )
end

local function test_newImage_missing_errors()
  graphics.install()
  local ok = pcall( love.graphics.newImage, "nonexistent_file.png" )
  assert( not ok )
end

local function test_newImage_existing()
  graphics.install()
  local img = love.graphics.newImage( "testy.lua" )
  assert( img ~= nil )
  assert( img:getWidth() == 100 )
end

local function test_draw_spy()
  graphics.install()
  graphics.reset()
  love.graphics.draw( "sprite", 10, 20 )
  local calls = graphics.get_draw_calls()
  assert( #calls == 1 )
  assert( calls[1][1] == "sprite" )
  assert( calls[1][2] == 10 )
  assert( calls[1][3] == 20 )
end

return {}
