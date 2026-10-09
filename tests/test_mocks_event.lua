local event = require( "testy.mocks.event" )

local function test_quit_captured()
  event.install()
  event.reset()
  love.event.quit( 0 )
  assert( #event.calls() == 1 )
  assert( event.calls()[1] == 0 )
end

local function test_quit_with_code()
  event.install()
  event.reset()
  love.event.quit( 1 )
  assert( event.calls()[1] == 1 )
end

local function test_quit_default_zero()
  event.install()
  event.reset()
  love.event.quit()
  assert( event.calls()[1] == 0 )
end

return {}
