local window = require( "testy.mocks.window" )

local function test_getMode_three_values()
  window.install()
  window.reset()
  local w, h, flags = love.window.getMode()
  assert( type( w ) == "number" )
  assert( type( h ) == "number" )
  assert( type( flags ) == "table" )
end

local function test_setMode_updates()
  window.install()
  window.reset()
  love.window.setMode( 800, 600 )
  local w, h = love.window.getMode()
  assert( w == 800 )
  assert( h == 600 )
end

return {}
