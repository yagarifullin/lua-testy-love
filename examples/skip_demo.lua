-- examples/skip_demo.lua
local function test_always_skip()
  testy_skip( "not implemented yet" )
end

local function test_after_skip()
  assert( 1 == 1 )
end

return {}
