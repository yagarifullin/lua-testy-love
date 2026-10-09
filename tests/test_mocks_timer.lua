-- Тесты мока love.timer.
local timer = require( "testy.mocks.timer" )

local function test_getTime_no_mutation()
  timer.install()
  timer.reset()
  local t0 = love.timer.getTime()
  local t1 = love.timer.getTime()
  assert( t0 == t1 )
end

local function test_advance()
  timer.install()
  timer.reset()
  local t0 = love.timer.getTime()
  timer.advance( 0.5 )
  local t1 = love.timer.getTime()
  assert( t1 - t0 == 0.5 )
end

local function test_getDelta()
  timer.install()
  timer.reset()
  timer.advance( 0.1 )
  assert( love.timer.getDelta() == 0.1 )
  timer.advance( 0.2 )
  assert( love.timer.getDelta() == 0.2 )
end

local function test_getFPS()
  timer.install()
  assert( love.timer.getFPS() == 60 )
end

local function test_sleep_noop()
  timer.install()
  love.timer.sleep( 1 )  -- не должно падать
  assert( true )
end

return {}
